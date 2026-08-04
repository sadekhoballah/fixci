import { Injectable, Logger } from '@nestjs/common';
import {
  RequestChargeParams,
  RequestChargeResult,
} from '../payment-provider-client';
import { WhishClient } from './whish-client';

const SIMULATED_APPROVAL_DELAY_MS = 3000;

// Placeholder until Lebanon actually has real Whish API access. It never
// actually contacts Whish — instead it simulates the customer approving the
// charge on their phone by calling our own webhook endpoint after a short
// delay, the same way Whish itself would. This keeps PaymentsService and the
// mobile polling flow honest: replacing this class with a real HTTP client
// (that gets a provider ref back immediately and waits for a genuine
// webhook) is the only thing that changes once Whish API access exists.
@Injectable()
export class StubWhishClient implements WhishClient {
  private readonly logger = new Logger(StubWhishClient.name);

  async requestCharge(
    params: RequestChargeParams,
  ): Promise<RequestChargeResult> {
    const port = process.env.PORT ?? 3000;
    const secretHeader = process.env.WHISH_WEBHOOK_SECRET
      ? ` -H "X-Webhook-Secret: ${process.env.WHISH_WEBHOOK_SECRET}"`
      : '';
    this.logger.warn(
      `Whish API not connected yet — simulating approval of ${params.reference} ` +
        `(${params.phone}, ${params.amount} ${params.currency}) in ${SIMULATED_APPROVAL_DELAY_MS}ms. ` +
        `To trigger it by hand instead: curl -X POST http://localhost:${port}/payments/whish/webhook ` +
        `-H "Content-Type: application/json"${secretHeader} -d '{"reference":"${params.reference}","status":"success"}'`,
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
    const secret = process.env.WHISH_WEBHOOK_SECRET;
    await fetch(`http://localhost:${port}/payments/whish/webhook`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        ...(secret ? { 'X-Webhook-Secret': secret } : {}),
      },
      body: JSON.stringify({ reference, status: 'success' }),
    });
  }
}
