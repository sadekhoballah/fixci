import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';

// Wave's real webhook signature scheme isn't known yet (no Developers tab
// access on the business account — see wave-webhook.dto.ts), so this is a
// stand-in: a shared secret both this server and StubWaveClient's simulated
// callback know. Swap this guard's check for real signature verification
// once Wave's actual webhook contract is available — nothing else about the
// webhook route needs to change.
@Injectable()
export class WaveWebhookSecretGuard implements CanActivate {
  private readonly logger = new Logger(WaveWebhookSecretGuard.name);

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const provided = request.headers['x-webhook-secret'];
    const expected = process.env.WAVE_WEBHOOK_SECRET;

    if (!expected) {
      if (process.env.NODE_ENV === 'production') {
        throw new UnauthorizedException('Webhook secret is not configured');
      }
      this.logger.warn(
        'WAVE_WEBHOOK_SECRET is not set — accepting the webhook unauthenticated (dev only).',
      );
      return true;
    }

    if (provided !== expected) {
      throw new UnauthorizedException('Invalid webhook secret');
    }
    return true;
  }
}
