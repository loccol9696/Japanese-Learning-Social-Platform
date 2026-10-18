import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, ChevronRight, Search, CheckCircle2, UserPlus, Lock, Unlock, Download, Copy, Sparkles } from 'lucide-react';
import {
  getAdminUsers,
  toggleUserStatus,
  createPrivilegedAccount,
  batchCreateAccounts,
  type AdminUserItem,
  type GeneratedAccountDto
} from '../../services/adminService';
import type { AdminTabProps } from './types';

/** Tab quản lý người dùng & tạo tài khoản đặc quyền (chỉ ADMIN). */
export const UsersTab: React.FC<AdminTabProps> = ({ isActive, showToast, actionsSlot, modalsSlot }) => {
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
    if (isActive) {
      loadAdminUsers();
    }
  }, [isActive, userRoleFilter, usersPage]);

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

  if (!isActive) return null;

  return (
    <>
      {actionsSlot && createPortal(
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
        </>,
        actionsSlot
      )}
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
                    <span className={`role-tag ${
                      u.role === 'ADMIN' ? 'admin' : u.role === 'MODERATOR' ? 'moderator' : 'user'
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
      {modalsSlot && createPortal(
        <>
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
        </>,
        modalsSlot
      )}
    </>
  );
};
