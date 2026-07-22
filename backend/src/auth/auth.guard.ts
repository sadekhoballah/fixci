import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Request } from 'express';
import { User } from '../database/entities/user.entity';
import { PhoneTokenVerifierService } from '../firebase/phone-token-verifier.service';
import { FirebaseAuthGuard } from './firebase-auth.guard';

// Like FirebaseAuthGuard, but also requires a local account to already exist
// for the verified phone — used on every route that acts on "my" data.
@Injectable()
export class AuthGuard extends FirebaseAuthGuard implements CanActivate {
  constructor(
    phoneTokenVerifier: PhoneTokenVerifierService,
    @InjectRepository(User) private readonly userRepository: Repository<User>,
  ) {
    super(phoneTokenVerifier);
  }

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest<Request>();
    const phone = await this.resolvePhone(request);
    request.authPhone = phone;

    const user = await this.userRepository.findOne({ where: { phone } });
    if (!user) {
      throw new UnauthorizedException('No account for this phone number');
    }
    request.user = { id: user.id, phone: user.phone, role: user.role };
    return true;
  }
}
