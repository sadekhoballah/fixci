import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Not, Repository } from 'typeorm';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { PresenceService } from '../matching/presence.service';

export interface PendingVerification {
  userId: string;
  fullName: string | null;
  phone: string;
  serviceCategory: string;
  experienceDetails: string | null;
  idCardStorageKey: string;
  createdAt: Date;
}

@Injectable()
export class AdminService {
  constructor(
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    private readonly presenceService: PresenceService,
  ) {}

  // Deactivated craftsmen (isActive: false) are deliberately excluded —
  // rejecting via deactivateCraftsman() is how a review gets resolved, so a
  // rejected account shouldn't keep reappearing in the queue.
  async getPendingVerifications(): Promise<PendingVerification[]> {
    const profiles = await this.craftsmanProfileRepository.find({
      where: {
        idVerified: false,
        isActive: true,
        idCardStorageKey: Not(IsNull()),
      },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });

    return profiles.map((profile) => ({
      userId: profile.userId,
      fullName: profile.user.fullName,
      phone: profile.user.phone,
      serviceCategory: profile.serviceCategory,
      experienceDetails: profile.experienceDetails,
      idCardStorageKey: profile.idCardStorageKey!,
      createdAt: profile.createdAt,
    }));
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
  async deactivateCraftsman(userId: string): Promise<void> {
    const result = await this.craftsmanProfileRepository.update(
      { userId },
      { isActive: false, isAvailable: false },
    );
    if (result.affected === 0) {
      throw new NotFoundException('No craftsman profile for this account');
    }
    await this.presenceService.setOffline(userId);
  }
}
