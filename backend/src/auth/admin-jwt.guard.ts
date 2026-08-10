import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import { Request } from 'express';
import { AdminUser } from '../database/entities/admin-user.entity';
import { AdminJwtPayload } from '../admin-auth/admin-auth.service';

// Guards every /admin/* route. Unrelated to AuthGuard/AccessTokenGuard (the
// phone-OTP path for clients/craftsmen) — admin identity comes from a
// separate admin_users table and a JWT issued by POST /admin-auth/login.
@Injectable()
export class AdminJwtGuard implements CanActivate {
  constructor(
    @InjectRepository(AdminUser)
    private readonly adminUserRepository: Repository<AdminUser>,
    private readonly jwtService: JwtService,
  ) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const header = request.headers.authorization;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing admin bearer token');
    }

    let payload: AdminJwtPayload;
    try {
      payload = await this.jwtService.verifyAsync<AdminJwtPayload>(
        header.slice('Bearer '.length),
      );
    } catch {
      throw new UnauthorizedException('Invalid or expired admin token');
    }

    const adminUser = await this.adminUserRepository.findOne({
      where: { id: payload.sub },
    });
    if (!adminUser || !adminUser.isActive) {
      throw new UnauthorizedException('Admin account no longer active');
    }

    request.adminUser = { id: adminUser.id, role: adminUser.role };
    return true;
  }
}
