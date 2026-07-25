import {
  CanActivate,
  ExecutionContext,
  ForbiddenException,
  Injectable,
} from '@nestjs/common';
import { Request } from 'express';
import { ADMIN_PHONE_NUMBERS } from './admin-phones.constants';

// Must run after AuthGuard, which populates request.user — combine as
// @UseGuards(AuthGuard, AdminGuard). Admin status is derived purely from the
// caller's verified phone number, not a stored/mutable DB flag: it can only
// ever be one of the numbers hardcoded in admin-phones.constants.ts.
@Injectable()
export class AdminGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<Request>();
    const phone = request.user?.phone;
    if (!phone || !ADMIN_PHONE_NUMBERS.has(phone)) {
      throw new ForbiddenException('Admin access only');
    }
    return true;
  }
}
