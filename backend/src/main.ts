import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { NestExpressApplication } from '@nestjs/platform-express';
import { AppModule } from './app.module';

// Uploaded ID-card photos are served only through UploadsController's
// authenticated GET /uploads/id-card/:filename — no public static serving.

function resolveAllowedOrigins(): string[] | boolean {
  const configured = (process.env.ALLOWED_ORIGINS ?? '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean);
  if (configured.length > 0) return configured;
  // No web/browser client exists yet (the mobile app's native HTTP client
  // isn't subject to CORS at all) — default to permissive outside
  // production so local/manual browser testing isn't blocked, and to
  // fully closed in production until real origins are configured.
  return process.env.NODE_ENV === 'production' ? false : true;
}

async function bootstrap() {
  const app = await NestFactory.create<NestExpressApplication>(AppModule);
  // Behind Apache's reverse proxy (see fixci-api.conf) — without this,
  // req.ip/@Ip() would resolve to 127.0.0.1 for every visitor instead of
  // reading the real client IP from X-Forwarded-For.
  app.set('trust proxy', true);
  app.useGlobalPipes(new ValidationPipe({ transform: true, whitelist: true }));
  app.enableCors({ origin: resolveAllowedOrigins() });
  await app.listen(process.env.PORT ?? 3000);
}
void bootstrap();
