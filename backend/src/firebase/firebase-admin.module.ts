import { Global, Logger, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { App, ServiceAccount, cert, initializeApp } from 'firebase-admin/app';
import { existsSync, readFileSync } from 'fs';
import { FIREBASE_ADMIN_APP } from './firebase-admin.constants';
import { NotificationsService } from './notifications.service';
import { User } from '../database/entities/user.entity';

const logger = new Logger('FirebaseAdminModule');

// Only used for FCM push (NotificationsService) now — phone verification
// (which used to go through the WhatsApp Cloud API) has been dropped for
// this phase; see AuthModule/ReconnectController for what phone-related
// flows remain. Still optional infrastructure: the rest of the app must
// keep working even
// before a Firebase service account is in place, so this never throws —
// NotificationsService treats a null app as "push unavailable" rather than
// the whole backend failing to boot.
function initializeFirebaseAdmin(): App | null {
  const credsPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!credsPath) {
    logger.warn(
      'FIREBASE_SERVICE_ACCOUNT_PATH not set — push notifications are disabled.',
    );
    return null;
  }
  if (!existsSync(credsPath)) {
    logger.warn(
      `FIREBASE_SERVICE_ACCOUNT_PATH is set to "${credsPath}" but no file exists there — push notifications are disabled.`,
    );
    return null;
  }
  try {
    const serviceAccount = JSON.parse(
      readFileSync(credsPath, 'utf8'),
    ) as ServiceAccount;
    return initializeApp({
      credential: cert(serviceAccount),
    });
  } catch (error) {
    logger.error(
      `Failed to initialize Firebase Admin SDK from "${credsPath}" — push notifications are disabled.`,
      error instanceof Error ? error.stack : String(error),
    );
    return null;
  }
}

@Global()
@Module({
  imports: [TypeOrmModule.forFeature([User])],
  providers: [
    {
      provide: FIREBASE_ADMIN_APP,
      useFactory: initializeFirebaseAdmin,
    },
    NotificationsService,
  ],
  exports: [FIREBASE_ADMIN_APP, NotificationsService],
})
export class FirebaseAdminModule {}
