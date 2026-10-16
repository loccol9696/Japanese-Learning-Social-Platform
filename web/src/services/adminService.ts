import type { ApiResponse, UserProfile, UserRole } from '../types/auth';

export interface AdminCreateUserPayload {
  username: string;
  email?: string;
  password: string;
  displayName?: string;
  role: UserRole;
}

export async function createPrivilegedAccount(payload: AdminCreateUserPayload): Promise<UserProfile> {
  const token = localStorage.getItem('jlsp_token');

  const response = await fetch('/api/v1/users/admin-create', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { 'Authorization': `Bearer ${token}` } : {})
    },
    body: JSON.stringify(payload),
  });

  const resData: ApiResponse<UserProfile> = await response.json();

  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tạo tài khoản đặc quyền. Vui lòng thử lại!');
  }

  return resData.data;
}
