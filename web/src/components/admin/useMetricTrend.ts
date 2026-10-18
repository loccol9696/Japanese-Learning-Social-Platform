import { useEffect, useState } from 'react';
import { getMetricTrend, type DailyMetricDto } from '../../services/adminService';
import type { TrendPeriod } from './types';

type Metric = 'user' | 'token' | 'revenue';

/** State + tải dữ liệu cho một biểu đồ xu hướng (mỗi biểu đồ chọn kỳ/tháng/năm độc lập). */
export function useMetricTrend(metric: Metric, isActive: boolean, errorLabel: string) {
  const [period, setPeriod] = useState<TrendPeriod>('days_in_month');
  const [year, setYear] = useState<number>(2026);
  const [month, setMonth] = useState<number>(10);
  const [data, setData] = useState<DailyMetricDto[] | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(false);
  const [chartType, setChartType] = useState<'spline' | 'bar'>('spline');

  useEffect(() => {
    if (!isActive) return;
    const fetchTrend = async () => {
      setIsLoading(true);
      try {
        setData(await getMetricTrend(metric, period, year, month));
      } catch (err) {
        console.error(errorLabel, err);
      } finally {
        setIsLoading(false);
      }
    };
    fetchTrend();
  }, [metric, errorLabel, isActive, period, year, month]);

  /** Đặt cùng lúc kỳ/năm/tháng (dùng cho "Đồng bộ nhanh tất cả biểu đồ"). */
  const setRange = (p: TrendPeriod, y: number, m: number) => {
    setPeriod(p);
    setYear(y);
    setMonth(m);
  };

  return { period, setPeriod, year, setYear, month, setMonth, data, isLoading, chartType, setChartType, setRange };
}

export type MetricTrend = ReturnType<typeof useMetricTrend>;
