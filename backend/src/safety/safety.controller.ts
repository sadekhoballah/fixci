import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  Param,
  ParseUUIDPipe,
  Post,
  UseGuards,
} from '@nestjs/common';
import { SafetyService } from './safety.service';
import { ReportUserDto } from './dto/report-user.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';

// User-facing report/block endpoints, deliberately at /users (not its own
// /safety prefix) — these are actions one user takes on another, same
// mount point as UsersController's other role-agnostic routes. The admin
// moderation view on top of these reports lives in AdminController instead
// (GET/PATCH /admin/reports), mirroring how mission moderation sits in
// AdminController while MissionsController owns the user-facing half.
@Controller('users')
@UseGuards(AuthGuard)
export class SafetyController {
  constructor(private readonly safetyService: SafetyService) {}

  @Post(':id/report')
  async report(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) reportedUserId: string,
    @Body() dto: ReportUserDto,
  ) {
    return this.safetyService.reportUser(user.id, reportedUserId, dto);
  }

  @Post(':id/block')
  @HttpCode(200)
  async block(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) blockedUserId: string,
  ) {
    await this.safetyService.blockUser(user.id, blockedUserId);
    return { blockedUserId };
  }

  @Delete(':id/block')
  @HttpCode(200)
  async unblock(
    @CurrentUser() user: AuthenticatedUser,
    @Param('id', ParseUUIDPipe) blockedUserId: string,
  ) {
    await this.safetyService.unblockUser(user.id, blockedUserId);
    return { blockedUserId };
  }

  // Static path, so this must be registered before the ':id/...' routes
  // above are reachable for a literal "blocked" id — not a concern here
  // since Nest matches routes in declaration order and 'blocked' can never
  // collide with a UUID anyway (ParseUUIDPipe would 400 it), but kept last
  // in the file for readability, not routing correctness.
  @Get('blocked')
  async listBlocked(@CurrentUser() user: AuthenticatedUser) {
    const items = await this.safetyService.getBlockedUsers(user.id);
    return { items };
  }
}
