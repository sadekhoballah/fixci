import type Redis from 'ioredis';
import type { IdDocAnalysis, StoredIdDocAnalysis } from './id-document-check';

// POST /uploads/id-card (and /uploads/license) is stateless — it runs before
// any account exists, so it can't write the Google Vision verdict onto a
// profile row. It stashes it here instead, keyed by the storage key it just
// handed back; UsersService.register (and the two resubmitIdCard paths) read
// it back once, delete it, and copy it onto the new/updated profile.
//
// TTL comfortably covers "pick the photo -> fill the form -> submit". If it
// lapses (slow user, Redis restart, Vision was unconfigured) the profile
// just stores nothing and the admin panel shows "non analysé" — never an
// error. Plain functions on an injected REDIS_CLIENT, same idiom as
// OtpThrottleService / PresenceService.

const KEY_PREFIX = 'iddoc:analysis:';
const TTL_SECONDS = 2 * 60 * 60;

export function idDocAnalysisKey(storageKey: string): string {
  return `${KEY_PREFIX}${storageKey}`;
}

export async function saveIdDocAnalysis(
  redis: Redis,
  storageKey: string,
  analysis: IdDocAnalysis,
): Promise<void> {
  const stored: StoredIdDocAnalysis = {
    verdict: analysis.verdict,
    score: analysis.score,
    reasons: analysis.reasons,
    degraded: analysis.degraded,
    at: new Date().toISOString(),
  };
  await redis.set(
    idDocAnalysisKey(storageKey),
    JSON.stringify(stored),
    'EX',
    TTL_SECONDS,
  );
}

// Read-and-delete: the verdict is consumed exactly once, when the profile
// row that will own it from then on is created/updated.
export async function takeIdDocAnalysis(
  redis: Redis,
  storageKey: string | null | undefined,
): Promise<StoredIdDocAnalysis | null> {
  if (!storageKey) return null;
  const key = idDocAnalysisKey(storageKey);
  const raw = await redis.get(key);
  if (!raw) return null;
  await redis.del(key);
  try {
    return JSON.parse(raw) as StoredIdDocAnalysis;
  } catch {
    return null;
  }
}
