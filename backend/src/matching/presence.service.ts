import { Inject, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';

export interface NearbyCraftsman {
  craftsmanId: string;
  distanceMeters: number;
}

// Presence (who's online, where) lives entirely in Redis, not Postgres:
// going online/offline is frequent and ephemeral, and GEOSEARCH gives O(log N)
// nearest-candidate lookups without touching the DB on the matching hot path.
@Injectable()
export class PresenceService {
  constructor(
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
  ) {}

  private geoKey(category: ServiceCategory): string {
    return `presence:geo:${category}`;
  }

  private categoryKey(craftsmanId: string): string {
    return `presence:category:${craftsmanId}`;
  }

  // The single choke point both go-online paths (REST PATCH
  // /craftsmen/me/availability and the socket craftsman:online event) go
  // through — an admin-deactivated craftsman (craftsman_profiles.is_active)
  // can never re-enter the Redis presence index, so they stop being
  // findable as a matching candidate immediately, without touching the
  // matching algorithm itself. Returns false instead of throwing so callers
  // in different contexts (HTTP vs. socket) can each decide how to surface
  // that.
  async setOnline(
    craftsmanId: string,
    category: ServiceCategory,
    longitude: number,
    latitude: number,
  ): Promise<boolean> {
    const profile = await this.craftsmanProfileRepository.findOne({
      where: { userId: craftsmanId },
    });
    if (!profile?.isActive) return false;

    await Promise.all([
      this.redis.geoadd(
        this.geoKey(category),
        longitude,
        latitude,
        craftsmanId,
      ),
      this.redis.set(this.categoryKey(craftsmanId), category),
    ]);
    return true;
  }

  async updateLocation(
    craftsmanId: string,
    longitude: number,
    latitude: number,
  ): Promise<void> {
    const category = await this.redis.get(this.categoryKey(craftsmanId));
    if (!category) return; // not currently online, ignore stray location pings
    await this.redis.geoadd(
      this.geoKey(category as ServiceCategory),
      longitude,
      latitude,
      craftsmanId,
    );
  }

  async setOffline(craftsmanId: string): Promise<void> {
    const category = await this.redis.get(this.categoryKey(craftsmanId));
    if (category) {
      await this.redis.zrem(
        this.geoKey(category as ServiceCategory),
        craftsmanId,
      );
    }
    await this.redis.del(this.categoryKey(craftsmanId));
  }

  async findNearest(
    category: ServiceCategory,
    longitude: number,
    latitude: number,
    radiusMeters: number,
    count: number,
  ): Promise<NearbyCraftsman[]> {
    const results = (await this.redis.geosearch(
      this.geoKey(category),
      'FROMLONLAT',
      longitude,
      latitude,
      'BYRADIUS',
      radiusMeters,
      'm',
      'ASC',
      'COUNT',
      count,
      'WITHDIST',
    )) as [string, string][];

    return results.map(([craftsmanId, distance]) => ({
      craftsmanId,
      distanceMeters: Number(distance),
    }));
  }
}
