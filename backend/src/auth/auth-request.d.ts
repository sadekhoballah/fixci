import { UserRole } from '../database/enums/user-role.enum';

export interface AuthenticatedUser {
  id: string;
  phone: string;
  role: UserRole;
}

declare global {
  namespace Express {
    interface Request {
      authPhone?: string;
      user?: AuthenticatedUser;
    }
  }
}
