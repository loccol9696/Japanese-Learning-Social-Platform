import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { Sliders, Edit2, Sparkles, Save } from 'lucide-react';
import {
  getAllPlansAdmin,
  updatePlan,
  getTokenRate,
  updateTokenRate,
  type SubscriptionPlanItem
} from '../../services/adminService';
import type { AdminTabProps } from './types';

/** Tab cấu hình gói VIP & tỷ lệ quy đổi Token AI (chỉ ADMIN). */
export const PricingTab: React.FC<AdminTabProps> = ({ isActive, showToast, modalsSlot }) => {
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
    if (isActive) {
      loadPlans();
    }
  }, [isActive]);

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

  if (!isActive) return null;

  return (
    <>
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
      {modalsSlot && createPortal(
        <>
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
        </>,
        modalsSlot
      )}
    </>
  );
};
