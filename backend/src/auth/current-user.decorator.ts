import { createParamDecorator, ExecutionContext } from '@nestjs/common';
import { Request } from 'express';
import { AuthenticatedUser } from './auth-request';

// Only meaningful behind AuthGuard, which is what actually populates
// request.user — routes guarded only by AccessTokenGuard should read
// request.authPhone instead.
export const CurrentUser = createParamDecorator(
  (_data: unknown, context: ExecutionContext): AuthenticatedUser => {
    const request = context.switchToHttp().getRequest<Request>();
    return request.user as AuthenticatedUser;
  },
);
