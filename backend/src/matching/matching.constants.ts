import { ServiceCategory } from '../database/enums/service-category.enum';

// The whole real-time search runs inside one fixed window. Within it,
// candidates are added step by step (see buildDispatchSchedule), but an
// offer is never withdrawn when the next step starts: every craftsman
// notified keeps it until the window closes, so whoever is nearest gets the
// full 75s to notice the push, unlock the phone and tap "Accepter" — a
// craftsman is usually mid-job, not staring at the app. When the window
// closes with no taker, the client is shown the nearest craftsmen to
// contact directly by WhatsApp / phone (see MatchingService.
// findFallbackCraftsmen) instead of a bare "nobody available".
export const MATCHING_WINDOW_MS = 75_000;

export const CANDIDATES_PER_STEP = 5;

// Craftsmen not live in Redis presence right now, but whose last-known
// location is within the step's radius, get a "wake-up" push at the same
// moment as the live candidates — so they too have the rest of the window
// to open the app (which re-delivers the request, see
// MatchingGateway.handleCraftsmanOnline) and accept.
export const WAKEUP_CANDIDATES_PER_STEP = 5;

export interface DispatchStep {
  // Offset from the start of the window at which this step's candidates
  // are notified.
  atMs: number;
  radiusMeters: number;
}

// Every category but taxi/camion: nearest 5 within 5km immediately (75s to
// answer), widened to 10km at 35s (40s to answer). 10km is the founder's
// cap — further than that, contacting directly is the better option.
const STANDARD_SCHEDULE: DispatchStep[] = [
  { atMs: 0, radiusMeters: 5_000 },
  { atMs: 35_000, radiusMeters: 10_000 },
];

// Taxi/camion get a much tighter, non-escalating-far search than every other
// category: the founder's explicit requirement is that a client never waits
// on a driver more than ~4km away, so the radii are hardcoded and
// MatchingGateway.runMatchingLoop skips the wake-up pushes for these two
// categories — drivers who take rides are expected to be online. Spread
// over the same 75s window, with the same "offers stay open" rule.
const TIGHT_RADIUS_CATEGORIES = new Set<ServiceCategory>([
  ServiceCategory.TAXI,
  ServiceCategory.CAMION,
]);
const TIGHT_SCHEDULE: DispatchStep[] = [
  { atMs: 0, radiusMeters: 100 },
  { atMs: 15_000, radiusMeters: 500 },
  { atMs: 30_000, radiusMeters: 1_500 },
  { atMs: 45_000, radiusMeters: 3_000 },
  { atMs: 60_000, radiusMeters: 4_000 },
];

// How far the post-window "contact directly" list may reach. Wider than the
// dispatch radius for regular trades — a craftsman 15km away can't take a
// live job in time, but is still worth a WhatsApp message — while
// taxi/camion keep their 4km guarantee.
const FALLBACK_RADIUS_METERS = 20_000;
const TIGHT_FALLBACK_RADIUS_METERS = 4_000;
export const FALLBACK_CRAFTSMEN_COUNT = 3;

// How long after a request expired its client may still fetch the
// fallback list — long enough to come back to it from the push
// notification, short enough that an old request can't be replayed to
// harvest craftsmen's phone numbers.
export const FALLBACK_LIST_TTL_MS = 2 * 60 * 60 * 1000;

export function isTightRadiusCategory(category: ServiceCategory): boolean {
  return TIGHT_RADIUS_CATEGORIES.has(category);
}

export function buildDispatchSchedule(
  category: ServiceCategory,
): DispatchStep[] {
  return isTightRadiusCategory(category) ? TIGHT_SCHEDULE : STANDARD_SCHEDULE;
}

export function initialRadiusMetersFor(category: ServiceCategory): number {
  return buildDispatchSchedule(category)[0].radiusMeters;
}

export function fallbackRadiusMetersFor(category: ServiceCategory): number {
  return isTightRadiusCategory(category)
    ? TIGHT_FALLBACK_RADIUS_METERS
    : FALLBACK_RADIUS_METERS;
}

// Longest a runMatchingLoop call could possibly run, across every category —
// used only to size abortMatchingLoop's self-clear timeout in
// matching.gateway.ts, which doesn't know (and shouldn't need to know) which
// category a given cancelled request belongs to. A little slack for the
// DB round-trips around the window itself.
export function worstCaseLoopDurationMs(): number {
  return MATCHING_WINDOW_MS + 10_000;
}
