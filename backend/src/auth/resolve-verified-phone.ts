import { UnauthorizedException } from '@nestjs/common';
import { TokensService } from './tokens.service';

export interface VerifiedAuth {
  phone: string;
  // Present only when a real access token was verified (from its `sub`
  // claim) — null for the dev-bypass path, which has no signed proof of an
  // account id, only a caller-supplied phone.
  userId: string | null;
  // The token's `pv` claim — false only for a session opened before the
  // number was OTP-confirmed. See AccessTokenPayload.pv.
  issuedBeforeVerification: boolean;
}

// Shared by AccessTokenGuard (HTTP) and MatchingGateway's socket handshake
// middleware (WS) — both need the same "verify the bearer token, or fall
// back to the gated dev-bypass" logic, just extracted from different
// transports (headers vs. handshake.auth).
//
// Used to also require WhatsApp to be unconfigured before the bypass could
// engage (belt-and-suspenders against ever enabling it somewhere real
// credentials were reachable) — dropped along with WhatsappService itself;
// NODE_ENV/ALLOW_DEV_AUTH_BYPASS alone now gate it, same as
// ADMIN_JWT_SECRET's dev fallback elsewhere in this codebase.
export async function resolveVerifiedAuth(
  tokensService: TokensService,
  token: string | undefined,
  devPhone: string | undefined,
): Promise<VerifiedAuth> {
  if (token) {
    const payload = await tokensService.verifyAccessToken(token);
    return {
      phone: payload.phone,
      userId: payload.sub,
      issuedBeforeVerification: payload.pv === false,
    };
  }

  const bypassEnabled =
    process.env.NODE_ENV !== 'production' &&
    process.env.ALLOW_DEV_AUTH_BYPASS === 'true';
  if (bypassEnabled && devPhone) {
    return { phone: devPhone, userId: null, issuedBeforeVerification: false };
  }

  throw new UnauthorizedException('Missing bearer token');
}
