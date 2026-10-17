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
  Filter,
  CheckCircle2,
  XCircle,
  Eye,
  Shield,
  ShieldAlert,
  UserPlus,
  Plus,
  Edit2,
  Lock,
  User as UserIcon
} from 'lucide-react';
import { createPrivilegedAccount } from '../services/adminService';
import './AdminDashboard.css';

interface AdminDashboardProps {
  user: UserProfile;
  onLogout: () => void;
}

type TabType = 'videos' | 'reports' | 'users' | 'subscriptions' | 'pricing';

export const AdminDashboard: React.FC<AdminDashboardProps> = ({ user, onLogout }) => {
  const [activeTab, setActiveTab] = useState<TabType>('videos');
  const [isSidebarCollapsed, setIsSidebarCollapsed] = useState(false);
  const [isCreateUserModalOpen, setIsCreateUserModalOpen] = useState(false);

  // Moderator guard: Auto redirect away from pricing if moderator
  useEffect(() => {
    if (user.role === 'MODERATOR' && activeTab === 'pricing') {
      setActiveTab('videos');
    }
  }, [user.role, activeTab]);

  const [newUsername, setNewUsername] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [newRole, setNewRole] = useState<'ADMIN' | 'MODERATOR'>('MODERATOR');
  const [isSubmittingUser, setIsSubmittingUser] = useState(false);

  // Mock Accounts State
  const [accounts, setAccounts] = useState([
    { id: 1, username: 'admin', email: 'admin@jlsp.edu.vn', role: 'ADMIN', status: 'ACTIVE', createdAt: '16/10/2026' },
    { id: 2, username: 'mod_kenji', email: 'kenji.sensei@jlsp.edu.vn', role: 'MODERATOR', status: 'ACTIVE', createdAt: '15/10/2026' },
    { id: 3, username: 'tanaka_san', email: 'tanaka.n2@gmail.com', role: 'USER', status: 'ACTIVE', createdAt: '14/10/2026' },
    { id: 4, username: 'spammer_09', email: 'bot_spam@tempmail.com', role: 'USER', status: 'LOCKED', createdAt: '12/10/2026' },
  ]);

  const [plans] = useState([
    { id: 'free', name: 'Gói Cơ Bản (Free)', price: 0, duration: 'Vĩnh viễn', features: ['Xem 10 video/ngày', 'Flashcard N5', 'Không AI Shadowing'], active: true },
    { id: 'premium_month', name: 'Gói Tháng (JLSP Pro)', price: 99000, duration: '1 Tháng', features: ['Video không giới hạn', 'Flashcard N5 - N1', 'AI Chấm điểm phát âm', 'Tải offline'], active: true },
    { id: 'premium_year', name: 'Gói Năm (JLSP Mastery)', price: 890000, duration: '1 Năm', features: ['Tất cả quyền Pro', 'Tiết kiệm 25%', 'Kèm cố vấn Sensei 1-1', 'Chứng nhận hoàn thành'], active: true },
  ]);

  const handleCreateAccount = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmittingUser(true);
    try {
      const createdUser = await createPrivilegedAccount({
        username: newUsername,
        password: newPassword,
        role: newRole,
      });

      setAccounts(prev => [
        {
          id: typeof createdUser.id === 'number' ? createdUser.id : Date.now(),
          username: createdUser.username,
          email: createdUser.email,
          role: createdUser.role || newRole,
          status: 'ACTIVE',
          createdAt: 'Vừa tạo'
        },
        ...prev
      ]);

      setIsCreateUserModalOpen(false);
      setNewUsername('');
      setNewPassword('');
      alert(`Đã khởi tạo thành công tài khoản ${newRole}: ${createdUser.username}!`);
    } catch (err: any) {
      alert('Lỗi tạo tài khoản: ' + (err.message || 'Có lỗi xảy ra'));
    } finally {
      setIsSubmittingUser(false);
    }
  };

  return (
    <div className={`admin-viewport ${isSidebarCollapsed ? 'sidebar-collapsed' : ''}`}>
      
      {/* Smooth Collapsible Sidebar */}
      <aside className="admin-sidebar">
        <div className="sidebar-brand">
          <div className="brand-logo-disc">
            <span className="brand-glyph">日</span>
          </div>
          {!isSidebarCollapsed && (
            <div className="brand-title-wrap">
              <span className="brand-name">JLSP Portal</span>
              <span className="brand-sub font-mono">
                {user.role === 'MODERATOR' ? 'MODERATOR PORTAL' : 'ADMIN CONSOLE'}
              </span>
            </div>
          )}
        </div>

        <nav className="sidebar-nav">
          <button
            onClick={() => setActiveTab('videos')}
            className={`nav-tab-item ${activeTab === 'videos' ? 'active' : ''}`}
            title="Duyệt video ngắn"
          >
            <Video size={19} className="nav-icon" />
            {!isSidebarCollapsed && <span className="nav-label">Duyệt Video</span>}
            {!isSidebarCollapsed && <span className="tab-pill-badge blue">3</span>}
          </button>

          <button
            onClick={() => setActiveTab('reports')}
            className={`nav-tab-item ${activeTab === 'reports' ? 'active' : ''}`}
            title="Xử lý báo cáo"
          >
            <AlertTriangle size={19} className="nav-icon" />
            {!isSidebarCollapsed && <span className="nav-label">Xử lý Report</span>}
            {!isSidebarCollapsed && <span className="tab-pill-badge rose">5</span>}
          </button>

          <button
            onClick={() => setActiveTab('users')}
            className={`nav-tab-item ${activeTab === 'users' ? 'active' : ''}`}
            title="Quản lý tài khoản"
          >
            <Users size={19} className="nav-icon" />
            {!isSidebarCollapsed && <span className="nav-label">Quản lý Tài khoản</span>}
          </button>

          <button
            onClick={() => setActiveTab('subscriptions')}
            className={`nav-tab-item ${activeTab === 'subscriptions' ? 'active' : ''}`}
            title="Lịch sử mua gói"
          >
            <CreditCard size={19} className="nav-icon" />
            {!isSidebarCollapsed && <span className="nav-label">Lịch sử Mua gói</span>}
          </button>

          {user.role !== 'MODERATOR' && (
            <button
              onClick={() => setActiveTab('pricing')}
              className={`nav-tab-item ${activeTab === 'pricing' ? 'active' : ''}`}
              title="Tùy chỉnh giá gói"
            >
              <Sliders size={19} className="nav-icon" />
              {!isSidebarCollapsed && <span className="nav-label">Tùy chỉnh Giá gói</span>}
            </button>
          )}
        </nav>

        {/* Sidebar Footer */}
        <div className="sidebar-footer">
          <button
            type="button"
            onClick={() => setIsSidebarCollapsed(!isSidebarCollapsed)}
            className="collapse-toggle-btn"
            title={isSidebarCollapsed ? "Mở rộng thanh bên" : "Thu gọn thanh bên"}
          >
            {isSidebarCollapsed ? <ChevronRight size={18} /> : <ChevronLeft size={18} />}
            {!isSidebarCollapsed && <span>Thu gọn Sidebar</span>}
          </button>

          <div className="admin-profile-pill">
            <div className="admin-avatar">
              <span>{user.username.charAt(0).toUpperCase()}</span>
            </div>
            {!isSidebarCollapsed && (
              <div className="admin-meta">
                <span className="admin-name">{user.displayName || user.username}</span>
                <span className="admin-badge font-mono">{user.role || 'ADMIN'}</span>
              </div>
            )}
            <button onClick={onLogout} className="logout-icon-btn" title="Đăng xuất">
              <LogOut size={16} />
            </button>
          </div>
        </div>
      </aside>

      {/* Main Administrative Stage */}
      <main className="admin-main-stage">
        
        {/* Top Header Breadcrumb Bar */}
        <header className="stage-top-bar">
          <div className="page-heading">
            <h1 className="stage-title">
              {activeTab === 'videos' && 'Duyệt & Kiểm Duyệt Video Ngắn'}
              {activeTab === 'reports' && 'Xử Lý Khiếu Nại & Báo Cáo Nội Dung'}
              {activeTab === 'users' && 'Quản Lý Người Dùng & Phân Quyền'}
              {activeTab === 'subscriptions' && 'Lịch Sử Giao Dịch & Mua Gói VIP'}
              {activeTab === 'pricing' && 'Cấu Hình Gói Dịch Vụ & Biểu Phí'}
            </h1>
            <span className="stage-subtitle">Hệ thống quản trị trung tâm JLSP</span>
          </div>

          <div className="stage-actions">
            {activeTab === 'users' && user.role !== 'MODERATOR' && (
              <button 
                onClick={() => setIsCreateUserModalOpen(true)}
                className="btn-create-admin"
              >
                <UserPlus size={16} />
                <span>Thêm Admin / Moderator</span>
              </button>
            )}
          </div>
        </header>

        {/* Dynamic Content Views */}
        <div className="stage-body">
          
          {/* TAB 1: DUYỆT VIDEO */}
          {activeTab === 'videos' && (
            <div className="content-view-section">
              <div className="overview-stats-grid">
                <div className="stat-card">
                  <span className="stat-card-title">Chờ duyệt hôm nay</span>
                  <span className="stat-card-num font-mono">14</span>
                  <span className="stat-card-sub text-blue">+4 video từ sáng</span>
                </div>
                <div className="stat-card">
                  <span className="stat-card-title">Đã thông qua</span>
                  <span className="stat-card-num font-mono">182</span>
                  <span className="stat-card-sub text-emerald">Tỉ lệ đạt 92%</span>
                </div>
                <div className="stat-card">
                  <span className="stat-card-title">Bị từ chối</span>
                  <span className="stat-card-num font-mono">16</span>
                  <span className="stat-card-sub text-rose">Vi phạm bản quyền</span>
                </div>
              </div>

              <div className="table-card-wrapper">
                <div className="table-header-row">
                  <h3 className="table-title">Hàng đợi video cần phê duyệt</h3>
                  <div className="search-pill">
                    <Search size={15} />
                    <input type="text" placeholder="Tìm theo tiêu đề, Sensei..." />
                  </div>
                </div>

                <table className="admin-data-table">
                  <thead>
                    <tr>
                      <th>Video Preview</th>
                      <th>Người Đăng</th>
                      <th>Cấp độ</th>
                      <th>Phụ đề Furigana</th>
                      <th>Thời gian tải</th>
                      <th>Hành động</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td className="video-col">
                        <div className="video-thumb-preview">
                          <img src="https://picsum.photos/seed/vid1/120/70" alt="Preview" />
                          <span className="duration-tag font-mono">0:45</span>
                        </div>
                        <span className="video-name">Hội thoại gọi món tại Quán Ramen</span>
                      </td>
                      <td>
                        <span className="user-text">@kenji_tokyo</span>
                      </td>
                      <td><span className="jlpt-badge n3">JLPT N3</span></td>
                      <td><span className="text-emerald">Đã đồng bộ AI (100%)</span></td>
                      <td><span className="font-mono text-dim">10 phút trước</span></td>
                      <td>
                        <div className="action-btn-group">
                          <button className="icon-btn-round check" title="Duyệt xuất bản"><CheckCircle2 size={16} /></button>
                          <button className="icon-btn-round reject" title="Từ chối video"><XCircle size={16} /></button>
                          <button className="icon-btn-round view" title="Xem chi tiết"><Eye size={16} /></button>
                        </div>
                      </td>
                    </tr>
                    <tr>
                      <td className="video-col">
                        <div className="video-thumb-preview">
                          <img src="https://picsum.photos/seed/vid2/120/70" alt="Preview" />
                          <span className="duration-tag font-mono">1:12</span>
                        </div>
                        <span className="video-name">5 Slang hay dùng nhất trong Anime 2026</span>
                      </td>
                      <td>
                        <span className="user-text">@sakura_nihongo</span>
                      </td>
                      <td><span className="jlpt-badge n4">JLPT N4</span></td>
                      <td><span className="text-emerald">Đã đồng bộ AI (98%)</span></td>
                      <td><span className="font-mono text-dim">35 phút trước</span></td>
                      <td>
                        <div className="action-btn-group">
                          <button className="icon-btn-round check" title="Duyệt xuất bản"><CheckCircle2 size={16} /></button>
                          <button className="icon-btn-round reject" title="Từ chối video"><XCircle size={16} /></button>
                          <button className="icon-btn-round view" title="Xem chi tiết"><Eye size={16} /></button>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TAB 2: XỬ LÝ REPORT */}
          {activeTab === 'reports' && (
            <div className="content-view-section">
              <div className="table-card-wrapper">
                <div className="table-header-row">
                  <h3 className="table-title">Danh sách nội dung bị báo cáo vi phạm</h3>
                  <div className="filter-group">
                    <button className="filter-pill-btn active">Tất cả (5)</button>
                    <button className="filter-pill-btn">Video vi phạm</button>
                    <button className="filter-pill-btn">Bình luận thô tục</button>
                  </div>
                </div>

                <table className="admin-data-table">
                  <thead>
                    <tr>
                      <th>Đối Tượng</th>
                      <th>Lý Do Báo Cáo</th>
                      <th>Người Báo Cáo</th>
                      <th>Mức Độ</th>
                      <th>Trạng Thái</th>
                      <th>Xử Lý</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td>
                        <strong>Video #4812</strong>
                        <p className="sub-text">"Phát âm sai lệch ngữ nghĩa tiếng lóng"</p>
                      </td>
                      <td>Nội dung sai kiến thức JLPT</td>
                      <td>@tanaka_sensei</td>
                      <td><span className="severity-badge warning">Cảnh báo</span></td>
                      <td><span className="status-tag pending">Đang chờ xem xét</span></td>
                      <td>
                        <div className="action-btn-group">
                          <button className="btn-table-action primary">Ẩn nội dung</button>
                          <button className="btn-table-action secondary">Bác bỏ report</button>
                        </div>
                      </td>
                    </tr>
                    <tr>
                      <td>
                        <strong>Bình luận tại Video #3901</strong>
                        <p className="sub-text">"Ngôn từ quấy rối học viên khác"</p>
                      </td>
                      <td>Spam & Quấy rối</td>
                      <td>@mai_nguyen99</td>
                      <td><span className="severity-badge high">Nghiêm trọng</span></td>
                      <td><span className="status-tag pending">Đang chờ xem xét</span></td>
                      <td>
                        <div className="action-btn-group">
                          <button className="btn-table-action danger">Khóa bình luận & Cảnh cáo</button>
                          <button className="btn-table-action secondary">Bỏ qua</button>
                        </div>
                      </td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TAB 3: QUẢN LÝ TÀI KHOẢN */}
          {activeTab === 'users' && (
            <div className="content-view-section">
              <div className="table-card-wrapper">
                <div className="table-header-row">
                  <div className="header-meta">
                    <h3 className="table-title">Danh sách tài khoản hệ thống</h3>
                    <p className="sub-text">Quản lý cấp bậc, role phân quyền và trạng thái hoạt động</p>
                  </div>
                  <div className="search-pill">
                    <Search size={15} />
                    <input type="text" placeholder="Tìm kiếm tài khoản, email..." />
                  </div>
                </div>

                <table className="admin-data-table">
                  <thead>
                    <tr>
                      <th>ID</th>
                      <th>Tài Khoản</th>
                      <th>Địa Chỉ Email</th>
                      <th>Vai Trò (Role)</th>
                      <th>Trạng Thái</th>
                      <th>Ngày Tạo</th>
                      <th>Hành Động</th>
                    </tr>
                  </thead>
                  <tbody>
                    {accounts.map(acc => (
                      <tr key={`acc-${acc.id}-${acc.username}`}>
                        <td className="font-mono">#{acc.id}</td>
                        <td>
                          <strong>{acc.username}</strong>
                        </td>
                        <td>{acc.email}</td>
                        <td>
                          {acc.role === 'ADMIN' && <span className="role-chip admin"><Shield size={12} /> ADMIN</span>}
                          {acc.role === 'MODERATOR' && <span className="role-chip moderator"><ShieldAlert size={12} /> MODERATOR</span>}
                          {acc.role === 'USER' && <span className="role-chip user">USER</span>}
                        </td>
                        <td>
                          {acc.status === 'ACTIVE' ? (
                            <span className="status-indicator-badge active">Hoạt động</span>
                          ) : (
                            <span className="status-indicator-badge locked">Bị khóa</span>
                          )}
                        </td>
                        <td className="font-mono text-dim">{acc.createdAt}</td>
                        <td>
                          <div className="action-btn-group">
                            <button className="btn-action-sm edit" title="Sửa quyền / Mật khẩu"><Edit2 size={14} /></button>
                            <button className="btn-action-sm lock" title="Khóa / Mở khóa"><Lock size={14} /></button>
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TAB 4: LỊCH SỬ MUA GÓI */}
          {activeTab === 'subscriptions' && (
            <div className="content-view-section">
              <div className="overview-stats-grid">
                <div className="stat-card">
                  <span className="stat-card-title">Doanh thu tháng này</span>
                  <span className="stat-card-num font-mono">48,250,000 đ</span>
                  <span className="stat-card-sub text-emerald">+18.5% so với tháng trước</span>
                </div>
                <div className="stat-card">
                  <span className="stat-card-title">Tổng số gói đã kích hoạt</span>
                  <span className="stat-card-num font-mono">312</span>
                  <span className="stat-card-sub text-blue">94% gia hạn tự động</span>
                </div>
                <div className="stat-card">
                  <span className="stat-card-title">Gói phổ biến nhất</span>
                  <span className="stat-card-num font-mono">JLSP Pro 1 Tháng</span>
                  <span className="stat-card-sub">Chiếm 68% tổng lượt mua</span>
                </div>
              </div>

              <div className="table-card-wrapper">
                <div className="table-header-row">
                  <h3 className="table-title">Giao dịch mua gói gần đây</h3>
                  <button className="filter-pill-btn"><Filter size={14} /> Xuất file báo cáo</button>
                </div>

                <table className="admin-data-table">
                  <thead>
                    <tr>
                      <th>Mã Giao Dịch</th>
                      <th>Người Mua</th>
                      <th>Gói Dịch Vụ</th>
                      <th>Số Tiền</th>
                      <th>Cổng Thanh Toán</th>
                      <th>Thời Gian</th>
                      <th>Trạng Thái</th>
                    </tr>
                  </thead>
                  <tbody>
                    <tr>
                      <td className="font-mono">#TX-94812</td>
                      <td><strong>nguyen_van_a</strong></td>
                      <td>JLSP Pro (1 Tháng)</td>
                      <td className="font-mono text-blue font-bold">99,000 đ</td>
                      <td>VNPay QR</td>
                      <td className="font-mono text-dim">16/10/2026 13:45</td>
                      <td><span className="status-indicator-badge active">Thành công</span></td>
                    </tr>
                    <tr>
                      <td className="font-mono">#TX-94811</td>
                      <td><strong>hoang_linh_jp</strong></td>
                      <td>JLSP Mastery (1 Năm)</td>
                      <td className="font-mono text-blue font-bold">890,000 đ</td>
                      <td>MoMo E-Wallet</td>
                      <td className="font-mono text-dim">16/10/2026 11:20</td>
                      <td><span className="status-indicator-badge active">Thành công</span></td>
                    </tr>
                    <tr>
                      <td className="font-mono">#TX-94810</td>
                      <td><strong>sensei_trung</strong></td>
                      <td>JLSP Pro (1 Tháng)</td>
                      <td className="font-mono text-blue font-bold">99,000 đ</td>
                      <td>Thẻ Visa/Mastercard</td>
                      <td className="font-mono text-dim">15/10/2026 18:02</td>
                      <td><span className="status-indicator-badge active">Thành công</span></td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          )}

          {/* TAB 5: TÙY CHỈNH GIÁ GÓI (CHỈ DÀNH CHO ADMIN) */}
          {activeTab === 'pricing' && user.role !== 'MODERATOR' && (
            <div className="content-view-section">
              <div className="pricing-config-header">
                <div>
                  <h3 className="table-title">Bảng cấu hình gói thành viên VIP</h3>
                  <p className="sub-text">Chỉnh sửa giá tiền, thời hạn và kích hoạt các ưu đãi trực tiếp lên mobile app</p>
                </div>
                <button className="btn-create-admin"><Plus size={16} /> Thêm Gói Mới</button>
              </div>

              <div className="pricing-cards-grid">
                {plans.map(p => (
                  <div key={p.id} className="plan-editor-card">
                    <div className="plan-card-top">
                      <span className="plan-name">{p.name}</span>
                      <span className="plan-badge font-mono">{p.duration}</span>
                    </div>

                    <div className="plan-price-block">
                      <span className="price-amount font-mono">
                        {p.price.toLocaleString('vi-VN')} <small>VND</small>
                      </span>
                    </div>

                    <ul className="plan-feature-list">
                      {p.features.map((f, i) => (
                        <li key={i}>
                          <CheckCircle2 size={15} className="feature-icon-check" />
                          <span>{f}</span>
                        </li>
                      ))}
                    </ul>

                    <div className="plan-card-actions">
                      <button className="btn-plan-edit"><Edit2 size={14} /> Chỉnh sửa giá & tính năng</button>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

        </div>
      </main>

      {/* CREATE ADMIN / MODERATOR MODAL */}
      {isCreateUserModalOpen && (
        <div className="modal-backdrop">
          <div className="modal-bezel-outer">
            <div className="modal-bezel-inner">
              <div className="modal-header">
                <div>
                  <h3 className="modal-title">Khởi Tạo Tài Khoản Đặc Quyền</h3>
                  <p className="modal-subtitle">Cấp quyền truy cập hệ thống cho Admin hoặc Moderator</p>
                </div>
                <button onClick={() => setIsCreateUserModalOpen(false)} className="modal-close-btn">&times;</button>
              </div>

              <form onSubmit={handleCreateAccount} className="modal-form">
                {/* Role Selector */}
                <div className="form-group">
                  <label className="input-label">Chọn Vai Trò (Role)</label>
                  <div className="role-radio-group">
                    <button
                      type="button"
                      className={`role-select-pill ${newRole === 'MODERATOR' ? 'active mod' : ''}`}
                      onClick={() => setNewRole('MODERATOR')}
                    >
                      <ShieldAlert size={16} />
                      <span>MODERATOR (Kiểm duyệt viên)</span>
                    </button>
                    <button
                      type="button"
                      className={`role-select-pill ${newRole === 'ADMIN' ? 'active admin' : ''}`}
                      onClick={() => setNewRole('ADMIN')}
                    >
                      <Shield size={16} />
                      <span>ADMIN (Quản trị tối cao)</span>
                    </button>
                  </div>
                </div>

                <div className="form-group">
                  <label className="input-label">Tên đăng nhập (Username)</label>
                  <div className="input-wrapper">
                    <UserIcon size={16} className="input-icon" />
                    <input
                      type="text"
                      placeholder="ví dụ: mod_tokyo"
                      value={newUsername}
                      onChange={e => setNewUsername(e.target.value)}
                      required
                    />
                  </div>
                </div>



                <div className="form-group">
                  <label className="input-label">Mật khẩu khởi tạo</label>
                  <div className="input-wrapper">
                    <Lock size={16} className="input-icon" />
                    <input
                      type="password"
                      placeholder="Tối thiểu 6 ký tự"
                      value={newPassword}
                      onChange={e => setNewPassword(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <div className="modal-actions-row">
                  <button
                    type="button"
                    onClick={() => setIsCreateUserModalOpen(false)}
                    className="btn-cancel"
                  >
                    Hủy bỏ
                  </button>
                  <button
                    type="submit"
                    className="btn-confirm-create"
                    disabled={isSubmittingUser}
                  >
                    {isSubmittingUser ? 'Đang tạo...' : `Khởi tạo ${newRole}`}
                  </button>
                </div>
              </form>
            </div>
          </div>
        </div>
      )}

    </div>
  );
};
