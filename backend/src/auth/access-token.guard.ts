import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Request } from 'express';
import { TokensService } from './tokens.service';
import { resolveVerifiedAuth, VerifiedAuth } from './resolve-verified-phone';

// Every protected route needs to know "who is calling, really" — this reads
// the bearer access token, verifies it, and stamps the verified phone (and,
// for a real token, the user id) onto the request. AuthGuard builds on top
// of this to also require a local User row; routes that can run before an
// account exists (upload, lookup) use this guard directly.
@Injectable()
export class AccessTokenGuard implements CanActivate {
  constructor(protected readonly tokensService: TokensService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const { phone, userId } = await this.resolveAuth(request);
    request.authPhone = phone;
    request.authUserId = userId ?? undefined;
    return true;
  }

  protected async resolveAuth(request: Request): Promise<VerifiedAuth> {
    const authHeader = request.headers['authorization'];
    const token = authHeader?.startsWith('Bearer ')
      ? authHeader.slice('Bearer '.length)
      : undefined;

    const devHeader = request.headers['x-dev-phone'];
    const devPhone = Array.isArray(devHeader) ? devHeader[0] : devHeader;

    return resolveVerifiedAuth(this.tokensService, token, devPhone);
  }
}
