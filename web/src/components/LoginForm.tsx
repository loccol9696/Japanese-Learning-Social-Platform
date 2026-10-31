import React, { useState } from 'react';
import { 
  Mail, 
  Lock, 
  Eye, 
  EyeOff, 
  ArrowRight, 
  AlertCircle,
  CheckCircle2,
  Check,
  User as UserIcon
} from 'lucide-react';
import { loginUser, registerUser } from '../services/authService';
import type { UserProfile } from '../types/auth';
import './LoginForm.css';

interface LoginFormProps {
  onLoginSuccess: (user: UserProfile, token: string) => void;
}

export const LoginForm: React.FC<LoginFormProps> = ({ onLoginSuccess }) => {
  const [isRegisterMode, setIsRegisterMode] = useState(false);
  
  // Login fields
  const [usernameOrEmail, setUsernameOrEmail] = useState('');
  const [password, setPassword] = useState('');
  const [rememberMe, setRememberMe] = useState(true);

  // Register additional fields
  const [regUsername, setRegUsername] = useState('');
  const [regEmail, setRegEmail] = useState('');
  const [regPassword, setRegPassword] = useState('');
  const [regConfirmPassword, setRegConfirmPassword] = useState('');
  const [regDisplayName, setRegDisplayName] = useState('');

  const [showPassword, setShowPassword] = useState(false);
  const [showConfirmPassword, setShowConfirmPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Handle Login Submit
  const handleLoginSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!usernameOrEmail.trim() || !password.trim()) {
      setErrorMessage('Vui lòng điền đầy đủ tài khoản/email và mật khẩu.');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    try {
      const data = await loginUser(usernameOrEmail.trim(), password);
      if (!data || !data.accessToken || !data.user) {
        throw new Error('Dữ liệu xác thực trả về từ máy chủ không hợp lệ.');
      }
      onLoginSuccess(data.user, data.accessToken);
    } catch (err: any) {
      setErrorMessage(err.message || 'Đăng nhập không thành công. Vui lòng kiểm tra lại thông tin.');
    } finally {
      setIsLoading(false);
    }
  };

  // Handle Register Submit
  const handleRegisterSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!regUsername.trim() || !regEmail.trim() || !regPassword.trim()) {
      setErrorMessage('Vui lòng điền đầy đủ tên đăng nhập, email và mật khẩu.');
      return;
    }

    if (regPassword !== regConfirmPassword) {
      setErrorMessage('Mật khẩu xác nhận không trùng khớp.');
      return;
    }

    if (regPassword.length < 8) {
      setErrorMessage('Mật khẩu phải có độ dài tối thiểu 8 ký tự.');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    try {
      const data = await registerUser({
        username: regUsername.trim(),
        email: regEmail.trim(),
        password: regPassword,
        displayName: regDisplayName.trim() || undefined,
      });

      if (data && data.accessToken && data.user) {
        onLoginSuccess(data.user, data.accessToken);
      } else {
        setSuccessMessage('Đăng ký tài khoản thành công! Vui lòng đăng nhập.');
        setIsRegisterMode(false);
        setUsernameOrEmail(regUsername.trim());
        setPassword(regPassword);
      }
    } catch (err: any) {
      setErrorMessage(err.message || 'Đăng ký tài khoản không thành công. Vui lòng thử lại.');
    } finally {
      setIsLoading(false);
    }
  };

  // 1-Click Fill Helpers for Testing
  const handleFillAdmin = () => {
    setIsRegisterMode(false);
    setUsernameOrEmail('admin');
    setPassword('AdminPassword123@');
    setErrorMessage(null);
    setSuccessMessage(null);
  };

  const handleFillModerator = () => {
    setIsRegisterMode(false);
    setUsernameOrEmail('moderator');
    setPassword('ModeratorPassword123@');
    setErrorMessage(null);
    setSuccessMessage(null);
  };

  const handleGoogleLogin = () => {
    alert('Tính năng Đăng nhập bằng Google đang được cấu hình tích hợp với máy chủ OAuth2.');
  };

  return (
    <div className="auth-viewport">
      <div className="auth-container">
        
        {/* Title */}
        <h1 className="auth-title">
          {isRegisterMode ? 'Đăng ký' : 'Đăng nhập'}
        </h1>

        {/* Notifications */}
        {errorMessage && (
          <div className="auth-alert error" role="alert">
            <AlertCircle size={18} className="alert-icon" />
            <span>{errorMessage}</span>
          </div>
        )}

        {successMessage && (
          <div className="auth-alert success" role="alert">
            <CheckCircle2 size={18} className="alert-icon" />
            <span>{successMessage}</span>
          </div>
        )}

        {/* ================= FORM: ĐĂNG NHẬP ================= */}
        {!isRegisterMode ? (
          <form onSubmit={handleLoginSubmit} className="auth-form">
            {/* Field: Email / Tên đăng nhập */}
            <div className="auth-field-group">
              <label htmlFor="login-identity" className="auth-label">
                Email/Tên đăng nhập
              </label>
              <div className="auth-input-wrapper">
                <Mail size={18} className="field-icon-left" />
                <input
                  id="login-identity"
                  type="text"
                  value={usernameOrEmail}
                  onChange={(e) => setUsernameOrEmail(e.target.value)}
                  placeholder="name@gmail.com"
                  className="auth-input"
                  autoComplete="username"
                  disabled={isLoading}
                  required
                />
              </div>
            </div>

            {/* Field: Mật khẩu */}
            <div className="auth-field-group">
              <label htmlFor="login-password" className="auth-label">
                Mật khẩu
              </label>
              <div className="auth-input-wrapper">
                <Lock size={18} className="field-icon-left" />
                <input
                  id="login-password"
                  type={showPassword ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  placeholder="Nhập mật khẩu"
                  className="auth-input"
                  autoComplete="current-password"
                  disabled={isLoading}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="field-icon-right"
                  aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {/* Action Row: Ghi nhớ đăng nhập + Quên mật khẩu? */}
            <div className="auth-action-row">
              <label className="remember-checkbox-label">
                <input
                  type="checkbox"
                  checked={rememberMe}
                  onChange={(e) => setRememberMe(e.target.checked)}
                  className="custom-checkbox"
                />
                <span>Ghi nhớ đăng nhập</span>
              </label>

              <button
                type="button"
                onClick={() => alert('Vui lòng sử dụng tính năng Đặt lại mật khẩu trên ứng dụng di động hoặc liên hệ Quản trị viên.')}
                className="forgot-link-btn"
              >
                Quên mật khẩu?
              </button>
            </div>

            {/* Button Submit: Đỏ hồng như TikTok */}
            <button
              id="btn-login-submit"
              type="submit"
              className="btn-tiktok-primary"
              disabled={isLoading}
            >
              <span>{isLoading ? 'Đang đăng nhập...' : 'Đăng nhập'}</span>
              {!isLoading && <ArrowRight size={18} className="btn-arrow" />}
            </button>
          </form>
        ) : (
          /* ================= FORM: ĐĂNG KÝ ================= */
          <form onSubmit={handleRegisterSubmit} className="auth-form">
            {/* Field: Tên đăng nhập */}
            <div className="auth-field-group">
              <label htmlFor="reg-username" className="auth-label">
                Tên đăng nhập
              </label>
              <div className="auth-input-wrapper">
                <UserIcon size={18} className="field-icon-left" />
                <input
                  id="reg-username"
                  type="text"
                  value={regUsername}
                  onChange={(e) => setRegUsername(e.target.value)}
                  placeholder="ví dụ: user123"
                  className="auth-input"
                  disabled={isLoading}
                  required
                />
              </div>
            </div>

            {/* Field: Email */}
            <div className="auth-field-group">
              <label htmlFor="reg-email" className="auth-label">
                Email
              </label>
              <div className="auth-input-wrapper">
                <Mail size={18} className="field-icon-left" />
                <input
                  id="reg-email"
                  type="email"
                  value={regEmail}
                  onChange={(e) => setRegEmail(e.target.value)}
                  placeholder="name@gmail.com"
                  className="auth-input"
                  disabled={isLoading}
                  required
                />
              </div>
            </div>

            {/* Field: Tên hiển thị (tuỳ chọn) */}
            <div className="auth-field-group">
              <label htmlFor="reg-displayname" className="auth-label">
                Tên hiển thị (tuỳ chọn)
              </label>
              <div className="auth-input-wrapper">
                <UserIcon size={18} className="field-icon-left" />
                <input
                  id="reg-displayname"
                  type="text"
                  value={regDisplayName}
                  onChange={(e) => setRegDisplayName(e.target.value)}
                  placeholder="ví dụ: Nguyễn Văn A"
                  className="auth-input"
                  disabled={isLoading}
                />
              </div>
            </div>

            {/* Field: Mật khẩu */}
            <div className="auth-field-group">
              <label htmlFor="reg-password" className="auth-label">
                Mật khẩu
              </label>
              <div className="auth-input-wrapper">
                <Lock size={18} className="field-icon-left" />
                <input
                  id="reg-password"
                  type={showPassword ? 'text' : 'password'}
                  value={regPassword}
                  onChange={(e) => setRegPassword(e.target.value)}
                  placeholder="Tối thiểu 8 ký tự"
                  className="auth-input"
                  disabled={isLoading}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword(!showPassword)}
                  className="field-icon-right"
                >
                  {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {/* Field: Xác nhận mật khẩu */}
            <div className="auth-field-group">
              <label htmlFor="reg-confirm-password" className="auth-label">
                Xác nhận mật khẩu
              </label>
              <div className="auth-input-wrapper">
                <Lock size={18} className="field-icon-left" />
                <input
                  id="reg-confirm-password"
                  type={showConfirmPassword ? 'text' : 'password'}
                  value={regConfirmPassword}
                  onChange={(e) => setRegConfirmPassword(e.target.value)}
                  placeholder="Nhập lại mật khẩu"
                  className="auth-input"
                  disabled={isLoading}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowConfirmPassword(!showConfirmPassword)}
                  className="field-icon-right"
                >
                  {showConfirmPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                </button>
              </div>
            </div>

            {/* Button Submit: Đăng ký */}
            <button
              id="btn-register-submit"
              type="submit"
              className="btn-tiktok-primary"
              disabled={isLoading}
            >
              <span>{isLoading ? 'Đang tạo tài khoản...' : 'Đăng ký'}</span>
              {!isLoading && <ArrowRight size={18} className="btn-arrow" />}
            </button>
          </form>
        )}

        {/* Divider: HOẶC TIẾP TỤC VỚI */}
        <div className="auth-divider">
          <div className="divider-line" />
          <span className="divider-text">HOẶC TIẾP TỤC VỚI</span>
          <div className="divider-line" />
        </div>

        {/* Google Login Button */}
        <button
          type="button"
          onClick={handleGoogleLogin}
          className="btn-google-pill"
        >
          {/* Official Google G Logo */}
          <svg className="google-icon" width="20" height="20" viewBox="0 0 24 24">
            <path
              fill="#4285F4"
              d="M22.56 12.25c0-.78-.07-1.53-.2-2.25H12v4.26h5.92c-.26 1.37-1.04 2.53-2.21 3.31v2.77h3.57c2.08-1.92 3.28-4.74 3.28-8.09z"
            />
            <path
              fill="#34A853"
              d="M12 23c2.97 0 5.46-.98 7.28-2.66l-3.57-2.77c-.98.66-2.23 1.06-3.71 1.06-2.86 0-5.29-1.93-6.16-4.53H2.18v2.84C3.99 20.53 7.7 23 12 23z"
            />
            <path
              fill="#FBBC05"
              d="M5.84 14.09c-.22-.66-.35-1.36-.35-2.09s.13-1.43.35-2.09V7.06H2.18C1.43 8.55 1 10.22 1 12s.43 3.45 1.18 4.94l2.85-2.22.81-.63z"
            />
            <path
              fill="#EA4335"
              d="M12 5.38c1.62 0 3.06.56 4.21 1.64l3.15-3.15C17.45 2.09 14.97 1 12 1 7.7 1 3.99 3.47 2.18 7.06l3.66 2.84c.87-2.6 3.3-4.52 6.16-4.52z"
            />
          </svg>
          <span className="google-text">Tiếp tục sử dụng dịch vụ bằng Google</span>
        </button>

        {/* Footer: Toggle Login / Register */}
        <div className="auth-footer">
          <span className="footer-switch-text">
            {isRegisterMode ? 'Đã có tài khoản? ' : 'Chưa có tài khoản? '}
          </span>
          <button
            type="button"
            onClick={() => {
              setIsRegisterMode(!isRegisterMode);
              setErrorMessage(null);
              setSuccessMessage(null);
            }}
            className="footer-highlight-link"
          >
            {isRegisterMode ? 'Đăng nhập ngay' : 'Đăng ký ngay'}
          </button>
        </div>

        {/* Development Quick-Fill helper chips */}
        <div className="demo-credentials-strip">
          <span>Điền nhanh:</span>
          <button
            type="button"
            onClick={handleFillAdmin}
            className="demo-chip-btn"
            title="Điền tài khoản Admin (admin / AdminPassword123@)"
          >
            <Check size={12} style={{ display: 'inline', marginRight: 4 }} />
            Admin
          </button>
          <button
            type="button"
            onClick={handleFillModerator}
            className="demo-chip-btn"
            style={{ color: '#f59e0b', borderColor: 'rgba(245, 158, 11, 0.3)' }}
            title="Điền tài khoản Moderator (moderator / ModeratorPassword123@)"
          >
            <Check size={12} style={{ display: 'inline', marginRight: 4 }} />
            Moderator
          </button>
        </div>

      </div>
    </div>
  );
};
