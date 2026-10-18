import React, { useState, useEffect } from 'react';
import { Edit2, Lock, Key, Shield, Save } from 'lucide-react';
import {
  changePassword,
  updateAdminProfile
} from '../../services/adminService';
import type { UserProfile } from '../../types/auth';
import type { AdminTabProps } from './types';

/** Tab hồ sơ cá nhân & đổi mật khẩu (ADMIN & MODERATOR). */
export const ProfileTab: React.FC<AdminTabProps & { user: UserProfile; onUpdateUser?: (updated: UserProfile) => void }> = ({ isActive, showToast, user, onUpdateUser }) => {
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

  if (!isActive) return null;

  return (
    <>
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
    </>
  );
};
