import React, { useEffect, useState } from 'react';
import { createPortal } from 'react-dom';
import { Coins, PieChart, RefreshCw, TrendingUp, Users } from 'lucide-react';
import { getAdminAnalytics, type AdminAnalyticsData } from '../../services/adminService';
import { TrendChartCard } from './TrendChartCard';
import { useMetricTrend } from './useMetricTrend';
import type { AdminTabProps, TrendPeriod } from './types';

/** Tab thống kê nền tảng & biểu đồ phân tích (chỉ ADMIN). */
export const AnalyticsTab: React.FC<AdminTabProps> = ({ isActive, actionsSlot }) => {
  const [analyticsData, setAnalyticsData] = useState<AdminAnalyticsData | null>(null);
  const [isLoadingAnalytics, setIsLoadingAnalytics] = useState(false);

  // Mỗi biểu đồ chọn kỳ / tháng / năm độc lập
  const userTrend = useMetricTrend('user', isActive, 'Lỗi tải xu hướng học viên:');
  const tokenTrend = useMetricTrend('token', isActive, 'Lỗi tải xu hướng token:');
  const revTrend = useMetricTrend('revenue', isActive, 'Lỗi tải xu hướng doanh thu:');

  const loadAnalytics = async () => {
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

  useEffect(() => {
    if (isActive) {
      loadAnalytics();
    }
  }, [isActive]);

  // Đồng bộ nhanh thời gian cho tất cả biểu đồ cùng một lúc
  const applyQuickSync = (period: TrendPeriod, y: number = 2026, m: number = 10) => {
    userTrend.setRange(period, y, m);
    tokenTrend.setRange(period, y, m);
    revTrend.setRange(period, y, m);
  };

  if (!isActive) return null;

  return (
    <>
      {actionsSlot && createPortal(
        <button onClick={() => loadAnalytics()} className="btn-outline">
          <RefreshCw size={15} className={isLoadingAnalytics ? 'spin' : ''} />
          <span>Làm mới Thống kê</span>
        </button>,
        actionsSlot
      )}
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
          <TrendChartCard
            trend={userTrend}
            fallback={analyticsData?.userRegistrationTrends}
            icon={<Users size={18} style={{ color: 'var(--admin-primary)' }} />}
            title="Học Viên Đăng Ký (Chỉ tính role USER)"
            subtitleSuffix=" • Loại trừ 100% Admin & Moderator"
            stripFormat={val => `${val}`}
            stripUnit="học viên"
            splineColor="#0284c7"
            splineGradientId="grad-user-spline"
            splineFormat={val => `${val}`}
            barColorClass=""
            barFormat={val => `${val}`}
          />

          {/* Biểu đồ 2: Tổng Lượng Token User Dùng */}
          <TrendChartCard
            trend={tokenTrend}
            fallback={analyticsData?.tokenUsageTrends}
            icon={<Coins size={18} style={{ color: 'var(--admin-success)' }} />}
            title="Tiêu Thụ Token AI (Speech-to-Text)"
            subtitleSuffix=" • Tổng lượng Token tiêu thụ thực tế"
            stripFormat={val => val.toLocaleString()}
            stripUnit="tokens"
            splineColor="#059669"
            splineGradientId="grad-token-spline"
            splineFormat={val => (val > 0 ? `${val.toLocaleString()}` : '0')}
            barColorClass="emerald"
            barFormat={val => `${val}`}
          />
        </div>

        {/* Biểu đồ 3: Tổng Doanh Thu Bán Gói & Cơ Cấu Gói */}
        <div className="analytics-charts-grid">
          {/* Doanh thu theo ngày/tháng/năm với đường cong Parabol */}
          <TrendChartCard
            trend={revTrend}
            fallback={analyticsData?.revenueTrends}
            icon={<TrendingUp size={18} style={{ color: 'var(--admin-primary-hover)' }} />}
            title="Doanh Thu Gói VIP (Đường Cong Parabol)"
            subtitleSuffix=" • Đơn hàng thanh toán thành công thực tế (VND)"
            stripFormat={val => `${val.toLocaleString('vi-VN')} đ`}
            splineColor="#d97706"
            splineGradientId="grad-rev-spline"
            splineFormat={val => (val > 0 ? `${(val / 1000).toFixed(0)}k` : '0đ')}
            barColorClass="amber"
            barFormat={val => (val > 0 ? `${(val / 1000).toFixed(0)}k` : '0đ')}
          />

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
    </>
  );
};
