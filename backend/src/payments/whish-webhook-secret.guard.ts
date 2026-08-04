import {
  CanActivate,
  ExecutionContext,
  Injectable,
  Logger,
  UnauthorizedException,
} from '@nestjs/common';
import { Request } from 'express';

// Whish's real webhook signature scheme isn't known yet (no API access for
// Lebanon yet — see payment-webhook.dto.ts), so this is a stand-in: a shared
// secret both this server and StubWhishClient's simulated callback know.
// Swap this guard's check for real signature verification once Whish's
// actual webhook contract is available — nothing else about the webhook
// route needs to change.
@Injectable()
export class WhishWebhookSecretGuard implements CanActivate {
  private readonly logger = new Logger(WhishWebhookSecretGuard.name);

  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const provided = request.headers['x-webhook-secret'];
    const expected = process.env.WHISH_WEBHOOK_SECRET;

    if (!expected) {
      if (process.env.NODE_ENV === 'production') {
        throw new UnauthorizedException('Webhook secret is not configured');
      }
      this.logger.warn(
        'WHISH_WEBHOOK_SECRET is not set — accepting the webhook unauthenticated (dev only).',
      );
      return true;
    }

    if (provided !== expected) {
      throw new UnauthorizedException('Invalid webhook secret');
    }
    return true;
  }
}
