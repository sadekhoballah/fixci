import { CanActivate, ExecutionContext, Injectable } from '@nestjs/common';
import { Request } from 'express';
import { PhoneTokenVerifierService } from '../firebase/phone-token-verifier.service';
import { resolveVerifiedPhone } from './resolve-verified-phone';

// Every protected route needs to know "who is calling, really" — this reads
// the bearer Firebase ID token, verifies it, and stamps the verified phone
// onto the request. AuthGuard builds on top of this to also require a local
// User row; routes that can run before an account exists (upload, lookup)
// use this guard directly.
@Injectable()
export class FirebaseAuthGuard implements CanActivate {
  constructor(
    protected readonly phoneTokenVerifier: PhoneTokenVerifierService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    request.authPhone = await this.resolvePhone(request);
    return true;
  }

  protected async resolvePhone(request: Request): Promise<string> {
    const authHeader = request.headers['authorization'];
    const token = authHeader?.startsWith('Bearer ')
      ? authHeader.slice('Bearer '.length)
      : undefined;

    const devHeader = request.headers['x-dev-phone'];
    const devPhone = Array.isArray(devHeader) ? devHeader[0] : devHeader;

    return resolveVerifiedPhone(this.phoneTokenVerifier, token, devPhone);
  }
}
