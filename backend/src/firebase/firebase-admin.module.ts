import { Global, Logger, Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { App, ServiceAccount, cert, initializeApp } from 'firebase-admin/app';
import { existsSync, readFileSync } from 'fs';
import { FIREBASE_ADMIN_APP } from './firebase-admin.constants';
import { PhoneTokenVerifierService } from './phone-token-verifier.service';
import { NotificationsService } from './notifications.service';
import { User } from '../database/entities/user.entity';

const logger = new Logger('FirebaseAdminModule');

// Phone verification is optional infrastructure during initial setup: the
// rest of the app (matching, uploads, registration itself) must keep working
// even before a Firebase service account is in place, so this never throws —
// PhoneTokenVerifierService treats a null app as "verification unavailable"
// rather than the whole backend failing to boot.
function initializeFirebaseAdmin(): App | null {
  const credsPath = process.env.FIREBASE_SERVICE_ACCOUNT_PATH;
  if (!credsPath) {
    logger.warn(
      'FIREBASE_SERVICE_ACCOUNT_PATH not set — phone verification tokens will not be checked; new users will be created with phoneVerified=false.',
    );
    return null;
  }
  if (!existsSync(credsPath)) {
    logger.warn(
      `FIREBASE_SERVICE_ACCOUNT_PATH is set to "${credsPath}" but no file exists there — phone verification is disabled.`,
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
      `Failed to initialize Firebase Admin SDK from "${credsPath}" — phone verification is disabled.`,
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
    PhoneTokenVerifierService,
    NotificationsService,
  ],
  exports: [
    FIREBASE_ADMIN_APP,
    PhoneTokenVerifierService,
    NotificationsService,
  ],
})
export class FirebaseAdminModule {}
