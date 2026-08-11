import { Injectable, Logger } from '@nestjs/common';

const DEFAULT_API_VERSION = 'v18.0';

export class WhatsappSendError extends Error {}

// The one place that ever calls out to Meta's WhatsApp Cloud API — mirrors
// PhoneTokenVerifierService's old role of being the single Firebase touch
// point, just for outbound OTP delivery instead of inbound token
// verification. Uses the global `fetch` (Node 24), same idiom as the
// payments stub clients (payments/wave/stub-wave-client.ts,
// payments/whish/stub-whish-client.ts).
@Injectable()
export class WhatsappService {
  private readonly logger = new Logger(WhatsappService.name);

  get isConfigured(): boolean {
    return Boolean(
      process.env.WHATSAPP_ACCESS_TOKEN && process.env.WHATSAPP_PHONE_NUMBER_ID,
    );
  }

  // Sends the pre-approved OTP template message to `phone` (E.164, e.g.
  // "+2250700000001") with `code` filled into the template's body
  // parameter. Meta requires the template to already be approved in Meta
  // Business Manager — free-form text can't be sent outside a 24h customer
  // session window, which an OTP request never has.
  //
  // "Authentication" category templates come with a "Copy code" button by
  // default, which is its own component the send call must fill in
  // separately from the body — Meta 400s the whole request if the
  // components sent don't match the approved template's shape. Controlled
  // by WHATSAPP_OTP_TEMPLATE_HAS_BUTTON (defaults to on, since that's
  // Meta's default for this template category); set it to "false" only if
  // you approved a template without that button.
  async sendOtpMessage(phone: string, code: string): Promise<void> {
    const accessToken = process.env.WHATSAPP_ACCESS_TOKEN;
    const phoneNumberId = process.env.WHATSAPP_PHONE_NUMBER_ID;
    const apiVersion = process.env.WHATSAPP_API_VERSION || DEFAULT_API_VERSION;
    const templateName = process.env.WHATSAPP_OTP_TEMPLATE_NAME;
    const templateLang = process.env.WHATSAPP_OTP_TEMPLATE_LANG || 'en_US';
    const templateHasButton = process.env.WHATSAPP_OTP_TEMPLATE_HAS_BUTTON !== 'false';

    if (!accessToken || !phoneNumberId || !templateName) {
      throw new WhatsappSendError(
        'WhatsApp Cloud API is not fully configured (access token, phone number ID, or template name missing)',
      );
    }

    // Meta's examples send the "to" number without a leading "+".
    const to = phone.startsWith('+') ? phone.slice(1) : phone;

    const components = [
      {
        type: 'body',
        parameters: [{ type: 'text', text: code }],
      },
      ...(templateHasButton
        ? [
            {
              type: 'button',
              sub_type: 'url',
              index: '0',
              parameters: [{ type: 'text', text: code }],
            },
          ]
        : []),
    ];

    let response: Response;
    try {
      response = await fetch(
        `https://graph.facebook.com/${apiVersion}/${phoneNumberId}/messages`,
        {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${accessToken}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            messaging_product: 'whatsapp',
            to,
            type: 'template',
            template: {
              name: templateName,
              language: { code: templateLang },
              components,
            },
          }),
        },
      );
    } catch (error) {
      this.logger.error(
        `Network error calling WhatsApp Cloud API for ${phone}`,
        error instanceof Error ? error.stack : String(error),
      );
      throw new WhatsappSendError('Failed to reach WhatsApp Cloud API');
    }

    if (!response.ok) {
      const body = await response.text().catch(() => '');
      this.logger.error(
        `WhatsApp Cloud API rejected OTP send to ${phone}: ${response.status} ${body}`,
      );
      throw new WhatsappSendError('WhatsApp Cloud API rejected the message');
    }
  }
}
