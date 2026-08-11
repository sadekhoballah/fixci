import { Global, Module } from '@nestjs/common';
import { WhatsappService } from './whatsapp.service';

// Global for the same reason AuthModule is: OtpService (in AuthModule) is
// the only consumer today, but it's cheap infrastructure with nothing
// route-specific to configure per-module.
@Global()
@Module({
  providers: [WhatsappService],
  exports: [WhatsappService],
})
export class WhatsappModule {}
