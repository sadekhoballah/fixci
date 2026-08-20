// Lifecycle of a UserReport, as reviewed from the admin Signalements queue.
// PENDING is the only state that queue actually lists — RESOLVED and
// DISMISSED both drop out of it once an admin has acted, same "acting is
// how it leaves the queue" shape as MissionStatus's moderation states.
export enum ReportStatus {
  PENDING = 'pending',
  RESOLVED = 'resolved',
  DISMISSED = 'dismissed',
}
