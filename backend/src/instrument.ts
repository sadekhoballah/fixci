// Must be the very first thing the process imports (see main.ts) — Sentry's
// Node auto-instrumentation patches modules (http, pg, ioredis, ...) as they
// load, so anything imported before this file runs is invisible to it.
import * as Sentry from '@sentry/nestjs';

// No DSN (local dev without one configured) means Sentry silently no-ops
// instead of throwing, so this is safe to run unconditionally in every
// environment.
Sentry.init({
  dsn: process.env.SENTRY_DSN,
  environment: process.env.NODE_ENV ?? 'development',
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.2 : 1.0,
});
