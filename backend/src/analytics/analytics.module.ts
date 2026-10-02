import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { SiteVisit } from '../database/entities/site-visit.entity';
import { AnalyticsService } from './analytics.service';
import { AnalyticsTrackController } from './analytics-track.controller';
import { AdminAnalyticsController } from './admin-analytics.controller';

@Module({
  imports: [TypeOrmModule.forFeature([SiteVisit])],
  controllers: [AnalyticsTrackController, AdminAnalyticsController],
  providers: [AnalyticsService],
})
export class AnalyticsModule {}
