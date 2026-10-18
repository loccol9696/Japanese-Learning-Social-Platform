/** Props chung cho mỗi tab của AdminDashboard. */
export interface AdminTabProps {
  /** Tab đang được chọn. Tab luôn được mount để giữ state khi chuyển tab, nhưng chỉ render khi active. */
  isActive: boolean;
  showToast: (msg: string) => void;
  /** Vùng nút hành động trên header (`.top-bar-right`) - tab render nút của mình vào đây qua portal. */
  actionsSlot: HTMLElement | null;
  /** Gốc `.admin-viewport` - modal của tab được portal vào đây (đúng vị trí cũ, sau `<main>`). */
  modalsSlot: HTMLElement | null;
}

export type TrendPeriod = '7days' | 'days_in_month' | 'month' | 'year';
