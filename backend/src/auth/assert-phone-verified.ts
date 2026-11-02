import { ForbiddenException } from '@nestjs/common';
import type { AuthenticatedUser } from './auth-request';

// Stable marker the mobile app keys off to open its one-time OTP step
// rather than just showing the message (see ensurePhoneVerified there).
export const PHONE_NOT_VERIFIED = 'PHONE_NOT_VERIFIED';

// The three actions that put a client in contact with a craftsman —
// requesting one, posting a mission, applying to a mission — need a
// confirmed phone number, since that number is how the other side reaches
// them. A client registers without OTP and confirms it here, once.
export function assertPhoneVerified(user: AuthenticatedUser): void {
  if (!user.phoneVerified) {
    throw new ForbiddenException({
      statusCode: 403,
      code: PHONE_NOT_VERIFIED,
      message:
        'Confirmez votre numéro de téléphone pour continuer (une seule fois).',
    });
  }
}
