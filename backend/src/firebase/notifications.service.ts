import { Inject, Injectable, Logger, Optional } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, IsNull, Not, Repository } from 'typeorm';
import { App } from 'firebase-admin/app';
import { getMessaging, type Message } from 'firebase-admin/messaging';
import { FIREBASE_ADMIN_APP } from './firebase-admin.constants';
import { User } from '../database/entities/user.entity';

export interface PushNotificationContent {
  title: string;
  body: string;
}

export interface PushOptions {
  // New request offers: on Android, ring like a call until the craftsman
  // touches the notification, cancelRing is called, or this time passes.
  ringUntil?: Date;
}

// Must match the app's ring channel handling (push_notification_service.dart).
const RING_FLAG = '1';

// Fallback delivery path for when a socket push can't reach the app —
// backgrounded, or killed outright by the OS. Sockets stay the primary path
// (faster, and already wired everywhere): this only needs to be reliable
// enough that a missed socket event still surfaces eventually. The only
// consumer of FIREBASE_ADMIN_APP now — phone verification (the app's other
// past consumer, via the WhatsApp Cloud API) has been dropped for this
// phase.
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
    options: PushOptions = {},
  ): Promise<void> {
    if (!this.adminApp) return;

    const user = await this.userRepository.findOne({ where: { id: userId } });
    if (!user?.fcmToken) return;

    const ringUntil = options.ringUntil;
    const message =
      ringUntil && user.pushRingCapable
        ? this.ringMessage(user.fcmToken, content, data, ringUntil)
        : this.plainMessage(user.fcmToken, content, data);

    try {
      await getMessaging(this.adminApp).send(message);
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

  // Stops the ringing on every phone that got this offer — sent once the
  // request is taken, cancelled or expired. Older builds never rang, so
  // they are skipped.
  async cancelRing(userIds: string[], requestId: string): Promise<void> {
    if (!this.adminApp || userIds.length === 0) return;
    const users = await this.userRepository.find({
      select: { id: true, fcmToken: true },
      where: {
        id: In(userIds),
        pushRingCapable: true,
        fcmToken: Not(IsNull()),
      },
    });
    const messaging = getMessaging(this.adminApp);
    await Promise.all(
      users.map((user) =>
        messaging
          .send({
            token: user.fcmToken as string,
            data: { event: 'request:unavailable', requestId },
            // Normal priority on purpose: FCM deprioritizes apps whose
            // high-priority pushes show nothing, and that would delay the
            // ringing offers themselves. A ringing phone is awake anyway.
            android: { priority: 'normal', ttl: 120_000 },
            apns: {
              headers: { 'apns-push-type': 'background', 'apns-priority': '5' },
              payload: { aps: { contentAvailable: true } },
            },
          })
          .catch((error) =>
            this.logger.warn(
              `Ring cancel to user ${user.id} failed: ${String(error)}`,
            ),
          ),
      ),
    );
  }

  private plainMessage(
    token: string,
    content: PushNotificationContent,
    data: Record<string, string>,
  ): Message {
    return {
      token,
      notification: content,
      data,
      android: {
        priority: 'high',
        notification: { channelId: 'job_updates_v2' },
      },
      apns: { payload: { aps: { sound: 'job_notification.caf' } } },
    };
  }

  // Android gets a data-only message so the app itself shows the ringing
  // notification (a "notification" payload is displayed by the system,
  // which can't loop the sound). iOS can't loop at all, so it keeps a
  // normal alert. The TTL stops a late delivery from ringing for an offer
  // that is already over.
  private ringMessage(
    token: string,
    content: PushNotificationContent,
    data: Record<string, string>,
    ringUntil: Date,
  ): Message {
    const remainingMs = Math.max(0, ringUntil.getTime() - Date.now());
    return {
      token,
      data: {
        ...data,
        title: content.title,
        body: content.body,
        ring: RING_FLAG,
        ringUntil: String(ringUntil.getTime()),
      },
      android: { priority: 'high', ttl: remainingMs },
      apns: {
        headers: {
          'apns-expiration': String(Math.floor(ringUntil.getTime() / 1000)),
        },
        payload: {
          aps: {
            alert: { title: content.title, body: content.body },
            sound: 'job_notification.caf',
          },
        },
      },
    };
  }
}
