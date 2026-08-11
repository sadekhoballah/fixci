import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { App } from 'firebase-admin/app';
import { getMessaging } from 'firebase-admin/messaging';
import { FIREBASE_ADMIN_APP } from './firebase-admin.constants';
import { User } from '../database/entities/user.entity';

export interface PushNotificationContent {
  title: string;
  body: string;
}

// Fallback delivery path for when a socket push can't reach the app —
// backgrounded, or killed outright by the OS. Sockets stay the primary path
// (faster, and already wired everywhere): this only needs to be reliable
// enough that a missed socket event still surfaces eventually. The only
// consumer of FIREBASE_ADMIN_APP now — phone verification (the app's other
// past consumer) moved to WhatsappService/TokensService.
@Injectable()
export class NotificationsService {
  private readonly logger = new Logger('NotificationsService');

  constructor(
    @Optional()
    @Inject(FIREBASE_ADMIN_APP)
    private readonly adminApp: App | null,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {}

  // Best-effort and silent by design: a push failure must never break the
  // matching flow that's calling this, since the socket emit alongside it
  // already carries the real-time path.
  async sendToUser(
    userId: string,
    content: PushNotificationContent,
    data: Record<string, string>,
  ): Promise<void> {
    if (!this.adminApp) return;

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user?.fcmToken) return;

    try {
      await getMessaging(this.adminApp).send({
        token: user.fcmToken,
        notification: content,
        data,
        android: { priority: 'high', notification: { channelId: 'job_updates_v2' } },
        apns: { payload: { aps: { sound: 'job_notification.caf' } } },
      });
    } catch (error) {
      const code = (error as { errorInfo?: { code?: string } }).errorInfo?.code;
      // Dead token (app uninstalled, or Firebase reset it) — clear it so
      // every future event for this user doesn't keep re-hitting the same
      // failure until they next open the app and re-register.
      if (
        code === 'messaging/registration-token-not-registered' ||
        code === 'messaging/invalid-registration-token'
      ) {
        await this.userRepository.update({ id: userId }, { fcmToken: null });
        return;
      }
      this.logger.warn(`Push to user ${userId} failed: ${String(error)}`);
    }
  }
}
