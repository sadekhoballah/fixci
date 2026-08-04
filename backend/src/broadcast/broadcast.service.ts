import {
  BadRequestException,
  Inject,
  Injectable,
  Logger,
  Optional,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Brackets, Repository } from 'typeorm';
import { App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { FIREBASE_ADMIN_APP } from '../firebase/firebase-admin.constants';
import { User } from '../database/entities/user.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { BroadcastNotification } from '../database/entities/broadcast-notification.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { SendBroadcastDto } from './dto/send-broadcast.dto';

export interface SendBroadcastResult {
  recipientCount: number;
  successCount: number;
  failureCount: number;
}

// FCM's sendEachForMulticast caps out at 500 tokens per call — batch
// larger audiences instead of failing outright.
const FCM_MULTICAST_LIMIT = 500;

@Injectable()
export class BroadcastService {
  private readonly logger = new Logger('BroadcastService');

  constructor(
    @Optional()
    @Inject(FIREBASE_ADMIN_APP)
    private readonly adminApp: App | null,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    @InjectRepository(BroadcastNotification)
    private readonly broadcastRepository: Repository<BroadcastNotification>,
  ) {}

  async list(): Promise<BroadcastNotification[]> {
    return this.broadcastRepository.find({
      order: { createdAt: 'DESC' },
      relations: { targetDistrict: true },
    });
  }

  async send(dto: SendBroadcastDto): Promise<SendBroadcastResult> {
    if (dto.serviceCategory && dto.role !== UserRole.CRAFTSMAN) {
      throw new BadRequestException(
        'serviceCategory only applies when role is craftsman',
      );
    }

    const tokens = await this.findRecipientTokens(dto);

    let successCount = 0;
    let failureCount = 0;

    if (!this.adminApp) {
      this.logger.warn(
        'Firebase Admin not configured — broadcast recorded but nothing was sent.',
      );
    } else {
      const messaging = getMessaging(this.adminApp);
      for (let i = 0; i < tokens.length; i += FCM_MULTICAST_LIMIT) {
        const batch = tokens.slice(i, i + FCM_MULTICAST_LIMIT);
        try {
          const response = await messaging.sendEachForMulticast({
            tokens: batch,
            notification: { title: dto.title, body: dto.body },
            android: { priority: 'high', notification: { channelId: 'job_updates_v2' } },
            apns: { payload: { aps: { sound: 'job_notification.caf' } } },
          });
          successCount += response.successCount;
          failureCount += response.failureCount;
        } catch (error) {
          failureCount += batch.length;
          this.logger.warn(`Broadcast batch failed: ${String(error)}`);
        }
      }
    }

    await this.broadcastRepository.save(
      this.broadcastRepository.create({
        title: dto.title,
        body: dto.body,
        targetRole: dto.role ?? null,
        targetServiceCategory: dto.serviceCategory ?? null,
        targetDistrictId: dto.districtId ?? null,
        waitlistOnly: dto.waitlistOnly ?? false,
        recipientCount: tokens.length,
      }),
    );

    return { recipientCount: tokens.length, successCount, failureCount };
  }

  private async findRecipientTokens(dto: SendBroadcastDto): Promise<string[]> {
    const qb = this.userRepository
      .createQueryBuilder('user')
      .innerJoin('user.district', 'district')
      .where('user.fcmToken IS NOT NULL');

    if (dto.role) {
      qb.andWhere('user.role = :role', { role: dto.role });
    }
    if (dto.districtId) {
      qb.andWhere('user.districtId = :districtId', {
        districtId: dto.districtId,
      });
    }
    if (dto.serviceCategory) {
      qb.innerJoin(CraftsmanProfile, 'cp', 'cp.userId = user.id').andWhere(
        'cp.serviceCategory = :serviceCategory',
        { serviceCategory: dto.serviceCategory },
      );
    }
    if (dto.waitlistOnly) {
      // "Waitlisted" is role-relative — a craftsman's district being
      // closed means isArtisanRegistrationActive=false, a client's means
      // isClientOrderingActive=false (see District entity). Without a
      // role filter this has to check both, each against its own role.
      qb.andWhere(
        new Brackets((sub) => {
          sub
            .where(
              'user.role = :craftsmanRole AND district.isArtisanRegistrationActive = false',
              { craftsmanRole: UserRole.CRAFTSMAN },
            )
            .orWhere(
              'user.role = :clientRole AND district.isClientOrderingActive = false',
              { clientRole: UserRole.CLIENT },
            );
        }),
      );
    }

    const rows = await qb
      .select('user.fcmToken', 'fcmToken')
      .getRawMany<{ fcmToken: string }>();
    return rows.map((r) => r.fcmToken);
  }
}
