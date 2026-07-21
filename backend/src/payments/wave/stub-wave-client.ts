import { Injectable, Logger } from '@nestjs/common';
import {
  RequestChargeParams,
  RequestChargeResult,
  WaveClient,
} from './wave-client';

const SIMULATED_APPROVAL_DELAY_MS = 3000;

// Placeholder until the business account has real Wave API access. It never
// actually contacts Wave — instead it simulates the customer approving the
// charge on their phone by calling our own webhook endpoint after a short
// delay, the same way Wave itself would. This keeps PaymentsService and the
// mobile polling flow honest: replacing this class with a real HTTP client
// (that gets a provider ref back immediately and waits for a genuine
// webhook) is the only thing that changes once Wave API access exists.
@Injectable()
export class StubWaveClient implements WaveClient {
  private readonly logger = new Logger(StubWaveClient.name);

  async requestCharge(
    params: RequestChargeParams,
  ): Promise<RequestChargeResult> {
    this.logger.warn(
      `Wave API not connected yet — simulating approval of ${params.reference} ` +
        `(${params.phone}, ${params.amountCfa} CFA) in ${SIMULATED_APPROVAL_DELAY_MS}ms.`,
    );
    setTimeout(() => {
      this.simulateApproval(params.reference).catch((error: unknown) => {
        this.logger.error(
          `Failed to simulate approval for ${params.reference}`,
          error instanceof Error ? error.stack : String(error),
        );
      });
    }, SIMULATED_APPROVAL_DELAY_MS);
    return Promise.resolve({ providerRef: null });
  }

  private async simulateApproval(reference: string): Promise<void> {
    const port = process.env.PORT ?? 3000;
    await fetch(`http://localhost:${port}/payments/wave/webhook`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ reference, status: 'success' }),
    });
  }
}
