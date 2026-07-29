import { Inject, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { ServiceCategory } from '../database/enums/service-category.enum';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { DistrictsService } from '../districts/districts.service';

export interface NearbyCraftsman {
  craftsmanId: string;
  distanceMeters: number;
}

export interface OnlineCraftsman {
  craftsmanId: string;
  category: ServiceCategory;
  onlineSince: Date | null;
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
    private readonly districtsService: DistrictsService,
  ) {}

  private geoKey(category: ServiceCategory): string {
    return `presence:geo:${category}`;
  }

  private categoryKey(craftsmanId: string): string {
    return `presence:category:${craftsmanId}`;
  }

  private onlineSinceKey(craftsmanId: string): string {
    return `presence:online_since:${craftsmanId}`;
  }

  private readonly onlineClientsKey = 'presence:online_clients';

  // The single choke point both go-online paths (REST PATCH
  // /craftsmen/me/availability and the socket craftsman:online event) go
  // through — an admin-deactivated craftsman (craftsman_profiles.is_active)
  // can never re-enter the Redis presence index, so they stop being
  // findable as a matching candidate immediately, without touching the
  // matching algorithm itself. Returns false instead of throwing so callers
  // in different contexts (HTTP vs. socket) can each decide how to surface
  // that. Also gated on the craftsman's district being open for
  // registration (see District entity) — CraftsmenService.setAvailability
  // checks this too beforehand for a precise error message, but the check
  // lives here as well so the socket path (which just silently no-ops on
  // false) can't bypass it.
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
    if (!(await this.districtsService.isArtisanRegistrationActiveForUser(craftsmanId))) {
      return false;
    }

    await Promise.all([
      this.redis.geoadd(
        this.geoKey(category),
        longitude,
        latitude,
        craftsmanId,
      ),
      this.redis.set(this.categoryKey(craftsmanId), category),
      // NX: only stamp the first time they come online, so a reconnect
      // while already online doesn't reset "online since" for the ops roster.
      this.redis.set(this.onlineSinceKey(craftsmanId), Date.now().toString(), 'NX'),
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
    await Promise.all([
      this.redis.del(this.categoryKey(craftsmanId)),
      this.redis.del(this.onlineSinceKey(craftsmanId)),
    ]);
  }

  // Admin ops roster — every craftsman currently online, across all
  // categories. No coordinates: the roster is a text list, not a map.
  async listOnline(): Promise<OnlineCraftsman[]> {
    const results: OnlineCraftsman[] = [];
    for (const category of Object.values(ServiceCategory)) {
      const craftsmanIds = await this.redis.zrange(this.geoKey(category), 0, -1);
      if (craftsmanIds.length === 0) continue;
      const sinceValues = await Promise.all(
        craftsmanIds.map((id) => this.redis.get(this.onlineSinceKey(id))),
      );
      craftsmanIds.forEach((craftsmanId, i) => {
        results.push({
          craftsmanId,
          category,
          onlineSince: sinceValues[i] ? new Date(Number(sinceValues[i])) : null,
        });
      });
    }
    return results;
  }

  // "Online" for a client means "has the app open right now" (the
  // client:join socket event, sent on launch) — unlike a craftsman there's
  // no explicit go-online action, so this is just connection tracking, not
  // a matching input. Single flag per user, same one-active-device
  // assumption as fcmToken (see User entity) — no reference counting for
  // multiple simultaneous sockets.
  async setClientOnline(clientId: string): Promise<void> {
    await this.redis.sadd(this.onlineClientsKey, clientId);
  }

  async setClientOffline(clientId: string): Promise<void> {
    await this.redis.srem(this.onlineClientsKey, clientId);
  }

  async listOnlineClientIds(): Promise<string[]> {
    return this.redis.smembers(this.onlineClientsKey);
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
