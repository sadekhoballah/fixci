import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { AdminJwtGuard } from '../auth/admin-jwt.guard';
import { BroadcastService } from './broadcast.service';
import { SendBroadcastDto } from './dto/send-broadcast.dto';

@Controller('admin/broadcast')
@UseGuards(AdminJwtGuard)
export class AdminBroadcastController {
  constructor(private readonly broadcastService: BroadcastService) {}

  @Get()
  async list() {
    return { items: await this.broadcastService.list() };
  }

  @Post()
  async send(@Body() dto: SendBroadcastDto) {
    return this.broadcastService.send(dto);
  }
}
