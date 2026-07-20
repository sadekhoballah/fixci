import { ConflictException, Injectable } from '@nestjs/common';
import { DataSource, Repository } from 'typeorm';
import { InjectRepository } from '@nestjs/typeorm';
import { User } from '../database/entities/user.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { UserRole } from '../database/enums/user-role.enum';
import { RegisterUserDto } from './dto/register-user.dto';
import { PhoneTokenVerifierService } from '../firebase/phone-token-verifier.service';

const UNIQUE_VIOLATION = '23505';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly userRepository: Repository<User>,
    private readonly dataSource: DataSource,
    private readonly phoneTokenVerifier: PhoneTokenVerifierService,
  ) {}

  async register(dto: RegisterUserDto): Promise<User> {
    const existing = await this.userRepository.findOne({
      where: { phone: dto.phone },
    });
    if (existing) {
      throw new ConflictException('Phone number already registered');
    }

    // Verified outside the transaction: this is a network call to Firebase,
    // not something that needs (or should hold open) a DB transaction.
    let phoneVerified = false;
    if (dto.firebaseIdToken) {
      const result = await this.phoneTokenVerifier.verifyPhoneToken(
        dto.firebaseIdToken,
        dto.phone,
      );
      phoneVerified = result.verified;
    }

    try {
      return await this.dataSource.transaction(async (manager) => {
        const user = await manager.save(
          manager.create(User, {
            phone: dto.phone,
            fullName: dto.fullName ?? null,
            role: dto.role,
            phoneVerified,
          }),
        );

        if (dto.role === UserRole.CRAFTSMAN) {
          await manager.save(
            manager.create(CraftsmanProfile, {
              userId: user.id,
              serviceCategory: dto.serviceCategory,
              experienceDetails: dto.experienceDetails ?? null,
              idCardStorageKey: dto.idCardStorageKey ?? null,
            }),
          );
        } else {
          await manager.save(
            manager.create(ClientProfile, {
              userId: user.id,
              idCardStorageKey: dto.idCardStorageKey ?? null,
            }),
          );
        }

        return user;
      });
    } catch (error) {
      if ((error as { code?: string }).code === UNIQUE_VIOLATION) {
        throw new ConflictException('Phone number already registered');
      }
      throw error;
    }
  }
}
