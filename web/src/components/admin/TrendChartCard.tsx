import React from 'react';
import type { DailyMetricDto } from '../../services/adminService';
import { renderBarChart, renderParabolicSpline, renderStatsStrip } from './charts';
import type { TrendPeriod } from './types';
import type { MetricTrend } from './useMetricTrend';

interface TrendChartCardProps {
  trend: MetricTrend;
  /** Dữ liệu dự phòng (từ API tổng quan) khi chưa tải xong dữ liệu riêng của biểu đồ. */
  fallback?: DailyMetricDto[];
  icon: React.ReactNode;
  title: string;
  subtitleSuffix: string;
  stripFormat: (val: number) => string;
  stripUnit?: string;
  splineColor: string;
  splineGradientId: string;
  splineFormat: (val: number) => string;
  barColorClass: string;
  barFormat: (val: number) => string;
}

export const TrendChartCard: React.FC<TrendChartCardProps> = ({
  trend,
  fallback,
  icon,
  title,
  subtitleSuffix,
  stripFormat,
  stripUnit,
  splineColor,
  splineGradientId,
  splineFormat,
  barColorClass,
  barFormat,
}) => {
  const { period, setPeriod, year, setYear, month, setMonth, isLoading, chartType, setChartType } = trend;
  const metrics = trend.data || fallback;

  return (
    <div className="chart-card">
      <div className="chart-card-header">
        <div className="chart-title-group">
          <div className="chart-title">
            {icon}
            <span>{title}</span>
          </div>
          <span className="chart-subtitle">
            {period === '7days' && '7 Ngày gần nhất'}
            {period === 'days_in_month' && `Từng ngày trong Tháng ${month}/${year}`}
            {period === 'month' && `12 Tháng trong Năm ${year}`}
            {period === 'year' && '5 Năm gần nhất (2022 - 2026)'}
            {subtitleSuffix}
          </span>
        </div>

        <div className="chart-card-toolbar">
          {/* Period Selector */}
          <select
            className="chart-mini-select"
            value={period}
            onChange={(e) => setPeriod(e.target.value as TrendPeriod)}
            title="Chọn kỳ hiển thị"
          >
            <option value="7days">7 Ngày gần nhất</option>
            <option value="days_in_month">Từng ngày trong tháng</option>
            <option value="month">12 Tháng trong năm</option>
            <option value="year">5 Năm gần nhất</option>
          </select>

          {/* Month Selector */}
          {period === 'days_in_month' && (
            <select
              className="chart-mini-select"
              value={month}
              onChange={(e) => setMonth(Number(e.target.value))}
              title="Chọn tháng"
            >
              {[1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].map(m => (
                <option key={m} value={m}>Tháng {m}</option>
              ))}
            </select>
          )}

          {/* Year Selector */}
          {(period === 'days_in_month' || period === 'month') && (
            <select
              className="chart-mini-select"
              value={year}
              onChange={(e) => setYear(Number(e.target.value))}
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
              className={`chart-view-btn ${chartType === 'spline' ? 'active' : ''}`}
              onClick={() => setChartType('spline')}
              title="Đường cong Parabol"
            >
              📈
            </button>
            <button
              type="button"
              className={`chart-view-btn ${chartType === 'bar' ? 'active' : ''}`}
              onClick={() => setChartType('bar')}
              title="Dạng Cột"
            >
              📊
            </button>
          </div>
        </div>
      </div>

      {/* Summary Stats Strip */}
      {renderStatsStrip(metrics, stripFormat, stripUnit)}

      {chartType === 'spline'
        ? renderParabolicSpline(metrics, splineColor, splineGradientId, splineFormat, isLoading)
        : renderBarChart(metrics, barColorClass, barFormat, isLoading)}
    </div>
  );
};
