import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Not, Repository } from 'typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { PresenceService } from '../matching/presence.service';
import { NotificationsService } from '../firebase/notifications.service';

const LICENSE_REQUIRED_CATEGORIES = [
  ServiceCategory.TAXI,
  ServiceCategory.CAMION,
];

export interface PendingVerification {
  userId: string;
  role: 'craftsman' | 'client';
  fullName: string | null;
  phone: string | null;
  // Craftsman-only fields — absent for client entries.
  serviceCategory: string | null;
  experienceDetails: string | null;
  idCardStorageKey: string;
  // Craftsman-only, and only ever set for taxi/camion (see
  // CraftsmanProfile.licenseStorageKey) — null for every other role/category.
  licenseStorageKey: string | null;
  licenseVerified: boolean;
  createdAt: Date;
}

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    private readonly presenceService: PresenceService,
    private readonly notificationsService: NotificationsService,
  ) {}

  // A single combined queue for both account types, oldest first — mirrors
  // the same review flow for craftsmen and clients so the admin only has one
  // screen to check. Deactivated accounts (isActive: false) are deliberately
  // excluded from both halves — rejecting is how a review gets resolved, so
  // a rejected account shouldn't keep reappearing in the queue.
  async getPendingVerifications(): Promise<PendingVerification[]> {
    // Craftsman queue is an OR of two conditions: the normal "ID card not
    // yet verified" case (every category), plus — taxi/camion only — "ID
    // card verified but the license isn't yet", so those two categories
    // never disappear from the queue after just one of their two documents
    // is approved. A profile can match both conditions at once (neither
    // document verified yet), hence the de-dup by userId below.
    const craftsmanProfiles = await this.craftsmanProfileRepository.find({
      where: [
        { idVerified: false, isActive: true, idCardStorageKey: Not(IsNull()) },
        {
          serviceCategory: In(LICENSE_REQUIRED_CATEGORIES),
          licenseVerified: false,
          isActive: true,
          idCardStorageKey: Not(IsNull()),
          licenseStorageKey: Not(IsNull()),
        },
      ],
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });
    const dedupedCraftsmanProfiles = [
      ...new Map(
        craftsmanProfiles.map((profile) => [profile.userId, profile]),
      ).values(),
    ];

    const clientProfiles = await this.clientProfileRepository.find({
      where: {
        idVerified: false,
        isActive: true,
        idCardStorageKey: Not(IsNull()),
      },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });

    const entries: PendingVerification[] = [
      ...dedupedCraftsmanProfiles.map((profile) => ({
        userId: profile.userId,
        role: 'craftsman' as const,
        fullName: profile.user.fullName,
        phone: profile.user.phone,
        serviceCategory: profile.serviceCategory,
        experienceDetails: profile.experienceDetails,
        idCardStorageKey: profile.idCardStorageKey!,
        licenseStorageKey: profile.licenseStorageKey,
        licenseVerified: profile.licenseVerified,
        createdAt: profile.createdAt,
      })),
      ...clientProfiles.map((profile) => ({
        userId: profile.userId,
        role: 'client' as const,
        fullName: profile.user.fullName,
        phone: profile.user.phone,
        serviceCategory: null,
        experienceDetails: null,
        idCardStorageKey: profile.idCardStorageKey!,
        licenseStorageKey: null,
        licenseVerified: false,
        createdAt: profile.createdAt,
      })),
    ];

    return entries.sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
    );
  }

  // A single "Approuver" action covers both documents at once — there's no
  // separate per-document review flow (see AdminKycScreen), so this also
  // marks the license verified whenever one was submitted. Harmless for
  // every category other than taxi/camion: licenseStorageKey stays null for
  // them forever, so this update is a no-op for that column in practice.
  async verifyCraftsman(userId: string): Promise<void> {
    const result = await this.craftsmanProfileRepository
      .createQueryBuilder()
      .update(CraftsmanProfile)
      .set({
        idVerified: true,
        licenseVerified: () =>
          `CASE WHEN "license_storage_key" IS NOT NULL THEN true ELSE "license_verified" END`,
      })
      .where('user_id = :userId', { userId })
      .execute();
    if (result.affected === 0) {
      throw new NotFoundException('No craftsman profile for this account');
    }
  }

  // The "reject" action from the review screen: stops the craftsman from
  // ever going online again (see PresenceService.setOnline) and immediately
  // pulls them out of presence if they're online right now.
  async deactivateCraftsman(userId: string, reason?: string): Promise<void> {
    const result = await this.craftsmanProfileRepository.update(
      { userId },
      {
        isActive: false,
        isAvailable: false,
        idRejectionReason: reason ?? null,
      },
    );
    if (result.affected === 0) {
      throw new NotFoundException('No craftsman profile for this account');
    }
    await this.presenceService.setOffline(userId);
    await this.notificationsService.sendToUser(
      userId,
      {
        title: 'Compte non validé',
        body:
          reason ??
          'Votre document a été refusé. Merci de le soumettre à nouveau.',
      },
      { type: 'id_verification_rejected' },
    );
  }

  async verifyClient(userId: string): Promise<void> {
    const result = await this.clientProfileRepository.update(
      { userId },
      { idVerified: true },
    );
    if (result.affected === 0) {
      throw new NotFoundException('No client profile for this account');
    }
  }

  // Clients have no presence/online concept to pull them out of — unlike
  // deactivateCraftsman, this is just the isActive flip the client app reads
  // to show the "rejected, please resubmit" state.
  async deactivateClient(userId: string, reason?: string): Promise<void> {
    const result = await this.clientProfileRepository.update(
      { userId },
      { isActive: false, idRejectionReason: reason ?? null },
    );
    if (result.affected === 0) {
      throw new NotFoundException('No client profile for this account');
    }
    await this.notificationsService.sendToUser(
      userId,
      {
        title: 'Compte non validé',
        body:
          reason ??
          'Votre document a été refusé. Merci de le soumettre à nouveau.',
      },
      { type: 'id_verification_rejected' },
    );
  }
}
