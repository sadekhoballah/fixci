import { Body, Controller, Ip, Post } from '@nestjs/common';
import { AnalyticsService } from './analytics.service';
import { TrackVisitDto } from './dto/track-visit.dto';

@Controller('analytics')
export class AnalyticsTrackController {
  constructor(private readonly analyticsService: AnalyticsService) {}

  // Public and unauthenticated by design — called from every page load of
  // the marketing site. Fire-and-forget on the client; never throws in a
  // way that would surface to the visitor.
  @Post('track')
  async track(
    @Ip() ip: string,
    @Body() dto: TrackVisitDto,
  ): Promise<{ ok: true }> {
    await this.analyticsService.track(ip, dto.path ?? null);
    return { ok: true };
  }
}
