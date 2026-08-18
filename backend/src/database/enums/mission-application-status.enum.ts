// PENDING -> SELECTED (the mission owner picked this applicant) or
// NOT_SELECTED (another applicant was picked instead — set in bulk when a
// selection happens, never individually notified, see MissionsService.select).
// WITHDRAWN is applicant-initiated (they change their mind before selection);
// kept distinct from NOT_SELECTED so the unique index below can let someone
// withdraw and re-apply cleanly instead of being permanently locked out.
export enum MissionApplicationStatus {
  PENDING = 'pending',
  SELECTED = 'selected',
  NOT_SELECTED = 'not_selected',
  WITHDRAWN = 'withdrawn',
}
