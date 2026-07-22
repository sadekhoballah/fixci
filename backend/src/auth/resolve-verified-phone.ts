import { UnauthorizedException } from '@nestjs/common';
import { PhoneTokenVerifierService } from '../firebase/phone-token-verifier.service';

// Shared by FirebaseAuthGuard (HTTP) and MatchingGateway's socket handshake
// middleware (WS) — both need the same "verify the bearer token, or fall
// back to the gated dev-bypass" logic, just extracted from different
// transports (headers vs. handshake.auth).
export async function resolveVerifiedPhone(
  phoneTokenVerifier: PhoneTokenVerifierService,
  token: string | undefined,
  devPhone: string | undefined,
): Promise<string> {
  if (token) {
    const { phone } = await phoneTokenVerifier.verifyIdToken(token);
    return phone;
  }

  const bypassEnabled =
    !phoneTokenVerifier.isConfigured &&
    process.env.NODE_ENV !== 'production' &&
    process.env.ALLOW_DEV_AUTH_BYPASS === 'true';
  if (bypassEnabled && devPhone) {
    return devPhone;
  }

  throw new UnauthorizedException('Missing bearer token');
}
