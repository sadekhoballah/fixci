// Predefined categories for a user-to-user report — easier for the admin
// moderation queue to triage/filter than free text alone (see
// UserReport.message for the optional free-text detail alongside this).
export enum ReportReason {
  HARASSMENT = 'harassment',
  NO_SHOW = 'no_show',
  FRAUD = 'fraud',
  INAPPROPRIATE_CONTENT = 'inappropriate_content',
  OTHER = 'other',
}
