import React, { useState } from 'react';
import { 
  User, 
  Lock, 
  ArrowRight, 
  Eye, 
  EyeOff, 
  AlertCircle,
  Volume2,
  BookmarkCheck,
  Check,
  Zap,
  Radio
} from 'lucide-react';
import { loginUser } from '../services/authService';
import type { UserProfile } from '../types/auth';
import './LoginForm.css';

interface LoginFormProps {
  onLoginSuccess: (user: UserProfile, token: string) => void;
}

export const LoginForm: React.FC<LoginFormProps> = ({ onLoginSuccess }) => {
  const [usernameOrEmail, setUsernameOrEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!usernameOrEmail.trim() || !password.trim()) {
      setErrorMessage('Vui lòng điền đầy đủ tài khoản và mật khẩu.');
      return;
    }

    setIsLoading(true);
    setErrorMessage(null);

    try {
      const data = await loginUser(usernameOrEmail, password);
      const userProfile: UserProfile = data.user || {
        username: usernameOrEmail,
        email: usernameOrEmail.includes('@') ? usernameOrEmail : `${usernameOrEmail}@jlsp.edu`,
        fullName: 'Học viên Nihongo',
        streakDays: 14,
        xp: 850,
        level: 'JLPT N3'
      };
      onLoginSuccess(userProfile, data.accessToken);
    } catch (err: any) {
      setErrorMessage(err.message || 'Xác thực không thành công. Hãy thử lại hoặc chọn tài khoản demo.');
    } finally {
      setIsLoading(false);
    }
  };

  const handleDemoFill = () => {
    setUsernameOrEmail('admin');
    setPassword('AdminPassword123@');
    setErrorMessage(null);
  };

  return (
    <div className="portal-viewport">
      {/* Split Stage Layout */}
      <div className="portal-split-grid">
        
        {/* Left Panel: High-Context Platform Showcase */}
        <aside className="portal-showcase-panel">
          <div className="showcase-content-wrapper">
            <header className="showcase-brand-header">
              <div className="brand-mark-block">
                <span className="brand-kanji-glyph">日</span>
                <span className="brand-wordmark">JLSP • Nihongo Hub</span>
              </div>
              <div className="live-status-pill">
                <span className="live-dot" />
                <span className="font-mono text-xs">v1.2.4-prod</span>
              </div>
            </header>

            <div className="showcase-hero-statement">
              <span className="eyebrow-slug">SOCIAL INTERACTION PLATFORM</span>
              <h1 className="hero-display-title">
                Học tiếng Nhật qua <br />
                <span className="hero-title-accent">ngữ cảnh thực tế.</span>
              </h1>
              <p className="hero-lead-text">
                Kết hợp trải nghiệm video ngắn tương tác, phụ đề Furigana theo thời gian thực và hệ thống phân tích phát âm AI.
              </p>
            </div>

            {/* Realistic Interactive Live Reel Simulation Card */}
            <div className="live-reel-preview-card">
              <div className="reel-card-inner">
                <div className="reel-top-bar">
                  <div className="creator-pill">
                    <img 
                      src="https://picsum.photos/seed/kenji82/80/80" 
                      alt="Sensei Kenji" 
                      className="creator-thumb" 
                    />
                    <div className="creator-info">
                      <span className="creator-title">Kenji Sensei</span>
                      <span className="creator-handle">@kenji_tokyo • N3 Daily</span>
                    </div>
                  </div>
                  <div className="audio-live-chip">
                    <Volume2 size={13} />
                    <span>Tokyo Slang</span>
                  </div>
                </div>

                {/* Subtitle Furigana Display */}
                <div className="subtitle-display-box">
                  <div className="japanese-furigana-line">
                    <ruby>朝<rt>asa</rt></ruby>が
                    <ruby>怖<rt>kowa</rt></ruby>くて
                    <ruby>起<rt>o</rt></ruby>きられない
                  </div>
                  <p className="vietnamese-translation">
                    "Tôi sợ buổi sáng đến mức không dậy nổi."
                  </p>
                </div>

                <div className="reel-metrics-bar">
                  <div className="metric-chip">
                    <Zap size={13} className="chip-icon accent-gold" />
                    <span className="font-mono">1,480 XP</span>
                  </div>
                  <div className="metric-chip">
                    <BookmarkCheck size={13} className="chip-icon accent-emerald" />
                    <span>Đã lưu 18 từ</span>
                  </div>
                </div>
              </div>
            </div>

            <footer className="showcase-bottom-footer">
              <div className="footer-stat-group">
                <div className="stat-unit">
                  <span className="stat-value font-mono">12,450+</span>
                  <span className="stat-name">Thẻ Flashcard</span>
                </div>
                <div className="stat-divider" />
                <div className="stat-unit">
                  <span className="stat-value font-mono">98.2%</span>
                  <span className="stat-name">Độ khớp âm thoại</span>
                </div>
              </div>
            </footer>
          </div>
        </aside>

        {/* Right Panel: Functional Minimalist Login Form */}
        <main className="portal-form-panel">
          <div className="form-card-container">
            
            <div className="form-header-group">
              <div className="badge-tag">
                <Radio size={12} className="tag-icon" />
                <span>CỔNG HỌC VIÊN CHÍNH THỨC</span>
              </div>
              <h2 className="panel-title">Đăng Nhập Tài Khoản</h2>
              <p className="panel-description">
                Nhập thông tin xác thực để đồng bộ tiến trình học tập trên nền tảng.
              </p>
            </div>

            {errorMessage && (
              <div className="alert-box error" role="alert">
                <AlertCircle size={16} className="alert-icon" />
                <span className="alert-message">{errorMessage}</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="entry-form">
              {/* Identity Field */}
              <div className="form-control-block">
                <label htmlFor="user-identity" className="control-label">
                  Tài khoản hoặc Địa chỉ Email
                </label>
                <div className="control-input-wrapper">
                  <div className="field-adornment left">
                    <User size={16} />
                  </div>
                  <input
                    id="user-identity"
                    type="text"
                    value={usernameOrEmail}
                    onChange={(e) => setUsernameOrEmail(e.target.value)}
                    placeholder="ví dụ: user1 hoặc email@domain.com"
                    className="text-input"
                    disabled={isLoading}
                    autoComplete="username"
                    required
                  />
                </div>
              </div>

              {/* Password Field */}
              <div className="form-control-block">
                <div className="label-with-action">
                  <label htmlFor="user-password" className="control-label">
                    Mật khẩu
                  </label>
                  <button 
                    type="button" 
                    onClick={() => alert('Vui lòng sử dụng tính năng Đặt lại mật khẩu trên ứng dụng di động Flutter hoặc liên hệ support@jlsp.edu')}
                    className="inline-action-btn"
                  >
                    Quên mật khẩu?
                  </button>
                </div>
                <div className="control-input-wrapper">
                  <div className="field-adornment left">
                    <Lock size={16} />
                  </div>
                  <input
                    id="user-password"
                    type={showPassword ? 'text' : 'password'}
                    value={password}
                    onChange={(e) => setPassword(e.target.value)}
                    placeholder="Nhập mật khẩu an toàn"
                    className="text-input"
                    disabled={isLoading}
                    autoComplete="current-password"
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="field-adornment right interactive"
                    aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                  >
                    {showPassword ? <EyeOff size={16} /> : <Eye size={16} />}
                  </button>
                </div>
              </div>

              {/* Primary Action Button */}
              <button
                id="btn-login-submit"
                type="submit"
                className="action-button primary-pill"
                disabled={isLoading}
              >
                <span className="btn-label">
                  {isLoading ? 'Đang xác thực thông tin...' : 'Tiếp tục truy cập'}
                </span>
                <span className="btn-icon-wrapper">
                  {isLoading ? (
                    <div className="loading-dots">
                      <span /><span /><span />
                    </div>
                  ) : (
                    <ArrowRight size={15} />
                  )}
                </span>
              </button>
            </form>

            {/* Production Utility: 1-Click Sandbox Credential */}
            <div className="sandbox-quick-fill">
              <div className="quick-fill-hint">
                <span className="hint-label">Môi trường kiểm thử:</span>
                <span className="hint-meta font-mono">admin / AdminPassword123@</span>
              </div>
              <button
                type="button"
                onClick={handleDemoFill}
                className="quick-fill-action-btn"
              >
                <Check size={13} />
                <span>Nạp mẫu</span>
              </button>
            </div>

            {/* Server Connectivity Info */}
            <div className="backend-linkage-row">
              <div className="indicator-led online" />
              <span className="linkage-text">
                Kết nối dịch vụ: <span className="font-mono">http://localhost:8080/api/auth</span>
              </span>
            </div>

          </div>
        </main>
      </div>
    </div>
  );
};
