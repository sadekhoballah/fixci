import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as geoip from 'geoip-lite';
import { SiteVisit } from '../database/entities/site-visit.entity';

export interface AnalyticsPeriodStats {
  visits: number;
  uniqueIps: number;
}

export interface AnalyticsStats {
  today: AnalyticsPeriodStats;
  week: AnalyticsPeriodStats;
  month: AnalyticsPeriodStats;
  topCountries: { countryCode: string | null; visits: number }[];
  recent: {
    ipAddress: string;
    countryCode: string | null;
    path: string | null;
    createdAt: Date;
  }[];
}

@Injectable()
export class AnalyticsService {
  constructor(
    @InjectRepository(SiteVisit)
    private readonly siteVisitRepository: Repository<SiteVisit>,
  ) {}

  async track(ipAddress: string, path: string | null): Promise<void> {
    const lookup = geoip.lookup(ipAddress);
    const visit = this.siteVisitRepository.create({
      ipAddress,
      countryCode: lookup?.country ?? null,
      path: path?.slice(0, 255) ?? null,
    });
    await this.siteVisitRepository.save(visit);
  }

  async getStats(): Promise<AnalyticsStats> {
    const now = new Date();
    const startOfToday = new Date(now);
    startOfToday.setHours(0, 0, 0, 0);
    const startOfWeek = new Date(now.getTime() - 7 * 24 * 60 * 60 * 1000);
    const startOfMonth = new Date(now.getTime() - 30 * 24 * 60 * 60 * 1000);

    const [today, week, month, topCountries, recent] = await Promise.all([
      this.periodStats(startOfToday),
      this.periodStats(startOfWeek),
      this.periodStats(startOfMonth),
      this.topCountries(startOfMonth),
      this.siteVisitRepository.find({
        order: { createdAt: 'DESC' },
        take: 50,
        select: {
          ipAddress: true,
          countryCode: true,
          path: true,
          createdAt: true,
        },
      }),
    ]);

    return { today, week, month, topCountries, recent };
  }

  private async periodStats(since: Date): Promise<AnalyticsPeriodStats> {
    const row = await this.siteVisitRepository
      .createQueryBuilder('visit')
      .select('COUNT(*)', 'visits')
      .addSelect('COUNT(DISTINCT visit.ip_address)', 'uniqueIps')
      .where('visit.created_at >= :since', { since })
      .getRawOne<{ visits: string; uniqueIps: string }>();

    return {
      visits: Number(row?.visits ?? 0),
      uniqueIps: Number(row?.uniqueIps ?? 0),
    };
  }

  private async topCountries(
    since: Date,
  ): Promise<{ countryCode: string | null; visits: number }[]> {
    const rows = await this.siteVisitRepository
      .createQueryBuilder('visit')
      .select('visit.country_code', 'countryCode')
      .addSelect('COUNT(*)', 'visits')
      .where('visit.created_at >= :since', { since })
      .groupBy('visit.country_code')
      .orderBy('visits', 'DESC')
      .limit(10)
      .getRawMany<{ countryCode: string | null; visits: string }>();

    return rows.map((row) => ({
      countryCode: row.countryCode,
      visits: Number(row.visits),
    }));
  }
}
