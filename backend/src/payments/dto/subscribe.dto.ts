import { IsEnum, Matches } from 'class-validator';
import { SubscriptionTier } from '../../database/enums/subscription-tier.enum';

export class SubscribeDto {
  @Matches(/^\+[1-9]\d{7,14}$/, {
    message: 'phone must be in E.164 format, e.g. +2250700000001',
  })
  phone: string;

  @IsEnum(SubscriptionTier)
  tier: SubscriptionTier;
}
