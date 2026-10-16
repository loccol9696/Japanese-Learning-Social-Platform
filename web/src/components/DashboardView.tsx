import type { UserProfile } from '../types/auth';
import { 
  LogOut, 
  Flame, 
  Sparkles, 
  Trophy, 
  BookOpen, 
  Video, 
  Layers, 
  ExternalLink,
  ShieldCheck
} from 'lucide-react';
import './DashboardView.css';

interface DashboardViewProps {
  user: UserProfile;
  onLogout: () => void;
}

export const DashboardView: React.FC<DashboardViewProps> = ({ user, onLogout }) => {
  return (
    <div className="dashboard-container">
      {/* Top Floating Glass Navigation */}
      <header className="dashboard-nav">
        <div className="brand-badge">
          <span className="brand-kanji">日本語</span>
          <span className="brand-text">JLSP HUB</span>
        </div>

        <div className="nav-user-island">
          <div className="avatar-chip">
            <div className="avatar-img">
              {user.avatarUrl ? (
                <img src={user.avatarUrl} alt={user.fullName || user.username} />
              ) : (
                <span>{(user.fullName || user.username || 'U').charAt(0).toUpperCase()}</span>
              )}
            </div>
            <div className="user-meta">
              <span className="user-name">{user.fullName || user.username}</span>
              <span className="user-email">{user.email}</span>
            </div>
          </div>

          <button 
            id="btn-logout"
            onClick={onLogout} 
            className="logout-button"
            title="Đăng xuất khỏi tài khoản"
          >
            <span>Đăng xuất</span>
            <div className="icon-disc">
              <LogOut size={15} />
            </div>
          </button>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="dashboard-content">
        {/* Welcome Hero Banner - Double Bezel Structure */}
        <section className="hero-bezel-outer">
          <div className="hero-bezel-inner">
            <div className="hero-decor-orb" />
            
            <div className="hero-text-block">
              <div className="status-pill">
                <span className="status-dot"></span>
                <span>Tài khoản đã xác thực</span>
                <ShieldCheck size={14} className="pill-icon" />
              </div>

              <h1 className="hero-heading">
                Chào mừng trở lại, <br />
                <span className="gradient-highlight">{user.fullName || user.username}</span>
                <span className="greeting-jp">おかえり!</span>
              </h1>

              <p className="hero-subtext">
                Hôm nay là một ngày tuyệt vời để bứt phá thêm 20 từ vựng và luyện phản xạ nghe qua video ngắn đời sống Nhật Bản.
              </p>
            </div>

            {/* Quick Metrics Bento */}
            <div className="quick-metrics-grid">
              <div className="metric-card">
                <div className="metric-icon-box flame">
                  <Flame size={20} />
                </div>
                <div className="metric-data">
                  <span className="metric-value">{user.streakDays || 7} <small>ngày</small></span>
                  <span className="metric-label">Chuỗi học tập</span>
                </div>
              </div>

              <div className="metric-card">
                <div className="metric-icon-box gold">
                  <Trophy size={20} />
                </div>
                <div className="metric-data">
                  <span className="metric-value">{user.xp || 350} <small>XP</small></span>
                  <span className="metric-label">Điểm tích lũy</span>
                </div>
              </div>

              <div className="metric-card">
                <div className="metric-icon-box indigo">
                  <Sparkles size={20} />
                </div>
                <div className="metric-data">
                  <span className="metric-value">{user.level || 'JLPT N4'}</span>
                  <span className="metric-label">Mục tiêu hiện tại</span>
                </div>
              </div>
            </div>
          </div>
        </section>

        {/* Feature Hub Showcase */}
        <section className="features-section">
          <div className="section-header">
            <span className="section-eyebrow">MODULES</span>
            <h2 className="section-title">Không gian học tập tương tác</h2>
          </div>

          <div className="features-grid">
            <div className="feature-bento-card">
              <div className="feature-card-header">
                <div className="feature-icon video">
                  <Video size={22} />
                </div>
                <span className="badge-new">Phổ biến</span>
              </div>
              <h3 className="feature-card-title">Feed Video Ngắn</h3>
              <p className="feature-card-desc">
                Lướt video reels hội thoại thực tế từ Tokyo & Kansai kèm phụ đề Furigana và phân tích ngữ pháp tức thì.
              </p>
              <div className="feature-footer">
                <span className="feature-cta">Đang kết nối Flutter App <ExternalLink size={14} /></span>
              </div>
            </div>

            <div className="feature-bento-card">
              <div className="feature-card-header">
                <div className="feature-icon flashcard">
                  <Layers size={22} />
                </div>
                <span className="badge-ready">Sẵn sàng</span>
              </div>
              <h3 className="feature-card-title">Bộ Flashcard Thông Minh</h3>
              <p className="feature-card-desc">
                Thuật toán lặp lại ngắt quãng (Spaced Repetition) lưu trữ từ vựng ngay khi xem video để ôn tập hàng ngày.
              </p>
              <div className="feature-footer">
                <span className="feature-cta">Xem bộ thẻ đã lưu <ExternalLink size={14} /></span>
              </div>
            </div>

            <div className="feature-bento-card">
              <div className="feature-card-header">
                <div className="feature-icon shadowing">
                  <BookOpen size={22} />
                </div>
                <span className="badge-ai">AI Vocal Service</span>
              </div>
              <h3 className="feature-card-title">Luyện Nói Shadowing</h3>
              <p className="feature-card-desc">
                Hệ thống nhận diện giọng nói tiếng Nhật và tách vocal AI so sánh cao độ, chấm điểm phát âm chính xác.
              </p>
              <div className="feature-footer">
                <span className="feature-cta">Khám phá bài học <ExternalLink size={14} /></span>
              </div>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
};
