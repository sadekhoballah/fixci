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
  countryCode: string;
  isArtisanRegistrationActive: boolean;
  isClientOrderingActive: boolean;
  artisansCount: number;
  verifiedArtisansCount: number;
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

  // One grouped query (not two COUNTs per district). Deleted accounts are
  // left out; verifiedArtisansCount (ID approved, account active) is what
  // tells whether a waitlisted city has enough craftsmen to open to clients.
  async listWithCounts(): Promise<DistrictWithCounts[]> {
    const rows: Array<{
      id: string;
      name: string;
      country_code: string;
      is_artisan_registration_active: boolean;
      is_client_ordering_active: boolean;
      artisans_count: number;
      verified_artisans_count: number;
      clients_count: number;
    }> = await this.districtRepository.query(
      `SELECT d.id, d.name, d.country_code,
              d.is_artisan_registration_active, d.is_client_ordering_active,
              COUNT(cp.user_id)::int AS artisans_count,
              COUNT(cp.user_id) FILTER (
                WHERE cp.id_verified AND cp.is_active)::int
                AS verified_artisans_count,
              COUNT(kp.user_id)::int AS clients_count
       FROM districts d
       LEFT JOIN users u ON u.district_id = d.id AND u.deleted_at IS NULL
       LEFT JOIN craftsman_profiles cp ON cp.user_id = u.id
       LEFT JOIN client_profiles kp ON kp.user_id = u.id
       GROUP BY d.id
       ORDER BY d.name`,
    );
    return rows.map((row) => ({
      id: row.id,
      name: row.name,
      countryCode: row.country_code,
      isArtisanRegistrationActive: row.is_artisan_registration_active,
      isClientOrderingActive: row.is_client_ordering_active,
      artisansCount: row.artisans_count,
      verifiedArtisansCount: row.verified_artisans_count,
      clientsCount: row.clients_count,
    }));
  }

  // Defaults both toggles closed: unlike the seeded districts (presumed
  // already-operating markets), a district an admin adds later represents a
  // not-yet-launched expansion target — see the migration's own comment.
  async create(name: string, countryCode: string): Promise<District> {
    return this.districtRepository.save(
      this.districtRepository.create({
        name,
        countryCode,
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
