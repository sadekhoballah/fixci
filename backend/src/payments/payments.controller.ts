import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { PaymentsService } from './payments.service';
import { SubscribeDto } from './dto/subscribe.dto';
import { WaveWebhookDto } from './dto/wave-webhook.dto';

@Controller('payments')
export class PaymentsController {
  constructor(private readonly paymentsService: PaymentsService) {}

  @Post('subscribe')
  subscribe(@Body() dto: SubscribeDto) {
    return this.paymentsService.subscribe(dto);
  }

  @Get('status')
  getStatus(@Query('reference') reference: string) {
    return this.paymentsService.getStatus(reference);
  }

  // Wave will call this once real API access exists. Until then, trigger it
  // by hand to simulate a completed payment (see StubWaveClient's log line
  // for a ready-to-run curl command with the right reference).
  @Post('wave/webhook')
  handleWaveWebhook(@Body() dto: WaveWebhookDto) {
    return this.paymentsService.handleWaveWebhook(dto);
  }
}
