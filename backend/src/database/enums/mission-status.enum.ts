// Lifecycle of a Missions/Freelance board post. Locked by the founder as
// exactly these 7 names — do not add/rename without re-checking the product
// spec. DRAFT is schema-only for now: creation goes straight to
// PENDING_MODERATION, nothing writes DRAFT yet (reserved for a future
// "save without submitting" screen). ARCHIVED doubles as the terminal state
// for a poster-initiated withdrawal (no separate "cancelled" status exists).
// The public board (GET /missions) only ever shows APPROVED_PUBLISHED;
// COMPLETED and ARCHIVED both live read-only under GET /missions/mine.
export enum MissionStatus {
  DRAFT = 'draft',
  PENDING_MODERATION = 'pending_moderation',
  APPROVED_PUBLISHED = 'approved_published',
  REJECTED = 'rejected',
  IN_PROGRESS = 'in_progress',
  COMPLETED = 'completed',
  ARCHIVED = 'archived',
}
