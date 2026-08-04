import { Currency } from '../database/enums/subscription-tier.enum';

export interface RequestChargeParams {
  phone: string;
  amount: number;
  currency: Currency;
  reference: string;
}

export interface RequestChargeResult {
  // The provider's own id for the charge attempt, once it exists. Stub
  // clients have nothing real to put here, since no request actually leaves
  // this process.
  providerRef: string | null;
}

// Whatever eventually calls a real provider API (Wave, Whish, or anything
// added later) must implement this same interface, so PaymentsService never
// has to change — only which client gets injected for a given country.
export interface PaymentProviderClient {
  requestCharge(params: RequestChargeParams): Promise<RequestChargeResult>;
}
