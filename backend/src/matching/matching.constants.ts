export const INITIAL_RADIUS_METERS = 5000;
export const RADIUS_STEP_METERS = 5000;
export const MAX_RADIUS_METERS = 30000;
export const CANDIDATES_PER_ROUND = 5;
export const ACCEPT_TIMEOUT_MS = 18000;

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
