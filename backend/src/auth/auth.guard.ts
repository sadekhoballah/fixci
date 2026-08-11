import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { IsNull, Repository } from 'typeorm';
import { Request } from 'express';
import { User } from '../database/entities/user.entity';
import { TokensService } from './tokens.service';
import { WhatsappService } from '../whatsapp/whatsapp.service';
import { AccessTokenGuard } from './access-token.guard';

// Like AccessTokenGuard, but also requires a local account to already exist
// for the verified caller — used on every route that acts on "my" data.
@Injectable()
export class AuthGuard extends AccessTokenGuard implements CanActivate {
  constructor(
    tokensService: TokensService,
    whatsapp: WhatsappService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {
    super(tokensService, whatsapp);
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const { phone, userId } = await this.resolveAuth(request);
    request.authPhone = phone;
    request.authUserId = userId ?? undefined;

    // A real access token carries the account id it was issued for — look
    // up by that (plus deletedAt IS NULL) rather than by phone. A stateless
    // JWT can't be revoked, so if this account was since soft-deleted (its
    // phone column nulled — see UsersService.deleteAccount) and someone
    // else later registers with that same phone number, a phone-based
    // lookup could resolve this caller's still-valid old token to the
    // *new* owner's account. The dev-bypass path has no signed id to fall
    // back on, so it's still resolved by phone — acceptable since it's
    // gated to local, non-production use only.
    const user = userId
      ? await this.userRepository.findOne({
          where: { id: userId, deletedAt: IsNull() },
        })
      : await this.userRepository.findOne({ where: { phone } });
    if (!user) {
      throw new UnauthorizedException('No account for this phone number');
    }
    // Non-null assertion is safe here: a deleted account (phone set to NULL
    // by UsersService.deleteAccount) is excluded by the deletedAt/phone
    // lookups above, so `user.phone` is always still set at this point.
    request.user = { id: user.id, phone: user.phone!, role: user.role };
    return true;
  }
}
