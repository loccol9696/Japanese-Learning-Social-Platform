import type { DailyMetricDto } from '../../services/adminService';

// Các hàm vẽ biểu đồ dùng chung cho tab Thống kê (chuyển nguyên văn từ AdminDashboard).

// Helper render thanh tóm tắt chỉ số đỉnh cao / trung bình / tổng cộng
export const renderStatsStrip = (
  metrics: DailyMetricDto[] | null | undefined,
  formatVal: (val: number) => string,
  unitLabel: string = ''
) => {
  const list = metrics || [];
  const total = list.reduce((sum, d) => sum + d.value, 0);
  const peak = list.length > 0 ? Math.max(0, ...list.map(d => d.value)) : 0;
  const avg = list.length > 0 ? Math.round(total / list.length) : 0;

  return (
    <div className="chart-stat-strip">
      <div className="stat-chip">
        <span className="stat-chip-label">Tổng kỳ:</span>
        <span className="stat-chip-val">{formatVal(total)} {unitLabel}</span>
      </div>
      <div className="stat-chip">
        <span className="stat-chip-label">Đỉnh cao (Peak):</span>
        <span className="stat-chip-val">{formatVal(peak)} {unitLabel}</span>
      </div>
      <div className="stat-chip">
        <span className="stat-chip-label">Trung bình:</span>
        <span className="stat-chip-val">{formatVal(avg)} {unitLabel}</span>
      </div>
    </div>
  );
};

// Helper render đường cong Parabol (Cubic Bezier Spline) mượt mà cho biểu đồ
export const renderParabolicSpline = (
  metrics: { dateLabel: string; value: number }[] | undefined,
  color: string,
  gradientId: string,
  formatVal: (val: number) => string,
  isLoading: boolean = false
) => {
  if (isLoading) {
    return (
      <div className="curved-chart-container" style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>
        <span className="live-pulse-dot" style={{ display: 'inline-block', marginRight: 8 }} />
        Đang tải dữ liệu biểu đồ...
      </div>
    );
  }

  if (!metrics || metrics.length === 0) {
    return (
      <div className="curved-chart-container" style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>
        Chưa có dữ liệu thống kê (0)
      </div>
    );
  }

  const width = 640;
  const height = 210;
  const isDense = metrics.length > 14;
  const padX = isDense ? 22 : 40;
  const padY = 32;
  const chartW = width - 2 * padX;
  const chartH = height - 2 * padY;

  const maxVal = Math.max(1, ...metrics.map(m => m.value));

  // Calculate points (x, y)
  const points = metrics.map((m, idx) => {
    const x = padX + (idx / Math.max(1, metrics.length - 1)) * chartW;
    const y = (height - padY) - (m.value / maxVal) * chartH;
    return { x, y, label: m.dateLabel, value: m.value };
  });

  // Compute smooth cubic Bezier parabolic path
  let curvePath = `M ${points[0].x.toFixed(1)} ${points[0].y.toFixed(1)}`;
  if (points.length > 1) {
    for (let i = 0; i < points.length - 1; i++) {
      const p0 = points[i === 0 ? 0 : i - 1];
      const p1 = points[i];
      const p2 = points[i + 1];
      const p3 = points[i + 2 < points.length ? i + 2 : i + 1];

      // Smooth parabolic tangent
      const cp1x = p1.x + (p2.x - p0.x) / 5;
      const cp1y = Math.min(height - padY, Math.max(padY / 2, p1.y + (p2.y - p0.y) / 5));
      const cp2x = p2.x - (p3.x - p1.x) / 5;
      const cp2y = Math.min(height - padY, Math.max(padY / 2, p2.y - (p3.y - p1.y) / 5));

      curvePath += ` C ${cp1x.toFixed(1)} ${cp1y.toFixed(1)}, ${cp2x.toFixed(1)} ${cp2y.toFixed(1)}, ${p2.x.toFixed(1)} ${p2.y.toFixed(1)}`;
    }
  }

  const areaPath = `${curvePath} L ${points[points.length - 1].x.toFixed(1)} ${(height - padY).toFixed(1)} L ${points[0].x.toFixed(1)} ${(height - padY).toFixed(1)} Z`;

  return (
    <div className="curved-chart-container">
      <svg viewBox={`0 0 ${width} ${height}`} className="curved-chart-svg">
        <defs>
          <linearGradient id={gradientId} x1="0" y1="0" x2="0" y2="1">
            <stop offset="0%" stopColor={color} stopOpacity="0.4" />
            <stop offset="100%" stopColor={color} stopOpacity="0.0" />
          </linearGradient>
        </defs>

        {/* Guide grid lines */}
        <line x1={padX} y1={padY} x2={width - padX} y2={padY} stroke="var(--admin-border-subtle)" strokeDasharray="3 3" />
        <line x1={padX} y1={height / 2} x2={width - padX} y2={height / 2} stroke="var(--admin-border-subtle)" strokeDasharray="3 3" />
        <line x1={padX} y1={height - padY} x2={width - padX} y2={height - padY} stroke="var(--admin-border)" strokeWidth="1.5" />

        {/* Area Fill under curve */}
        <path d={areaPath} fill={`url(#${gradientId})`} />

        {/* Parabolic Curved Spline Line */}
        <path d={curvePath} fill="none" stroke={color} strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />

        {/* Nodes with Badges and Labels */}
        {points.map((pt, i) => {
          const valStr = formatVal(pt.value);
          const badgeW = Math.max(26, valStr.length * 7 + 10);
          const showLabel = !isDense || (i % 3 === 0) || (i === points.length - 1) || (pt.value > 0);
          const showBadge = !isDense || (pt.value > 0);

          return (
            <g key={i} className="chart-svg-node">
              <title>{`${pt.label}: ${valStr}`}</title>

              {/* Vertical hint line */}
              {pt.value > 0 && (
                <line
                  x1={pt.x}
                  y1={pt.y}
                  x2={pt.x}
                  y2={height - padY}
                  stroke={color}
                  strokeWidth="1"
                  strokeDasharray="2 2"
                  opacity="0.45"
                />
              )}

              {/* Point circle */}
              <circle
                cx={pt.x}
                cy={pt.y}
                r={pt.value > 0 ? (isDense ? 4.5 : 5.5) : (isDense ? 2.5 : 3.5)}
                fill="#ffffff"
                stroke={pt.value > 0 ? color : '#94a3b8'}
                strokeWidth="2.5"
              />

              {/* Badge Container */}
              {showBadge && (
                <>
                  <rect
                    x={pt.x - badgeW / 2}
                    y={Math.min(height - padY - 26, Math.max(6, pt.y - 25))}
                    width={badgeW}
                    height={18}
                    rx={3}
                    fill="#ffffff"
                    stroke={pt.value > 0 ? color : '#cbd5e1'}
                    strokeWidth="1.2"
                    className="chart-svg-badge-rect"
                  />
                  <text
                    x={pt.x}
                    y={Math.min(height - padY - 13, Math.max(19, pt.y - 12))}
                    textAnchor="middle"
                    className="chart-svg-badge-text"
                    fill={pt.value > 0 ? '#0f172a' : '#94a3b8'}
                  >
                    {valStr}
                  </text>
                </>
              )}

              {/* X Axis Label */}
              {showLabel && (
                <text x={pt.x} y={height - 10} textAnchor="middle" className="chart-svg-label">
                  {pt.label}
                </text>
              )}
            </g>
          );
        })}
      </svg>
    </div>
  );
};

// Helper render biểu đồ cột trực quan
export const renderBarChart = (
  metrics: { dateLabel: string; value: number }[] | undefined,
  colorClass: string,
  formatVal: (val: number) => string,
  isLoading: boolean = false
) => {
  if (isLoading) {
    return (
      <div className="chart-bars-wrap" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 210 }}>
        <span style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>Đang tải dữ liệu biểu đồ...</span>
      </div>
    );
  }

  if (!metrics || metrics.length === 0) {
    return (
      <div className="chart-bars-wrap" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', minHeight: 210 }}>
        <span style={{ color: 'var(--admin-text-dim)', fontSize: '0.85rem' }}>Chưa có dữ liệu (0)</span>
      </div>
    );
  }

  const maxVal = Math.max(1, ...metrics.map(t => t.value));
  const isDense = metrics.length > 14;

  return (
    <div className="chart-bars-wrap">
      {metrics.map((t, idx) => {
        const heightPct = t.value > 0 ? Math.max(10, (t.value / maxVal) * 85) : 3;
        const showLabel = !isDense || (idx % 3 === 0) || (idx === metrics.length - 1) || (t.value > 0);
        return (
          <div key={idx} className="chart-col-item">
            <div
              className={`chart-bar-rect ${colorClass} ${t.value === 0 ? 'is-zero' : ''}`}
              style={{
                height: `${heightPct}%`,
                animationDelay: `${idx * 20}ms`
              }}
              title={`${t.dateLabel}: ${formatVal(t.value)}`}
            >
              <span className="chart-bar-val-badge">
                {t.value > 0 ? formatVal(t.value) : (isDense ? '' : '0')}
              </span>
            </div>
            <span className="chart-col-label">{showLabel ? t.dateLabel : ''}</span>
          </div>
        );
      })}
    </div>
  );
};
