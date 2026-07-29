import { ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { BlacklistedPhone } from '../database/entities/blacklisted-phone.entity';

const UNIQUE_VIOLATION = '23505';

@Injectable()
export class BlacklistService {
  constructor(
    @InjectRepository(BlacklistedPhone)
    private readonly blacklistedPhoneRepository: Repository<BlacklistedPhone>,
  ) {}

  async list(): Promise<BlacklistedPhone[]> {
    return this.blacklistedPhoneRepository.find({
      order: { createdAt: 'DESC' },
    });
  }

  async add(phone: string, reason?: string): Promise<BlacklistedPhone> {
    try {
      return await this.blacklistedPhoneRepository.save(
        this.blacklistedPhoneRepository.create({
          phone,
          reason: reason ?? null,
        }),
      );
    } catch (error) {
      if ((error as { code?: string }).code === UNIQUE_VIOLATION) {
        throw new ConflictException('Phone number already blacklisted');
      }
      throw error;
    }
  }

  async remove(id: string): Promise<void> {
    const result = await this.blacklistedPhoneRepository.delete({ id });
    if (result.affected === 0) {
      throw new NotFoundException('Entrée introuvable');
    }
  }
}
