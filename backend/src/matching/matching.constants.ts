import { ServiceCategory } from '../database/enums/service-category.enum';

export const INITIAL_RADIUS_METERS = 5000;
export const RADIUS_STEP_METERS = 5000;
export const MAX_RADIUS_METERS = 30000;
export const CANDIDATES_PER_ROUND = 5;
export const ACCEPT_TIMEOUT_MS = 18000;

// Fallback round after every radius round comes up empty: pushes to the
// nearest craftsmen by last-known location (see PresenceService) instead of
// live Redis presence. Timeout is much longer than ACCEPT_TIMEOUT_MS because
// a woken-up craftsman needs to notice the push, unlock their phone, let the
// app cold-start, and get a fresh GPS fix before they can even see the
// request — 18s is calibrated for someone with the app already open.
export const WAKEUP_CANDIDATES = 5;
export const WAKEUP_ACCEPT_TIMEOUT_MS = 90000;

// Taxi/camion get a much tighter, non-escalating-far search than every other
// category: the founder's explicit requirement is that a client never waits
// on a driver more than ~4km away, so unlike the other categories this
// sequence is hardcoded rather than derived from INITIAL/STEP/MAX above, and
// MatchingGateway.runMatchingLoop skips the last-known-location wake-up
// fallback entirely for these two categories (see the TIGHT_RADIUS_CATEGORIES
// check there) — that fallback has no radius cap of its own, which would
// silently break the "never further than 4km" guarantee.
const TIGHT_RADIUS_CATEGORIES = new Set<ServiceCategory>([
  ServiceCategory.TAXI,
  ServiceCategory.CAMION,
]);
const TIGHT_RADIUS_SEQUENCE_METERS = [100, 500, 1500, 3000, 4000];

export function isTightRadiusCategory(category: ServiceCategory): boolean {
  return TIGHT_RADIUS_CATEGORIES.has(category);
}

export function buildRadiusSequence(category: ServiceCategory): number[] {
  if (isTightRadiusCategory(category)) {
    return TIGHT_RADIUS_SEQUENCE_METERS;
  }
  const radii: number[] = [];
  for (
    let radius = INITIAL_RADIUS_METERS;
    radius <= MAX_RADIUS_METERS;
    radius += RADIUS_STEP_METERS
  ) {
    radii.push(radius);
  }
  return radii;
}

export function initialRadiusMetersFor(category: ServiceCategory): number {
  return isTightRadiusCategory(category)
    ? TIGHT_RADIUS_SEQUENCE_METERS[0]
    : INITIAL_RADIUS_METERS;
}

// Longest a runMatchingLoop call could possibly run, across every category —
// used only to size abortMatchingLoop's self-clear timeout in
// matching.gateway.ts, which doesn't know (and shouldn't need to know) which
// category a given cancelled request belongs to.
const DEFAULT_ROUNDS =
  Math.floor((MAX_RADIUS_METERS - INITIAL_RADIUS_METERS) / RADIUS_STEP_METERS) +
  1;

export function worstCaseLoopDurationMs(): number {
  const maxRounds = Math.max(
    DEFAULT_ROUNDS,
    TIGHT_RADIUS_SEQUENCE_METERS.length,
  );
  return maxRounds * ACCEPT_TIMEOUT_MS + WAKEUP_ACCEPT_TIMEOUT_MS;
}
