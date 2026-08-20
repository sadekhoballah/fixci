import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Not, Repository } from 'typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { Mission } from '../database/entities/mission.entity';
import { MissionStatus } from '../database/enums/mission-status.enum';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { PresenceService } from '../matching/presence.service';
import { MatchingGateway } from '../matching/matching.gateway';
import { NotificationsService } from '../firebase/notifications.service';
import { SafetyService, PendingReport } from '../safety/safety.service';
import { ReportStatus } from '../database/enums/report-status.enum';
import { ResolveReportDto } from './dto/resolve-report.dto';

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
    @InjectRepository(Mission)
    private readonly missionRepository: Repository<Mission>,
    private readonly presenceService: PresenceService,
    private readonly notificationsService: NotificationsService,
    private readonly matchingGateway: MatchingGateway,
    private readonly safetyService: SafetyService,
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

  // Oldest first, mirrors getPendingVerifications — the queue an admin
  // works through top to bottom.
  async getPendingMissions(): Promise<Mission[]> {
    return this.missionRepository.find({
      where: { status: MissionStatus.PENDING_MODERATION },
      relations: { poster: true },
      order: { createdAt: 'ASC' },
    });
  }

  async getMission(id: string): Promise<Mission> {
    const mission = await this.missionRepository.findOne({
      where: { id },
      relations: { poster: true },
    });
    if (!mission) {
      throw new NotFoundException('Mission not found');
    }
    return mission;
  }

  async approveMission(id: string): Promise<void> {
    const result = await this.missionRepository.update(
      { id, status: MissionStatus.PENDING_MODERATION },
      { status: MissionStatus.APPROVED_PUBLISHED, publishedAt: new Date() },
    );
    if (result.affected === 0) {
      throw new NotFoundException(
        'No pending mission with this id (already moderated, or missing)',
      );
    }
    const mission = await this.missionRepository.findOne({ where: { id } });
    if (mission) {
      void this.matchingGateway.notifyUser(
        mission.posterId,
        'mission:approved',
        { missionId: id },
        {
          title: 'Mission publiée',
          body: 'Votre mission est maintenant visible par les candidats.',
        },
      );
    }
  }

  async rejectMission(id: string, reason?: string): Promise<void> {
    const result = await this.missionRepository.update(
      { id, status: MissionStatus.PENDING_MODERATION },
      { status: MissionStatus.REJECTED, rejectionReason: reason ?? null },
    );
    if (result.affected === 0) {
      throw new NotFoundException(
        'No pending mission with this id (already moderated, or missing)',
      );
    }
    const mission = await this.missionRepository.findOne({ where: { id } });
    if (mission) {
      void this.matchingGateway.notifyUser(
        mission.posterId,
        'mission:rejected',
        { missionId: id },
        {
          title: 'Mission refusée',
          body: reason ?? 'Votre mission a été refusée par la modération.',
        },
      );
    }
  }

  // Pending-only, oldest first — see SafetyService.getPendingReports.
  async getPendingReports(): Promise<PendingReport[]> {
    return this.safetyService.getPendingReports();
  }

  async resolveReport(reportId: string, dto: ResolveReportDto): Promise<void> {
    if (dto.action === 'deactivate_reported') {
      const reportedUserId = await this.safetyService.getReportedUserId(
        reportId,
      );
      await this.suspendReportedUser(reportedUserId, dto.note);
    }
    await this.safetyService.markReportResolved(
      reportId,
      dto.action === 'dismiss' ? ReportStatus.DISMISSED : ReportStatus.RESOLVED,
      dto.note,
    );
  }

  // Role-agnostic isActive flip for a reported account — deliberately NOT
  // deactivateCraftsman/deactivateClient above: those two exist for the KYC
  // review flow and their push copy ("votre document a été refusé...")
  // would be actively misleading here. Tries the craftsman profile first,
  // falls back to the client one; a User row is always exactly one or the
  // other (see User.role), so exactly one of these two updates ever matches.
  private async suspendReportedUser(
    userId: string,
    reason?: string,
  ): Promise<void> {
    const craftsmanResult = await this.craftsmanProfileRepository.update(
      { userId },
      { isActive: false, isAvailable: false },
    );
    if ((craftsmanResult.affected ?? 0) > 0) {
      await this.presenceService.setOffline(userId);
    } else {
      const clientResult = await this.clientProfileRepository.update(
        { userId },
        { isActive: false },
      );
      if ((clientResult.affected ?? 0) === 0) {
        throw new NotFoundException('No profile for this account');
      }
    }
    void this.notificationsService.sendToUser(
      userId,
      {
        title: 'Compte suspendu',
        body:
          reason ??
          'Votre compte a été suspendu suite à un signalement. Contactez-nous si vous pensez qu’il s’agit d’une erreur.',
      },
      { type: 'account_suspended_report' },
    );
  }
}
