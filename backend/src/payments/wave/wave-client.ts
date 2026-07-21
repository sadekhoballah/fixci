export const WAVE_CLIENT = Symbol('WAVE_CLIENT');

export interface RequestChargeParams {
  phone: string;
  amountCfa: number;
  reference: string;
}

export interface RequestChargeResult {
  // Wave's own id for the charge attempt, once it exists. The stub has
  // nothing real to put here, since no request actually leaves this process.
  providerRef: string | null;
}

// Whatever eventually calls the real Wave API (Checkout API session, or a
// request-to-pay endpoint if Wave's API turns out to expose one — TBD until
// the Developers tab is unlocked on the business account) must implement
// this same interface, so PaymentsService never has to change.
export interface WaveClient {
  requestCharge(params: RequestChargeParams): Promise<RequestChargeResult>;
}
