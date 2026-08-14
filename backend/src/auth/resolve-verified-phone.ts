import { UnauthorizedException } from '@nestjs/common';
import { TokensService } from './tokens.service';

export interface VerifiedAuth {
  phone: string;
  // Present only when a real access token was verified (from its `sub`
  // claim) — null for the dev-bypass path, which has no signed proof of an
  // account id, only a caller-supplied phone.
  userId: string | null;
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
    return { phone: payload.phone, userId: payload.sub };
  }

  const bypassEnabled =
    process.env.NODE_ENV !== 'production' &&
    process.env.ALLOW_DEV_AUTH_BYPASS === 'true';
  if (bypassEnabled && devPhone) {
    return { phone: devPhone, userId: null };
  }

  throw new UnauthorizedException('Missing bearer token');
}
