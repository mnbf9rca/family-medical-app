// backend/src/email.ts

import { SESClient, SendEmailCommand } from '@aws-sdk/client-ses';

export interface EmailConfig {
  awsAccessKeyId: string;
  awsSecretAccessKey: string;
  awsRegion: string;
  fromAddress: string;
}

/**
 * Send verification code email via AWS SES
 */
export async function sendVerificationEmail(
  config: EmailConfig,
  toEmail: string,
  code: string
): Promise<boolean> {
  const client = new SESClient({
    region: config.awsRegion,
    credentials: {
      accessKeyId: config.awsAccessKeyId,
      secretAccessKey: config.awsSecretAccessKey
    }
  });

  const htmlBody = `
    <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; max-width: 480px; margin: 0 auto; padding: 40px 20px;">
      <h1 style="color: #007AFF; font-size: 24px; margin-bottom: 24px;">Verification Code</h1>
      <p style="color: #333; font-size: 16px; line-height: 1.5;">
        Your verification code for Family Medical App is:
      </p>
      <div style="background: #F5F5F7; border-radius: 12px; padding: 24px; text-align: center; margin: 24px 0;">
        <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #1D1D1F;">${code}</span>
      </div>
      <p style="color: #666; font-size: 14px;">
        This code expires in 5 minutes. If you didn't request this, you can safely ignore this email.
      </p>
    </div>
  `;

  const textBody = `Your Family Medical App verification code is: ${code}\n\nThis code expires in 5 minutes.`;

  try {
    const command = new SendEmailCommand({
      Source: config.fromAddress,
      Destination: {
        ToAddresses: [toEmail]
      },
      Message: {
        Subject: {
          Data: 'Family Medical App - Verification Code',
          Charset: 'UTF-8'
        },
        Body: {
          Html: {
            Data: htmlBody,
            Charset: 'UTF-8'
          },
          Text: {
            Data: textBody,
            Charset: 'UTF-8'
          }
        }
      }
    });

    await client.send(command);
    return true;
  } catch (error) {
    console.error('[email] SES send failed:', error);
    return false;
  }
}

/**
 * Generate a cryptographically secure 6-digit code
 */
export function generateVerificationCode(): string {
  const array = new Uint32Array(1);
  crypto.getRandomValues(array);
  const code = (array[0] % 900000) + 100000; // 100000-999999
  return code.toString();
}
