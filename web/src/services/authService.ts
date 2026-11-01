import type { ApiResponse, AuthResponseData } from '../types/auth';

// Use relative URL so Vite proxy forwards cleanly without CORS issues
const API_BASE_URL = '/api/v1/auth';

export async function loginUser(usernameOrEmail: string, password: string): Promise<AuthResponseData> {
  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}/login`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ usernameOrEmail, password }),
    });
  } catch (err: any) {
    throw new Error('Không thể kết nối đến máy chủ Backend (cổng 8080 chưa khởi chạy).');
  }

  const rawText = await response.text();
  let resData: ApiResponse<AuthResponseData> | null = null;
  
  if (rawText && rawText.trim().length > 0) {
    try {
      resData = JSON.parse(rawText);
    } catch {
      // Body is not JSON (e.g. HTML proxy error)
    }
  }

  if (!response.ok) {
    const errorMsg = resData?.message || 
      (response.status === 504 || response.status === 502
        ? 'Không thể kết nối đến máy chủ Backend (cổng 8080 chưa khởi chạy).'
        : `Lỗi máy chủ (${response.status})`);
    throw new Error(errorMsg);
  }

  if (!resData?.data) {
    throw new Error('Phản hồi từ máy chủ không hợp lệ.');
  }

  return resData.data;
}

export interface RegisterPayload {
  username: string;
  email: string;
  password: string;
  displayName?: string;
}

export async function registerUser(payload: RegisterPayload): Promise<AuthResponseData> {
  let response: Response;
  try {
    response = await fetch(`${API_BASE_URL}/register`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload),
    });
  } catch (err: any) {
    throw new Error('Không thể kết nối đến máy chủ Backend (cổng 8080 chưa khởi chạy).');
  }

  const rawText = await response.text();
  let resData: ApiResponse<AuthResponseData> | null = null;

  if (rawText && rawText.trim().length > 0) {
    try {
      resData = JSON.parse(rawText);
    } catch {
      // Body is not JSON
    }
  }

  if (!response.ok) {
    const errorMsg = resData?.message || 
      (response.status === 504 || response.status === 502
        ? 'Không thể kết nối đến máy chủ Backend (cổng 8080 chưa khởi chạy).'
        : `Lỗi đăng ký tài khoản (${response.status})`);
    throw new Error(errorMsg);
  }

  if (!resData?.data) {
    throw new Error('Phản hồi từ máy chủ không hợp lệ.');
  }

  return resData.data;
}
