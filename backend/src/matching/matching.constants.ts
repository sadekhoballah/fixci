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

export function buildRadiusSequence(): number[] {
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
