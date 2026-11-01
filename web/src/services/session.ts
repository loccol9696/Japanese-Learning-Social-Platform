const TOKEN_KEY = 'jlsp_token';
const USER_KEY = 'jlsp_user';

/** Phát ra khi server từ chối token (hết hạn / bị thu hồi) để App đưa người dùng về màn đăng nhập. */
export const SESSION_EXPIRED_EVENT = 'jlsp:session-expired';

export function getToken(): string | null {
  return localStorage.getItem(TOKEN_KEY);
}

export function saveSession(user: unknown, token: string): void {
  localStorage.setItem(USER_KEY, JSON.stringify(user));
  localStorage.setItem(TOKEN_KEY, token);
}

export function clearSession(): void {
  localStorage.removeItem(USER_KEY);
  localStorage.removeItem(TOKEN_KEY);
}

/** Đọc thời điểm hết hạn (ms) từ JWT; null nếu không đọc được. Chỉ để bỏ qua token đã chết, không để xác thực. */
export function tokenExpiryMs(token: string): number | null {
  try {
    const payload = token.split('.')[1].replace(/-/g, '+').replace(/_/g, '/');
    const json = JSON.parse(atob(payload.padEnd(Math.ceil(payload.length / 4) * 4, '=')));
    return typeof json.exp === 'number' ? json.exp * 1000 : null;
  } catch {
    return null;
  }
}

export function isTokenExpired(token: string, now: number = Date.now()): boolean {
  const exp = tokenExpiryMs(token);
  return exp !== null && exp <= now;
}

/** fetch có xử lý phiên: 401 khi đang có token nghĩa là phiên chết, xoá phiên và báo cho App. */
export async function authFetch(input: RequestInfo | URL, init?: RequestInit): Promise<Response> {
  const response = await fetch(input, init);
  if (response.status === 401 && getToken()) {
    clearSession();
    window.dispatchEvent(new Event(SESSION_EXPIRED_EVENT));
  }
  return response;
}

/** Đọc JSON an toàn: server trả 429/502 dạng HTML hoặc rỗng thì không ném lỗi parse khó hiểu. */
export async function readJson(response: Response): Promise<any> {
  try {
    return await response.json();
  } catch {
    return {};
  }
}
