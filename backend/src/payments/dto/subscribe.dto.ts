import { IsEnum } from 'class-validator';
import { SubscriptionTier } from '../../database/enums/subscription-tier.enum';

export class SubscribeDto {
  @IsEnum(SubscriptionTier)
  tier: SubscriptionTier;
}
