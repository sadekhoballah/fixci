import type { PaymentProviderClient } from '../payment-provider-client';

export const WHISH_CLIENT = Symbol('WHISH_CLIENT');

// Lebanon's provider — pays out in USD, unlike Wave's CFA. Whatever
// eventually calls the real Whish API must implement this same interface,
// so PaymentsService never has to change.
export type WhishClient = PaymentProviderClient;
