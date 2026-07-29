import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { ILike, Repository } from 'typeorm';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { PresenceService } from '../matching/presence.service';

export interface DirectoryEntry {
  userId: string;
  fullName: string | null;
  phone: string;
  districtName: string;
  isOnline: boolean;
}

export interface CraftsmanDirectoryEntry extends DirectoryEntry {
  serviceCategory: ServiceCategory;
}

@Injectable()
export class DirectoryService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    private readonly presenceService: PresenceService,
  ) {}

  async listClients(search?: string): Promise<DirectoryEntry[]> {
    const onlineIds = new Set(await this.presenceService.listOnlineClientIds());
    const users = await this.userRepository.find({
      where: search
        ? { role: UserRole.CLIENT, phone: ILike(`%${search}%`) }
        : { role: UserRole.CLIENT },
      relations: { district: true },
      order: { fullName: 'ASC' },
    });
    return users.map((user) => ({
      userId: user.id,
      fullName: user.fullName,
      phone: user.phone,
      districtName: user.district.name,
      isOnline: onlineIds.has(user.id),
    }));
  }

  async listCraftsmen(
    search?: string,
    category?: ServiceCategory,
  ): Promise<CraftsmanDirectoryEntry[]> {
    // "Online" here reuses the same Redis presence PresenceService.listOnline
    // already exposes for the Live Ops roster (module 4) — a craftsman is
    // online when they've explicitly gone available, not just connected.
    const online = await this.presenceService.listOnline();
    const onlineIds = new Set(online.map((entry) => entry.craftsmanId));

    const qb = this.craftsmanProfileRepository
      .createQueryBuilder('cp')
      .innerJoinAndSelect('cp.user', 'user')
      .innerJoinAndSelect('user.district', 'district')
      .orderBy('user.fullName', 'ASC');
    if (search) {
      qb.andWhere('user.phone ILIKE :search', { search: `%${search}%` });
    }
    if (category) {
      qb.andWhere('cp.serviceCategory = :category', { category });
    }
    const profiles = await qb.getMany();

    return profiles.map((profile) => ({
      userId: profile.userId,
      fullName: profile.user.fullName,
      phone: profile.user.phone,
      districtName: profile.user.district.name,
      serviceCategory: profile.serviceCategory,
      isOnline: onlineIds.has(profile.userId),
    }));
  }
}
