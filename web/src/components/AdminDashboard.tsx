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
  Key,
  Shield,
  BarChart3
} from 'lucide-react';
import { AnalyticsTab } from './admin/AnalyticsTab';
import { VideoModerationTab } from './admin/VideoModerationTab';
import { UsersTab } from './admin/UsersTab';
import { SubscriptionsTab } from './admin/SubscriptionsTab';
import { PricingTab } from './admin/PricingTab';
import { ReportsTab } from './admin/ReportsTab';
import { ProfileTab } from './admin/ProfileTab';
import './AdminDashboard.css';

interface AdminDashboardProps {
  user: UserProfile;
  onLogout: () => void;
  onUpdateUser?: (updated: UserProfile) => void;
}

type TabType = 'analytics' | 'videos' | 'users' | 'subscriptions' | 'pricing' | 'reports' | 'profile';

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
    if (isModerator && (activeTab === 'users' || activeTab === 'subscriptions' || activeTab === 'pricing' || activeTab === 'analytics')) {
      setActiveTab('videos');
    }
  }, [isAdmin, isModerator, activeTab]);

  // Global Toasts / Notification
  const [toastMessage, setToastMessage] = useState<string | null>(null);
  const showToast = (msg: string) => {
    setToastMessage(msg);
    setTimeout(() => setToastMessage(null), 4000);
  };


  // Vị trí portal: nút hành động trên header & modal (gốc .admin-viewport) của từng tab
  const [viewportEl, setViewportEl] = useState<HTMLDivElement | null>(null);
  const [actionsEl, setActionsEl] = useState<HTMLDivElement | null>(null);
  const tabProps = { showToast, actionsSlot: actionsEl, modalsSlot: viewportEl };

  return (
    <div ref={setViewportEl} className={`admin-viewport ${isSidebarCollapsed ? 'sidebar-collapsed' : ''}`}>
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
                {user.username.charAt(0).toUpperCase()}
              </div>
              <div className="user-info-text">
                <span className="user-name-title">{user.displayName || user.username}</span>
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
                title={`Hồ sơ cá nhân: ${user.displayName || user.username} (Click để mở)`}
              >
                {user.username.charAt(0).toUpperCase()}
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
              {activeTab === 'reports' && 'Xử Lý Khiếu Nại & Báo Cáo Vi Phạm'}
              {activeTab === 'profile' && 'Hồ Sơ Cá Nhân & Quản Trị Hệ Thống'}
            </h1>
            <span className="stage-subtitle">
              JLSP Social Japanese Learning Platform • Enterprise Backend Console
            </span>
          </div>

          <div ref={setActionsEl} className="top-bar-right" />
        </header>

        <div className="stage-body">
          {/* Các tab luôn được mount để giữ state khi chuyển tab; tab không active render null */}
          {isAdmin && <AnalyticsTab isActive={activeTab === 'analytics'} {...tabProps} />}
          {isModerator && <VideoModerationTab isActive={activeTab === 'videos'} {...tabProps} />}
          {isAdmin && <UsersTab isActive={activeTab === 'users'} {...tabProps} />}
          {isAdmin && <SubscriptionsTab isActive={activeTab === 'subscriptions'} {...tabProps} />}
          {isAdmin && <PricingTab isActive={activeTab === 'pricing'} {...tabProps} />}
          <ReportsTab isActive={activeTab === 'reports'} {...tabProps} />
          <ProfileTab isActive={activeTab === 'profile'} {...tabProps} user={user} onUpdateUser={onUpdateUser} />
        </div>
      </main>
    </div>
  );
};
