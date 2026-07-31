import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Not, Repository } from 'typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { PresenceService } from '../matching/presence.service';
import { NotificationsService } from '../firebase/notifications.service';

export interface PendingVerification {
  userId: string;
  role: 'craftsman' | 'client';
  fullName: string | null;
  phone: string | null;
  // Craftsman-only fields — absent for client entries.
  serviceCategory: string | null;
  experienceDetails: string | null;
  idCardStorageKey: string;
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
    const craftsmanProfiles = await this.craftsmanProfileRepository.find({
      where: {
        idVerified: false,
        isActive: true,
        idCardStorageKey: Not(IsNull()),
      },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });

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
      ...craftsmanProfiles.map((profile) => ({
        userId: profile.userId,
        role: 'craftsman' as const,
        fullName: profile.user.fullName,
        phone: profile.user.phone,
        serviceCategory: profile.serviceCategory,
        experienceDetails: profile.experienceDetails,
        idCardStorageKey: profile.idCardStorageKey!,
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
        createdAt: profile.createdAt,
      })),
    ];

    return entries.sort(
      (a, b) => a.createdAt.getTime() - b.createdAt.getTime(),
    );
  }

  async verifyCraftsman(userId: string): Promise<void> {
    const result = await this.craftsmanProfileRepository.update(
      { userId },
      { idVerified: true },
    );
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
        body: reason ?? 'Votre document a été refusé. Merci de le soumettre à nouveau.',
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
        body: reason ?? 'Votre document a été refusé. Merci de le soumettre à nouveau.',
      },
      { type: 'id_verification_rejected' },
    );
  }
}
