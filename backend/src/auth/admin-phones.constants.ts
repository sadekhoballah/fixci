// The founder's own phone — the only account with admin privileges. A Set
// (not a single string) so more admins can be added later without touching
// AdminGuard itself. Same E.164 format as User.phone (see register-user.dto.ts).
export const ADMIN_PHONE_NUMBERS = new Set(['+2250707930194']);
