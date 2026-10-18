import type { ApiResponse, AuthResponseData } from '../types/auth';

// Use relative URL so Vite proxy forwards cleanly without CORS issues
const API_BASE_URL = '/api/v1/auth';

export async function loginUser(usernameOrEmail: string, password: string): Promise<AuthResponseData> {
  const response = await fetch(`${API_BASE_URL}/login`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ usernameOrEmail, password }),
  });

  const resData: ApiResponse<AuthResponseData> = await response.json();

  if (!response.ok) {
    throw new Error(resData.message || 'Đăng nhập không thành công. Vui lòng kiểm tra lại!');
  }

  return resData.data;
}
