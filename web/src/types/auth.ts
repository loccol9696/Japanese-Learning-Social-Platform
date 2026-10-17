export type UserRole = 'ADMIN' | 'USER' | 'MODERATOR';

export interface UserProfile {
  id?: number | string;
  username: string;
  email: string;
  displayName?: string;
  fullName?: string;
  avatarUrl?: string;
  role?: UserRole;
  streakDays?: number;
  level?: string;
  xp?: number;
}

export interface AuthResponseData {
  tokenType: string;
  accessToken: string;
  refreshToken?: string;
  user?: UserProfile;
}

export interface ApiResponse<T> {
  statusCode: number;
  message: string;
  data: T;
  timestamp?: string;
}
