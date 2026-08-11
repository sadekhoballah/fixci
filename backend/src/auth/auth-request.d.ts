import { UserRole } from '../database/enums/user-role.enum';
import { AdminRole } from '../database/enums/admin-role.enum';

export interface AuthenticatedUser {
  id: string;
  phone: string;
  role: UserRole;
}

export interface AuthenticatedAdmin {
  id: string;
  role: AdminRole;
}

declare global {
  namespace Express {
    interface Request {
      authPhone?: string;
      // Only set when the caller presented a real access token (populated
      // from its `sub` claim) — null/undefined for the dev-bypass path,
      // which only ever proves a phone, not an account id. See AuthGuard.
      authUserId?: string;
      user?: AuthenticatedUser;
      adminUser?: AuthenticatedAdmin;
    }
  }
}
