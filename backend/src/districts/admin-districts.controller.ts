import {
  Body,
  Controller,
  Get,
  Param,
  ParseUUIDPipe,
  Patch,
  Post,
  UseGuards,
} from '@nestjs/common';
import { DistrictsService } from './districts.service';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { CreateDistrictDto } from './dto/create-district.dto';
import { UpdateDistrictTogglesDto } from './dto/update-district-toggles.dto';

@Controller('admin/districts')
@UseGuards(AdminJwtGuard)
export class AdminDistrictsController {
  constructor(private readonly districtsService: DistrictsService) {}

  @Get()
  async list() {
    return { items: await this.districtsService.listWithCounts() };
  }

  @Post()
  async create(@Body() dto: CreateDistrictDto) {
    return this.districtsService.create(dto.name);
  }

  @Patch(':id')
  async updateToggles(
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: UpdateDistrictTogglesDto,
  ) {
    return this.districtsService.updateToggles(id, dto);
  }

  @Get(':id/waitlist')
  async getWaitlist(@Param('id', ParseUUIDPipe) id: string) {
    return this.districtsService.getWaitlist(id);
  }
}
