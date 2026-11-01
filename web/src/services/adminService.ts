import type { ApiResponse, UserProfile, UserRole } from '../types/auth';
import { authFetch, readJson } from './session';

export interface AdminCreateUserPayload {
  username: string;
  email?: string;
  password: string;
  displayName?: string;
  role: UserRole;
}

export interface GeneratedAccountDto {
  id: number;
  username: string;
  password: string;
  email: string;
  role: UserRole;
  displayName: string;
}

export interface VideoModerationItem {
  id: number;
  title: string;
  description?: string;
  videoUrl: string;
  thumbnailUrl: string;
  duration: number;
  japaneseTranscription?: string;
  vietnameseTranslation?: string;
  subtitles?: string;
  status: 'PUBLIC' | 'PRIVATE' | 'UNLISTED';
  modStatus: 'PENDING' | 'APPROVED' | 'REJECTED';
  rejectionReason?: string;
  moderatedBy?: string;
  moderatedAt?: string;
  jlptLevel?: string;
  topics?: TopicItem[];
  hashtags?: string[];
  viewCount?: number;
  likeCount?: number;
  saveCount?: number;
  creatorId?: number;
  creatorUsername?: string;
  creatorDisplayName?: string;
  creatorAvatarUrl?: string;
  user?: {
    id: number;
    username: string;
    displayName: string;
    avatarUrl?: string;
  };
  createdAt: string;
}

export interface AdminUserItem {
  id: number;
  username: string;
  email: string;
  displayName?: string;
  role: UserRole;
  isActive: boolean;
  violationCount?: number;
  avatarUrl?: string;
  createdAt: string;
  updatedAt?: string;
}

export interface SubscriptionPlanItem {
  id: number;
  name: string;
  code: string;
  price: number;
  durationDays: number;
  dailyTokenLimit: number;
  description?: string;
  features?: string;
  isActive: boolean;
}

export interface SubscriptionOrderItem {
  id: number;
  orderCode: string;
  verificationCode: string;
  username: string;
  userDisplayName?: string;
  planName: string;
  planCode: string;
  amount: number;
  paymentMethod: string;
  status: 'PENDING' | 'SUCCESS' | 'FAILED' | 'CANCELLED';
  qrUrl?: string;
  createdAt: string;
  completedAt?: string;
}

export interface PageResponse<T> {
  content: T[];
  page: number;
  size: number;
  totalElements: number;
  totalPages: number;
  last: boolean;
}

function getAuthHeaders(): HeadersInit {
  const token = localStorage.getItem('jlsp_token');
  return {
    'Content-Type': 'application/json',
    ...(token ? { 'Authorization': `Bearer ${token}` } : {})
  };
}

// ==================== VIDEO MODERATION (MODERATOR) ====================

export async function getModerationVideos(
  modStatus: 'PENDING' | 'APPROVED' | 'REJECTED' = 'PENDING',
  page = 0,
  size = 10
): Promise<PageResponse<VideoModerationItem>> {
  const response = await fetch(`/api/v1/videos/moderation?status=${modStatus}&modStatus=${modStatus}&page=${page}&size=${size}`, {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<PageResponse<VideoModerationItem>> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải danh sách video cần duyệt');
  }
  return resData.data;
}

export async function approveVideo(videoId: number): Promise<VideoModerationItem> {
  const response = await fetch(`/api/v1/videos/${videoId}/approve`, {
    method: 'POST',
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<VideoModerationItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Phê duyệt video thất bại');
  }
  return resData.data;
}

export async function rejectVideo(videoId: number, reason: string): Promise<VideoModerationItem> {
  const response = await fetch(`/api/v1/videos/${videoId}/reject`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ reason }),
  });
  const resData: ApiResponse<VideoModerationItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Từ chối duyệt video thất bại');
  }
  return resData.data;
}

/** Sửa chủ đề / hashtag của video; video giữ nguyên trạng thái kiểm duyệt. */
export async function updateVideoClassification(
  videoId: number,
  payload: { topicIds: number[]; hashtags: string[] },
): Promise<VideoModerationItem> {
  const response = await authFetch(`/api/v1/videos/${videoId}/classification`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
  const resData: ApiResponse<VideoModerationItem> = await readJson(response);
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể cập nhật phân loại video');
  }
  return resData.data;
}

/** Cập nhật phụ đề / lời thoại của video (dành cho Moderator/Admin khi duyệt hoặc chỉnh sửa). */
export async function updateVideoSubtitles(
  videoId: number,
  subtitlesJson: string,
): Promise<VideoModerationItem> {
  const response = await authFetch(`/api/v1/videos/${videoId}/subtitles`, {
    method: 'PUT',
    headers: getAuthHeaders(),
    body: JSON.stringify({ subtitles: subtitlesJson }),
  });
  const resData: ApiResponse<VideoModerationItem> = await readJson(response);
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể cập nhật phụ đề video');
  }
  return resData.data;
}

// ==================== USER MANAGEMENT (ADMIN) ====================

export async function getAdminUsers(
  search = '',
  role = '',
  page = 0,
  size = 15
): Promise<PageResponse<AdminUserItem>> {
  const params = new URLSearchParams({
    page: page.toString(),
    size: size.toString(),
  });
  if (search.trim()) params.append('search', search.trim());
  if (role) params.append('role', role);

  const response = await fetch(`/api/v1/users/admin-list?${params.toString()}`, {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<PageResponse<AdminUserItem>> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải danh sách tài khoản');
  }
  return resData.data;
}

export async function toggleUserStatus(userId: number): Promise<AdminUserItem> {
  const response = await fetch(`/api/v1/users/${userId}/toggle-status`, {
    method: 'PATCH',
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<AdminUserItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể thay đổi trạng thái tài khoản');
  }
  return resData.data;
}

export async function createPrivilegedAccount(payload: AdminCreateUserPayload): Promise<UserProfile> {
  const response = await fetch('/api/v1/users/admin-create', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });

  const resData: ApiResponse<UserProfile> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tạo tài khoản đặc quyền. Vui lòng thử lại!');
  }
  return resData.data;
}

export async function batchCreateAccounts(
  count: number,
  role: 'ADMIN' | 'MODERATOR'
): Promise<GeneratedAccountDto[]> {
  const response = await fetch('/api/v1/users/admin-batch-create', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ count, role }),
  });

  const text = await response.text();
  let resData: ApiResponse<GeneratedAccountDto[]> | null = null;
  if (text && text.trim().length > 0) {
    try {
      resData = JSON.parse(text);
    } catch (_) {
      // not json
    }
  }

  if (!response.ok) {
    const errorMsg = resData?.message ||
      (response.status === 504 || response.status === 502
        ? 'Backend Spring Boot chưa khởi động hoặc mất kết nối (Port 8080)!'
        : `Lỗi máy chủ (${response.status}: ${response.statusText})`);
    throw new Error(errorMsg);
  }

  if (!resData || !resData.data) {
    throw new Error('Máy chủ trả về phản hồi rỗng. Vui lòng kiểm tra lại Backend.');
  }

  return resData.data;
}

// ==================== AUTH & CHANGE PASSWORD ====================

export async function changePassword(payload: {
  oldPassword: string;
  newPassword: string;
  username?: string;
}): Promise<void> {
  const response = await fetch('/api/v1/auth/change-password', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });

  const resData: ApiResponse<void> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Đổi mật khẩu thất bại. Kiểm tra lại mật khẩu cũ.');
  }
}

// ==================== PLANS & DAILY TOKEN LIMIT (ADMIN) ====================

export async function getAllPlansAdmin(): Promise<SubscriptionPlanItem[]> {
  const response = await fetch('/api/v1/subscription-plans/admin-all', {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<SubscriptionPlanItem[]> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải danh sách gói đăng ký');
  }
  return resData.data;
}

export async function createPlan(payload: {
  name: string;
  code: string;
  price: number;
  durationDays: number;
  dailyTokenLimit: number;
  description?: string;
  features?: string;
}): Promise<SubscriptionPlanItem> {
  const response = await fetch('/api/v1/subscription-plans', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
  const resData: ApiResponse<SubscriptionPlanItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tạo mới gói đăng ký');
  }
  return resData.data;
}

export async function updatePlan(
  id: number,
  payload: {
    name: string;
    code: string;
    price: number;
    durationDays: number;
    dailyTokenLimit: number;
    description?: string;
    features?: string;
    isActive?: boolean;
  }
): Promise<SubscriptionPlanItem> {
  const response = await fetch(`/api/v1/subscription-plans/${id}`, {
    method: 'PUT',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
  const resData: ApiResponse<SubscriptionPlanItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể cập nhật gói đăng ký');
  }
  return resData.data;
}

export interface TokenRateDto {
  secondsPerToken: number;
  description?: string;
}

export async function getTokenRate(): Promise<TokenRateDto> {
  const response = await fetch('/api/v1/subscription-plans/token-rate', {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<TokenRateDto> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải cấu hình tỷ lệ Token');
  }
  return resData.data;
}

export async function updateTokenRate(secondsPerToken: number): Promise<TokenRateDto> {
  const response = await fetch('/api/v1/subscription-plans/token-rate', {
    method: 'PUT',
    headers: getAuthHeaders(),
    body: JSON.stringify({ secondsPerToken }),
  });
  const resData: ApiResponse<TokenRateDto> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể lưu cấu hình tỷ lệ Token');
  }
  return resData.data;
}

// ==================== SUBSCRIPTION ORDER & QR LOCAL SIMULATOR ====================

export async function getSubscriptionOrders(
  page = 0,
  size = 15,
  sort = 'createdAt,desc',
  status: 'SUCCESS' | 'PENDING' | '' = 'SUCCESS'
): Promise<PageResponse<SubscriptionOrderItem>> {
  const statusParam = status ? `&status=${status}` : '';
  const response = await fetch(`/api/v1/payments/history?page=${page}&size=${size}&sort=${sort}${statusParam}`, {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<PageResponse<SubscriptionOrderItem>> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải lịch sử mua gói');
  }
  return resData.data;
}

export async function createQrOrder(planCode: string): Promise<{
  id?: number;
  orderCode: string;
  verificationCode: string;
  planName: string;
  amount: number;
  qrUrl?: string;
  qrCodeUrl?: string;
  status: string;
}> {
  const response = await fetch('/api/v1/payments/create-order', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ planCode }),
  });
  const resData: ApiResponse<any> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể khởi tạo đơn hàng thanh toán QR');
  }
  return resData.data;
}

export async function confirmPayment(orderCode: string, verificationCode: string): Promise<any> {
  const response = await fetch('/api/v1/payments/confirm', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ orderCode, verificationCode }),
  });
  const resData: ApiResponse<any> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Mã xác thực không đúng hoặc đơn hàng đã xử lý');
  }
  return resData.data;
}

export interface DailyMetricDto {
  dateLabel: string;
  value: number;
}

export interface PlanSalesBreakdownDto {
  planCode: string;
  planName: string;
  salesCount: number;
  revenue: number;
  percentage: number;
}

export interface AdminAnalyticsData {
  totalUsers: number;
  activeUsers: number;
  lockedUsers: number;
  adminCount: number;
  moderatorCount: number;
  learnerCount: number;
  userRegistrationTrends: DailyMetricDto[];
  totalTokensUsed: number;
  activeTokenUsersCount: number;
  tokenUsageTrends: DailyMetricDto[];
  totalRevenue: number;
  successfulOrdersCount: number;
  pendingOrdersCount: number;
  revenueTrends: DailyMetricDto[];
  planSalesBreakdown: PlanSalesBreakdownDto[];
}

export async function getAdminAnalytics(period: '7days' | 'month' | 'year' = '7days'): Promise<AdminAnalyticsData> {
  const response = await fetch(`/api/v1/admin/analytics?period=${period}`, {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<AdminAnalyticsData> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải dữ liệu thống kê từ máy chủ Backend');
  }
  return resData.data;
}

export async function getMetricTrend(
  metric: 'user' | 'token' | 'revenue',
  period: 'range' | '7days' | 'month' | 'year' | 'days_in_month',
  year?: number,
  month?: number,
  startDate?: string,
  endDate?: string
): Promise<DailyMetricDto[]> {
  const params = new URLSearchParams({ metric, period });
  if (year) params.append('year', year.toString());
  if (month) params.append('month', month.toString());
  if (startDate) params.append('startDate', startDate);
  if (endDate) params.append('endDate', endDate);

  const response = await fetch(`/api/v1/admin/analytics/trend?${params.toString()}`, {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<DailyMetricDto[]> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải dữ liệu xu hướng từ máy chủ Backend');
  }
  return resData.data || [];
}

export interface UpdateProfilePayload {
  username?: string;
  displayName?: string;
  email?: string;
  bio?: string;
  avatarUrl?: string;
}

export async function updateAdminProfile(
  currentUsername: string,
  payload: UpdateProfilePayload
): Promise<AdminUserItem> {
  const response = await fetch(`/api/v1/users/profile-by-username/${encodeURIComponent(currentUsername)}`, {
    method: 'PUT',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
  const resData: ApiResponse<AdminUserItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể cập nhật thông tin hồ sơ');
  }
  return resData.data;
}

// ==================== TOPICS (ADMIN) ====================

export interface TopicItem {
  id: number;
  name: string;
  isActive: boolean;
  sortOrder: number;
}

/** Chủ đề đang hiển thị; kiểm duyệt viên không có quyền gọi {@link getAllTopicsAdmin}. */
export async function getActiveTopics(): Promise<TopicItem[]> {
  const response = await authFetch('/api/v1/topics', { headers: getAuthHeaders() });
  const resData: ApiResponse<TopicItem[]> = await readJson(response);
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải danh sách chủ đề');
  }
  return resData.data;
}

export async function getAllTopicsAdmin(): Promise<TopicItem[]> {
  const response = await authFetch('/api/v1/topics/admin', { headers: getAuthHeaders() });
  const resData: ApiResponse<TopicItem[]> = await readJson(response);
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải danh sách chủ đề');
  }
  return resData.data;
}

export async function createTopic(payload: { name: string; sortOrder?: number }): Promise<TopicItem> {
  const response = await authFetch('/api/v1/topics/admin', {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
  const resData: ApiResponse<TopicItem> = await readJson(response);
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tạo chủ đề');
  }
  return resData.data;
}

export async function updateTopic(
  id: number,
  payload: { name: string; isActive?: boolean; sortOrder?: number }
): Promise<TopicItem> {
  const response = await authFetch(`/api/v1/topics/admin/${id}`, {
    method: 'PUT',
    headers: getAuthHeaders(),
    body: JSON.stringify(payload),
  });
  const resData: ApiResponse<TopicItem> = await readJson(response);
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể cập nhật chủ đề');
  }
  return resData.data;
}

// ==================== CONTENT REPORTS (MODERATOR ONLY) ====================
export type ReportTargetType = 'VIDEO' | 'COMMENT' | 'USER' | 'MESSAGE' | 'TRANSLATION' | 'GRAMMAR' | 'SCRIPT';
export type ReportReason =
  | 'SPAM'
  | 'INAPPROPRIATE'
  | 'HARASSMENT'
  | 'MISINFORMATION'
  | 'COPYRIGHT'
  | 'INACCURATE'
  | 'OTHER';
export type ReportStatus = 'PENDING' | 'RESOLVED' | 'DISMISSED';
export type ReportAction =
  | 'NONE'
  | 'WARN_USER'
  | 'HIDE_VIDEO'
  | 'DELETE_COMMENT'
  | 'HIDE_MESSAGE'
  | 'EDIT_TRANSLATION'
  | 'REMOVE_TRANSLATION'
  | 'EDIT_GRAMMAR'
  | 'REMOVE_GRAMMAR'
  | 'LOCK_USER'
  | 'EDIT_SCRIPT';

/** Nội dung bản dịch / mẫu ngữ pháp / câu thoại: backend trả về để điền sẵn, kiểm duyệt viên sửa rồi gửi lại. */
export interface ReportCorrection {
  translation?: string;
  pattern?: string;
  meaning?: string;
  explanation?: string;
  scriptText?: string;
}

export interface ReportItem {
  id: number;
  targetType: ReportTargetType;
  targetId: number;
  reason: ReportReason;
  detail?: string;
  status: ReportStatus;
  action?: ReportAction;
  resolutionNote?: string;
  resolvedBy?: number;
  resolvedAt?: string;
  createdAt: string;
  reporterId: number;
  reporterUsername: string;
  targetExists: boolean;
  targetSummary?: string;
  targetSnapshot?: string;
  targetImageUrl?: string;
  targetContent?: ReportCorrection;
  targetOwnerId?: number;
  targetOwnerUsername?: string;
  targetOwnerViolationCount?: number;
  targetVideoId?: number;
  targetVideoUrl?: string;
  pendingCountForTarget?: number;
}

export async function getReports(
  status: ReportStatus = 'PENDING',
  targetType?: ReportTargetType | '',
  page = 0,
  size = 10
): Promise<PageResponse<ReportItem>> {
  const params = new URLSearchParams({ status, page: String(page), size: String(size) });
  if (targetType) params.set('targetType', targetType);
  const response = await fetch(`/api/v1/admin/reports?${params.toString()}`, {
    headers: getAuthHeaders(),
  });
  const resData: ApiResponse<PageResponse<ReportItem>> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể tải danh sách báo cáo');
  }
  return resData.data;
}

export async function resolveReport(
  id: number,
  action: ReportAction,
  note: string,
  correction?: ReportCorrection
): Promise<ReportItem> {
  const response = await fetch(`/api/v1/admin/reports/${id}/resolve`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ action, note: note.trim() || undefined, correction }),
  });
  const resData: ApiResponse<ReportItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể xử lý báo cáo');
  }
  return resData.data;
}

export async function dismissReport(id: number, note?: string): Promise<ReportItem> {
  const response = await fetch(`/api/v1/admin/reports/${id}/dismiss`, {
    method: 'POST',
    headers: getAuthHeaders(),
    body: JSON.stringify({ note: note ? note.trim() : undefined }),
  });
  const resData: ApiResponse<ReportItem> = await response.json();
  if (!response.ok) {
    throw new Error(resData.message || 'Không thể bác bỏ báo cáo');
  }
  return resData.data;
}

export async function getPendingReportCount(): Promise<number> {
  try {
    const response = await fetch('/api/v1/admin/reports?status=PENDING&page=0&size=1', {
      headers: getAuthHeaders(),
    });
    const resData: ApiResponse<PageResponse<ReportItem>> = await response.json();
    if (!response.ok || !resData.data) {
      return 0;
    }
    return resData.data.totalElements || 0;
  } catch {
    return 0;
  }
}