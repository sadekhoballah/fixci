import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { District } from '../database/entities/district.entity';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { UpdateDistrictTogglesDto } from './dto/update-district-toggles.dto';

export interface DistrictWithCounts {
  id: string;
  name: string;
  isArtisanRegistrationActive: boolean;
  isClientOrderingActive: boolean;
  artisansCount: number;
  clientsCount: number;
}

export interface WaitlistEntry {
  userId: string;
  fullName: string | null;
  phone: string | null;
  serviceCategory: string | null;
  registeredAt: Date;
}

@Injectable()
export class DistrictsService {
  constructor(
    @InjectRepository(District)
    private readonly districtRepository: Repository<District>,
    @InjectRepository(User)
    private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
  ) {}

  // Public, unguarded — needed at registration time, before the caller has
  // any account at all.
  async listPublic(): Promise<District[]> {
    return this.districtRepository.find({ order: { name: 'ASC' } });
  }

  async listWithCounts(): Promise<DistrictWithCounts[]> {
    const districts = await this.districtRepository.find({
      order: { name: 'ASC' },
    });
    return Promise.all(
      districts.map(async (district) => {
        const [artisansCount, clientsCount] = await Promise.all([
          this.craftsmanProfileRepository.count({
            where: { user: { districtId: district.id } },
          }),
          this.clientProfileRepository.count({
            where: { user: { districtId: district.id } },
          }),
        ]);
        return {
          id: district.id,
          name: district.name,
          isArtisanRegistrationActive: district.isArtisanRegistrationActive,
          isClientOrderingActive: district.isClientOrderingActive,
          artisansCount,
          clientsCount,
        };
      }),
    );
  }

  // Defaults both toggles closed: unlike the seeded districts (presumed
  // already-operating markets), a district an admin adds later represents a
  // not-yet-launched expansion target — see the migration's own comment.
  async create(name: string): Promise<District> {
    return this.districtRepository.save(
      this.districtRepository.create({
        name,
        isArtisanRegistrationActive: false,
        isClientOrderingActive: false,
      }),
    );
  }

  async updateToggles(
    id: string,
    dto: UpdateDistrictTogglesDto,
  ): Promise<District> {
    const district = await this.districtRepository.findOne({
      where: { id },
    });
    if (!district) {
      throw new NotFoundException('District introuvable');
    }
    if (dto.isArtisanRegistrationActive !== undefined) {
      district.isArtisanRegistrationActive = dto.isArtisanRegistrationActive;
    }
    if (dto.isClientOrderingActive !== undefined) {
      district.isClientOrderingActive = dto.isClientOrderingActive;
    }
    return this.districtRepository.save(district);
  }

  async getWaitlist(
    id: string,
  ): Promise<{ artisans: WaitlistEntry[]; clients: WaitlistEntry[] }> {
    const district = await this.districtRepository.findOne({
      where: { id },
    });
    if (!district) {
      throw new NotFoundException('District introuvable');
    }

    const [craftsmanProfiles, clientProfiles] = await Promise.all([
      this.craftsmanProfileRepository.find({
        where: { user: { districtId: id, deletedAt: IsNull() } },
        relations: { user: true },
        order: { createdAt: 'ASC' },
      }),
      this.clientProfileRepository.find({
        where: { user: { districtId: id, deletedAt: IsNull() } },
        relations: { user: true },
        order: { createdAt: 'ASC' },
      }),
    ]);

    return {
      artisans: craftsmanProfiles.map((profile) => ({
        userId: profile.userId,
        fullName: profile.user.fullName,
        phone: profile.user.phone,
        serviceCategory: profile.serviceCategory,
        registeredAt: profile.createdAt,
      })),
      clients: clientProfiles.map((profile) => ({
        userId: profile.userId,
        fullName: profile.user.fullName,
        phone: profile.user.phone,
        serviceCategory: null,
        registeredAt: profile.createdAt,
      })),
    };
  }

  async isArtisanRegistrationActiveForUser(userId: string): Promise<boolean> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: { district: true },
    });
    return user?.district?.isArtisanRegistrationActive ?? false;
  }

  async isClientOrderingActiveForUser(userId: string): Promise<boolean> {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: { district: true },
    });
    return user?.district?.isClientOrderingActive ?? false;
  }
}
