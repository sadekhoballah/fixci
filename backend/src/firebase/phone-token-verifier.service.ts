import {
  BadRequestException,
  Inject,
  Injectable,
  Optional,
  UnauthorizedException,
} from '@nestjs/common';
import { App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { FIREBASE_ADMIN_APP } from './firebase-admin.constants';

@Injectable()
export class PhoneTokenVerifierService {
  constructor(
    @Optional()
    @Inject(FIREBASE_ADMIN_APP)
    private readonly adminApp: App | null,
  ) {}

  // Confirms a Firebase ID token is genuine AND that its verified phone
  // number actually matches what's being registered — the client-side OTP
  // confirmation alone can't be trusted, since any client could just claim
  // "this phone is verified" without ever proving it.
  async verifyPhoneToken(
    idToken: string,
    expectedPhone: string,
  ): Promise<{ verified: boolean }> {
    if (!this.adminApp) {
      // Admin SDK not configured yet — registration should still succeed,
      // just without a verified phone (see FirebaseAdminModule).
      return { verified: false };
    }

    let decodedPhoneNumber: string | undefined;
    try {
      const decoded = await getAuth(this.adminApp).verifyIdToken(idToken);
      decodedPhoneNumber = decoded.phone_number;
    } catch {
      throw new BadRequestException('Invalid or expired verification token');
    }

    if (decodedPhoneNumber !== expectedPhone) {
      throw new UnauthorizedException(
        'Verification token does not match the phone number being registered',
      );
    }

    return { verified: true };
  }
}
