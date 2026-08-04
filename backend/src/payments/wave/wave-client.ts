import type { PaymentProviderClient } from '../payment-provider-client';

export const WAVE_CLIENT = Symbol('WAVE_CLIENT');

// Whatever eventually calls the real Wave API (Checkout API session, or a
// request-to-pay endpoint if Wave's API turns out to expose one — TBD until
// the Developers tab is unlocked on the business account) must implement
// this same interface, so PaymentsService never has to change.
export type WaveClient = PaymentProviderClient;
