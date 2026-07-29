import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { BlacklistService } from './blacklist.service';
import { CreateBlacklistEntryDto } from './dto/create-blacklist-entry.dto';

@Controller('admin/blacklist')
@UseGuards(AdminJwtGuard)
export class AdminBlacklistController {
  constructor(private readonly blacklistService: BlacklistService) {}

  @Get()
  async list() {
    return { items: await this.blacklistService.list() };
  }

  @Post()
  async add(@Body() dto: CreateBlacklistEntryDto) {
    return this.blacklistService.add(dto.phone, dto.reason);
  }

  @Delete(':id')
  async remove(@Param('id', ParseUUIDPipe) id: string) {
    await this.blacklistService.remove(id);
    return { success: true };
  }
}
