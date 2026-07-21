import { Injectable, Logger } from '@nestjs/common';
import {
  RequestChargeParams,
  RequestChargeResult,
  WaveClient,
} from './wave-client';

// Placeholder until the business account has real Wave API access: it
// doesn't contact Wave at all, so a subscribe request only ever produces a
// `pending` payment. To move it to `success` for local testing, hit
// POST /payments/wave/webhook by hand with the reference this returned.
@Injectable()
export class StubWaveClient implements WaveClient {
  private readonly logger = new Logger(StubWaveClient.name);

  async requestCharge(
    params: RequestChargeParams,
  ): Promise<RequestChargeResult> {
    this.logger.warn(
      `Wave API not connected yet — not charging ${params.phone}. ` +
        `Simulate a completed payment with: ` +
        `curl -X POST http://localhost:3000/payments/wave/webhook -H "Content-Type: application/json" ` +
        `-d '{"reference":"${params.reference}","status":"success"}'`,
    );
    return Promise.resolve({ providerRef: null });
  }
}
