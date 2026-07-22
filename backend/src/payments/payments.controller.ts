import { Body, Controller, Get, Post, Query, UseGuards } from '@nestjs/common';
import { Throttle } from '@nestjs/throttler';
import { PaymentsService } from './payments.service';
import { SubscribeDto } from './dto/subscribe.dto';
import { GetPaymentStatusDto } from './dto/get-payment-status.dto';
import { WaveWebhookDto } from './dto/wave-webhook.dto';
import { AuthGuard } from '../auth/auth.guard';
import { CurrentUser } from '../auth/current-user.decorator';
import type { AuthenticatedUser } from '../auth/auth-request';
import { WaveWebhookSecretGuard } from './wave-webhook-secret.guard';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('subscribe')
  @UseGuards(AuthGuard)
  subscribe(@CurrentUser() user: AuthenticatedUser, @Body() dto: SubscribeDto) {
    return this.paymentsService.subscribe(user, dto);
  }

  @Get('status')
  @UseGuards(AuthGuard)
  getStatus(
    @CurrentUser() user: AuthenticatedUser,
    @Query() query: GetPaymentStatusDto,
  ) {
    return this.paymentsService.getStatus(user.id, query.reference);
  }

  // Wave will call this once real API access exists. Until then, trigger it
  // by hand to simulate a completed payment (see StubWaveClient's log line
  // for a ready-to-run curl command with the right reference/secret). Not
  // guarded by AuthGuard — Wave isn't a signed-in user — but does require the
  // shared webhook secret (see WaveWebhookSecretGuard).
  @Post('wave/webhook')
  @UseGuards(WaveWebhookSecretGuard)
  @Throttle({ default: { limit: 20, ttl: 60_000 } })
  handleWaveWebhook(@Body() dto: WaveWebhookDto) {
    return this.paymentsService.handleWaveWebhook(dto);
  }
}
