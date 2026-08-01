import { Injectable, UnauthorizedException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { JwtService } from '@nestjs/jwt';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { AdminUser } from '../database/entities/admin-user.entity';

export interface AdminJwtPayload {
  sub: string;
  role: string;
}

@Injectable()
export class AdminAuthService {
  constructor(
    @InjectRepository(AdminUser)
    private readonly adminUserRepository: Repository<AdminUser>,
    private readonly jwtService: JwtService,
  ) {}

  async login(username: string, password: string): Promise<{ token: string }> {
    const adminUser = await this.adminUserRepository.findOne({
      where: { username },
    });
    // Same generic error whether the username doesn't exist, the account is
    // deactivated, or the password is wrong — never tell a caller which one.
    if (!adminUser || !adminUser.isActive) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const passwordMatches = await bcrypt.compare(
      password,
      adminUser.passwordHash,
    );
    if (!passwordMatches) {
      throw new UnauthorizedException('Invalid credentials');
    }

    const payload: AdminJwtPayload = {
      sub: adminUser.id,
      role: adminUser.role,
    };
    return { token: await this.jwtService.signAsync(payload) };
  }
}
