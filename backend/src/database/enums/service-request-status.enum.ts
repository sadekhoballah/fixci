export enum ServiceRequestStatus {
  PENDING = 'pending',
  ASSIGNED = 'assigned',
  IN_PROGRESS = 'in_progress',
  AWAITING_CLIENT_CONFIRMATION = 'awaiting_client_confirmation',
  COMPLETED = 'completed',
  CANCELLED = 'cancelled',
  EXPIRED = 'expired',
}
