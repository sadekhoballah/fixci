import {
  ConflictException,
  ForbiddenException,
  Inject,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { unlink } from 'fs/promises';
import { join } from 'path';
import { DataSource, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import type Redis from 'ioredis';
import { REDIS_CLIENT } from '../redis/redis.constants';
import { takeIdDocAnalysis } from '../uploads/id-doc-analysis.store';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { District } from '../database/entities/district.entity';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { SubscriptionTier } from '../database/enums/subscription-tier.enum';
import { RegisterUserDto } from './dto/register-user.dto';
import { TokensService } from '../auth/tokens.service';
import { PresenceService } from '../matching/presence.service';
import { UPLOADS_ROOT } from '../uploads/uploads.constants';

const UNIQUE_VIOLATION = '23505';

// The same 4 "unresolved" statuses service_requests_one_active_per_client
// already treats as "still open" — self-service deletion is blocked while
// either party has one, so an account can't vanish out from under a
// counterparty mid-job.
const ACTIVE_REQUEST_STATUSES = [
  'pending',
  'assigned',
  'in_progress',
  'awaiting_client_confirmation',
];

@Injectable()
export class UsersService {
  private readonly logger = new Logger(UsersService.name);

  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    @InjectRepository(District)
    private readonly districtRepository: Repository<District>,
    @InjectRepository(BlacklistedPhone)
    private readonly blacklistedPhoneRepository: Repository<BlacklistedPhone>,
    private readonly dataSource: DataSource,
    private readonly tokensService: TokensService,
    private readonly presenceService: PresenceService,
    @Inject(REDIS_CLIENT) private readonly redis: Redis,
  ) {}

  async findByPhone(phone: string): Promise<User | null> {
    return this.userRepository.findOne({ where: { phone } });
  }

  // Called on every app launch/login and whenever FCM hands the app a
  // refreshed token — always overwrites rather than merging, since a device
  // switch or reinstall means the old token is dead anyway (see the fcmToken
  // column comment on the entity).
  async updateFcmToken(userId: string, fcmToken: string): Promise<void> {
    await this.userRepository.update({ id: userId }, { fcmToken });
  }

  // Only meaningful for a craftsman — used by GET /users/lookup so a
  // returning craftsman (reinstalled app, cleared local storage) lands
  // straight back on their dashboard instead of being routed through tier
  // selection again as if they'd never subscribed.
  async findCraftsmanTier(userId: string): Promise<SubscriptionTier | null> {
    const profile = await this.craftsmanProfileRepository.findOne({
      where: { userId },
    });
    return profile?.subscriptionTier ?? null;
  }

  async register(dto: RegisterUserDto): Promise<User> {
    const existing = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new ConflictException('Phone number already registered');
    }

    // Unlike a closed district (a waitlist — see below), a blacklisted
    // phone is a hard rejection: no account gets created at all.
    const blacklisted = await this.blacklistedPhoneRepository.findOne({
      where: { phone: dto.phone },
    });
    if (blacklisted) {
      throw new ForbiddenException('This phone number cannot be registered');
    }

    // Registration itself is never blocked by a closed district — that's
    // what makes it a waitlist rather than a rejection (see District
    // entity). Only existence is checked here; the toggle state is
    // enforced later, at the point where it actually matters (going
    // online / creating a service request).
    const district = await this.districtRepository.findOne({
      where: { id: dto.districtId },
    });
    if (!district) {
      throw new NotFoundException('District introuvable');
    }

    // Verified outside the transaction: throws UnauthorizedException if the
    // token is invalid/expired or wasn't issued for this exact phone (see
    // TokensService.verifyRegistrationToken) — registration can't proceed
    // without having passed OTP verification via POST /auth/otp/check first.
    await this.tokensService.verifyRegistrationToken(
      dto.registrationToken,
      dto.phone,
    );

    // Google Vision verdict stashed by POST /uploads/id-card (and /license)
    // — read once, deleted, and carried onto the profile below. A Redis
    // failure here must never fail a registration: worst case the profile
    // stores no auto-check and the admin panel shows "non analysé".
    const idAutoCheck = await takeIdDocAnalysis(
      this.redis,
      dto.idCardStorageKey,
    ).catch(() => null);
    const licenseAutoCheck =
      dto.role === UserRole.CRAFTSMAN
        ? await takeIdDocAnalysis(this.redis, dto.licenseStorageKey).catch(
            () => null,
          )
        : null;

    try {
      return await this.dataSource.transaction(async (manager) => {
        // phoneVerified: the registrationToken above is proof Twilio Verify
        // approved a code sent to this exact number.
        const user = await manager.save(
          manager.create(User, {
            phone: dto.phone,
            fullName: dto.fullName ?? null,
            role: dto.role,
            districtId: dto.districtId,
            phoneVerified: true,
          }),
        );

        if (dto.role === UserRole.CRAFTSMAN) {
          await manager.save(
            manager.create(CraftsmanProfile, {
              userId: user.id,
              serviceCategory: dto.serviceCategory,
              experienceDetails: dto.experienceDetails ?? null,
              idCardStorageKey: dto.idCardStorageKey ?? null,
              idAutoCheck,
              licenseStorageKey: dto.licenseStorageKey ?? null,
              licenseAutoCheck,
            }),
          );
        } else {
          await manager.save(
            manager.create(ClientProfile, {
              userId: user.id,
              idCardStorageKey: dto.idCardStorageKey ?? null,
              idAutoCheck,
            }),
          );
        }

        return user;
      });
    } catch (error) {
      if ((error as { code?: string }).code === UNIQUE_VIOLATION) {
        throw new ConflictException('Phone number already registered');
      }
      throw error;
    }
  }

  // Self-service, irreversible account deletion. Never a hard DELETE:
  // service_requests.client_id/craftsman_id and ratings.client_id/
  // craftsman_id are ON DELETE RESTRICT (the other party's history depends
  // on this row existing), so this anonymizes in place instead — the same
  // pattern Uber/Airbnb use. Blocked entirely while the account has any
  // request in one of the four "unresolved" statuses, so a client/craftsman
  // can't vanish out from under a counterparty mid-job.
  async deleteAccount(userId: string): Promise<void> {
    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user || user.deletedAt) {
      throw new NotFoundException('Compte introuvable');
    }

    let idCardStorageKey: string | null = null;
    let licenseStorageKey: string | null = null;

    await this.dataSource.transaction(async (manager) => {
      const [{ count }]: [{ count: string }] = await manager.query(
        `SELECT count(*) FROM "service_requests"
         WHERE ("client_id" = $1 OR "craftsman_id" = $1)
           AND "status"::text = ANY($2::text[])`,
        [userId, ACTIVE_REQUEST_STATUSES],
      );
      if (Number(count) > 0) {
        throw new ConflictException(
          'Vous avez une mission en cours. Terminez-la ou annulez-la avant de supprimer votre compte.',
        );
      }

      if (user.role === UserRole.CRAFTSMAN) {
        const profile = await manager.findOne(CraftsmanProfile, {
          where: { userId },
        });
        idCardStorageKey = profile?.idCardStorageKey ?? null;
        licenseStorageKey = profile?.licenseStorageKey ?? null;
        await manager.update(
          CraftsmanProfile,
          { userId },
          {
            experienceDetails: null,
            idCardStorageKey: null,
            licenseStorageKey: null,
            location: null,
            isAvailable: false,
            isActive: false,
          },
        );
      } else {
        const profile = await manager.findOne(ClientProfile, {
          where: { userId },
        });
        idCardStorageKey = profile?.idCardStorageKey ?? null;
        await manager.update(
          ClientProfile,
          { userId },
          { idCardStorageKey: null, isActive: false },
        );
      }

      await manager.update(
        User,
        { id: userId },
        { phone: null, fullName: null, fcmToken: null, deletedAt: new Date() },
      );
    });

    // Best-effort, outside the transaction: the DB row is already the
    // source of truth by this point, so a disk/Redis failure here must
    // never undo (or appear to fail) an already-committed deletion.
    if (idCardStorageKey) {
      await unlink(join(UPLOADS_ROOT, idCardStorageKey)).catch(() => undefined);
    }
    if (licenseStorageKey) {
      await unlink(join(UPLOADS_ROOT, licenseStorageKey)).catch(
        () => undefined,
      );
    }
    if (user.role === UserRole.CRAFTSMAN) {
      await this.presenceService.setOffline(userId).catch(() => undefined);
    }
  }

  // Admin-triggered variant of deleteAccount, called from the Annuaire tab
  // (e.g. a mis-registered or misbehaving account) rather than by the user
  // themselves. Same anonymization path and the same "blocked while a
  // mission is active" guard — the admin panel is expected to call
  // MatchingService.adminCancelActiveRequests first when that guard fires.
  // The only addition is a log line, since once this returns the row itself
  // no longer holds any trace of who was deleted or why.
  async adminDeleteAccount(
    userId: string,
    adminId: string,
    reason: string | null,
  ): Promise<void> {
    await this.deleteAccount(userId);
    this.logger.warn(
      `Admin ${adminId} deleted account ${userId}${reason ? ` — ${reason}` : ''}`,
    );
  }
}
