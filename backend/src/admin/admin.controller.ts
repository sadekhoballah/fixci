import {
  Controller,
  Get,
  NotFoundException,
  Param,
  ParseUUIDPipe,
  Patch,
  Res,
  UseGuards,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import type { Response } from 'express';
import { existsSync } from 'fs';
import { basename, join } from 'path';
import { AdminService } from './admin.service';
import { AuthGuard } from '../auth/auth.guard';
import { AdminGuard } from '../auth/admin.guard';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ID_CARDS_DIR } from '../uploads/uploads.constants';

@Controller('admin')
@UseGuards(AuthGuard, AdminGuard)
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
  ) {}

  @Get('verifications')
  async getPendingVerifications() {
    return { items: await this.adminService.getPendingVerifications() };
  }

  @Patch('craftsmen/:id/verify')
  async verify(@Param('id', ParseUUIDPipe) id: string) {
    await this.adminService.verifyCraftsman(id);
    return { userId: id, idVerified: true };
  }

  @Patch('craftsmen/:id/deactivate')
  async deactivate(@Param('id', ParseUUIDPipe) id: string) {
    await this.adminService.deactivateCraftsman(id);
    return { userId: id, isActive: false };
  }

  // Separate from the owner-checked GET /uploads/id-card/:filename — this
  // one is keyed by craftsman user id (not a bare filename) and is only
  // reachable by the admin, who by definition isn't the document's owner.
  @Get('craftsmen/:id/id-card')
  async getIdCard(
    @Param('id', ParseUUIDPipe) id: string,
    @Res() res: Response,
  ) {
    const profile = await this.craftsmanProfileRepository.findOne({
      where: { userId: id },
    });
    if (!profile?.idCardStorageKey) {
      throw new NotFoundException('No ID card on file for this craftsman');
    }
    const filePath = join(ID_CARDS_DIR, basename(profile.idCardStorageKey));
    if (!existsSync(filePath)) {
      throw new NotFoundException('ID card file not found');
    }
    res.sendFile(filePath);
  }
}
