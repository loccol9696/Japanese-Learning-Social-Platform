import React, { useState, useEffect } from 'react';
import type { UserProfile } from '../types/auth';
import {
  Video,
  AlertTriangle,
  Users,
  CreditCard,
  Sliders,
  ChevronLeft,
  ChevronRight,
  LogOut,
  Search,
  CheckCircle2,
  XCircle,
  UserPlus,
  Edit2,
  Lock,
  Unlock,
  Key,
  Download,
  Copy,
  QrCode,
  RefreshCw,
  ArrowUpDown,
  Sparkles,
  Shield,
  BarChart3,
  TrendingUp,
  PieChart,
  Coins,
  Save,
  Eye,
  Play,
  Ticket,
  Plus,
  Trash2,
  Calendar
} from 'lucide-react';
import {
  getModerationVideos,
  approveVideo,
  rejectVideo,
  getAdminUsers,
  toggleUserStatus,
  createPrivilegedAccount,
  batchCreateAccounts,
  changePassword,
  getAllPlansAdmin,
  updatePlan,
  getSubscriptionOrders,
  createQrOrder,
  confirmPayment,
  getAdminAnalytics,
  updateAdminProfile,
  getMetricTrend,
  getTokenRate,
  updateTokenRate,
  type VideoModerationItem,
  type AdminUserItem,
  type SubscriptionPlanItem,
  type SubscriptionOrderItem,
  type GeneratedAccountDto,
  type AdminAnalyticsData,
  type DailyMetricDto,
  getAdminPromoCodes,
  createAdminPromoCode,
  updateAdminPromoCode,
  toggleAdminPromoCode,
  deleteAdminPromoCode,
  type PromoCodeItem,
  type PromoCodePayload
} from '../services/adminService';
import './AdminDashboard.css';

interface AdminDashboardProps {
  user: UserProfile;
  onLogout: () => void;
  onUpdateUser?: (updated: UserProfile) => void;
}

type TabType = 'analytics' | 'videos' | 'users' | 'subscriptions' | 'pricing' | 'vouchers' | 'reports' | 'profile';

export const AdminDashboard: React.FC<AdminDashboardProps> = ({ user, onLogout, onUpdateUser }) => {
  const isModerator = user.role === 'MODERATOR';
  const isAdmin = user.role === 'ADMIN';

  // Guard: Initial tab depends on role.
  const [activeTab, setActiveTab] = useState<TabType>(() => (isModerator ? 'videos' : 'analytics'));
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);

  // Enforce role separation on tab changes
  useEffect(() => {
    if (isAdmin && activeTab === 'videos') {
      setActiveTab('analytics');
    }
    if (isModerator && (activeTab === 'users' || activeTab === 'subscriptions' || activeTab === 'pricing' || activeTab === 'vouchers' || activeTab === 'analytics')) {
      setActiveTab('videos');
    }
  }, [isAdmin, isModerator, activeTab]);

  // Global Toasts / Notification
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };

  // ==================== PROFILE & CHANGE PASSWORD STATE ====================
  const [profileUsername, setProfileUsername] = useState(user.username);
  const [profileDisplayName, setProfileDisplayName] = useState(user.displayName || user.username);
  const [profileEmail, setProfileEmail] = useState(user.email || `${user.username}@jlsp.internal`);
  const [profileBio, setProfileBio] = useState('');
  const [profileAvatarUrl, setProfileAvatarUrl] = useState(user.avatarUrl || '');
  const [isSavingProfile, setIsSavingProfile] = useState(false);

  const [oldPassword, setOldPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmPassword, setConfirmPassword] = useState('');
  const [isSubmittingPassword, setIsSubmittingPassword] = useState(false);

  // Synchronize profile state when user prop changes
  useEffect(() => {
    setProfileUsername(user.username);
    setProfileDisplayName(user.displayName || user.username);
    setProfileEmail(user.email || `${user.username}@jlsp.internal`);
    setProfileAvatarUrl(user.avatarUrl || '');
  }, [user]);

  const handleSaveProfile = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!profileUsername.trim()) {
      alert('Tên đăng nhập không được để trống!');
      return;
    }
    setIsSavingProfile(true);
    try {
      const updated = await updateAdminProfile(user.username, {
        username: profileUsername.trim(),
        displayName: profileDisplayName.trim(),
        email: profileEmail.trim(),
        bio: profileBio.trim(),
        avatarUrl: profileAvatarUrl.trim(),
      });
      showToast('Cập nhật hồ sơ tài khoản thành công!');
      const updatedProfile: UserProfile = {
        ...user,
        username: updated.username,
        displayName: updated.displayName,
        email: updated.email,
        avatarUrl: updated.avatarUrl,
      };
      if (onUpdateUser) {
        onUpdateUser(updatedProfile);
      }
    } catch (err: any) {
      alert('Lỗi: ' + (err.message || 'Không thể cập nhật hồ sơ'));
    } finally {
      setIsSavingProfile(false);
    }
  };

  const handleChangePassword = async (e: React.FormEvent) => {
    e.preventDefault();
    if (newPassword !== confirmPassword) {
      alert('Mật khẩu xác nhận không khớp!');
      return;
    }
    if (newPassword.length < 6) {
      alert('Mật khẩu mới phải có ít nhất 6 ký tự!');
      return;
    }
    setIsSubmittingPassword(true);
    try {
      await changePassword({
        oldPassword,
        newPassword,
        username: profileUsername || user.username,
      });
      showToast('Đổi mật khẩu thành công!');
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
    } catch (err: any) {
      alert('Lỗi: ' + (err.message || 'Không thể đổi mật khẩu'));
    } finally {
      setIsSubmittingPassword(false);
    }
  };

  // ==================== ANALYTICS & PLATFORM STATS (ADMIN ONLY) ====================
  const [analyticsData, setAnalyticsData] = useState<AdminAnalyticsData | null>(null);
  const [isLoadingAnalytics, setIsLoadingAnalytics] = useState(false);

  // Chart 1: Học viên đăng ký (Chỉ role USER, loại trừ Admin/Mod)
  const [userPeriod, setUserPeriod] = useState<'7days' | 'days_in_month' | 'month' | 'year'>('days_in_month');
  const [userYear, setUserYear] = useState<number>(2026);
  const [userMonth, setUserMonth] = useState<number>(10);
  const [userTrendData, setUserTrendData] = useState<DailyMetricDto[] | null>(null);
  const [isLoadingUserTrend, setIsLoadingUserTrend] = useState<boolean>(false);
  const [userChartType, setUserChartType] = useState<'spline' | 'bar'>('spline');

  // Chart 2: Tiêu thụ Token AI
  const [tokenPeriod, setTokenPeriod] = useState<'7days' | 'days_in_month' | 'month' | 'year'>('days_in_month');
  const [tokenYear, setTokenYear] = useState<number>(2026);
  const [tokenMonth, setTokenMonth] = useState<number>(10);
  const [tokenTrendData, setTokenTrendData] = useState<DailyMetricDto[] | null>(null);
  const [isLoadingTokenTrend, setIsLoadingTokenTrend] = useState<boolean>(false);
  const [tokenChartType, setTokenChartType] = useState<'spline' | 'bar'>('spline');

  // Chart 3: Doanh thu bán gói VIP
  const [revPeriod, setRevPeriod] = useState<'7days' | 'days_in_month' | 'month' | 'year'>('days_in_month');
  const [revYear, setRevYear] = useState<number>(2026);
  const [revMonth, setRevMonth] = useState<number>(10);
  const [revTrendData, setRevTrendData] = useState<DailyMetricDto[] | null>(null);
  const [isLoadingRevTrend, setIsLoadingRevTrend] = useState<boolean>(false);
  const [revChartType, setRevChartType] = useState<'spline' | 'bar'>('spline');

  const loadAnalytics = async () => {
    if (!isAdmin) return;
    setIsLoadingAnalytics(true);
    try {
      const data = await getAdminAnalytics('month');
      setAnalyticsData(data);
    } catch (err: any) {
      console.error('Lỗi tải thống kê:', err);
    } finally {
      setIsLoadingAnalytics(false);
    }
  };

  const fetchUserTrend = async (period: '7days' | 'days_in_month' | 'month' | 'year', y: number, m: number) => {
    if (!isAdmin) return;
    setIsLoadingUserTrend(true);
    try {
      const data = await getMetricTrend('user', period, y, m);
      setUserTrendData(data);
    } catch (err) {
      console.error('Lỗi tải xu hướng học viên:', err);
    } finally {
      setIsLoadingUserTrend(false);
    }
  };

  const fetchTokenTrend = async (period: '7days' | 'days_in_month' | 'month' | 'year', y: number, m: number) => {
    if (!isAdmin) return;
    setIsLoadingTokenTrend(true);
    try {
      const data = await getMetricTrend('token', period, y, m);
      setTokenTrendData(data);
    } catch (err) {
      console.error('Lỗi tải xu hướng token:', err);
    } finally {
      setIsLoadingTokenTrend(false);
    }
  };

  const fetchRevTrend = async (period: '7days' | 'days_in_month' | 'month' | 'year', y: number, m: number) => {
    if (!isAdmin) return;
    setIsLoadingRevTrend(true);
    try {
      const data = await getMetricTrend('revenue', period, y, m);
      setRevTrendData(data);
    } catch (err) {
      console.error('Lỗi tải xu hướng doanh thu:', err);
    } finally {
      setIsLoadingRevTrend(false);
    }
  };

  useEffect(() => {
    if (isAdmin && activeTab === 'analytics') {
      loadAnalytics();
    }
  }, [isAdmin, activeTab]);

  useEffect(() => {
    if (isAdmin && activeTab === 'analytics') {
      fetchUserTrend(userPeriod, userYear, userMonth);
    }
  }, [isAdmin, activeTab, userPeriod, userYear, userMonth]);

  useEffect(() => {
    if (isAdmin && activeTab === 'analytics') {
      fetchTokenTrend(tokenPeriod, tokenYear, tokenMonth);
    }
  }, [isAdmin, activeTab, tokenPeriod, tokenYear, tokenMonth]);

  useEffect(() => {
    if (isAdmin && activeTab === 'analytics') {
      fetchRevTrend(revPeriod, revYear, revMonth);
    }
  }, [isAdmin, activeTab, revPeriod, revYear, revMonth]);

  // Đồng bộ nhanh thời gian cho tất cả biểu đồ cùng một lúc
  const applyQuickSync = (period: '7days' | 'days_in_month' | 'month' | 'year', y: number = 2026, m: number = 10) => {
    setUserPeriod(period);
    setUserYear(y);
    setUserMonth(m);

    setTokenPeriod(period);
    setTokenYear(y);
    setTokenMonth(m);

    setRevPeriod(period);
    setRevYear(y);
    setRevMonth(m);
  };

  // Helper render thanh tóm tắt chỉ số đỉnh cao / trung bình / tổng cộng
  const renderStatsStrip = (
    metrics: DailyMetricDto[] | null | undefined,
    formatVal: (val: number) => string,
    unitLabel: string = ''
  ) => {
    const list = metrics || [];
    const total = list.reduce((sum, d) => sum + d.value, 0);
    const peak = list.length > 0 ? Math.max(0, ...list.map(d => d.value)) : 0;
    const avg = list.length > 0 ? Math.round(total / list.length) : 0;

    return (
      <div className="chart-stat-strip">
        <div className="stat-chip">
          <span className="stat-chip-label">Tổng kỳ:</span>
          <span className="stat-chip-val">{formatVal(total)} {unitLabel}</span>
        </div>
        <div className="stat-chip">
          <span className="stat-chip-label">Đỉnh cao (Peak):</span>
          <span className="stat-chip-val">{formatVal(peak)} {unitLabel}</span>
        </div>
        <div className="stat-chip">
          <span className="stat-chip-label">Trung bình:</span>
          <span className="stat-chip-val">{formatVal(avg)} {unitLabel}</span>
        </div>
      </div>
    );
  };

  // Helper render đường cong Parabol (Cubic Bezier Spline) mượt mà cho biểu đồ
  const renderParabolicSpline = (
    metrics: { dateLabel: string; value: number }[] | undefined,
    color: string,
    gradientId: string,
    formatVal: (val: number) => string,
    isLoading: boolean = false
  ) => {
    if (isLoading) {
      return (
        <div className="curved-chart-container" style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>
          <span className="live-pulse-dot" style={{ display: 'inline-block', marginRight: 8 }} />
          Đang tải dữ liệu biểu đồ...
        </div>
      );
    }

    if (!metrics || metrics.length === 0) {
      return (
        <div className="curved-chart-container" style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>
          Chưa có dữ liệu thống kê (0)
        </div>
      );
    }

    const width = 640;
    const height = 210;
    const isDense = metrics.length > 14;
    const padX = isDense ? 22 : 40;
    const padY = 32;
    const chartW = width - 2 * padX;
    const chartH = height - 2 * padY;

    const maxVal = Math.max(1, ...metrics.map(m => m.value));

    // Calculate points (x, y)
    const points = metrics.map((m, idx) => {
      const x = padX + (idx / Math.max(1, metrics.length - 1)) * chartW;
      const y = (height - padY) - (m.value / maxVal) * chartH;
      return { x, y, label: m.dateLabel, value: m.value };
    });

    // Compute smooth cubic Bezier parabolic path
    let curvePath = `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)}`;
    if (points.length > 1) {
      for (let i = 0; i < points.length - 1; i++) {
        const p0 = points[i === 0 ? 0 : i - 1];
        const p1 = points[i];
        const p2 = points[i + 1];
        const p3 = points[i + 2 < points.length ? i + 2 : i + 1];

        // Smooth parabolic tangent
        const cp1x = p1.x + (p2.x - p0.x) / 5;
        const cp1y = Math.min(height - padY, Math.max(padY / 2, p1.y + (p2.y - p0.y) / 5));
        const cp2x = p2.x - (p3.x - p1.x) / 5;
        const cp2y = Math.min(height - padY, Math.max(padY / 2, p2.y - (p3.y - p1.y) / 5));

        curvePath += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`;
      }
    }

    const areaPath = `${curvePath} L ${points[points.length - 1].x.toFixed(1)} ${(height - padY).toFixed(1)} L ${points[0].x.toFixed(1)} ${(height - padY).toFixed(1)} Z`;

    return (
      <div className="curved-chart-container">
        <svg viewBox={`0 0 ${width} ${height}`} className="curved-chart-svg">
          <defs>
            <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
              <stop offset="0%" stopColor={color} stopOpacity="0.4" />
              <stop offset="100%" stopColor={color} stopOpacity="0.0" />
            </linearGradient>
          </defs>

          {/* Guide grid lines */}
          <line x1={padX} y1={padY} x2={width - padX} y2={padY} stroke="var(--admin-border-subtle)" strokeDasharray="3 3" />
          <line x1={padX} y1={height / 2} x2={width - padX} y2={height / 2} stroke="var(--admin-border-subtle)" strokeDasharray="3 3" />
          <line x1={padX} y1={height - padY} x2={width - padX} y2={height - padY} stroke="var(--admin-border)" strokeWidth="1.5" />

          {/* Area Fill under curve */}
          <path d={areaPath} fill={`url(#${gradientId})`} />

          {/* Parabolic Curved Spline Line */}
          <path d={curvePath} fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />

          {/* Nodes with Badges and Labels */}
          {points.map((pt, i) => {
            const valStr = formatVal(pt.value);
            const badgeW = Math.max(26, valStr.length * 7 + 10);
            const showLabel = !isDense || (i % 3 === 0) || (i === points.length - 1) || (pt.value > 0);
            const showBadge = !isDense || (pt.value > 0);

            return (
              <g key={i} className="chart-svg-node">
                <title>{`${pt.label}: ${valStr}`}</title>

                {/* Vertical hint line */}
                {pt.value > 0 && (
                  <line
                    x1={pt.x}
                    y1={pt.y}
                    x2={pt.x}
                    y2={height - padY}
                    stroke={color}
                    strokeWidth="1"
                    strokeDasharray="2 2"
                    opacity="0.45"
                  />
                )}

                {/* Point circle */}
                <circle
                  cx={pt.x}
                  cy={pt.y}
                  r={pt.value > 0 ? (isDense ? 4.5 : 5.5) : (isDense ? 2.5 : 3.5)}
                  fill="#ffffff"
                  stroke={pt.value > 0 ? color : '#94a3b8'}
                  strokeWidth="2.5"
                />

                {/* Badge Container */}
                {showBadge && (
                  <>
                    <rect
                      x={pt.x - badgeW / 2}
                      y={Math.min(height - padY - 26, Math.max(6, pt.y - 25))}
                      width={badgeW}
                      height={18}
                      rx={3}
                      fill="#ffffff"
                      stroke={pt.value > 0 ? color : '#cbd5e1'}
                      strokeWidth="1.2"
                      className="chart-svg-badge-rect"
                    />
                    <text
                      x={pt.x}
                      y={Math.min(height - padY - 13, Math.max(19, pt.y - 12))}
                      textAnchor="middle"
                      className="chart-svg-badge-text"
                      fill={pt.value > 0 ? '#0f172a' : '#94a3b8'}
                    >
                      {valStr}
                    </text>
                  </>
                )}

                {/* X Axis Label */}
                {showLabel && (
                  <text x={pt.x} y={height - 10} textAnchor="middle" className="chart-svg-label">
                    {pt.label}
                  </text>
                )}
              </g>
            );
          })}
        </svg>
      </div>
    );
  };

  // Helper render biểu đồ cột trực quan
  const renderBarChart = (
    metrics: { dateLabel: string; value: number }[] | undefined,
    colorClass: string,
    formatVal: (val: number) => string,
    isLoading: boolean = false
  ) => {
    if (isLoading) {
      return (
        <div className="chart-bars-wrap" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 210 }}>
          <span style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>Đang tải dữ liệu biểu đồ...</span>
        </div>
      );
    }

    if (!metrics || metrics.length === 0) {
      return (
        <div className="chart-bars-wrap" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 210 }}>
          <span style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>Chưa có dữ liệu (0)</span>
        </div>
      );
    }

    const maxVal = Math.max(1, ...metrics.map(t => t.value));
    const isDense = metrics.length > 14;

    return (
      <div className="chart-bars-wrap">
        {metrics.map((t, idx) => {
          const heightPct = t.value > 0 ? Math.max(10, (t.value / maxVal) * 85) : 3;
          const showLabel = !isDense || (idx % 3 === 0) || (idx === metrics.length - 1) || (t.value > 0);
          return (
            <div key={idx} className="chart-col-item">
              <div
                className={`chart-bar-rect ${colorClass} ${t.value === 0 ? 'is-zero' : ''}`}
                style={{
                  height: `${heightPct}%`,
                  animationDelay: `${idx * 20}ms`
                }}
                title={`${t.dateLabel}: ${formatVal(t.value)}`}
              >
                <span className="chart-bar-val-badge">
                  {t.value > 0 ? formatVal(t.value) : (isDense ? '' : '0')}
                </span>
              </div>
              <span className="chart-col-label">{showLabel ? t.dateLabel : ''}</span>
            </div>
          );
        })}
      </div>
    );
  };

  // ==================== VIDEO MODERATION (MODERATOR ONLY) ====================
  const [videos, setVideos] = useState<VideoModerationItem[]>([]);
  const [videoModFilter, setVideoModFilter] = useState<'PENDING' | 'APPROVED' | 'REJECTED'>('PENDING');
  const [isLoadingVideos, setIsLoadingVideos] = useState(false);
  const [selectedRejectVideo, setSelectedRejectVideo] = useState<VideoModerationItem | null>(null);
  const [selectedDetailVideo, setSelectedDetailVideo] = useState<VideoModerationItem | null>(null);
  const [rejectReason, setRejectReason] = useState('Vi phạm bản quyền âm thanh / video');
  const [customRejectReason, setCustomRejectReason] = useState('');
  const [isSubmittingReject, setIsSubmittingReject] = useState(false);

  // Pagination for video moderation table (Limit 10 per page)
  const [videosPage, setVideosPage] = useState(0);
  const [videosTotalPages, setVideosTotalPages] = useState(1);
  const [videosTotalElements, setVideosTotalElements] = useState(0);

  const loadModerationVideos = async () => {
    if (!isModerator) return;
    setIsLoadingVideos(true);
    try {
      const data = await getModerationVideos(videoModFilter, videosPage, 10);
      setVideos(data.content || []);
      setVideosTotalPages(data.totalPages || 1);
      setVideosTotalElements(data.totalElements || 0);
    } catch (err: any) {
      console.error(err);
    } finally {
      setIsLoadingVideos(false);
    }
  };

  useEffect(() => {
    if (isModerator && activeTab === 'videos') {
      loadModerationVideos();
    }
  }, [isModerator, activeTab, videoModFilter, videosPage]);

  const handleApproveVideo = async (videoId: number) => {
    try {
      await approveVideo(videoId);
      showToast('Đã phê duyệt video bài học thành công! Video đã chuyển sang mục Đã thông qua (APPROVED).');
      if (selectedDetailVideo && selectedDetailVideo.id === videoId) {
        setSelectedDetailVideo(null);
      }
      if (videoModFilter === 'PENDING') {
        setVideosPage(0);
        setVideoModFilter('APPROVED');
      } else {
        loadModerationVideos();
      }
    } catch (err: any) {
      alert('Lỗi phê duyệt: ' + err.message);
    }
  };

  const handleConfirmRejectVideo = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedRejectVideo) return;
    const finalReason = rejectReason === 'Lý do khác' ? customRejectReason.trim() : rejectReason;
    if (!finalReason) {
      alert('Vui lòng cung cấp lý do từ chối kiểm duyệt!');
      return;
    }

    setIsSubmittingReject(true);
    try {
      await rejectVideo(selectedRejectVideo.id, finalReason);
      showToast(`Đã từ chối video "${selectedRejectVideo.title}"! Đã chuyển sang mục Đã từ chối (REJECTED).`);
      if (selectedDetailVideo && selectedDetailVideo.id === selectedRejectVideo.id) {
        setSelectedDetailVideo(null);
      }
      setSelectedRejectVideo(null);
      setCustomRejectReason('');
      if (videoModFilter === 'PENDING') {
        setVideosPage(0);
        setVideoModFilter('REJECTED');
      } else {
        loadModerationVideos();
      }
    } catch (err: any) {
      alert('Lỗi từ chối video: ' + err.message);
    } finally {
      setIsSubmittingReject(false);
    }
  };

  // ==================== USER MANAGEMENT (ADMIN ONLY) ====================
  const [usersList, setUsersList] = useState<AdminUserItem[]>([]);
  const [userSearch, setUserSearch] = useState('');
  const [userRoleFilter, setUserRoleFilter] = useState('USER');
  const [isLoadingUsers, setIsLoadingUsers] = useState(false);

  // Single User Create Modal
  const [isSingleCreateModalOpen, setIsSingleCreateModalOpen] = useState(false);
  const [singleUsername, setSingleUsername] = useState('');
  const [singlePassword, setSinglePassword] = useState('');
  const [singleDisplayName, setSingleDisplayName] = useState('');
  const [singleRole, setSingleRole] = useState<'ADMIN' | 'MODERATOR'>('MODERATOR');
  const [isSubmittingSingle, setIsSubmittingSingle] = useState(false);

  // Batch User Create Modal
  const [isBatchModalOpen, setIsBatchModalOpen] = useState(false);
  const [batchCount, setBatchCount] = useState<number>(5);
  const [batchRole, setBatchRole] = useState<'MODERATOR' | 'ADMIN'>('MODERATOR');
  const [generatedAccounts, setGeneratedAccounts] = useState<GeneratedAccountDto[] | null>(null);
  const [isSubmittingBatch, setIsSubmittingBatch] = useState(false);

  // Pagination state for users table (Limit 10 per page)
  const [usersPage, setUsersPage] = useState(0);
  const [usersTotalPages, setUsersTotalPages] = useState(1);
  const [usersTotalElements, setUsersTotalElements] = useState(0);

  const loadAdminUsers = async () => {
    if (!isAdmin) return;
    setIsLoadingUsers(true);
    try {
      const data = await getAdminUsers(userSearch, userRoleFilter, usersPage, 10);
      setUsersList(data.content || []);
      setUsersTotalPages(data.totalPages || 1);
      setUsersTotalElements(data.totalElements || 0);
    } catch (err: any) {
      console.error(err);
    } finally {
      setIsLoadingUsers(false);
    }
  };

  useEffect(() => {
    if (isAdmin && activeTab === 'users') {
      loadAdminUsers();
    }
  }, [isAdmin, activeTab, userRoleFilter, usersPage]);

  const handleToggleUserStatus = async (userId: number) => {
    try {
      const updated = await toggleUserStatus(userId);
      setUsersList(prev => prev.map(u => (u.id === userId ? { ...u, isActive: updated.isActive } : u)));
      showToast(updated.isActive ? 'Đã mở khóa tài khoản!' : 'Đã khóa tài khoản thành công!');
    } catch (err: any) {
      alert('Lỗi thao tác: ' + err.message);
    }
  };

  const handleSingleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmittingSingle(true);
    try {
      await createPrivilegedAccount({
        username: singleUsername.trim(),
        password: singlePassword,
        displayName: singleDisplayName.trim(),
        role: singleRole,
      });
      showToast(`Tạo thành công tài khoản ${singleRole}: ${singleUsername}!`);
      setIsSingleCreateModalOpen(false);
      setSingleUsername('');
      setSinglePassword('');
      setSingleDisplayName('');
      loadAdminUsers();
    } catch (err: any) {
      alert('Lỗi: ' + err.message);
    } finally {
      setIsSubmittingSingle(false);
    }
  };

  const downloadTextFile = (accounts: GeneratedAccountDto[], role: string) => {
    const timestamp = new Date().toISOString().replace(/T/, ' ').replace(/\..+/, '');
    const header = [
      '================================================================================',
      'HỆ THỐNG JLSP - DANH SÁCH TÀI KHOẢN ĐẶC QUYỀN ĐƯỢC TẠO TỰ ĐỘNG',
      `Thời gian tạo: ${timestamp}`,
      `Vai trò hệ thống: ${role}`,
      `Số lượng tài khoản: ${accounts.length}`,
      '================================================================================',
      'STT | Tên tài khoản          | Mật khẩu ban đầu   | Email',
      '----+------------------------+--------------------+------------------------------'
    ];

    const rows = accounts.map((acc, idx) => {
      const stt = String(idx + 1).padEnd(3, ' ');
      const uname = acc.username.padEnd(22, ' ');
      const pwd = acc.password.padEnd(18, ' ');
      return `${stt} | ${uname} | ${pwd} | ${acc.email}`;
    });

    const footer = [
      '================================================================================',
      'LƯU Ý BẢO MẬT:',
      '- Hãy gửi thông tin tài khoản an toàn qua kênh bảo mật nội bộ.',
      '- Yêu cầu đổi mật khẩu ngay sau lần đăng nhập đầu tiên tại mục "Đổi mật khẩu".',
      '================================================================================'
    ];

    const fullContent = [...header, ...rows, ...footer].join('\r\n');
    const blob = new Blob([fullContent], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `JLSP_Accounts_${role}_${new Date().toISOString().slice(0, 10)}.txt`;
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
  };

  const handleBatchCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (batchCount < 1 || batchCount > 50) {
      alert('Số lượng tài khoản phải từ 1 đến 50!');
      return;
    }
    setIsSubmittingBatch(true);
    try {
      const accounts = await batchCreateAccounts(batchCount, batchRole);
      setGeneratedAccounts(accounts);
      // Tự động tải file txt về máy theo yêu cầu của user
      downloadTextFile(accounts, batchRole);
      showToast(`Đã tự động khởi tạo ${accounts.length} tài khoản ${batchRole} và tải file .txt về máy!`);
      loadAdminUsers();
    } catch (err: any) {
      alert('Lỗi tạo hàng loạt: ' + err.message);
    } finally {
      setIsSubmittingBatch(false);
    }
  };

  // ==================== SUBSCRIPTION HISTORY & QR LOCAL SIMULATOR ====================
  const [orders, setOrders] = useState<SubscriptionOrderItem[]>([]);
  const [isLoadingOrders, setIsLoadingOrders] = useState(false);
  const [orderSortField, setOrderSortField] = useState<'createdAt' | 'amount' | 'status'>('createdAt');
  const [orderSortDir, setOrderSortDir] = useState<'asc' | 'desc'>('desc');

  // QR Test Simulator State
  const [isQrModalOpen, setIsQrModalOpen] = useState(false);
  const [selectedPlanCode, setSelectedPlanCode] = useState('PRO_MONTHLY');
  const [activeQrOrder, setActiveQrOrder] = useState<{
    orderCode: string;
    verificationCode: string;
    planName: string;
    amount: number;
    qrCodeUrl: string;
    status: string;
  } | null>(null);
  const [verificationInput, setVerificationInput] = useState('');
  const [isProcessingPayment, setIsProcessingPayment] = useState(false);
  const [paymentSuccessData, setPaymentSuccessData] = useState<any | null>(null);

  // Pagination state for subscription orders table (Limit 10 per page)
  const [ordersPage, setOrdersPage] = useState(0);
  const [ordersTotalPages, setOrdersTotalPages] = useState(1);
  const [ordersTotalElements, setOrdersTotalElements] = useState(0);

  const loadSubscriptionOrders = async () => {
    if (!isAdmin) return;
    setIsLoadingOrders(true);
    try {
      const sortParam = `${orderSortField},${orderSortDir}`;
      const data = await getSubscriptionOrders(ordersPage, 10, sortParam);
      setOrders(data.content || []);
      setOrdersTotalPages(data.totalPages || 1);
      setOrdersTotalElements(data.totalElements || 0);
    } catch (err: any) {
      console.error(err);
    } finally {
      setIsLoadingOrders(false);
    }
  };

  useEffect(() => {
    if (isAdmin && activeTab === 'subscriptions') {
      loadSubscriptionOrders();
    }
  }, [isAdmin, activeTab, orderSortField, orderSortDir, ordersPage]);

  const handleToggleSort = (field: 'createdAt' | 'amount' | 'status') => {
    setOrdersPage(0);
    if (orderSortField === field) {
      setOrderSortDir(prev => (prev === 'asc' ? 'desc' : 'asc'));
    } else {
      setOrderSortField(field);
      setOrderSortDir('desc');
    }
  };

  const handleCreateQrOrder = async () => {
    try {
      const data = await createQrOrder(selectedPlanCode);
      setActiveQrOrder(data);
      setVerificationInput(data.verificationCode); // Tiện ích điền sẵn mã dưới QR để test nhanh
      setPaymentSuccessData(null);
    } catch (err: any) {
      alert('Lỗi tạo mã QR: ' + err.message);
    }
  };

  const handleConfirmQrPayment = async () => {
    if (!activeQrOrder) return;
    if (!verificationInput.trim()) {
      alert('Vui lòng nhập mã xác thực hiện ở dưới QR!');
      return;
    }
    setIsProcessingPayment(true);
    try {
      const result = await confirmPayment(activeQrOrder.orderCode, verificationInput.trim());
      setPaymentSuccessData(result);
      showToast('Thanh toán thành công! Gói VIP và hạn mức Token ngày đã được nâng cấp.');
      loadSubscriptionOrders();
    } catch (err: any) {
      alert('Xác thực thất bại: ' + err.message);
    } finally {
      setIsProcessingPayment(false);
    }
  };

  // ==================== SUBSCRIPTION PLANS & TOKEN LIMIT (ADMIN ONLY) ====================
  const [plans, setPlans] = useState<SubscriptionPlanItem[]>([]);
  const [isLoadingPlans, setIsLoadingPlans] = useState(false);
  const [editingPlan, setEditingPlan] = useState<SubscriptionPlanItem | null>(null);
  const [editName, setEditName] = useState('');
  const [editPrice, setEditPrice] = useState<number>(0);
  const [editDuration, setEditDuration] = useState<number>(30);
  const [editDailyTokenLimit, setEditDailyTokenLimit] = useState<number>(500);
  const [editDescription, setEditDescription] = useState('');
  const [editFeatures, setEditFeatures] = useState('');
  const [isSubmittingPlan, setIsSubmittingPlan] = useState(false);

  // Cấu hình tỷ lệ quy đổi Token AI (X giây = 1 Token)
  const [secondsPerToken, setSecondsPerToken] = useState<number>(60);
  const [isSavingTokenRate, setIsSavingTokenRate] = useState<boolean>(false);

  const loadPlans = async () => {
    if (!isAdmin) return;
    setIsLoadingPlans(true);
    try {
      const [plansData, rateData] = await Promise.all([
        getAllPlansAdmin(),
        getTokenRate().catch(() => ({ secondsPerToken: 60 })),
      ]);
      setPlans(plansData);
      if (rateData && rateData.secondsPerToken) {
        setSecondsPerToken(rateData.secondsPerToken);
      }
    } catch (err: any) {
      console.error(err);
    } finally {
      setIsLoadingPlans(false);
    }
  };

  const handleSaveTokenRate = async (e: React.FormEvent) => {
    e.preventDefault();
    if (secondsPerToken < 1) {
      alert('Thời lượng cho 1 Token phải từ 1 giây trở lên!');
      return;
    }
    setIsSavingTokenRate(true);
    try {
      const res = await updateTokenRate(secondsPerToken);
      setSecondsPerToken(res.secondsPerToken);
      showToast(`Đã lưu cấu hình: 1 Token = ${res.secondsPerToken} giây (~${(res.secondsPerToken / 60).toFixed(1)} phút)!`);
    } catch (err: any) {
      alert('Lỗi cập nhật tỷ lệ Token: ' + (err.message || 'Không thể cập nhật'));
    } finally {
      setIsSavingTokenRate(false);
    }
  };

  useEffect(() => {
    if (isAdmin && (activeTab === 'pricing' || activeTab === 'subscriptions')) {
      loadPlans();
    }
  }, [isAdmin, activeTab]);

  // ==================== VOUCHER / PROMO CODE MANAGEMENT STATE ====================
  const [vouchers, setVouchers] = useState<PromoCodeItem[]>([]);
  const [isLoadingVouchers, setIsLoadingVouchers] = useState(false);
  const [voucherSearch, setVoucherSearch] = useState('');
  const [isVoucherModalOpen, setIsVoucherModalOpen] = useState(false);
  const [editingVoucher, setEditingVoucher] = useState<PromoCodeItem | null>(null);

  const [voucherCode, setVoucherCode] = useState('');
  const [voucherDescription, setVoucherDescription] = useState('');
  const [voucherDiscountType, setVoucherDiscountType] = useState<'percent' | 'amount'>('percent');
  const [voucherDiscountValue, setVoucherDiscountValue] = useState<number>(10);
  const [voucherMaxUses, setVoucherMaxUses] = useState<number>(100);
  const [voucherStartDate, setVoucherStartDate] = useState('');
  const [voucherEndDate, setVoucherEndDate] = useState('');
  const [voucherIsActive, setVoucherIsActive] = useState(true);
  const [isSavingVoucher, setIsSavingVoucher] = useState(false);

  const loadVouchers = async () => {
    try {
      setIsLoadingVouchers(true);
      const data = await getAdminPromoCodes();
      setVouchers(data);
    } catch (err: any) {
      showToast(err.message || 'Lỗi khi tải danh sách voucher');
    } finally {
      setIsLoadingVouchers(false);
    }
  };

  useEffect(() => {
    if (isAdmin && activeTab === 'vouchers') {
      loadVouchers();
    }
  }, [isAdmin, activeTab]);

  const handleOpenCreateVoucher = () => {
    setEditingVoucher(null);
    setVoucherCode('');
    setVoucherDescription('');
    setVoucherDiscountType('percent');
    setVoucherDiscountValue(10);
    setVoucherMaxUses(100);
    setVoucherStartDate(new Date().toISOString().slice(0, 16));
    const nextYear = new Date();
    nextYear.setFullYear(nextYear.getFullYear() + 1);
    setVoucherEndDate(nextYear.toISOString().slice(0, 16));
    setVoucherIsActive(true);
    setIsVoucherModalOpen(true);
  };

  const handleOpenEditVoucher = (v: PromoCodeItem) => {
    setEditingVoucher(v);
    setVoucherCode(v.code);
    setVoucherDescription(v.description || '');
    if (v.discountPercent && v.discountPercent > 0) {
      setVoucherDiscountType('percent');
      setVoucherDiscountValue(v.discountPercent);
    } else {
      setVoucherDiscountType('amount');
      setVoucherDiscountValue(v.discountAmount || 50000);
    }
    setVoucherMaxUses(v.maxUses);
    setVoucherStartDate(v.startDate ? v.startDate.slice(0, 16) : '');
    setVoucherEndDate(v.endDate ? v.endDate.slice(0, 16) : '');
    setVoucherIsActive(v.isActive);
    setIsVoucherModalOpen(true);
  };

  const handleSaveVoucher = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!voucherCode.trim()) {
      showToast('Vui lòng nhập mã khuyến mãi');
      return;
    }

    const payload: PromoCodePayload = {
      code: voucherCode.trim().toUpperCase(),
      description: voucherDescription.trim(),
      discountPercent: voucherDiscountType === 'percent' ? Number(voucherDiscountValue) : 0,
      discountAmount: voucherDiscountType === 'amount' ? Number(voucherDiscountValue) : 0,
      maxUses: Number(voucherMaxUses) || 100,
      startDate: voucherStartDate ? new Date(voucherStartDate).toISOString() : undefined,
      endDate: voucherEndDate ? new Date(voucherEndDate).toISOString() : undefined,
      isActive: voucherIsActive,
    };

    try {
      setIsSavingVoucher(true);
      if (editingVoucher) {
        await updateAdminPromoCode(editingVoucher.id, payload);
        showToast(`Cập nhật voucher "${payload.code}" thành công!`);
      } else {
        await createAdminPromoCode(payload);
        showToast(`Tạo mã voucher mới "${payload.code}" thành công!`);
      }
      setIsVoucherModalOpen(false);
      loadVouchers();
    } catch (err: any) {
      showToast(err.message || 'Lỗi khi lưu voucher');
    } finally {
      setIsSavingVoucher(false);
    }
  };

  const handleToggleVoucher = async (id: number) => {
    try {
      const updated = await toggleAdminPromoCode(id);
      showToast(`${updated.isActive ? 'Đã kích hoạt' : 'Đã tạm dừng'} mã "${updated.code}"`);
      setVouchers(prev => prev.map(v => v.id === id ? updated : v));
    } catch (err: any) {
      showToast(err.message || 'Lỗi khi đổi trạng thái voucher');
    }
  };

  const handleDeleteVoucher = async (v: PromoCodeItem) => {
    if (!window.confirm(`Bạn có chắc chắn muốn xóa mã voucher "${v.code}" không? Hành động này không thể hoàn tác.`)) {
      return;
    }
    try {
      await deleteAdminPromoCode(v.id);
      showToast(`Đã xóa mã voucher "${v.code}" thành công!`);
      setVouchers(prev => prev.filter(item => item.id !== v.id));
    } catch (err: any) {
      showToast(err.message || 'Lỗi khi xóa voucher');
    }
  };

  const handleOpenEditPlan = (plan: SubscriptionPlanItem) => {
    setEditingPlan(plan);
    setEditName(plan.name);
    setEditPrice(plan.price);
    setEditDuration(plan.durationDays);
    setEditDailyTokenLimit(plan.dailyTokenLimit);
    setEditDescription(plan.description || '');
    setEditFeatures(plan.features || '');
  };

  const handleSavePlan = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!editingPlan) return;
    setIsSubmittingPlan(true);
    try {
      await updatePlan(editingPlan.id, {
        name: editName.trim() || editingPlan.name,
        code: editingPlan.code,
        price: editPrice,
        durationDays: editDuration,
        dailyTokenLimit: editDailyTokenLimit,
        description: editDescription,
        features: editFeatures,
        isActive: editingPlan.isActive,
      });
      showToast(`Đã cập nhật biểu phí và hạn mức Token cho gói ${editName || editingPlan.name}!`);
      setEditingPlan(null);
      loadPlans();
    } catch (err: any) {
      alert('Lỗi cập nhật gói: ' + err.message);
    } finally {
      setIsSubmittingPlan(false);
    }
  };

  return (
    <div className={`admin-viewport ${isSidebarCollapsed ? 'sidebar-collapsed' : ''}`}>
      {/* Toast Notification */}
      {toastMessage && (
        <div style={{
          position: 'fixed',
          top: 16,
          right: 16,
          background: '#0284c7',
          color: '#ffffff',
          padding: '0.65rem 1.15rem',
          borderRadius: '2px',
          border: '1px solid #38bdf8',
          fontSize: '0.84rem',
          fontWeight: 600,
          zIndex: 9999,
          boxShadow: '0 4px 18px rgba(0,0,0,0.5)'
        }}>
          {toastMessage}
        </div>
      )}

      {/* ==================== SHARP RECTANGULAR ENTERPRISE SIDEBAR ==================== */}
      <aside className={`admin-sidebar ${isSidebarCollapsed ? 'collapsed' : ''}`}>
        <div className="sidebar-brand">
          <div className="brand-square">日</div>
          {!isSidebarCollapsed && (
            <div className="brand-meta">
              <span className="brand-name">JLSP Console</span>
              <span className="brand-role-tag">
                {isModerator ? 'MODERATOR PORTAL' : 'ADMIN CONSOLE'}
              </span>
            </div>
          )}
        </div>

        <nav className="sidebar-nav">
          {/* TAB: THỐNG KÊ & ANALYTICS (CHỈ ADMIN) */}
          {isAdmin && (
            <button
              onClick={() => setActiveTab('analytics')}
              className={`nav-tab-item ${activeTab === 'analytics' ? 'active' : ''}`}
              title="Thống kê tổng quan & Biểu đồ phân tích"
            >
              <BarChart3 size={18} />
              {!isSidebarCollapsed && <span>Thống Kê & Phân Tích</span>}
            </button>
          )}

          {/* TAB: DUYỆT VIDEO - CHỈ HIỆN VỚI MODERATOR (ADMIN KHÔNG CÓ QUYỀN) */}
          {isModerator && (
            <button
              onClick={() => setActiveTab('videos')}
              className={`nav-tab-item ${activeTab === 'videos' ? 'active' : ''}`}
              title="Duyệt video bài học"
            >
              <Video size={18} />
              {!isSidebarCollapsed && <span>Duyệt Video</span>}
              {!isSidebarCollapsed && <span className="nav-tab-badge">KIỂM DUYỆT</span>}
            </button>
          )}

          {/* TAB: QUẢN LÝ NGƯỜI DÙNG & TẠO TK HÀNG LOẠT (CHỈ ADMIN) */}
          {isAdmin && (
            <button
              onClick={() => setActiveTab('users')}
              className={`nav-tab-item ${activeTab === 'users' ? 'active' : ''}`}
              title="Quản lý người dùng & Phân quyền"
            >
              <Users size={18} />
              {!isSidebarCollapsed && <span>Quản lý Người dùng</span>}
            </button>
          )}

          {/* TAB: LỊCH SỬ MUA GÓI & LOCAL QR (CHỈ ADMIN) */}
          {isAdmin && (
            <button
              onClick={() => setActiveTab('subscriptions')}
              className={`nav-tab-item ${activeTab === 'subscriptions' ? 'active' : ''}`}
              title="Lịch sử giao dịch & Thanh toán QR"
            >
              <CreditCard size={18} />
              {!isSidebarCollapsed && <span>Lịch sử Mua gói</span>}
            </button>
          )}

          {/* TAB: CẤU HÌNH GÓI & DAILY TOKEN LIMIT (CHỈ ADMIN) */}
          {isAdmin && (
            <button
              onClick={() => setActiveTab('pricing')}
              className={`nav-tab-item ${activeTab === 'pricing' ? 'active' : ''}`}
              title="Cấu hình Gói & Hạn mức Token AI"
            >
              <Sliders size={18} />
              {!isSidebarCollapsed && <span>Gói & Hạn mức Token</span>}
            </button>
          )}

          {/* TAB: QUẢN LÝ VOUCHER & MÃ KHUYẾN MÃI (CHỈ ADMIN) */}
          {isAdmin && (
            <button
              onClick={() => setActiveTab('vouchers')}
              className={`nav-tab-item ${activeTab === 'vouchers' ? 'active' : ''}`}
              title="Quản lý Voucher & Mã Khuyến Mãi"
            >
              <Ticket size={18} />
              {!isSidebarCollapsed && <span>Mã Voucher</span>}
            </button>
          )}

          {/* TAB: XỬ LÝ BÁO CÁO (CẢ ADMIN VÀ MODERATOR) */}
          <button
            onClick={() => setActiveTab('reports')}
            className={`nav-tab-item ${activeTab === 'reports' ? 'active' : ''}`}
            title="Xử lý báo cáo vi phạm"
          >
            <AlertTriangle size={18} />
            {!isSidebarCollapsed && <span>Xử lý Report</span>}
          </button>

          {/* TAB: TRANG HỒ SƠ CÁ NHÂN (CẢ ADMIN VÀ MODERATOR) */}
          <button
            onClick={() => setActiveTab('profile')}
            className={`nav-tab-item ${activeTab === 'profile' ? 'active' : ''}`}
            title="Trang cá nhân & Cập nhật bảo mật"
          >
            <Shield size={18} />
            {!isSidebarCollapsed && <span>Hồ Sơ Cá Nhân</span>}
          </button>
        </nav>

        {/* Sidebar Footer */}
        <div className="sidebar-footer">
          <button
            onClick={() => setIsSidebarCollapsed(!isSidebarCollapsed)}
            className="collapse-btn"
            title={isSidebarCollapsed ? "Mở rộng" : "Thu gọn"}
          >
            {isSidebarCollapsed ? <ChevronRight size={16} /> : <ChevronLeft size={16} />}
            {!isSidebarCollapsed && <span>Thu gọn Menu</span>}
          </button>

          {!isSidebarCollapsed ? (
            <div
              className={`user-profile-strip clickable ${activeTab === 'profile' ? 'active' : ''}`}
              onClick={() => setActiveTab('profile')}
              title="Mở Trang Hồ Sơ & Đổi Mật Khẩu"
            >
              <div className="user-avatar-box">
                {profileUsername.charAt(0).toUpperCase()}
              </div>
              <div className="user-info-text">
                <span className="user-name-title">{profileDisplayName || profileUsername}</span>
                <span className="user-role-label">{user.role}</span>
              </div>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  setActiveTab('profile');
                }}
                className="btn-icon-square"
                title="Trang hồ sơ & Đổi mật khẩu"
              >
                <Key size={14} />
              </button>
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onLogout();
                }}
                className="btn-icon-square logout-btn"
                title="Đăng xuất"
              >
                <LogOut size={14} />
              </button>
            </div>
          ) : (
            <div className="collapsed-footer-actions">
              <button
                onClick={() => setActiveTab('profile')}
                className={`collapsed-avatar-btn ${activeTab === 'profile' ? 'active' : ''}`}
                title={`Hồ sơ cá nhân: ${profileDisplayName || profileUsername} (Click để mở)`}
              >
                {profileUsername.charAt(0).toUpperCase()}
              </button>
              <button
                onClick={onLogout}
                className="collapsed-logout-btn"
                title="Đăng xuất"
              >
                <LogOut size={16} />
              </button>
            </div>
          )}
        </div>
      </aside>

      {/* ==================== MAIN STAGE ==================== */}
      <main className="admin-main-stage">
        <header className="stage-top-bar">
          <div className="top-bar-left">
            <h1 className="stage-title">
              {activeTab === 'analytics' && 'Thống Kê Nền Tảng & Biểu Đồ Phân Tích'}
              {activeTab === 'videos' && 'Duyệt Video Bài Học (Moderator Only)'}
              {activeTab === 'users' && 'Quản Lý Người Dùng & Phân Quyền Hệ Thống'}
              {activeTab === 'subscriptions' && 'Lịch Sử Giao Dịch & Giả Lập Thanh Toán QR'}
              {activeTab === 'pricing' && 'Cấu Hình Gói VIP & Hạn Mức Token Trích Xuất AI'}
              {activeTab === 'vouchers' && 'Quản Lý Voucher & Mã Khuyến Mãi'}
              {activeTab === 'reports' && 'Xử Lý Khiếu Nại & Báo Cáo Vi Phạm'}
              {activeTab === 'profile' && 'Hồ Sơ Cá Nhân & Quản Trị Hệ Thống'}
            </h1>
            <span className="stage-subtitle">
              JLSP Social Japanese Learning Platform • Enterprise Backend Console
            </span>
          </div>

          <div className="top-bar-right">
            {activeTab === 'analytics' && isAdmin && (
              <button onClick={() => loadAnalytics()} className="btn-outline">
                <RefreshCw size={15} className={isLoadingAnalytics ? 'spin' : ''} />
                <span>Làm mới Thống kê</span>
              </button>
            )}
            {activeTab === 'users' && isAdmin && (
              <>
                <button
                  onClick={() => setIsSingleCreateModalOpen(true)}
                  className="btn-outline"
                >
                  <UserPlus size={15} />
                  <span>Tạo 1 TK Đơn Lẻ</span>
                </button>
                <button
                  onClick={() => {
                    setGeneratedAccounts(null);
                    setIsBatchModalOpen(true);
                  }}
                  className="btn-solid-primary"
                >
                  <Sparkles size={15} />
                  <span>⚡ Tạo Hàng Loạt (Batch Auto)</span>
                </button>
              </>
            )}

            {activeTab === 'subscriptions' && isAdmin && (
              <button
                onClick={() => {
                  setIsQrModalOpen(true);
                  handleCreateQrOrder();
                }}
                className="btn-solid-primary"
              >
                <QrCode size={15} />
                <span>⚡ Giả lập Quét QR Thanh toán Local</span>
              </button>
            )}
          </div>
        </header>

        <div className="stage-body">
          {/* ==================== TAB: THỐNG KÊ & BIỂU ĐỒ PHÂN TÍCH (ADMIN ONLY) ==================== */}
          {activeTab === 'analytics' && isAdmin && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: '1.5rem' }}>
              {/* 3 Top Stat KPI Cards */}
              <div className="analytics-kpi-grid">
                {/* KPI 1: User đăng ký (Chỉ tính học viên / regular user, không tính admin/mod) */}
                <div className="kpi-card">
                  <div className="kpi-card-header">
                    <span className="kpi-title">Học Viên Đăng Ký (Không tính Admin/Mod)</span>
                    <div className="kpi-icon-wrap">
                      <Users size={18} />
                    </div>
                  </div>
                  <div className="kpi-value">
                    {analyticsData ? analyticsData.totalUsers.toLocaleString() : '0'}
                  </div>
                  <div className="kpi-subtext">
                    <span className="status-pill success" style={{ padding: '0.1rem 0.4rem' }}>
                      {analyticsData?.activeUsers ?? 0} Học viên hoạt động
                    </span>
                    <span className="status-pill danger" style={{ padding: '0.1rem 0.4rem' }}>
                      {analyticsData?.lockedUsers ?? 0} Đã khóa
                    </span>
                    <span style={{ fontSize: '0.73rem', color: 'var(--admin-text-dim)' }}>
                      • Riêng {analyticsData?.adminCount ?? 0} Admin / {analyticsData?.moderatorCount ?? 0} Mod
                    </span>
                  </div>
                </div>

                {/* KPI 2: Tổng lượng token user dùng */}
                <div className="kpi-card emerald">
                  <div className="kpi-card-header">
                    <span className="kpi-title">Tổng Lượng Token AI Đã Dùng</span>
                    <div className="kpi-icon-wrap emerald">
                      <Coins size={18} />
                    </div>
                  </div>
                  <div className="kpi-value" style={{ color: 'var(--admin-success)' }}>
                    {analyticsData ? analyticsData.totalTokensUsed.toLocaleString() : '0'}
                  </div>
                  <div className="kpi-subtext">
                    <span>⚡ <strong>{analyticsData?.activeTokenUsersCount ?? 0}</strong> học viên đã dùng tính năng AI</span>
                  </div>
                </div>

                {/* KPI 3: Tổng doanh thu bán gói */}
                <div className="kpi-card amber">
                  <div className="kpi-card-header">
                    <span className="kpi-title">Tổng Doanh Thu Bán Gói VIP</span>
                    <div className="kpi-icon-wrap amber">
                      <TrendingUp size={18} />
                    </div>
                  </div>
                  <div className="kpi-value" style={{ color: 'var(--admin-primary-hover)' }}>
                    {analyticsData ? `${analyticsData.totalRevenue.toLocaleString('vi-VN')} đ` : '0 đ'}
                  </div>
                  <div className="kpi-subtext">
                    <span style={{ color: 'var(--admin-success)', fontWeight: 700 }}>
                      ✓ {analyticsData?.successfulOrdersCount ?? 0} đơn thành công
                    </span>
                    <span>• {analyticsData?.pendingOrdersCount ?? 0} đơn đang chờ</span>
                  </div>
                </div>
              </div>

              {/* Quick Sync & Preset Toolbar */}
              <div className="analytics-filter-bar">
                <div className="analytics-filter-group">
                  <span className="filter-label">⚡ Đồng bộ nhanh tất cả biểu đồ:</span>
                  <div className="segmented-pill-wrap">
                    <button
                      type="button"
                      className="pill-btn"
                      onClick={() => applyQuickSync('7days')}
                    >
                      7 Ngày gần nhất
                    </button>
                    <button
                      type="button"
                      className="pill-btn"
                      onClick={() => applyQuickSync('days_in_month', 2026, 10)}
                    >
                      Tháng 10/2026
                    </button>
                    <button
                      type="button"
                      className="pill-btn"
                      onClick={() => applyQuickSync('month', 2026)}
                    >
                      12 Tháng năm 2026
                    </button>
                    <button
                      type="button"
                      className="pill-btn"
                      onClick={() => applyQuickSync('year')}
                    >
                      5 Năm gần nhất
                    </button>
                  </div>
                </div>

                <div className="analytics-filter-group" style={{ marginLeft: 'auto' }}>
                  <span style={{ fontSize: '0.78rem', color: 'var(--admin-text-dim)' }}>
                    💡 Hoặc tùy chỉnh độc lập tháng / năm riêng cho từng biểu đồ bên dưới
                  </span>
                </div>
              </div>

              {/* 3 Interactive Visual Charts */}
              <div className="analytics-charts-grid">
                {/* Biểu đồ 1: Phân tích User Đăng Ký (Chỉ tính Học viên role USER) */}
                <div className="chart-card">
                  <div className="chart-card-header">
                    <div className="chart-title-group">
                      <div className="chart-title">
                        <Users size={18} style={{ color: 'var(--admin-primary)' }} />
                        <span>Học Viên Đăng Ký (Chỉ tính role USER)</span>
                      </div>
                      <span className="chart-subtitle">
                        {userPeriod === '7days' && '7 Ngày gần nhất'}
                        {userPeriod === 'days_in_month' && `Từng ngày trong Tháng ${userMonth}/${userYear}`}
                        {userPeriod === 'month' && `12 Tháng trong Năm ${userYear}`}
                        {userPeriod === 'year' && '5 Năm gần nhất (2022 - 2026)'}
                        {' • Loại trừ 100% Admin & Moderator'}
                      </span>
                    </div>

                    <div className="chart-card-toolbar">
                      {/* Period Selector */}
                      <select
                        className="chart-mini-select"
                        value={userPeriod}
                        onChange={(e) => setUserPeriod(e.target.value as any)}
                        title="Chọn kỳ hiển thị"
                      >
                        <option value="7days">7 Ngày gần nhất</option>
                        <option value="days_in_month">Từng ngày trong tháng</option>
                        <option value="month">12 Tháng trong năm</option>
                        <option value="year">5 Năm gần nhất</option>
                      </select>

                      {/* Month Selector */}
                      {userPeriod === 'days_in_month' && (
                        <select
                          className="chart-mini-select"
                          value={userMonth}
                          onChange={(e) => setUserMonth(Number(e.target.value))}
                          title="Chọn tháng"
                        >
                          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(m => (
                            <option key={m} value={m}>Tháng {m}</option>
                          ))}
                        </select>
                      )}

                      {/* Year Selector */}
                      {(userPeriod === 'days_in_month' || userPeriod === 'month') && (
                        <select
                          className="chart-mini-select"
                          value={userYear}
                          onChange={(e) => setUserYear(Number(e.target.value))}
                          title="Chọn năm"
                        >
                          {[2026, 2025, 2024, 2023, 2022].map(y => (
                            <option key={y} value={y}>Năm {y}</option>
                          ))}
                        </select>
                      )}

                      {/* View Type Toggle */}
                      <div className="chart-view-toggle">
                        <button
                          type="button"
                          className={`chart-view-btn ${userChartType === 'spline' ? 'active' : ''}`}
                          onClick={() => setUserChartType('spline')}
                          title="Đường cong Parabol"
                        >
                          📈
                        </button>
                        <button
                          type="button"
                          className={`chart-view-btn ${userChartType === 'bar' ? 'active' : ''}`}
                          onClick={() => setUserChartType('bar')}
                          title="Dạng Cột"
                        >
                          📊
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Summary Stats Strip */}
                  {renderStatsStrip(userTrendData || analyticsData?.userRegistrationTrends, val => `${val}`, 'học viên')}

                  {userChartType === 'spline' ? (
                    renderParabolicSpline(
                      userTrendData || analyticsData?.userRegistrationTrends,
                      '#0284c7',
                      'grad-user-spline',
                      val => `${val}`,
                      isLoadingUserTrend
                    )
                  ) : (
                    renderBarChart(
                      userTrendData || analyticsData?.userRegistrationTrends,
                      '',
                      val => `${val}`,
                      isLoadingUserTrend
                    )
                  )}
                </div>

                {/* Biểu đồ 2: Tổng Lượng Token User Dùng */}
                <div className="chart-card">
                  <div className="chart-card-header">
                    <div className="chart-title-group">
                      <div className="chart-title">
                        <Coins size={18} style={{ color: 'var(--admin-success)' }} />
                        <span>Tiêu Thụ Token AI (Speech-to-Text)</span>
                      </div>
                      <span className="chart-subtitle">
                        {tokenPeriod === '7days' && '7 Ngày gần nhất'}
                        {tokenPeriod === 'days_in_month' && `Từng ngày trong Tháng ${tokenMonth}/${tokenYear}`}
                        {tokenPeriod === 'month' && `12 Tháng trong Năm ${tokenYear}`}
                        {tokenPeriod === 'year' && '5 Năm gần nhất (2022 - 2026)'}
                        {' • Tổng lượng Token tiêu thụ thực tế'}
                      </span>
                    </div>

                    <div className="chart-card-toolbar">
                      {/* Period Selector */}
                      <select
                        className="chart-mini-select"
                        value={tokenPeriod}
                        onChange={(e) => setTokenPeriod(e.target.value as any)}
                        title="Chọn kỳ hiển thị"
                      >
                        <option value="7days">7 Ngày gần nhất</option>
                        <option value="days_in_month">Từng ngày trong tháng</option>
                        <option value="month">12 Tháng trong năm</option>
                        <option value="year">5 Năm gần nhất</option>
                      </select>

                      {/* Month Selector */}
                      {tokenPeriod === 'days_in_month' && (
                        <select
                          className="chart-mini-select"
                          value={tokenMonth}
                          onChange={(e) => setTokenMonth(Number(e.target.value))}
                          title="Chọn tháng"
                        >
                          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(m => (
                            <option key={m} value={m}>Tháng {m}</option>
                          ))}
                        </select>
                      )}

                      {/* Year Selector */}
                      {(tokenPeriod === 'days_in_month' || tokenPeriod === 'month') && (
                        <select
                          className="chart-mini-select"
                          value={tokenYear}
                          onChange={(e) => setTokenYear(Number(e.target.value))}
                          title="Chọn năm"
                        >
                          {[2026, 2025, 2024, 2023, 2022].map(y => (
                            <option key={y} value={y}>Năm {y}</option>
                          ))}
                        </select>
                      )}

                      {/* View Type Toggle */}
                      <div className="chart-view-toggle">
                        <button
                          type="button"
                          className={`chart-view-btn ${tokenChartType === 'spline' ? 'active' : ''}`}
                          onClick={() => setTokenChartType('spline')}
                          title="Đường cong Parabol"
                        >
                          📈
                        </button>
                        <button
                          type="button"
                          className={`chart-view-btn ${tokenChartType === 'bar' ? 'active' : ''}`}
                          onClick={() => setTokenChartType('bar')}
                          title="Dạng Cột"
                        >
                          📊
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Summary Stats Strip */}
                  {renderStatsStrip(tokenTrendData || analyticsData?.tokenUsageTrends, val => val.toLocaleString(), 'tokens')}

                  {tokenChartType === 'spline' ? (
                    renderParabolicSpline(
                      tokenTrendData || analyticsData?.tokenUsageTrends,
                      '#059669',
                      'grad-token-spline',
                      val => (val > 0 ? `${val.toLocaleString()}` : '0'),
                      isLoadingTokenTrend
                    )
                  ) : (
                    renderBarChart(
                      tokenTrendData || analyticsData?.tokenUsageTrends,
                      'emerald',
                      val => `${val}`,
                      isLoadingTokenTrend
                    )
                  )}
                </div>
              </div>

              {/* Biểu đồ 3: Tổng Doanh Thu Bán Gói & Cơ Cấu Gói */}
              <div className="analytics-charts-grid">
                {/* Doanh thu theo ngày/tháng/năm với đường cong Parabol */}
                <div className="chart-card">
                  <div className="chart-card-header">
                    <div className="chart-title-group">
                      <div className="chart-title">
                        <TrendingUp size={18} style={{ color: 'var(--admin-primary-hover)' }} />
                        <span>Doanh Thu Gói VIP (Đường Cong Parabol)</span>
                      </div>
                      <span className="chart-subtitle">
                        {revPeriod === '7days' && '7 Ngày gần nhất'}
                        {revPeriod === 'days_in_month' && `Từng ngày trong Tháng ${revMonth}/${revYear}`}
                        {revPeriod === 'month' && `12 Tháng trong Năm ${revYear}`}
                        {revPeriod === 'year' && '5 Năm gần nhất (2022 - 2026)'}
                        {' • Đơn hàng thanh toán thành công thực tế (VND)'}
                      </span>
                    </div>

                    <div className="chart-card-toolbar">
                      {/* Period Selector */}
                      <select
                        className="chart-mini-select"
                        value={revPeriod}
                        onChange={(e) => setRevPeriod(e.target.value as any)}
                        title="Chọn kỳ hiển thị"
                      >
                        <option value="7days">7 Ngày gần nhất</option>
                        <option value="days_in_month">Từng ngày trong tháng</option>
                        <option value="month">12 Tháng trong năm</option>
                        <option value="year">5 Năm gần nhất</option>
                      </select>

                      {/* Month Selector */}
                      {revPeriod === 'days_in_month' && (
                        <select
                          className="chart-mini-select"
                          value={revMonth}
                          onChange={(e) => setRevMonth(Number(e.target.value))}
                          title="Chọn tháng"
                        >
                          {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(m => (
                            <option key={m} value={m}>Tháng {m}</option>
                          ))}
                        </select>
                      )}

                      {/* Year Selector */}
                      {(revPeriod === 'days_in_month' || revPeriod === 'month') && (
                        <select
                          className="chart-mini-select"
                          value={revYear}
                          onChange={(e) => setRevYear(Number(e.target.value))}
                          title="Chọn năm"
                        >
                          {[2026, 2025, 2024, 2023, 2022].map(y => (
                            <option key={y} value={y}>Năm {y}</option>
                          ))}
                        </select>
                      )}

                      {/* View Type Toggle */}
                      <div className="chart-view-toggle">
                        <button
                          type="button"
                          className={`chart-view-btn ${revChartType === 'spline' ? 'active' : ''}`}
                          onClick={() => setRevChartType('spline')}
                          title="Đường cong Parabol"
                        >
                          📈
                        </button>
                        <button
                          type="button"
                          className={`chart-view-btn ${revChartType === 'bar' ? 'active' : ''}`}
                          onClick={() => setRevChartType('bar')}
                          title="Dạng Cột"
                        >
                          📊
                        </button>
                      </div>
                    </div>
                  </div>

                  {/* Summary Stats Strip */}
                  {renderStatsStrip(revTrendData || analyticsData?.revenueTrends, val => `${val.toLocaleString('vi-VN')} đ`)}

                  {revChartType === 'spline' ? (
                    renderParabolicSpline(
                      revTrendData || analyticsData?.revenueTrends,
                      '#d97706',
                      'grad-rev-spline',
                      val => (val > 0 ? `${(val / 1000).toFixed(0)}k` : '0đ'),
                      isLoadingRevTrend
                    )
                  ) : (
                    renderBarChart(
                      revTrendData || analyticsData?.revenueTrends,
                      'amber',
                      val => (val > 0 ? `${(val / 1000).toFixed(0)}k` : '0đ'),
                      isLoadingRevTrend
                    )
                  )}
                </div>

                {/* Cơ cấu tỷ trọng doanh số theo gói */}
                <div className="chart-card">
                  <div className="chart-card-header">
                    <div className="chart-title-group">
                      <div className="chart-title">
                        <PieChart size={18} style={{ color: 'var(--admin-primary)' }} />
                        <span>Cơ Cấu Doanh Thu Theo Gói VIP</span>
                      </div>
                      <span className="chart-subtitle">Tỷ lệ đóng góp doanh số giữa các gói dịch vụ</span>
                    </div>
                  </div>

                  <div className="plan-breakdown-list">
                    {analyticsData?.planSalesBreakdown && analyticsData.planSalesBreakdown.length > 0 ? (
                      analyticsData.planSalesBreakdown.map(plan => (
                        <div key={plan.planCode} className="plan-breakdown-row">
                          <div className="plan-breakdown-meta">
                            <span>{plan.planName} ({plan.salesCount} đơn)</span>
                            <span style={{ fontFamily: 'var(--font-mono)', color: 'var(--admin-primary-hover)' }}>
                              {plan.revenue.toLocaleString('vi-VN')} đ ({plan.percentage}%)
                            </span>
                          </div>
                          <div className="plan-progress-track">
                            <div
                              className="plan-progress-fill"
                              style={{ width: `${Math.min(100, Math.max(plan.percentage > 0 ? 3 : 0, plan.percentage))}%` }}
                            />
                          </div>
                        </div>
                      ))
                    ) : (
                      <div style={{ textAlign: 'center', color: 'var(--admin-text-dim)', padding: '2rem' }}>
                        Chưa có giao dịch phân bổ theo gói (0đ)
                      </div>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ==================== TAB 1: DUYỆT VIDEO (MODERATOR ONLY) ==================== */}
          {activeTab === 'videos' && isModerator && (
            <>
              <div style={{
                backgroundColor: 'var(--admin-bg-surface)',
                border: '1px solid var(--admin-border)',
                padding: '0.85rem 1.25rem',
                borderRadius: 'var(--radius-sharp)',
                fontSize: '0.84rem',
                color: 'var(--admin-text-main)',
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem',
                marginBottom: '1rem'
              }}>
                <Shield size={18} style={{ color: 'var(--admin-primary)', flexShrink: 0 }} />
                <div>
                  <strong>Quy chuẩn Kiểm duyệt:</strong> Moderator chỉ tiếp nhận và kiểm duyệt các video ở chế độ <strong>Công khai (PUBLIC)</strong> trước khi phát hành lên Bảng tin cộng đồng (For-You Feed). Các video riêng tư (PRIVATE) của học viên sẽ không đưa vào hàng đợi kiểm duyệt.
                </div>
              </div>

              <div className="toolbar-row">
                <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
                  <button
                    className={`btn-outline ${videoModFilter === 'PENDING' ? 'btn-solid-primary' : ''}`}
                    onClick={() => {
                      setVideosPage(0);
                      setVideoModFilter('PENDING');
                    }}
                  >
                    Chờ duyệt (PENDING)
                  </button>
                  <button
                    className={`btn-outline ${videoModFilter === 'APPROVED' ? 'btn-solid-primary' : ''}`}
                    onClick={() => {
                      setVideosPage(0);
                      setVideoModFilter('APPROVED');
                    }}
                  >
                    Đã thông qua (APPROVED)
                  </button>
                  <button
                    className={`btn-outline ${videoModFilter === 'REJECTED' ? 'btn-solid-primary' : ''}`}
                    onClick={() => {
                      setVideosPage(0);
                      setVideoModFilter('REJECTED');
                    }}
                  >
                    Đã từ chối (REJECTED)
                  </button>
                </div>

                <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.8rem', color: '#94a3b8', fontFamily: 'var(--font-mono)' }}>
                    Tổng: {videosTotalElements} video
                  </span>
                  <button onClick={loadModerationVideos} className="btn-outline">
                    <RefreshCw size={15} className={isLoadingVideos ? 'spin' : ''} />
                    <span>Làm mới danh sách</span>
                  </button>
                </div>
              </div>

              {isLoadingVideos ? (
                <div style={{ padding: '3rem', textAlign: 'center', color: '#94a3b8' }}>
                  Đang tải danh sách video bài học từ server...
                </div>
              ) : videos.length === 0 ? (
                <div style={{
                  padding: '3rem',
                  textAlign: 'center',
                  background: 'var(--admin-bg-surface)',
                  border: '1px solid var(--admin-border)',
                  borderRadius: '2px',
                  color: 'var(--admin-text-muted)'
                }}>
                  Không có video nào trong danh mục <strong>{videoModFilter}</strong>.
                </div>
              ) : (
                <>
                  <div className="data-table-container">
                    <table className="enterprise-table mod-table">
                      <thead>
                        <tr>
                          <th style={{ width: '45px', textAlign: 'center' }}>ID</th>
                          <th style={{ width: '210px' }}>Video Bài Học</th>
                          <th style={{ width: '100px', textAlign: 'center' }}>Cấp độ</th>
                          <th style={{ width: '80px', textAlign: 'center' }}>Thời lượng</th>
                          <th style={{ width: '120px' }}>Người đăng</th>
                          <th style={{ width: '100px', textAlign: 'center' }}>Chế độ</th>
                          <th style={{ width: '90px', textAlign: 'center' }}>Ngày gửi</th>
                          <th style={{ width: '100px', textAlign: 'center' }}>Trạng thái</th>
                          <th style={{ width: '155px', textAlign: 'center' }}>Thao tác</th>
                        </tr>
                      </thead>
                      <tbody>
                        {videos.map(v => (
                          <tr
                            key={v.id}
                            className="clickable-row"
                            onClick={() => setSelectedDetailVideo(v)}
                            title="Click vào hàng để xem chi tiết video và phụ đề AI"
                          >
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                              <div className="mod-cell-center">
                                <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, color: 'var(--admin-text-dim)' }}>
                                  #{v.id}
                                </span>
                              </div>
                            </td>
                            <td style={{ verticalAlign: 'middle' }}>
                              <div className="mod-table-video-cell" style={{ minHeight: '44px', display: 'flex', alignItems: 'center' }}>
                                <div className="video-thumb-preview">
                                  <img
                                    src={v.thumbnailUrl}
                                    alt={v.title}
                                    onError={(e) => { (e.target as HTMLElement).style.display = 'none'; }}
                                  />
                                  <div className="video-thumb-play-overlay">
                                    <Play size={11} color="#ffffff" fill="#ffffff" />
                                  </div>
                                </div>
                                <div className="mod-table-video-info">
                                  <strong className="mod-table-video-title" title={v.title}>
                                    {v.title}
                                  </strong>
                                  {(() => {
                                    let preview = '';
                                    if (v.subtitles && v.subtitles !== '[]') {
                                      try {
                                        const parsed = typeof v.subtitles === 'string' ? JSON.parse(v.subtitles) : v.subtitles;
                                        if (Array.isArray(parsed) && parsed.length > 0) {
                                          preview = parsed[0]?.text || parsed[0]?.translation || '';
                                        }
                                      } catch {
                                        preview = v.subtitles;
                                      }
                                    }
                                    if (!preview && v.description) preview = v.description;
                                    if (!preview) return null;
                                    return (
                                      <span className="mod-table-video-subtitle" title={preview}>
                                        💬 {preview.length > 14 ? preview.substring(0, 14) + '...' : preview}
                                      </span>
                                    );
                                  })()}
                                </div>
                              </div>
                            </td>
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                              <div className="mod-cell-center">
                                <span className={`status-pill ${v.jlptLevel === 'N1' ? 'danger' :
                                  v.jlptLevel === 'N2' ? 'warning' :
                                    v.jlptLevel === 'N3' ? 'info' : 'success'
                                  }`}>
                                  JLPT {v.jlptLevel || 'N5'}
                                </span>
                              </div>
                            </td>
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                              <div className="mod-cell-center">
                                <span style={{ fontSize: '0.8rem', fontFamily: 'var(--font-mono)' }}>
                                  {v.duration ? `${Math.floor(v.duration / 60)}m ${v.duration % 60}s` : '0s'}
                                </span>
                              </div>
                            </td>
                            <td style={{ verticalAlign: 'middle' }}>
                              <div className="mod-table-user-cell" style={{ minHeight: '44px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                                <strong className="mod-table-user-name" title={v.creatorDisplayName || v.creatorUsername || 'Creator'}>
                                  {v.creatorDisplayName || v.creatorUsername || v.user?.displayName || v.user?.username || 'Creator'}
                                </strong>
                                <span className="mod-table-user-handle">
                                  @{v.creatorUsername || v.user?.username || 'creator'}
                                </span>
                              </div>
                            </td>
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                              <div className="mod-cell-center">
                                <span className="status-pill info">
                                  🌐 {v.status || 'PUBLIC'}
                                </span>
                              </div>
                            </td>
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                              <div className="mod-cell-center">
                                <span style={{ fontSize: '0.78rem', color: 'var(--admin-text-dim)', whiteSpace: 'nowrap' }}>
                                  {v.createdAt ? new Date(v.createdAt).toLocaleDateString('vi-VN') : '—'}
                                </span>
                              </div>
                            </td>
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                              <div className="mod-cell-center">
                                <span className={`status-pill ${v.modStatus === 'APPROVED' ? 'success' : v.modStatus === 'REJECTED' ? 'danger' : 'pending'
                                  }`}>
                                  {v.modStatus === 'APPROVED' ? 'ĐÃ DUYỆT' : v.modStatus === 'REJECTED' ? 'TỪ CHỐI' : 'CHỜ DUYỆT'}
                                </span>
                              </div>
                            </td>
                            <td style={{ textAlign: 'center', verticalAlign: 'middle' }} onClick={(e) => e.stopPropagation()}>
                              <div className="mod-cell-center" style={{ gap: '0.25rem' }}>
                                <button
                                  onClick={() => setSelectedDetailVideo(v)}
                                  className="btn-outline"
                                  style={{ padding: '0 0.45rem', fontSize: '0.72rem', height: '26px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                                  title="Xem chi tiết video và phụ đề"
                                >
                                  <Eye size={12} />
                                  <span>Chi tiết</span>
                                </button>

                                {v.modStatus === 'PENDING' && (
                                  <>
                                    <button
                                      onClick={() => handleApproveVideo(v.id)}
                                      className="btn-success"
                                      style={{ padding: '0 0.45rem', fontSize: '0.72rem', height: '26px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                                      title="Phê duyệt video công khai"
                                    >
                                      <CheckCircle2 size={12} />
                                      <span>Duyệt</span>
                                    </button>
                                    <button
                                      onClick={() => setSelectedRejectVideo(v)}
                                      className="btn-danger"
                                      style={{ padding: '0 0.45rem', fontSize: '0.72rem', height: '26px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                                      title="Từ chối video vi phạm"
                                    >
                                      <XCircle size={12} />
                                      <span>Từ chối</span>
                                    </button>
                                  </>
                                )}
                              </div>
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>

                  {/* Table Pagination Bar */}
                  {videosTotalPages > 1 && (
                    <div className="pagination-bar">
                      <span className="pagination-info">
                        Trang <strong>{videosPage + 1}</strong> / {videosTotalPages} • Tổng <strong>{videosTotalElements}</strong> video
                      </span>
                      <div className="pagination-actions">
                        <button
                          disabled={videosPage === 0}
                          onClick={() => setVideosPage(prev => Math.max(0, prev - 1))}
                          className="pagination-btn"
                          title="Trang trước"
                        >
                          <ChevronLeft size={14} />
                          <span>Trước</span>
                        </button>
                        <button
                          disabled={videosPage >= videosTotalPages - 1}
                          onClick={() => setVideosPage(prev => Math.min(videosTotalPages - 1, prev + 1))}
                          className="pagination-btn"
                          title="Trang sau"
                        >
                          <span>Sau</span>
                          <ChevronRight size={14} />
                        </button>
                      </div>
                    </div>
                  )}
                </>
              )}
            </>
          )}

          {/* ==================== TAB 2: QUẢN LÝ NGƯỜI DÙNG (ADMIN ONLY) ==================== */}
          {activeTab === 'users' && isAdmin && (
            <>
              <div className="toolbar-row">
                <div style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
                  <div className="search-box-wrap">
                    <Search size={15} color="#94a3b8" />
                    <input
                      type="text"
                      placeholder="Tìm kiếm username, email, tên..."
                      value={userSearch}
                      onChange={e => setUserSearch(e.target.value)}
                      onKeyDown={e => {
                        if (e.key === 'Enter') {
                          setUsersPage(0);
                          loadAdminUsers();
                        }
                      }}
                    />
                  </div>

                  <select
                    className="filter-select"
                    value={userRoleFilter}
                    onChange={e => {
                      setUserRoleFilter(e.target.value);
                      setUsersPage(0);
                    }}
                  >
                    <option value="USER">Chỉ Học viên (Role: USER)</option>
                    <option value="">Tất cả tài khoản (Bao gồm Admin/Mod)</option>
                    <option value="ADMIN">Quản trị viên (ADMIN)</option>
                    <option value="MODERATOR">Kiểm duyệt viên (MODERATOR)</option>
                  </select>

                  <button
                    onClick={() => {
                      setUsersPage(0);
                      loadAdminUsers();
                    }}
                    className="btn-outline"
                  >
                    <Search size={14} />
                    <span>Tìm</span>
                  </button>
                </div>

                <span style={{ fontSize: '0.8rem', color: '#94a3b8', fontFamily: 'var(--font-mono)' }}>
                  Tổng cộng: {usersTotalElements} học viên (10/trang)
                </span>
              </div>

              <div className="data-table-container">
                <table className="enterprise-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Tài khoản</th>
                      <th>Vai trò</th>
                      <th>Tên hiển thị</th>
                      <th>Email</th>
                      <th>Trạng thái</th>
                      <th>Ngày tạo</th>
                      <th style={{ textAlign: 'right' }}>Thao tác</th>
                    </tr>
                  </thead>
                  <tbody>
                    {isLoadingUsers ? (
                      <tr>
                        <td colSpan={8} style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8' }}>
                          Đang tải danh sách người dùng...
                        </td>
                      </tr>
                    ) : usersList.length === 0 ? (
                      <tr>
                        <td colSpan={8} style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8' }}>
                          Không tìm thấy người dùng nào phù hợp.
                        </td>
                      </tr>
                    ) : (
                      usersList.map(u => (
                        <tr key={u.id}>
                          <td style={{ fontFamily: 'var(--font-mono)', color: '#64748b' }}>#{u.id}</td>
                          <td style={{ fontWeight: 600 }}>{u.username}</td>
                          <td>
                            <span className={`role-tag ${u.role === 'ADMIN' ? 'admin' : u.role === 'MODERATOR' ? 'moderator' : 'user'
                              }`}>
                              {u.role}
                            </span>
                          </td>
                          <td>{u.displayName || '—'}</td>
                          <td style={{ fontFamily: 'var(--font-mono)', fontSize: '0.8rem', color: '#94a3b8' }}>
                            {u.email}
                          </td>
                          <td>
                            <span className={`status-pill ${u.isActive ? 'success' : 'danger'}`}>
                              {u.isActive ? 'Hoạt động' : 'Đã khóa'}
                            </span>
                          </td>
                          <td style={{ fontSize: '0.8rem', color: '#94a3b8' }}>
                            {u.createdAt ? new Date(u.createdAt).toLocaleDateString('vi-VN') : '—'}
                          </td>
                          <td style={{ textAlign: 'right' }}>
                            <button
                              onClick={() => handleToggleUserStatus(u.id)}
                              className={u.isActive ? 'btn-danger' : 'btn-success'}
                              title={u.isActive ? 'Khóa tài khoản' : 'Mở khóa tài khoản'}
                            >
                              {u.isActive ? <Lock size={14} /> : <Unlock size={14} />}
                              <span>{u.isActive ? 'Khóa' : 'Mở khóa'}</span>
                            </button>
                          </td>
                        </tr>
                      )))}
                  </tbody>
                </table>
              </div>

              {/* Phân trang bảng Người Dùng (Giới hạn 10 tài khoản / trang, mũi tên chuyển tab) */}
              <div className="pagination-bar">
                <div className="pagination-info">
                  Hiển thị <strong>{usersList.length > 0 ? (usersPage * 10) + 1 : 0}</strong> - <strong>{Math.min((usersPage + 1) * 10, usersTotalElements)}</strong> trên tổng số <strong>{usersTotalElements}</strong> tài khoản
                </div>
                <div className="pagination-actions">
                  <button
                    className="pagination-btn"
                    disabled={usersPage === 0 || isLoadingUsers}
                    onClick={() => setUsersPage(prev => Math.max(0, prev - 1))}
                    title="Trang trước"
                  >
                    <ChevronLeft size={16} />
                    <span>Trang trước</span>
                  </button>
                  <span className="pagination-page-indicator">
                    Trang <strong>{usersPage + 1}</strong> / {Math.max(1, usersTotalPages)}
                  </span>
                  <button
                    className="pagination-btn"
                    disabled={usersPage >= usersTotalPages - 1 || isLoadingUsers}
                    onClick={() => setUsersPage(prev => prev + 1)}
                    title="Trang sau"
                  >
                    <span>Trang sau</span>
                    <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            </>
          )}

          {/* ==================== TAB 3: LỊCH SỬ MUA GÓI & QR LOCAL (ADMIN ONLY) ==================== */}
          {activeTab === 'subscriptions' && isAdmin && (
            <>
              <div className="toolbar-row">
                <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                  <span style={{ fontSize: '0.82rem', color: '#94a3b8', fontWeight: 600 }}>Sắp xếp theo:</span>
                  <button
                    onClick={() => handleToggleSort('createdAt')}
                    className={`btn-outline ${orderSortField === 'createdAt' ? 'btn-solid-primary' : ''}`}
                  >
                    <ArrowUpDown size={14} />
                    <span>Ngày tạo ({orderSortDir})</span>
                  </button>
                  <button
                    onClick={() => handleToggleSort('amount')}
                    className={`btn-outline ${orderSortField === 'amount' ? 'btn-solid-primary' : ''}`}
                  >
                    <ArrowUpDown size={14} />
                    <span>Số tiền ({orderSortDir})</span>
                  </button>
                  <button
                    onClick={() => handleToggleSort('status')}
                    className={`btn-outline ${orderSortField === 'status' ? 'btn-solid-primary' : ''}`}
                  >
                    <ArrowUpDown size={14} />
                    <span>Trạng thái</span>
                  </button>
                </div>

                <button onClick={loadSubscriptionOrders} className="btn-outline">
                  <RefreshCw size={15} />
                  <span>Làm mới</span>
                </button>
              </div>

              <div className="data-table-container">
                <table className="enterprise-table">
                  <thead>
                    <tr>
                      <th>Mã Đơn Hàng</th>
                      <th>Người Dùng</th>
                      <th>Gói Đăng Ký</th>
                      <th className="sortable" onClick={() => handleToggleSort('amount')}>
                        Số Tiền (VND) ↕
                      </th>
                      <th>Mã Xác Thực (Dưới QR)</th>
                      <th className="sortable" onClick={() => handleToggleSort('status')}>
                        Trạng Thái ↕
                      </th>
                      <th className="sortable" onClick={() => handleToggleSort('createdAt')}>
                        Thời Gian ↕
                      </th>
                    </tr>
                  </thead>
                  <tbody>
                    {isLoadingOrders ? (
                      <tr>
                        <td colSpan={7} style={{ textAlign: 'center', padding: '2.5rem', color: '#94a3b8' }}>
                          Đang tải lịch sử giao dịch gói...
                        </td>
                      </tr>
                    ) : orders.length === 0 ? (
                      <tr>
                        <td colSpan={7} style={{ textAlign: 'center', padding: '2.5rem', color: '#94a3b8' }}>
                          Chưa có lịch sử giao dịch nào. Bấm nút <strong>"⚡ Giả lập Quét QR Thanh toán Local"</strong> ở trên để tạo giao dịch thử nghiệm!
                        </td>
                      </tr>
                    ) : (
                      orders.map(o => (
                        <tr key={o.id}>
                          <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#38bdf8' }}>
                            {o.orderCode}
                          </td>
                          <td style={{ fontWeight: 600 }}>{o.userDisplayName || o.username}</td>
                          <td>
                            <span style={{ fontWeight: 700, color: '#0f172a' }}>{o.planName}</span>
                          </td>
                          <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: '0.9rem' }}>
                            {o.amount?.toLocaleString('vi-VN')} đ
                          </td>
                          <td>
                            <span style={{
                              fontFamily: 'var(--font-mono)',
                              fontWeight: 800,
                              background: '#1e293b',
                              border: '1px solid #38bdf8',
                              padding: '0.2rem 0.5rem',
                              borderRadius: '2px',
                              color: '#38bdf8'
                            }}>
                              {o.verificationCode}
                            </span>
                          </td>
                          <td>
                            <div style={{ display: 'flex', alignItems: 'center', minHeight: '24px' }}>
                              <span className={`status-pill ${o.status === 'SUCCESS' ? 'success' : o.status === 'PENDING' ? 'pending' : 'danger'
                                }`}
                                style={{ transform: 'translateY(10px)' }}
                              >
                                {o.status}
                              </span>
                            </div>
                          </td>
                          <td style={{ fontSize: '0.8rem', color: '#94a3b8' }}>
                            {o.createdAt ? new Date(o.createdAt).toLocaleString('vi-VN') : '—'}
                          </td>
                        </tr>
                      ))
                    )}
                  </tbody>
                </table>
              </div>

              {/* Phân trang bảng Lịch Sử Mua Gói (Giới hạn 10 giao dịch / trang, mũi tên chuyển tab) */}
              <div className="pagination-bar">
                <div className="pagination-info">
                  Hiển thị <strong>{orders.length > 0 ? (ordersPage * 10) + 1 : 0}</strong> - <strong>{Math.min((ordersPage + 1) * 10, ordersTotalElements)}</strong> trên tổng số <strong>{ordersTotalElements}</strong> giao dịch (10/trang)
                </div>
                <div className="pagination-actions">
                  <button
                    className="pagination-btn"
                    disabled={ordersPage === 0 || isLoadingOrders}
                    onClick={() => setOrdersPage(prev => Math.max(0, prev - 1))}
                    title="Trang trước"
                  >
                    <ChevronLeft size={16} />
                    <span>Trang trước</span>
                  </button>
                  <span className="pagination-page-indicator">
                    Trang <strong>{ordersPage + 1}</strong> / {Math.max(1, ordersTotalPages)}
                  </span>
                  <button
                    className="pagination-btn"
                    disabled={ordersPage >= ordersTotalPages - 1 || isLoadingOrders}
                    onClick={() => setOrdersPage(prev => prev + 1)}
                    title="Trang sau"
                  >
                    <span>Trang sau</span>
                    <ChevronRight size={16} />
                  </button>
                </div>
              </div>
            </>
          )}

          {/* ==================== TAB 4: CẤU HÌNH GÓI & DAILY TOKEN LIMIT (ADMIN ONLY) ==================== */}
          {activeTab === 'pricing' && isAdmin && (
            <>
              <div style={{
                backgroundColor: 'var(--admin-bg-surface)',
                border: '1px solid var(--admin-border)',
                padding: '0.85rem 1.25rem',
                borderRadius: 'var(--radius-sharp)',
                fontSize: '0.84rem',
                color: 'var(--admin-text-main)',
                display: 'flex',
                alignItems: 'center',
                gap: '0.75rem'
              }}>
                <Sparkles size={18} style={{ color: 'var(--admin-primary)', flexShrink: 0 }} />
                <div>
                  <strong>Cấu Hình Gói Dịch Vụ & Hạn Mức Token:</strong> Quản trị viên có thể tùy chỉnh giá dịch vụ (VND), thời hạn sử dụng và hạn mức Token cấp phát mỗi ngày (Daily Token Limit) cho từng gói thành viên.
                </div>
              </div>

              {/* Card Tùy chỉnh Tỷ lệ Quy Đổi Token AI (X giây = 1 Token) */}
              <div className="token-rate-card">
                <div className="token-rate-header">
                  <div className="token-rate-title-wrap">
                    <div className="token-rate-icon">
                      <Sliders size={20} />
                    </div>
                    <div>
                      <h3 className="token-rate-title">⚙️ Cấu Hình Tỷ Lệ Quy Đổi Token AI (Speech-to-Text & Dịch)</h3>
                      <p className="token-rate-desc">
                        Quy định thời lượng video/audio tương ứng với 1 Token AI khi học viên sử dụng tính năng trích xuất lời thoại & dịch thuật.
                      </p>
                    </div>
                  </div>
                  <div className="token-rate-badge">
                    <span className="live-pulse-dot" />
                    <strong>1 Token = {secondsPerToken} giây</strong> ({secondsPerToken >= 60 ? `${(secondsPerToken / 60).toFixed(1)} phút` : `${secondsPerToken}s`})
                  </div>
                </div>

                <form onSubmit={handleSaveTokenRate} className="token-rate-form">
                  <div className="token-rate-inputs-row">
                    <div className="token-rate-field">
                      <label className="token-rate-label">Thời lượng cho 1 Token (Số giây):</label>
                      <div className="token-rate-input-box">
                        <input
                          type="number"
                          min={1}
                          max={3600}
                          required
                          value={secondsPerToken}
                          onChange={e => setSecondsPerToken(parseInt(e.target.value) || 1)}
                          className="token-rate-num-input"
                        />
                        <span className="token-rate-unit">giây / 1 Token</span>
                      </div>
                    </div>

                    <div className="token-rate-presets">
                      <span className="preset-label">Mốc nhanh:</span>
                      <button
                        type="button"
                        className={`preset-btn ${secondsPerToken === 30 ? 'active' : ''}`}
                        onClick={() => setSecondsPerToken(30)}
                      >
                        30s
                      </button>
                      <button
                        type="button"
                        className={`preset-btn ${secondsPerToken === 60 ? 'active' : ''}`}
                        onClick={() => setSecondsPerToken(60)}
                      >
                        60s (1 phút)
                      </button>
                      <button
                        type="button"
                        className={`preset-btn ${secondsPerToken === 120 ? 'active' : ''}`}
                        onClick={() => setSecondsPerToken(120)}
                      >
                        120s (2 phút)
                      </button>
                      <button
                        type="button"
                        className={`preset-btn ${secondsPerToken === 300 ? 'active' : ''}`}
                        onClick={() => setSecondsPerToken(300)}
                      >
                        300s (5 phút)
                      </button>
                    </div>

                    <button
                      type="submit"
                      disabled={isSavingTokenRate}
                      className="btn-solid-primary"
                      style={{ height: '40px', padding: '0 1.25rem' }}
                    >
                      <Save size={15} />
                      <span>{isSavingTokenRate ? 'Đang lưu...' : 'Lưu Tỷ Lệ Token'}</span>
                    </button>
                  </div>

                  {/* Minh họa quy đổi thực tế cho học viên */}
                  <div className="token-simulation-strip">
                    <span className="sim-title">📊 Mô phỏng quy đổi thực tế:</span>
                    <span className="sim-item">
                      Clip 1 phút (60s): <strong>{Math.max(1, Math.ceil(60 / (secondsPerToken || 60)))} Token</strong>
                    </span>
                    <span className="sim-item">
                      Clip 3 phút (180s): <strong>{Math.max(1, Math.ceil(180 / (secondsPerToken || 60)))} Token</strong>
                    </span>
                    <span className="sim-item">
                      Clip 5 phút (300s): <strong>{Math.max(1, Math.ceil(300 / (secondsPerToken || 60)))} Token</strong>
                    </span>
                  </div>
                </form>
              </div>

              {isLoadingPlans ? (
                <div style={{ padding: '3rem', textAlign: 'center', color: '#94a3b8' }}>
                  Đang tải thông tin biểu phí và hạn mức Token các gói...
                </div>
              ) : (
                <div className="pricing-cards-grid">
                  {plans.map(p => (
                    <div key={p.id} className={`pricing-plan-card ${p.code === 'PRO_MONTHLY' ? 'highlight' : p.code === 'FREE' ? 'free-plan-card' : ''}`}>
                      <div className="plan-header-row">
                        <h3 className="plan-name-title">
                          {p.code === 'FREE' ? `🌱 ${p.name}` : p.name}
                        </h3>
                        <span className={`status-pill ${p.code === 'FREE' ? 'info' : p.isActive ? 'success' : 'danger'}`}>
                          {p.code === 'FREE' ? 'Mặc định Free' : p.isActive ? 'Active' : 'Disabled'}
                        </span>
                      </div>

                      <div className="plan-price-tag">
                        {p.price === 0 || p.code === 'FREE' ? (
                          <>0 đ <span style={{ fontSize: '0.85rem', color: '#38bdf8', fontWeight: 600 }}>(Gói Miễn Phí Mặc Định)</span></>
                        ) : (
                          <>{p.price?.toLocaleString('vi-VN')} <span style={{ fontSize: '0.9rem', color: '#94a3b8' }}>đ / {p.durationDays} ngày</span></>
                        )}
                      </div>

                      {/* Token Limit Highlight */}
                      <div className="plan-token-limit-badge">
                        <span style={{ fontSize: '0.72rem', textTransform: 'uppercase', color: '#94a3b8', fontWeight: 700 }}>
                          Hạn mức Token ngày:
                        </span>
                        <div className="token-limit-num">
                          {p.dailyTokenLimit?.toLocaleString()} <span style={{ fontSize: '0.75rem', color: '#cbd5e1' }}>Tokens / ngày</span>
                        </div>
                      </div>

                      <div style={{ fontSize: '0.8rem', color: 'var(--admin-text-muted)', minHeight: '36px', whiteSpace: 'pre-line' }}>
                        {p.features || p.description}
                      </div>

                      <button
                        onClick={() => handleOpenEditPlan(p)}
                        className="btn-outline"
                        style={{ marginTop: 'auto', justifyContent: 'center' }}
                      >
                        <Edit2 size={14} />
                        <span>Chỉnh sửa Biểu phí & Token</span>
                      </button>
                    </div>
                  ))}
                </div>
              )}
            </>
          )}

          {/* ==================== TAB: QUẢN LÝ VOUCHER & MÃ KHUYẾN MÃI (CHỈ ADMIN) ==================== */}
          {activeTab === 'vouchers' && isAdmin && (
            <>
              {/* Header card with Actions */}
              <div style={{
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: '1rem',
                backgroundColor: 'var(--admin-bg-surface)',
                border: '1px solid var(--admin-border)',
                padding: '1rem 1.25rem',
                borderRadius: 'var(--radius-sharp)'
              }}>
                <div>
                  <h3 style={{ fontSize: '1.05rem', fontWeight: 700, margin: 0, display: 'flex', alignItems: 'center', gap: '0.5rem', color: 'var(--admin-text-main)' }}>
                    <Ticket size={20} style={{ color: '#38bdf8' }} />
                    Danh Sách Mã Khuyến Mãi (Voucher)
                  </h3>
                  <p style={{ margin: '0.2rem 0 0', fontSize: '0.8rem', color: 'var(--admin-text-muted)' }}>
                    Cấu hình tỷ lệ giảm giá, giới hạn số lượt sử dụng và thời gian hiệu lực cho các chương trình ưu đãi
                  </p>
                </div>
                <div style={{ display: 'flex', gap: '0.65rem', alignItems: 'center' }}>
                  <div className="search-box" style={{ width: '220px' }}>
                    <Search size={15} />
                    <input
                      type="text"
                      placeholder="Tìm mã voucher..."
                      value={voucherSearch}
                      onChange={e => setVoucherSearch(e.target.value)}
                    />
                  </div>
                  <button onClick={loadVouchers} className="btn-outline" title="Tải lại dữ liệu">
                    <RefreshCw size={15} className={isLoadingVouchers ? 'spin' : ''} />
                  </button>
                  <button
                    onClick={handleOpenCreateVoucher}
                    className="btn-primary"
                    style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontWeight: 600 }}
                  >
                    <Plus size={16} />
                    <span>Tạo Voucher Mới</span>
                  </button>
                </div>
              </div>

              {/* Statistics Overview */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))',
                gap: '1rem'
              }}>
                <div style={{
                  backgroundColor: 'var(--admin-bg-surface)',
                  border: '1px solid var(--admin-border)',
                  padding: '1rem',
                  borderRadius: 'var(--radius-sharp)'
                }}>
                  <div style={{ fontSize: '0.78rem', color: 'var(--admin-text-muted)', textTransform: 'uppercase', fontWeight: 600 }}>Tổng Số Voucher</div>
                  <div style={{ fontSize: '1.6rem', fontWeight: 800, color: 'var(--admin-text-main)', marginTop: '0.25rem' }}>{vouchers.length}</div>
                </div>
                <div style={{
                  backgroundColor: 'var(--admin-bg-surface)',
                  border: '1px solid var(--admin-border)',
                  padding: '1rem',
                  borderRadius: 'var(--radius-sharp)'
                }}>
                  <div style={{ fontSize: '0.78rem', color: '#10b981', textTransform: 'uppercase', fontWeight: 600 }}>Đang Hoạt Động</div>
                  <div style={{ fontSize: '1.6rem', fontWeight: 800, color: '#10b981', marginTop: '0.25rem' }}>
                    {vouchers.filter(v => v.status === 'ACTIVE').length}
                  </div>
                </div>
                <div style={{
                  backgroundColor: 'var(--admin-bg-surface)',
                  border: '1px solid var(--admin-border)',
                  padding: '1rem',
                  borderRadius: 'var(--radius-sharp)'
                }}>
                  <div style={{ fontSize: '0.78rem', color: '#f59e0b', textTransform: 'uppercase', fontWeight: 600 }}>Đã Dùng / Hết Lượt</div>
                  <div style={{ fontSize: '1.6rem', fontWeight: 800, color: '#f59e0b', marginTop: '0.25rem' }}>
                    {vouchers.filter(v => v.status === 'EXHAUSTED' || v.status === 'EXPIRED').length}
                  </div>
                </div>
                <div style={{
                  backgroundColor: 'var(--admin-bg-surface)',
                  border: '1px solid var(--admin-border)',
                  padding: '1rem',
                  borderRadius: 'var(--radius-sharp)'
                }}>
                  <div style={{ fontSize: '0.78rem', color: '#ef4444', textTransform: 'uppercase', fontWeight: 600 }}>Tạm Dừng / Khóa</div>
                  <div style={{ fontSize: '1.6rem', fontWeight: 800, color: '#ef4444', marginTop: '0.25rem' }}>
                    {vouchers.filter(v => v.status === 'DISABLED').length}
                  </div>
                </div>
              </div>

              {/* Table Data */}
              {isLoadingVouchers ? (
                <div style={{ padding: '3rem', textAlign: 'center', color: '#94a3b8' }}>
                  Đang tải danh sách voucher từ hệ thống...
                </div>
              ) : vouchers.length === 0 ? (
                <div style={{
                  padding: '3rem',
                  textAlign: 'center',
                  backgroundColor: 'var(--admin-bg-surface)',
                  border: '1px solid var(--admin-border)',
                  borderRadius: 'var(--radius-sharp)',
                  color: 'var(--admin-text-muted)'
                }}>
                  Chưa có mã khuyến mãi nào trong hệ thống. Bấm nút <strong>"Tạo Voucher Mới"</strong> để thêm mã đầu tiên.
                </div>
              ) : (
                <div className="data-table-container">
                  <table className="enterprise-table">
                    <thead>
                      <tr>
                        <th style={{ width: '130px' }}>Mã Voucher</th>
                        <th>Mô Tả & Chiến Dịch</th>
                        <th style={{ width: '150px' }}>Mức Giảm</th>
                        <th style={{ width: '150px' }}>Lượt Sử Dụng</th>
                        <th style={{ width: '170px' }}>Thời Hạn</th>
                        <th style={{ width: '120px' }}>Trạng Thái</th>
                        <th style={{ width: '140px', textAlign: 'center' }}>Thao Tác</th>
                      </tr>
                    </thead>
                    <tbody>
                      {vouchers
                        .filter(v =>
                          v.code.toLowerCase().includes(voucherSearch.toLowerCase()) ||
                          (v.description && v.description.toLowerCase().includes(voucherSearch.toLowerCase()))
                        )
                        .map(v => {
                          const percentUsed = v.maxUses > 0 ? Math.min(100, Math.round((v.usedCount / v.maxUses) * 100)) : 0;
                          return (
                            <tr key={v.id}>
                              <td>
                                <div style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                                  <span style={{
                                    fontFamily: 'monospace',
                                    fontWeight: 700,
                                    fontSize: '0.88rem',
                                    padding: '0.2rem 0.5rem',
                                    borderRadius: '4px',
                                    background: 'rgba(56, 189, 248, 0.12)',
                                    color: '#38bdf8',
                                    border: '1px solid rgba(56, 189, 248, 0.3)'
                                  }}>
                                    {v.code}
                                  </span>
                                  <button
                                    onClick={() => {
                                      navigator.clipboard.writeText(v.code);
                                      showToast(`Đã sao chép mã "${v.code}"`);
                                    }}
                                    className="btn-icon-square"
                                    title="Sao chép mã"
                                    style={{ width: '22px', height: '22px' }}
                                  >
                                    <Copy size={12} />
                                  </button>
                                </div>
                              </td>
                              <td>
                                <div style={{ fontWeight: 500, color: 'var(--admin-text-main)', fontSize: '0.85rem' }}>
                                  {v.description || 'Không có mô tả'}
                                </div>
                              </td>
                              <td>
                                {v.discountPercent && v.discountPercent > 0 ? (
                                  <span className="status-pill info" style={{ fontWeight: 700 }}>
                                    Giảm {v.discountPercent}%
                                  </span>
                                ) : (
                                  <span className="status-pill success" style={{ fontWeight: 700 }}>
                                    -{(v.discountAmount || 0).toLocaleString('vi-VN')} đ
                                  </span>
                                )}
                              </td>
                              <td>
                                <div>
                                  <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', marginBottom: '0.2rem' }}>
                                    <span><strong>{v.usedCount}</strong> / {v.maxUses} lượt</span>
                                    <span style={{ color: percentUsed >= 90 ? '#ef4444' : 'var(--admin-text-muted)' }}>{percentUsed}%</span>
                                  </div>
                                  <div style={{ height: '5px', backgroundColor: 'rgba(255,255,255,0.08)', borderRadius: '3px', overflow: 'hidden' }}>
                                    <div style={{
                                      height: '100%',
                                      width: `${percentUsed}%`,
                                      backgroundColor: percentUsed >= 100 ? '#ef4444' : percentUsed >= 75 ? '#f59e0b' : '#38bdf8',
                                      transition: 'width 0.3s'
                                    }} />
                                  </div>
                                </div>
                              </td>
                              <td style={{ fontSize: '0.78rem', color: 'var(--admin-text-muted)' }}>
                                {v.endDate ? (
                                  <>Hạn: {new Date(v.endDate).toLocaleDateString('vi-VN')}</>
                                ) : (
                                  <span style={{ color: '#10b981' }}>Vĩnh viễn</span>
                                )}
                              </td>
                              <td>
                                <span className={`status-pill ${
                                  v.status === 'ACTIVE' ? 'success' :
                                  v.status === 'PENDING' ? 'info' :
                                  v.status === 'EXHAUSTED' || v.status === 'EXPIRED' ? 'danger' : 'neutral'
                                }`}>
                                  {v.status === 'ACTIVE' ? 'Đang mở' :
                                   v.status === 'PENDING' ? 'Chưa mở' :
                                   v.status === 'EXHAUSTED' ? 'Hết lượt' :
                                   v.status === 'EXPIRED' ? 'Hết hạn' : 'Đã khóa'}
                                </span>
                              </td>
                              <td>
                                <div style={{ display: 'flex', gap: '0.35rem', justifyContent: 'center' }}>
                                  <button
                                    onClick={() => handleToggleVoucher(v.id)}
                                    className="btn-icon-square"
                                    title={v.isActive ? 'Tạm khóa voucher' : 'Kích hoạt lại voucher'}
                                    style={{ color: v.isActive ? '#10b981' : '#94a3b8' }}
                                  >
                                    {v.isActive ? <Unlock size={14} /> : <Lock size={14} />}
                                  </button>
                                  <button
                                    onClick={() => handleOpenEditVoucher(v)}
                                    className="btn-icon-square"
                                    title="Chỉnh sửa voucher"
                                  >
                                    <Edit2 size={14} />
                                  </button>
                                  <button
                                    onClick={() => handleDeleteVoucher(v)}
                                    className="btn-icon-square"
                                    title="Xóa voucher"
                                    style={{ color: '#ef4444' }}
                                  >
                                    <Trash2 size={14} />
                                  </button>
                                </div>
                              </td>
                            </tr>
                          );
                        })}
                    </tbody>
                  </table>
                </div>
              )}
            </>
          )}

          {/* ==================== TAB 5: XỬ LÝ REPORT ==================== */}
          {activeTab === 'reports' && (
            <div style={{
              background: 'var(--admin-bg-surface)',
              border: '1px solid var(--admin-border)',
              borderRadius: '2px',
              padding: '2.5rem',
              textAlign: 'center',
              color: 'var(--admin-text-dim)'
            }}>
              <AlertTriangle size={36} color="#f59e0b" style={{ margin: '0 auto 1rem' }} />
              <h3 style={{ color: 'var(--admin-text-main)', marginBottom: '0.5rem' }}>Hệ Thống Khiếu Nại & Báo Cáo Nội Dung</h3>
              <p style={{ maxWidth: '480px', margin: '0 auto', fontSize: '0.85rem' }}>
                Hiện tại không có báo cáo vi phạm nào tồn đọng. Hệ thống sẽ tự động cập nhật khi có người dùng gắn cờ báo cáo video hoặc bình luận không lành mạnh.
              </p>
            </div>
          )}
          {/* ==================== TAB 6: TRANG HỒ SƠ CÁ NHÂN (ADMIN & MODERATOR) ==================== */}
          {activeTab === 'profile' && (
            <div className="profile-page-grid">
              {/* Cột trái: Form cập nhật thông tin cá nhân & username */}
              <div className="profile-card-surface">
                <div className="profile-card-header">
                  <Edit2 size={18} style={{ color: 'var(--admin-primary)' }} />
                  <h3>Cập Nhật Thông Tin Tài Khoản</h3>
                </div>

                <div className="profile-avatar-row">
                  <div className="profile-avatar-preview">
                    {profileAvatarUrl ? (
                      <img
                        src={profileAvatarUrl}
                        alt="Avatar"
                        onError={(e) => { (e.target as HTMLElement).style.display = 'none'; }}
                      />
                    ) : (
                      <span>{profileUsername.charAt(0).toUpperCase()}</span>
                    )}
                  </div>
                  <div className="profile-avatar-info">
                    <span className="profile-avatar-title">{profileDisplayName || profileUsername}</span>
                    <span className="profile-avatar-role-badge">{user.role}</span>
                    <span className="profile-avatar-hint">Ảnh đại diện & danh xưng trên console</span>
                  </div>
                </div>

                <form onSubmit={handleSaveProfile} className="profile-form-layout">
                  <div className="form-group-sharp">
                    <label className="form-label-sharp">
                      Tên đăng nhập (Username) <span style={{ color: 'var(--admin-primary)' }}>*</span>
                    </label>
                    <input
                      type="text"
                      required
                      className="form-input-sharp"
                      value={profileUsername}
                      onChange={e => setProfileUsername(e.target.value)}
                      placeholder="Nhập username..."
                    />
                    <span className="form-input-help">Tên đăng nhập dùng để xác thực quyền {user.role} trên hệ thống.</span>
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Tên hiển thị (Display Name)</label>
                    <input
                      type="text"
                      className="form-input-sharp"
                      value={profileDisplayName}
                      onChange={e => setProfileDisplayName(e.target.value)}
                      placeholder="Nhập tên hiển thị..."
                    />
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Email liên hệ nội bộ</label>
                    <input
                      type="email"
                      className="form-input-sharp"
                      value={profileEmail}
                      onChange={e => setProfileEmail(e.target.value)}
                      placeholder="email@jlsp.internal"
                    />
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Đường dẫn ảnh đại diện (Avatar URL)</label>
                    <input
                      type="url"
                      className="form-input-sharp"
                      value={profileAvatarUrl}
                      onChange={e => setProfileAvatarUrl(e.target.value)}
                      placeholder="https://..."
                    />
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Tiểu sử / Ghi chú quyền hạn (Bio)</label>
                    <textarea
                      rows={3}
                      className="form-input-sharp"
                      value={profileBio}
                      onChange={e => setProfileBio(e.target.value)}
                      placeholder="Ghi chú trách nhiệm quản trị hoặc kiểm duyệt bài học..."
                    />
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '0.5rem' }}>
                    <button
                      type="submit"
                      disabled={isSavingProfile}
                      className="btn-solid-primary"
                    >
                      <Save size={16} />
                      <span>{isSavingProfile ? 'Đang lưu thông tin...' : 'Lưu Thay Đổi Thông Tin'}</span>
                    </button>
                  </div>
                </form>
              </div>

              {/* Cột phải: Form Đổi Mật Khẩu (mang vào trang Profile theo yêu cầu) & Tóm tắt bảo mật */}
              <div className="profile-card-surface">
                <div className="profile-card-header">
                  <Key size={18} style={{ color: 'var(--admin-primary)' }} />
                  <h3>Bảo Mật & Đổi Mật Khẩu</h3>
                </div>

                <div className="security-notice-box">
                  <Shield size={20} style={{ color: 'var(--admin-primary)', flexShrink: 0 }} />
                  <div>
                    <strong>Chính sách bảo mật tài khoản:</strong>
                    <div>Mật khẩu mới yêu cầu tối thiểu 6 ký tự. Vui lòng bảo mật thông tin phân quyền và không chia sẻ mật khẩu cho người khác.</div>
                  </div>
                </div>

                <form onSubmit={handleChangePassword} className="profile-form-layout">
                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Mật khẩu hiện tại</label>
                    <input
                      type="password"
                      required
                      placeholder="Nhập mật khẩu hiện tại..."
                      className="form-input-sharp"
                      value={oldPassword}
                      onChange={e => setOldPassword(e.target.value)}
                    />
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Mật khẩu mới (Tối thiểu 6 ký tự)</label>
                    <input
                      type="password"
                      required
                      placeholder="Nhập mật khẩu mới..."
                      className="form-input-sharp"
                      value={newPassword}
                      onChange={e => setNewPassword(e.target.value)}
                    />
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Xác nhận mật khẩu mới</label>
                    <input
                      type="password"
                      required
                      placeholder="Xác nhận lại mật khẩu mới..."
                      className="form-input-sharp"
                      value={confirmPassword}
                      onChange={e => setConfirmPassword(e.target.value)}
                    />
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: '0.5rem' }}>
                    <button
                      type="submit"
                      disabled={isSubmittingPassword}
                      className="btn-solid-primary"
                    >
                      <Lock size={16} />
                      <span>{isSubmittingPassword ? 'Đang cập nhật...' : 'Cập Nhật Mật Khẩu'}</span>
                    </button>
                  </div>
                </form>

                {/* Session & Account Metadata */}
                <div className="profile-session-summary">
                  <div className="session-summary-title">Thông Tin Phiên Đăng Nhập</div>
                  <div className="session-summary-grid">
                    <div>
                      <span className="summary-label">Vai trò:</span>
                      <span className="summary-val">{user.role}</span>
                    </div>
                    <div>
                      <span className="summary-label">Mã tài khoản:</span>
                      <span className="summary-val">#{user.id}</span>
                    </div>
                    <div>
                      <span className="summary-label">Username hiện tại:</span>
                      <span className="summary-val">@{profileUsername}</span>
                    </div>
                    <div>
                      <span className="summary-label">Trạng thái:</span>
                      <span className="status-pill success" style={{ padding: '0.1rem 0.4rem', fontSize: '0.7rem' }}>HOẠT ĐỘNG</span>
                    </div>
                  </div>
                </div>
              </div>
            </div>
          )}
        </div>
      </main>

      {/* ==================== MODAL: TẠO 1 TÀI KHOẢN ĐƠN LẺ ==================== */}
      {isSingleCreateModalOpen && (
        <div className="modal-overlay">
          <div className="modal-sharp-box" style={{ maxWidth: '460px' }}>
            <div className="modal-sharp-header">
              <h3 className="modal-sharp-title">Tạo Tài Khoản Đặc Quyền Đơn Lẻ</h3>
              <button onClick={() => setIsSingleCreateModalOpen(false)} className="btn-icon-square">✕</button>
            </div>
            <form onSubmit={handleSingleCreate}>
              <div className="modal-sharp-body">
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Vai trò</label>
                  <select
                    className="form-select-sharp"
                    value={singleRole}
                    onChange={e => setSingleRole(e.target.value as any)}
                  >
                    <option value="MODERATOR">MODERATOR (Kiểm duyệt viên)</option>
                    <option value="ADMIN">ADMIN (Quản trị viên)</option>
                  </select>
                </div>
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Tên đăng nhập (Username)</label>
                  <input
                    type="text"
                    required
                    className="form-input-sharp"
                    value={singleUsername}
                    onChange={e => setSingleUsername(e.target.value)}
                    placeholder="e.g. mod_sensei"
                  />
                </div>
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Tên hiển thị</label>
                  <input
                    type="text"
                    className="form-input-sharp"
                    value={singleDisplayName}
                    onChange={e => setSingleDisplayName(e.target.value)}
                    placeholder="e.g. Sensei Tanaka"
                  />
                </div>
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Mật khẩu</label>
                  <input
                    type="password"
                    required
                    className="form-input-sharp"
                    value={singlePassword}
                    onChange={e => setSinglePassword(e.target.value)}
                  />
                </div>
              </div>
              <div className="modal-sharp-footer">
                <button type="button" onClick={() => setIsSingleCreateModalOpen(false)} className="btn-outline">Hủy</button>
                <button type="submit" disabled={isSubmittingSingle} className="btn-solid-primary">
                  {isSubmittingSingle ? 'Đang tạo...' : 'Tạo tài khoản'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================== MODAL: TẠO HÀNG LOẠT (BATCH AUTO) & TỰ ĐỘNG TẢI FILE TXT ==================== */}
      {isBatchModalOpen && (
        <div className="modal-overlay">
          <div className="modal-sharp-box" style={{ maxWidth: '640px' }}>
            <div className="modal-sharp-header">
              <h3 className="modal-sharp-title">⚡ Khởi Tạo Tài Khoản Hàng Loạt & Tải File .txt</h3>
              <button onClick={() => setIsBatchModalOpen(false)} className="btn-icon-square">✕</button>
            </div>
            {!generatedAccounts ? (
              <form onSubmit={handleBatchCreate}>
                <div className="modal-sharp-body">
                  <div style={{
                    background: 'var(--admin-primary-soft)',
                    border: '1px solid #bae6fd',
                    padding: '0.75rem',
                    borderRadius: '2px',
                    fontSize: '0.8rem',
                    color: 'var(--admin-primary-hover)'
                  }}>
                    <strong>Quy luật tự động sinh tài khoản:</strong>
                    <ul style={{ margin: '0.4rem 0 0 1.25rem', padding: 0 }}>
                      <li>Định dạng Username: <code>mod_YYYYMMDD_001</code> hoặc <code>admin_YYYYMMDD_001</code></li>
                      <li>Mật khẩu bảo mật ngẫu nhiên: <code>Pass@xxxxxx</code></li>
                      <li>Email nội bộ tự cấp: <code>username@jlsp.internal</code></li>
                      <li><strong>Hệ thống sẽ tự động xuất và tải về file <code>.txt</code> danh sách tài khoản ngay khi tạo xong!</strong></li>
                    </ul>
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Chọn vai trò cần tạo:</label>
                    <select
                      className="form-select-sharp"
                      value={batchRole}
                      onChange={e => setBatchRole(e.target.value as any)}
                    >
                      <option value="MODERATOR">MODERATOR (Kiểm duyệt viên video bài học)</option>
                      <option value="ADMIN">ADMIN (Quản trị viên toàn hệ thống)</option>
                    </select>
                  </div>

                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Số lượng tài khoản cần tạo (1 - 50):</label>
                    <input
                      type="number"
                      min={1}
                      max={50}
                      required
                      className="form-input-sharp"
                      value={batchCount}
                      onChange={e => setBatchCount(parseInt(e.target.value) || 1)}
                    />
                  </div>
                </div>
                <div className="modal-sharp-footer">
                  <button type="button" onClick={() => setIsBatchModalOpen(false)} className="btn-outline">Hủy</button>
                  <button type="submit" disabled={isSubmittingBatch} className="btn-solid-primary">
                    {isSubmittingBatch ? 'Đang tạo và xuất file...' : 'Tạo và Tải File .txt Ngay'}
                  </button>
                </div>
              </form>
            ) : (
              <div className="modal-sharp-body">
                <div style={{
                  background: 'var(--admin-success-bg)',
                  border: '1px solid #a7f3d0',
                  padding: '0.75rem',
                  borderRadius: '2px',
                  color: '#065f46',
                  fontSize: '0.82rem',
                  display: 'flex',
                  alignItems: 'center',
                  gap: '0.5rem'
                }}>
                  <CheckCircle2 size={18} />
                  <span>Đã tạo thành công {generatedAccounts.length} tài khoản và tải file <strong>.txt</strong> về máy!</span>
                </div>

                <div style={{ maxHeight: '280px', overflowY: 'auto', border: '1px solid var(--admin-border)' }}>
                  <table className="enterprise-table" style={{ fontSize: '0.78rem' }}>
                    <thead>
                      <tr>
                        <th>Tên Đăng Nhập</th>
                        <th>Mật Khẩu Ban Đầu</th>
                        <th>Email Nội Bộ</th>
                      </tr>
                    </thead>
                    <tbody>
                      {generatedAccounts.map((acc, idx) => (
                        <tr key={idx}>
                          <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: 'var(--admin-primary)' }}>
                            {acc.username}
                          </td>
                          <td style={{ fontFamily: 'var(--font-mono)', color: 'var(--admin-text-main)' }}>
                            {acc.password}
                          </td>
                          <td style={{ fontFamily: 'var(--font-mono)', color: 'var(--admin-text-muted)' }}>
                            {acc.email}
                          </td>
                        </tr>
                      ))}
                    </tbody>
                  </table>
                </div>

                <div style={{ display: 'flex', gap: '0.5rem' }}>
                  <button
                    onClick={() => downloadTextFile(generatedAccounts, batchRole)}
                    className="btn-solid-primary"
                    style={{ flex: 1, justifyContent: 'center' }}
                  >
                    <Download size={15} />
                    <span>Tải lại File .txt</span>
                  </button>
                  <button
                    onClick={() => {
                      const text = generatedAccounts.map(a => `${a.username} | ${a.password} | ${a.email}`).join('\n');
                      navigator.clipboard.writeText(text);
                      showToast('Đã copy danh sách tài khoản vào bộ nhớ tạm!');
                    }}
                    className="btn-outline"
                    style={{ flex: 1, justifyContent: 'center' }}
                  >
                    <Copy size={15} />
                    <span>Sao chép tất cả</span>
                  </button>
                </div>

                <div className="modal-sharp-footer" style={{ margin: '0 -1.25rem -1.25rem' }}>
                  <button onClick={() => setIsBatchModalOpen(false)} className="btn-outline">Đóng</button>
                </div>
              </div>
            )}
          </div>
        </div>
      )}

      {/* ==================== MODAL: TỪ CHỐI DUYỆT VIDEO (REASON PICKER) ==================== */}
      {selectedRejectVideo && (
        <div className="modal-overlay">
          <div className="modal-sharp-box" style={{ maxWidth: '480px' }}>
            <div className="modal-sharp-header">
              <h3 className="modal-sharp-title">Từ Chối Duyệt Video Bài Học</h3>
              <button onClick={() => setSelectedRejectVideo(null)} className="btn-icon-square">✕</button>
            </div>
            <form onSubmit={handleConfirmRejectVideo}>
              <div className="modal-sharp-body">
                <div style={{ fontSize: '0.84rem', color: 'var(--admin-text-main)' }}>
                  Video: <strong>{selectedRejectVideo.title}</strong>
                </div>

                <div className="form-group-sharp">
                  <label className="form-label-sharp">Chọn lý do vi phạm:</label>
                  <select
                    className="form-select-sharp"
                    value={rejectReason}
                    onChange={e => setRejectReason(e.target.value)}
                  >
                    <option value="Vi phạm bản quyền âm thanh / video">Vi phạm bản quyền âm thanh / video</option>
                    <option value="Nội dung không liên quan đến học tiếng Nhật">Nội dung không liên quan đến học tiếng Nhật</option>
                    <option value="Ngôn từ thù ghét, thô tục hoặc không phù hợp giáo dục">Ngôn từ thù ghét, thô tục hoặc không phù hợp giáo dục</option>
                    <option value="Chất lượng âm thanh/hình ảnh quá kém, không nhận diện được giọng">Chất lượng âm thanh/hình ảnh quá kém, không nhận diện được giọng</option>
                    <option value="Phát âm hoặc ngữ pháp sai lệch nghiêm trọng">Phát âm hoặc ngữ pháp sai lệch nghiêm trọng</option>
                    <option value="Lý do khác">Lý do khác (Nhập chi tiết bên dưới)</option>
                  </select>
                </div>

                {rejectReason === 'Lý do khác' && (
                  <div className="form-group-sharp">
                    <label className="form-label-sharp">Chi tiết vi phạm gửi cho User:</label>
                    <textarea
                      required
                      rows={3}
                      className="form-textarea-sharp"
                      placeholder="Mô tả cụ thể vi phạm để người đăng video biết và chỉnh sửa..."
                      value={customRejectReason}
                      onChange={e => setCustomRejectReason(e.target.value)}
                    />
                  </div>
                )}
              </div>
              <div className="modal-sharp-footer">
                <button type="button" onClick={() => setSelectedRejectVideo(null)} className="btn-outline">Hủy</button>
                <button type="submit" disabled={isSubmittingReject} className="btn-danger">
                  {isSubmittingReject ? 'Đang gửi...' : 'Xác nhận Từ chối Duyệt'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================== MODAL: CHI TIẾT VIDEO KIỂM DUYỆT ==================== */}
      {selectedDetailVideo && (
        <div className="modal-overlay" onClick={() => setSelectedDetailVideo(null)}>
          <div className="modal-sharp-box" style={{ maxWidth: '780px' }} onClick={e => e.stopPropagation()}>
            <div className="modal-sharp-header">
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                <span className={`status-pill ${selectedDetailVideo.modStatus === 'APPROVED' ? 'success' : selectedDetailVideo.modStatus === 'REJECTED' ? 'danger' : 'pending'
                  }`}>
                  {selectedDetailVideo.modStatus === 'APPROVED' ? 'ĐÃ DUYỆT' : selectedDetailVideo.modStatus === 'REJECTED' ? 'TỪ CHỐI' : 'CHỜ DUYỆT'}
                </span>
                <h3 className="modal-sharp-title" style={{ fontSize: '1.05rem', margin: 0 }}>
                  {selectedDetailVideo.title}
                </h3>
              </div>
              <button onClick={() => setSelectedDetailVideo(null)} className="btn-icon-square">✕</button>
            </div>

            <div className="modal-sharp-body" style={{ maxHeight: '78vh', overflowY: 'auto' }}>
              {/* Video Player - Compact, centered, 100% full frame without cropping */}
              <div className="mod-detail-video-box">
                <div className="mod-detail-video-player-wrap">
                  <video
                    src={selectedDetailVideo.videoUrl}
                    poster={selectedDetailVideo.thumbnailUrl}
                    controls
                    autoPlay
                    playsInline
                  />
                </div>
              </div>

              {/* Meta Grid */}
              <div style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))',
                gap: '0.75rem',
                marginTop: '1rem',
                background: 'var(--admin-bg-base)',
                padding: '0.85rem',
                borderRadius: 'var(--radius-sharp)',
                border: '1px solid var(--admin-border-subtle)',
                fontSize: '0.82rem'
              }}>
                <div>
                  <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Người đăng:</span>
                  <strong style={{ color: 'var(--admin-text-main)' }}>
                    {selectedDetailVideo.creatorDisplayName || selectedDetailVideo.creatorUsername || selectedDetailVideo.user?.displayName || selectedDetailVideo.user?.username || 'Creator'}
                  </strong>
                  <span style={{ display: 'block', fontSize: '0.72rem', color: '#94a3b8' }}>
                    @{selectedDetailVideo.creatorUsername || selectedDetailVideo.user?.username || 'creator'}
                  </span>
                </div>

                <div>
                  <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Cấp độ & Thời lượng:</span>
                  <strong style={{ color: 'var(--admin-text-main)' }}>
                    JLPT {selectedDetailVideo.jlptLevel || 'N5'} • {Math.floor((selectedDetailVideo.duration || 0) / 60)}m {(selectedDetailVideo.duration || 0) % 60}s
                  </strong>
                </div>

                <div>
                  <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Ngày đăng bài:</span>
                  <strong style={{ color: 'var(--admin-text-main)' }}>
                    {selectedDetailVideo.createdAt ? new Date(selectedDetailVideo.createdAt).toLocaleString('vi-VN') : '—'}
                  </strong>
                </div>

                <div>
                  <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem', marginBottom: '0.2rem' }}>Chế độ hiển thị:</span>
                  <span className="status-pill info">
                    🌐 {selectedDetailVideo.status || 'PUBLIC'}
                  </span>
                </div>

                <div>
                  <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Tương tác:</span>
                  <span style={{ color: 'var(--admin-text-main)' }}>
                    {selectedDetailVideo.viewCount || 0} xem • {selectedDetailVideo.likeCount || 0} like • {selectedDetailVideo.saveCount || 0} save
                  </span>
                </div>
              </div>

              {/* Description */}
              {selectedDetailVideo.description && (
                <div style={{ marginTop: '0.85rem' }}>
                  <label className="form-label-sharp" style={{ marginBottom: '0.3rem' }}>Mô tả bài học:</label>
                  <p style={{
                    margin: 0,
                    padding: '0.65rem 0.85rem',
                    background: 'var(--admin-bg-base)',
                    border: '1px solid var(--admin-border-subtle)',
                    borderRadius: 'var(--radius-sharp)',
                    fontSize: '0.83rem',
                    color: 'var(--admin-text-muted)'
                  }}>
                    {selectedDetailVideo.description}
                  </p>
                </div>
              )}

              {/* Speech-to-text Transcription / Subtitles block */}
              {(selectedDetailVideo.japaneseTranscription || selectedDetailVideo.vietnameseTranslation || (selectedDetailVideo.subtitles && selectedDetailVideo.subtitles !== '[]')) && (
                <div style={{ marginTop: '0.85rem' }}>
                  {(() => {
                    let parsedSubs: Array<{ start?: string; end?: string; text?: string; translation?: string }> = [];
                    if (selectedDetailVideo.subtitles && selectedDetailVideo.subtitles !== '[]') {
                      try {
                        const parsed = typeof selectedDetailVideo.subtitles === 'string'
                          ? JSON.parse(selectedDetailVideo.subtitles)
                          : selectedDetailVideo.subtitles;
                        if (Array.isArray(parsed) && parsed.length > 0) {
                          parsedSubs = parsed;
                        }
                      } catch {
                        // ignore json parse error
                      }
                    }

                    return (
                      <>
                        <label className="form-label-sharp" style={{ marginBottom: '0.35rem', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                          <span>Trích xuất lời thoại AI (Speech-to-Text) & Phụ đề:</span>
                          {parsedSubs.length > 0 && (
                            <span style={{ fontSize: '0.72rem', color: '#0284c7', fontWeight: 600 }}>
                              ({parsedSubs.length} đoạn hội thoại)
                            </span>
                          )}
                        </label>

                        {parsedSubs.length > 0 ? (
                          <div className="mod-subtitles-list">
                            {parsedSubs.map((sub, idx) => (
                              <div key={idx} className="mod-subtitle-item">
                                {(sub.start || sub.end) && (
                                  <div className="mod-subtitle-time">
                                    {sub.start || '00:00'} - {sub.end || ''}
                                  </div>
                                )}
                                <div style={{ flex: 1 }}>
                                  <div className="mod-subtitle-text">{sub.text}</div>
                                  {sub.translation && (
                                    <div className="mod-subtitle-trans">"{sub.translation}"</div>
                                  )}
                                </div>
                              </div>
                            ))}
                          </div>
                        ) : (
                          <div className="mod-transcript-box">
                            {selectedDetailVideo.japaneseTranscription && (
                              <div className="mod-transcript-jp">{selectedDetailVideo.japaneseTranscription}</div>
                            )}
                            {selectedDetailVideo.vietnameseTranslation && (
                              <div className="mod-transcript-vn">"{selectedDetailVideo.vietnameseTranslation}"</div>
                            )}
                            {!selectedDetailVideo.japaneseTranscription && !selectedDetailVideo.vietnameseTranslation && selectedDetailVideo.subtitles && (
                              <div className="mod-transcript-jp">{selectedDetailVideo.subtitles}</div>
                            )}
                          </div>
                        )}
                      </>
                    );
                  })()}
                </div>
              )}

              {/* Rejection Reason if any */}
              {selectedDetailVideo.rejectionReason && (
                <div style={{
                  marginTop: '0.85rem',
                  background: 'rgba(239, 68, 68, 0.1)',
                  border: '1px solid #ef4444',
                  padding: '0.75rem',
                  borderRadius: 'var(--radius-sharp)',
                  color: '#f87171',
                  fontSize: '0.82rem'
                }}>
                  <strong>Lý do từ chối:</strong> {selectedDetailVideo.rejectionReason}
                </div>
              )}
            </div>

            <div className="modal-sharp-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
              <button
                type="button"
                onClick={() => setSelectedDetailVideo(null)}
                className="btn-outline"
              >
                Đóng
              </button>

              <div style={{ display: 'flex', gap: '0.5rem' }}>
                {selectedDetailVideo.modStatus === 'PENDING' && (
                  <>
                    <button
                      type="button"
                      onClick={() => setSelectedRejectVideo(selectedDetailVideo)}
                      className="btn-danger"
                    >
                      <XCircle size={15} />
                      <span>Từ chối</span>
                    </button>
                    <button
                      type="button"
                      onClick={() => handleApproveVideo(selectedDetailVideo.id)}
                      className="btn-success"
                    >
                      <CheckCircle2 size={15} />
                      <span>Phê duyệt video</span>
                    </button>
                  </>
                )}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* ==================== MODAL: GIẢ LẬP THANH TOÁN QR LOCAL ==================== */}
      {isQrModalOpen && (
        <div className="modal-overlay">
          <div className="modal-sharp-box" style={{ maxWidth: '520px' }}>
            <div className="modal-sharp-header">
              <h3 className="modal-sharp-title">⚡ Giả Lập Quét QR Thanh Toán Local</h3>
              <button onClick={() => setIsQrModalOpen(false)} className="btn-icon-square">✕</button>
            </div>
            <div className="modal-sharp-body">
              <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                <label className="form-label-sharp" style={{ minWidth: '90px' }}>Chọn gói mua:</label>
                <select
                  className="form-select-sharp"
                  style={{ flex: 1 }}
                  value={selectedPlanCode}
                  onChange={e => {
                    setSelectedPlanCode(e.target.value);
                  }}
                >
                  {plans && plans.length > 0 ? (
                    plans.map(p => (
                      <option key={p.id} value={p.code}>
                        {p.name} ({p.price.toLocaleString('vi-VN')} đ - {p.dailyTokenLimit} token/ngày)
                      </option>
                    ))
                  ) : (
                    <>
                      <option value="FREE">Gói 1 Năm (419.000 đ - 50 token/ngày)</option>
                      <option value="PRO_YEARLY">Gói 3 Tháng (299.000 đ - 50 token/ngày)</option>
                      <option value="PRO_MONTHLY">Gói Trọn Đời (699.000 đ - 50 token/ngày)</option>
                    </>
                  )}
                </select>
                <button onClick={handleCreateQrOrder} className="btn-outline">
                  Tạo QR
                </button>
              </div>

              {activeQrOrder && (
                <div className="qr-display-box">
                  <div style={{ fontWeight: 700, fontSize: '1rem', color: '#0f172a' }}>
                    {activeQrOrder.planName} • {activeQrOrder.amount?.toLocaleString('vi-VN')} đ
                  </div>

                  {/* Clean SVG QR Representation */}
                  <div className="qr-code-canvas-wrap">
                    <svg width="150" height="150" viewBox="0 0 150 150">
                      <rect width="150" height="150" fill="#ffffff" />
                      {/* Top-left position marker */}
                      <rect x="10" y="10" width="35" height="35" fill="#0f172a" />
                      <rect x="15" y="15" width="25" height="25" fill="#ffffff" />
                      <rect x="20" y="20" width="15" height="15" fill="#0f172a" />
                      {/* Top-right position marker */}
                      <rect x="105" y="10" width="35" height="35" fill="#0f172a" />
                      <rect x="110" y="15" width="25" height="25" fill="#ffffff" />
                      <rect x="115" y="20" width="15" height="15" fill="#0f172a" />
                      {/* Bottom-left position marker */}
                      <rect x="10" y="105" width="35" height="35" fill="#0f172a" />
                      <rect x="15" y="110" width="25" height="25" fill="#ffffff" />
                      <rect x="20" y="115" width="15" height="15" fill="#0f172a" />
                      {/* Simulated QR data grid */}
                      <rect x="55" y="15" width="12" height="12" fill="#0284c7" />
                      <rect x="75" y="15" width="12" height="12" fill="#0f172a" />
                      <rect x="55" y="35" width="12" height="12" fill="#0f172a" />
                      <rect x="55" y="60" width="40" height="40" fill="#0284c7" />
                      <rect x="65" y="70" width="20" height="20" fill="#ffffff" />
                      <rect x="105" y="60" width="15" height="15" fill="#0f172a" />
                      <rect x="125" y="80" width="15" height="15" fill="#0f172a" />
                      <rect x="55" y="115" width="15" height="15" fill="#0f172a" />
                      <rect x="80" y="115" width="15" height="15" fill="#0284c7" />
                      <rect x="110" y="115" width="25" height="20" fill="#0f172a" />
                    </svg>
                  </div>

                  {/* THE PROMINENT VERIFICATION CODE DISPLAYED UNDER THE QR CODE AS REQUESTED */}
                  <div className="verification-code-banner">
                    <span className="verification-code-title">
                      Mã xác thực hiển thị ở dưới mã QR:
                    </span>
                    <span className="verification-code-display">
                      {activeQrOrder.verificationCode}
                    </span>
                    <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>
                      (Người dùng quét QR ngân hàng hoặc nhập mã này vào trang thanh toán để kích hoạt)
                    </span>
                  </div>

                  {/* Payment Confirmation Form */}
                  <div style={{ width: '100%', marginTop: '0.5rem' }}>
                    <label className="form-label-sharp" style={{ color: '#0f172a', marginBottom: '0.3rem', display: 'block' }}>
                      Nhập mã xác thực để hoàn tất thanh toán:
                    </label>
                    <div style={{ display: 'flex', gap: '0.5rem' }}>
                      <input
                        type="text"
                        className="form-input-sharp"
                        style={{
                          flex: 1,
                          background: '#f1f5f9',
                          color: '#0f172a',
                          border: '1px solid #cbd5e1',
                          fontFamily: 'var(--font-mono)',
                          fontWeight: 700,
                          fontSize: '1rem',
                          textAlign: 'center'
                        }}
                        value={verificationInput}
                        onChange={e => setVerificationInput(e.target.value)}
                        placeholder="e.g. JLSP-XXXXX"
                      />
                      <button
                        onClick={handleConfirmQrPayment}
                        disabled={isProcessingPayment}
                        className="btn-solid-primary"
                        style={{ whiteSpace: 'nowrap' }}
                      >
                        {isProcessingPayment ? 'Đang xác thực...' : 'Xác nhận thanh toán'}
                      </button>
                    </div>
                  </div>

                  {paymentSuccessData && (
                    <div style={{
                      background: 'rgba(16, 185, 129, 0.15)',
                      border: '1px solid #10b981',
                      padding: '0.75rem',
                      borderRadius: '2px',
                      color: '#047857',
                      fontSize: '0.85rem',
                      width: '100%',
                      textAlign: 'center',
                      fontWeight: 600
                    }}>
                      ✓ Giao dịch thành công! Tài khoản đã được nâng cấp VIP và mở rộng hạn mức Token ngày.
                    </div>
                  )}
                </div>
              )}
            </div>
            <div className="modal-sharp-footer">
              <button onClick={() => setIsQrModalOpen(false)} className="btn-outline">
                Đóng
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ==================== MODAL: TẠO MỚI / CHỈNH SỬA VOUCHER ==================== */}
      {isVoucherModalOpen && (
        <div className="modal-overlay">
          <div className="modal-sharp-box" style={{ maxWidth: '480px' }}>
            <div className="modal-sharp-header">
              <h3 className="modal-sharp-title">
                {editingVoucher ? `Chỉnh Sửa Voucher: ${editingVoucher.code}` : 'Tạo Mã Khuyến Mãi (Voucher) Mới'}
              </h3>
              <button onClick={() => setIsVoucherModalOpen(false)} className="btn-icon-square">✕</button>
            </div>

            <form onSubmit={handleSaveVoucher} style={{ display: 'flex', flexDirection: 'column', gap: '1rem', marginTop: '1rem' }}>
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                  Mã Voucher (In hoa, viết liền):
                </label>
                <input
                  type="text"
                  required
                  placeholder="VD: JLSP30, SENSEI, TET2026"
                  value={voucherCode}
                  onChange={e => setVoucherCode(e.target.value.toUpperCase())}
                  style={{
                    width: '100%',
                    padding: '0.55rem 0.75rem',
                    background: 'var(--admin-bg-base)',
                    border: '1px solid var(--admin-border)',
                    borderRadius: 'var(--radius-sharp)',
                    color: '#38bdf8',
                    fontWeight: 700,
                    fontFamily: 'monospace',
                    fontSize: '0.95rem'
                  }}
                />
              </div>

              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                  Mô Tả Chiến Dịch:
                </label>
                <input
                  type="text"
                  placeholder="VD: Ưu đãi 20% cho học viên mới đăng ký"
                  value={voucherDescription}
                  onChange={e => setVoucherDescription(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '0.55rem 0.75rem',
                    background: 'var(--admin-bg-base)',
                    border: '1px solid var(--admin-border)',
                    borderRadius: 'var(--radius-sharp)',
                    color: 'var(--admin-text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              {/* Discount Type Selection */}
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                  Hình Thức Giảm Giá:
                </label>
                <div style={{ display: 'flex', gap: '1.5rem', marginTop: '0.25rem' }}>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.84rem', cursor: 'pointer' }}>
                    <input
                      type="radio"
                      name="discountType"
                      checked={voucherDiscountType === 'percent'}
                      onChange={() => {
                        setVoucherDiscountType('percent');
                        if (voucherDiscountValue > 100) setVoucherDiscountValue(20);
                      }}
                    />
                    <span>Theo phần trăm (%)</span>
                  </label>
                  <label style={{ display: 'flex', alignItems: 'center', gap: '0.4rem', fontSize: '0.84rem', cursor: 'pointer' }}>
                    <input
                      type="radio"
                      name="discountType"
                      checked={voucherDiscountType === 'amount'}
                      onChange={() => {
                        setVoucherDiscountType('amount');
                        if (voucherDiscountValue <= 100) setVoucherDiscountValue(50000);
                      }}
                    />
                    <span>Số tiền cố định (VNĐ)</span>
                  </label>
                </div>
              </div>

              {/* Discount Value */}
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                  {voucherDiscountType === 'percent' ? 'Mức giảm (%) (từ 1% đến 100%):' : 'Số tiền giảm (VNĐ):'}
                </label>
                <input
                  type="number"
                  required
                  min={1}
                  max={voucherDiscountType === 'percent' ? 100 : 5000000}
                  step={voucherDiscountType === 'percent' ? 1 : 1000}
                  value={voucherDiscountValue}
                  onChange={e => setVoucherDiscountValue(Number(e.target.value))}
                  style={{
                    width: '100%',
                    padding: '0.55rem 0.75rem',
                    background: 'var(--admin-bg-base)',
                    border: '1px solid var(--admin-border)',
                    borderRadius: 'var(--radius-sharp)',
                    color: 'var(--admin-text-main)',
                    fontSize: '0.9rem',
                    fontWeight: 600
                  }}
                />
              </div>

              {/* Max Uses */}
              <div>
                <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                  Giới Hạn Lượt Dùng Tối Đa:
                </label>
                <input
                  type="number"
                  required
                  min={1}
                  value={voucherMaxUses}
                  onChange={e => setVoucherMaxUses(Number(e.target.value))}
                  style={{
                    width: '100%',
                    padding: '0.55rem 0.75rem',
                    background: 'var(--admin-bg-base)',
                    border: '1px solid var(--admin-border)',
                    borderRadius: 'var(--radius-sharp)',
                    color: 'var(--admin-text-main)',
                    fontSize: '0.85rem'
                  }}
                />
              </div>

              {/* Start & End Dates */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '0.75rem' }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                    Bắt Đầu:
                  </label>
                  <input
                    type="datetime-local"
                    value={voucherStartDate}
                    onChange={e => setVoucherStartDate(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.45rem 0.65rem',
                      background: 'var(--admin-bg-base)',
                      border: '1px solid var(--admin-border)',
                      borderRadius: 'var(--radius-sharp)',
                      color: 'var(--admin-text-main)',
                      fontSize: '0.8rem'
                    }}
                  />
                </div>
                <div>
                  <label style={{ display: 'block', fontSize: '0.8rem', fontWeight: 600, marginBottom: '0.35rem', color: 'var(--admin-text-main)' }}>
                    Hết Hạn:
                  </label>
                  <input
                    type="datetime-local"
                    value={voucherEndDate}
                    onChange={e => setVoucherEndDate(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '0.45rem 0.65rem',
                      background: 'var(--admin-bg-base)',
                      border: '1px solid var(--admin-border)',
                      borderRadius: 'var(--radius-sharp)',
                      color: 'var(--admin-text-main)',
                      fontSize: '0.8rem'
                    }}
                  />
                </div>
              </div>

              {/* Active Toggle Checkbox */}
              <div style={{ display: 'flex', alignItems: 'center', gap: '0.5rem', marginTop: '0.25rem' }}>
                <input
                  type="checkbox"
                  id="voucherIsActive"
                  checked={voucherIsActive}
                  onChange={e => setVoucherIsActive(e.target.checked)}
                />
                <label htmlFor="voucherIsActive" style={{ fontSize: '0.84rem', color: 'var(--admin-text-main)', cursor: 'pointer' }}>
                  Kích hoạt voucher ngay lập tức
                </label>
              </div>

              {/* Action buttons */}
              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '0.65rem', marginTop: '0.75rem' }}>
                <button
                  type="button"
                  onClick={() => setIsVoucherModalOpen(false)}
                  className="btn-outline"
                >
                  Hủy
                </button>
                <button
                  type="submit"
                  disabled={isSavingVoucher}
                  className="btn-primary"
                  style={{ minWidth: '110px', justifyContent: 'center' }}
                >
                  {isSavingVoucher ? 'Đang lưu...' : (editingVoucher ? 'Cập Nhật' : 'Tạo Voucher')}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* ==================== MODAL: CHỈNH SỬA BIỂU PHÍ & TOKEN LIMIT ==================== */}
      {editingPlan && (
        <div className="modal-overlay">
          <div className="modal-sharp-box" style={{ maxWidth: '480px' }}>
            <div className="modal-sharp-header">
              <h3 className="modal-sharp-title">Cấu Hình Gói: {editingPlan.name}</h3>
              <button onClick={() => setEditingPlan(null)} className="btn-icon-square">✕</button>
            </div>
            <form onSubmit={handleSavePlan}>
              <div className="modal-sharp-body">
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Tên gói dịch vụ</label>
                  <input
                    type="text"
                    required
                    className="form-input-sharp"
                    value={editName}
                    onChange={e => setEditName(e.target.value)}
                    placeholder="e.g. Gói Miễn Phí (Mặc định)"
                  />
                </div>

                <div className="form-group-sharp">
                  <label className="form-label-sharp">Giá dịch vụ (VND)</label>
                  <input
                    type="number"
                    min={0}
                    step={1000}
                    required
                    className="form-input-sharp"
                    value={editPrice}
                    onChange={e => setEditPrice(parseInt(e.target.value) || 0)}
                  />
                  {editingPlan.code === 'FREE' && (
                    <span className="form-input-help" style={{ color: '#38bdf8' }}>
                      Gói miễn phí mặc định có giá 0 đ.
                    </span>
                  )}
                </div>

                <div className="form-group-sharp">
                  <label className="form-label-sharp">Thời hạn sử dụng (Ngày)</label>
                  <input
                    type="number"
                    min={1}
                    required
                    className="form-input-sharp"
                    value={editDuration}
                    onChange={e => setEditDuration(parseInt(e.target.value) || 1)}
                  />
                </div>

                {/* Daily Token Limit field connected to SpeechToText AI */}
                <div className="form-group-sharp">
                  <label className="form-label-sharp">
                    Hạn mức Token ngày (Daily Token Limit):
                  </label>
                  <input
                    type="number"
                    min={10}
                    step={10}
                    required
                    className="form-input-sharp"
                    value={editDailyTokenLimit}
                    onChange={e => setEditDailyTokenLimit(parseInt(e.target.value) || 0)}
                  />
                  <span className="form-input-help" style={{ color: editingPlan.code === 'FREE' ? '#38bdf8' : undefined }}>
                    {editingPlan.code === 'FREE'
                      ? '⚡ Học viên mới và người dùng chưa mua VIP sẽ tự động nhận hạn mức Token này mỗi ngày từ Database (100% không còn fallback gán cứng).'
                      : 'Hạn mức số lượng Token AI (Speech-to-Text) học viên sở hữu gói này được dùng trong 1 ngày.'}
                  </span>
                </div>

                <div className="form-group-sharp">
                  <label className="form-label-sharp">Mô tả ngắn của gói (Description)</label>
                  <input
                    type="text"
                    className="form-input-sharp"
                    value={editDescription}
                    onChange={e => setEditDescription(e.target.value)}
                    placeholder="Ví dụ: Gói đặc quyền VIP trọn đời"
                  />
                </div>

                <div className="form-group-sharp">
                  <label className="form-label-sharp">Mô tả tính năng chi tiết</label>
                  <textarea
                    rows={3}
                    className="form-textarea-sharp"
                    value={editFeatures}
                    onChange={e => setEditFeatures(e.target.value)}
                  />
                </div>
              </div>
              <div className="modal-sharp-footer">
                <button type="button" onClick={() => setEditingPlan(null)} className="btn-outline">Hủy</button>
                <button type="submit" disabled={isSubmittingPlan} className="btn-solid-primary">
                  {isSubmittingPlan ? 'Đang lưu...' : 'Lưu thay đổi'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
};
