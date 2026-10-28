import { useCallback, useEffect, useRef, useState } from 'react';
import { CheckCircle2, ChevronLeft, ChevronRight, XCircle } from 'lucide-react';
import {
  dismissReport,
  getReports,
  resolveReport,
  type PageResponse,
  type ReportAction,
  type ReportItem,
  type ReportStatus,
  type ReportTargetType,
} from '../services/adminService';

interface ReportsManagerProps {
  isAdmin: boolean;
  showToast: (message: string) => void;
}

const REASON_LABEL: Record<string, string> = {
  SPAM: 'Spam / quảng cáo',
  INAPPROPRIATE: 'Nội dung không phù hợp',
  HARASSMENT: 'Quấy rối / thù ghét',
  MISINFORMATION: 'Thông tin sai lệch',
  COPYRIGHT: 'Vi phạm bản quyền',
  OTHER: 'Lý do khác',
};

const TARGET_LABEL: Record<ReportTargetType, string> = {
  VIDEO: 'Video',
  COMMENT: 'Bình luận',
  USER: 'Người dùng',
};

const ACTION_LABEL: Record<ReportAction, string> = {
  NONE: 'Đã nhắc nhở / không cần hành động',
  HIDE_VIDEO: 'Ẩn video (từ chối khỏi feed)',
  DELETE_COMMENT: 'Xóa bình luận',
  LOCK_USER: 'Khóa tài khoản chủ nội dung',
};

const STATUS_TABS: { key: ReportStatus; label: string }[] = [
  { key: 'PENDING', label: 'Chờ xử lý' },
  { key: 'RESOLVED', label: 'Đã xử lý' },
  { key: 'DISMISSED', label: 'Đã bác bỏ' },
];

/** Hành động khả dụng cho từng loại đối tượng; khóa tài khoản chỉ Admin. */
function actionsFor(type: ReportTargetType, isAdmin: boolean): ReportAction[] {
  const actions: ReportAction[] = ['NONE'];
  if (type === 'VIDEO') actions.push('HIDE_VIDEO');
  if (type === 'COMMENT') actions.push('DELETE_COMMENT');
  if (isAdmin) actions.push('LOCK_USER');
  return actions;
}

export default function ReportsManager({ isAdmin, showToast: showToastProp }: ReportsManagerProps) {
  // Cha truyền hàm mới mỗi lần render; giữ trong ref để không kích hoạt tải lại liên tục.
  const toastRef = useRef(showToastProp);
  useEffect(() => {
    toastRef.current = showToastProp;
  });
  const showToast = useCallback((message: string) => toastRef.current(message), []);

  const [status, setStatus] = useState<ReportStatus>('PENDING');
  const [targetType, setTargetType] = useState<ReportTargetType | ''>('');
  const [page, setPage] = useState(0);
  const [data, setData] = useState<PageResponse<ReportItem> | null>(null);
  const [isLoading, setIsLoading] = useState(true);

  const [active, setActive] = useState<ReportItem | null>(null);
  const [action, setAction] = useState<ReportAction>('NONE');
  const [note, setNote] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const load = useCallback(async () => {
    setIsLoading(true);
    try {
      setData(await getReports(status, targetType, page));
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể tải danh sách báo cáo');
    } finally {
      setIsLoading(false);
    }
  }, [status, targetType, page, showToast]);

  useEffect(() => {
    load();
  }, [load]);

  const openDialog = (report: ReportItem) => {
    setActive(report);
    setAction('NONE');
    setNote('');
  };

  const submit = async (mode: 'resolve' | 'dismiss') => {
    if (!active) return;
    setIsSubmitting(true);
    try {
      if (mode === 'resolve') {
        await resolveReport(active.id, action, note);
        showToast('Đã xử lý báo cáo');
      } else {
        await dismissReport(active.id, note);
        showToast('Đã bác bỏ báo cáo');
      }
      setActive(null);
      await load();
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể xử lý báo cáo');
    } finally {
      setIsSubmitting(false);
    }
  };

  const reports = data?.content ?? [];

  return (
    <div>
      <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', marginBottom: '1rem', flexWrap: 'wrap' }}>
        {STATUS_TABS.map(tab => (
          <button
            key={tab.key}
            className={`btn-outline ${status === tab.key ? 'btn-solid-primary' : ''}`}
            onClick={() => {
              setStatus(tab.key);
              setPage(0);
            }}
          >
            {tab.label}
          </button>
        ))}
        <select
          className="form-input-sharp"
          style={{ maxWidth: '180px', marginLeft: 'auto' }}
          value={targetType}
          onChange={e => {
            setTargetType(e.target.value as ReportTargetType | '');
            setPage(0);
          }}
        >
          <option value="">Mọi loại đối tượng</option>
          <option value="VIDEO">Video</option>
          <option value="COMMENT">Bình luận</option>
          <option value="USER">Người dùng</option>
        </select>
      </div>

      <div className="data-table-container">
        <table className="enterprise-table">
          <thead>
            <tr>
              <th>Đối tượng</th>
              <th>Lý do</th>
              <th>Người báo cáo</th>
              <th>Thời gian</th>
              <th>{status === 'PENDING' ? 'Số báo cáo' : 'Kết quả'}</th>
              {status === 'PENDING' && <th style={{ textAlign: 'right' }}>Thao tác</th>}
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8' }}>
                  Đang tải danh sách báo cáo...
                </td>
              </tr>
            ) : reports.length === 0 ? (
              <tr>
                <td colSpan={6} style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8' }}>
                  Không có báo cáo nào.
                </td>
              </tr>
            ) : (
              reports.map(r => (
                <tr key={r.id}>
                  <td>
                    <div style={{ fontWeight: 600 }}>
                      {TARGET_LABEL[r.targetType]} #{r.targetId}
                      {!r.targetExists && (
                        <span className="status-pill danger" style={{ marginLeft: '0.5rem' }}>
                          Đã bị xóa
                        </span>
                      )}
                    </div>
                    <div style={{ fontSize: '0.8rem', color: '#94a3b8', maxWidth: '320px' }}>
                      {r.targetSummary || '—'}
                    </div>
                    {r.targetOwnerUsername && r.targetType !== 'USER' && (
                      <div style={{ fontSize: '0.75rem', color: '#64748b' }}>
                        Chủ nội dung: @{r.targetOwnerUsername}
                      </div>
                    )}
                  </td>
                  <td>
                    <div>{REASON_LABEL[r.reason] ?? r.reason}</div>
                    {r.detail && (
                      <div style={{ fontSize: '0.8rem', color: '#94a3b8', maxWidth: '260px' }}>{r.detail}</div>
                    )}
                  </td>
                  <td>@{r.reporterUsername}</td>
                  <td style={{ fontSize: '0.8rem', color: '#94a3b8' }}>
                    {new Date(r.createdAt).toLocaleString('vi-VN')}
                  </td>
                  <td>
                    {status === 'PENDING' ? (
                      <span className={`status-pill ${r.pendingCountForTarget > 1 ? 'warning' : 'info'}`}>
                        {r.pendingCountForTarget}
                      </span>
                    ) : (
                      <div style={{ fontSize: '0.8rem' }}>
                        <span className={`status-pill ${r.status === 'RESOLVED' ? 'success' : 'info'}`}>
                          {r.status === 'RESOLVED' ? (r.action ? ACTION_LABEL[r.action] : 'Đã xử lý') : 'Bác bỏ'}
                        </span>
                        {r.resolutionNote && (
                          <div style={{ color: '#94a3b8', marginTop: '0.25rem' }}>{r.resolutionNote}</div>
                        )}
                      </div>
                    )}
                  </td>
                  {status === 'PENDING' && (
                    <td style={{ textAlign: 'right' }}>
                      <button className="btn-solid-primary" onClick={() => openDialog(r)}>
                        Xử lý
                      </button>
                    </td>
                  )}
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>

      {data && data.totalPages > 1 && (
        <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center', justifyContent: 'flex-end', marginTop: '1rem' }}>
          <span style={{ fontSize: '0.8rem', color: '#94a3b8' }}>
            Trang {data.page + 1}/{data.totalPages} • {data.totalElements} báo cáo
          </span>
          <button className="btn-outline" disabled={page === 0} onClick={() => setPage(p => p - 1)}>
            <ChevronLeft size={14} />
          </button>
          <button className="btn-outline" disabled={data.last} onClick={() => setPage(p => p + 1)}>
            <ChevronRight size={14} />
          </button>
        </div>
      )}

      {active && (
        <div
          role="dialog"
          aria-modal="true"
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0,0,0,0.55)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
          }}
          onClick={() => !isSubmitting && setActive(null)}
        >
          <div
            style={{
              background: 'var(--admin-bg-surface)',
              border: '1px solid var(--admin-border)',
              padding: '1.5rem',
              width: 'min(520px, 92vw)',
            }}
            onClick={e => e.stopPropagation()}
          >
            <h3 style={{ marginBottom: '0.25rem' }}>
              Xử lý báo cáo {TARGET_LABEL[active.targetType].toLowerCase()} #{active.targetId}
            </h3>
            <p style={{ fontSize: '0.8rem', color: '#94a3b8', marginBottom: '1rem' }}>
              {active.pendingCountForTarget > 1
                ? `Kết quả áp dụng cho cả ${active.pendingCountForTarget} báo cáo đang chờ về đối tượng này.`
                : 'Kết quả áp dụng cho báo cáo này.'}
            </p>

            <div className="form-group-sharp">
              <label className="form-label-sharp">Hành động</label>
              {actionsFor(active.targetType, isAdmin).map(a => (
                <label key={a} style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', margin: '0.35rem 0' }}>
                  <input type="radio" name="report-action" checked={action === a} onChange={() => setAction(a)} />
                  <span>{ACTION_LABEL[a]}</span>
                </label>
              ))}
            </div>

            <div className="form-group-sharp">
              <label className="form-label-sharp">Ghi chú (tuỳ chọn)</label>
              <textarea
                className="form-input-sharp"
                rows={3}
                maxLength={500}
                value={note}
                onChange={e => setNote(e.target.value)}
              />
            </div>

            <div style={{ display: 'flex', gap: '0.5rem', justifyContent: 'flex-end', marginTop: '1rem' }}>
              <button className="btn-outline" disabled={isSubmitting} onClick={() => setActive(null)}>
                Đóng
              </button>
              <button className="btn-danger" disabled={isSubmitting} onClick={() => submit('dismiss')}>
                <XCircle size={14} />
                <span>Bác bỏ</span>
              </button>
              <button className="btn-success" disabled={isSubmitting} onClick={() => submit('resolve')}>
                <CheckCircle2 size={14} />
                <span>Xác nhận xử lý</span>
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
