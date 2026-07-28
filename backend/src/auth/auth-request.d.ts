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
      user?: AuthenticatedUser;
      adminUser?: AuthenticatedAdmin;
    }
  }
}
