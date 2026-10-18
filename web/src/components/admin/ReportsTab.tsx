import React from 'react';
import { AlertTriangle } from 'lucide-react';
import type { AdminTabProps } from './types';

/** Tab xử lý báo cáo vi phạm (ADMIN & MODERATOR). */
export const ReportsTab: React.FC<AdminTabProps> = ({ isActive }) => {

  if (!isActive) return null;

  return (
    <>
      <div style={{
        background: 'var(--admin-bg-surface)',
        border: '1px solid var(--admin-border)',
        borderRadius: '2px',
        padding: '2.5rem',
        textAlign: 'center',
        color: 'var(--admin-text-dim)'
      }}>
        <AlertTriangle size={36} color="#f59e0b" style={{ margin: '0 auto 1rem' }} />
        <h3 style={{ color: 'var(--admin-text-main)', marginBottom: '0.5rem' }}>Hệ Thống Khiếu Nại & Báo Cáo Nội Dung</h3>
        <p style={{ maxWidth: '480px', margin: '0 auto', fontSize: '0.85rem' }}>
          Hiện tại không có báo cáo vi phạm nào tồn đọng. Hệ thống sẽ tự động cập nhật khi có người dùng gắn cờ báo cáo video hoặc bình luận không lành mạnh.
        </p>
      </div>
    </>
  );
};
