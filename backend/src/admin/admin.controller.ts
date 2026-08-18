import {
  Body,
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
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { CraftsmanProfile } from '../database/entities/craftsman-profile.entity';
import { ClientProfile } from '../database/entities/client-profile.entity';
import { Mission } from '../database/entities/mission.entity';
import {
  ID_CARDS_DIR,
  LICENSES_DIR,
  MISSION_PHOTOS_DIR,
} from '../uploads/uploads.constants';
import { DeactivateAccountDto } from './dto/deactivate-account.dto';
import { RejectMissionDto } from './dto/reject-mission.dto';

@Controller('admin')
@UseGuards(AdminJwtGuard)
export class AdminController {
  constructor(
    private readonly adminService: AdminService,
    @InjectRepository(CraftsmanProfile)
    private readonly craftsmanProfileRepository: Repository<CraftsmanProfile>,
    @InjectRepository(ClientProfile)
    private readonly clientProfileRepository: Repository<ClientProfile>,
    @InjectRepository(Mission)
    private readonly missionRepository: Repository<Mission>,
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
  async deactivate(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DeactivateAccountDto,
  ) {
    await this.adminService.deactivateCraftsman(id, dto.reason);
    return { userId: id, isActive: false };
  }

  @Patch('clients/:id/verify')
  async verifyClient(@Param('id', ParseUUIDPipe) id: string) {
    await this.adminService.verifyClient(id);
    return { userId: id, idVerified: true };
  }

  @Patch('clients/:id/deactivate')
  async deactivateClient(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: DeactivateAccountDto,
  ) {
    await this.adminService.deactivateClient(id, dto.reason);
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

  // Driver's license counterpart to the above — taxi/camion craftsmen only.
  // Same rationale: admin-only, keyed by craftsman user id.
  @Get('craftsmen/:id/license')
  async getLicense(
    @Param('id', ParseUUIDPipe) id: string,
    @Res() res: Response,
  ) {
    const profile = await this.craftsmanProfileRepository.findOne({
      where: { userId: id },
    });
    if (!profile?.licenseStorageKey) {
      throw new NotFoundException('No license on file for this craftsman');
    }
    const filePath = join(LICENSES_DIR, basename(profile.licenseStorageKey));
    if (!existsSync(filePath)) {
      throw new NotFoundException('License file not found');
    }
    res.sendFile(filePath);
  }

  // Client counterpart to the above — same ownership rationale, keyed by
  // client user id against client_profiles instead.
  @Get('clients/:id/id-card')
  async getClientIdCard(
    @Param('id', ParseUUIDPipe) id: string,
    @Res() res: Response,
  ) {
    const profile = await this.clientProfileRepository.findOne({
      where: { userId: id },
    });
    if (!profile?.idCardStorageKey) {
      throw new NotFoundException('No ID card on file for this client');
    }
    const filePath = join(ID_CARDS_DIR, basename(profile.idCardStorageKey));
    if (!existsSync(filePath)) {
      throw new NotFoundException('ID card file not found');
    }
    res.sendFile(filePath);
  }

  @Get('missions/pending')
  async getPendingMissions() {
    return { items: await this.adminService.getPendingMissions() };
  }

  @Get('missions/:id')
  async getMission(@Param('id', ParseUUIDPipe) id: string) {
    return this.adminService.getMission(id);
  }

  @Patch('missions/:id/approve')
  async approveMission(@Param('id', ParseUUIDPipe) id: string) {
    await this.adminService.approveMission(id);
    return { id, status: 'approved_published' };
  }

  @Patch('missions/:id/reject')
  async rejectMission(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: RejectMissionDto,
  ) {
    await this.adminService.rejectMission(id, dto.reason);
    return { id, status: 'rejected' };
  }

  // Admin-only preview of a mission's attached photos, same ownership-free
  // rationale as the id-card/license endpoints above (the admin isn't the
  // document's owner by definition).
  @Get('missions/:id/photo/:filename')
  async getMissionPhoto(
    @Param('id', ParseUUIDPipe) id: string,
    @Param('filename') filename: string,
    @Res() res: Response,
  ) {
    const mission = await this.missionRepository.findOne({ where: { id } });
    const storageKey = `mission-photos/${basename(filename)}`;
    if (!mission?.photoStorageKeys?.includes(storageKey)) {
      throw new NotFoundException('Photo not found for this mission');
    }
    const filePath = join(MISSION_PHOTOS_DIR, basename(filename));
    if (!existsSync(filePath)) {
      throw new NotFoundException('Photo file not found');
    }
    res.sendFile(filePath);
  }
}
