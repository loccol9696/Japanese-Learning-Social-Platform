import { useCallback, useEffect, useRef, useState } from 'react';
import { CheckCircle2, ChevronLeft, ChevronRight, XCircle } from 'lucide-react';
import {
  dismissReport,
  getReports,
  resolveReport,
  type PageResponse,
  type ReportAction,
  type ReportCorrection,
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
  INACCURATE: 'Dịch / giải thích sai',
  OTHER: 'Lý do khác',
};

const TARGET_LABEL: Record<ReportTargetType, string> = {
  VIDEO: 'Video',
  COMMENT: 'Bình luận',
  USER: 'Người dùng',
  MESSAGE: 'Tin nhắn',
  TRANSLATION: 'Bản dịch',
  GRAMMAR: 'Ngữ pháp',
};

const ACTION_LABEL: Record<ReportAction, string> = {
  NONE: 'Không cần hành động',
  WARN_USER: 'Nhắc nhở (gửi lý do vi phạm, +1 lần vi phạm)',
  HIDE_VIDEO: 'Ẩn video (từ chối khỏi feed)',
  DELETE_COMMENT: 'Xóa bình luận',
  HIDE_MESSAGE: 'Gỡ tin nhắn',
  EDIT_TRANSLATION: 'Sửa bản dịch',
  REMOVE_TRANSLATION: 'Gỡ bản dịch của câu này',
  EDIT_GRAMMAR: 'Sửa mẫu ngữ pháp',
  REMOVE_GRAMMAR: 'Gỡ mẫu ngữ pháp này',
  LOCK_USER: 'Khóa tài khoản chủ nội dung',
};

/** Hành động gỡ nội dung của từng loại đối tượng. */
const REMOVAL_ACTION: Partial<Record<ReportTargetType, ReportAction>> = {
  VIDEO: 'HIDE_VIDEO',
  COMMENT: 'DELETE_COMMENT',
  MESSAGE: 'HIDE_MESSAGE',
  TRANSLATION: 'REMOVE_TRANSLATION',
  GRAMMAR: 'REMOVE_GRAMMAR',
};

const STATUS_TABS: { key: ReportStatus; label: string }[] = [
  { key: 'PENDING', label: 'Chờ xử lý' },
  { key: 'RESOLVED', label: 'Đã xử lý' },
  { key: 'DISMISSED', label: 'Đã bác bỏ' },
];

/** Hành động sửa nội dung của từng loại đối tượng. */
const EDIT_ACTION: Partial<Record<ReportTargetType, ReportAction>> = {
  TRANSLATION: 'EDIT_TRANSLATION',
  GRAMMAR: 'EDIT_GRAMMAR',
};

/** Hành động khả dụng cho một báo cáo; khóa tài khoản chỉ Admin, nội dung đã đổi thì không sửa được. */
function actionsFor(report: ReportItem, isAdmin: boolean): ReportAction[] {
  const actions: ReportAction[] = [];
  if (report.targetOwnerId != null) actions.push('WARN_USER');
  const edit = EDIT_ACTION[report.targetType];
  if (edit && report.targetExists) actions.push(edit);
  const removal = REMOVAL_ACTION[report.targetType];
  if (removal) actions.push(removal);
  if (isAdmin && report.targetOwnerId != null) actions.push('LOCK_USER');
  return actions.length > 0 ? actions : ['NONE'];
}

/** Đủ thông tin để xác nhận chưa: sửa thì phải nhập các trường bắt buộc. */
function isCorrectionComplete(action: ReportAction, correction: ReportCorrection): boolean {
  if (action === 'EDIT_TRANSLATION') return !!correction.translation?.trim();
  if (action === 'EDIT_GRAMMAR') return !!correction.pattern?.trim() && !!correction.meaning?.trim();
  return true;
}

/** Bản dịch/ngữ pháp có thể bị chủ video sửa, không hẳn đã bị xóa. */
function goneLabel(type: ReportTargetType): string {
  return type === 'TRANSLATION' || type === 'GRAMMAR' ? 'Đã thay đổi' : 'Đã bị xóa';
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
  const [correction, setCorrection] = useState<ReportCorrection>({});
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
    setAction(actionsFor(report, isAdmin)[0]);
    setNote('');
    setCorrection(report.targetContent ?? {});
  };

  const updateCorrection = (patch: ReportCorrection) => setCorrection(current => ({ ...current, ...patch }));

  const submit = async (mode: 'resolve' | 'dismiss') => {
    if (!active) return;
    setIsSubmitting(true);
    try {
      if (mode === 'resolve') {
        const isEdit = action === 'EDIT_TRANSLATION' || action === 'EDIT_GRAMMAR';
        await resolveReport(active.id, action, note, isEdit ? correction : undefined);
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
          <option value="MESSAGE">Tin nhắn</option>
          <option value="TRANSLATION">Bản dịch</option>
          <option value="GRAMMAR">Ngữ pháp</option>
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
                          {goneLabel(r.targetType)}
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
                      <span className={`status-pill ${(r.pendingCountForTarget ?? 0) > 1 ? 'warning' : 'info'}`} style={{ marginTop: '20px' }}>
                        {r.pendingCountForTarget ?? 1}
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
              maxHeight: '90vh',
              overflowY: 'auto',
            }}
            onClick={e => e.stopPropagation()}
          >
            <h3 style={{ marginBottom: '0.25rem' }}>
              Xử lý báo cáo {TARGET_LABEL[active.targetType].toLowerCase()} #{active.targetId}
            </h3>
            <p style={{ fontSize: '0.8rem', color: '#94a3b8', marginBottom: '1rem' }}>
              {(active.pendingCountForTarget ?? 0) > 1
                ? `Kết quả áp dụng cho cả ${active.pendingCountForTarget} báo cáo đang chờ về đối tượng này.`
                : 'Kết quả áp dụng cho báo cáo này.'}
            </p>

            {active.targetOwnerUsername && (
              <p style={{ fontSize: '0.8rem', marginBottom: '1rem' }}>
                Chủ nội dung: @{active.targetOwnerUsername} • {active.targetOwnerViolationCount ?? 0} lần vi phạm
              </p>
            )}

            {active.targetVideoUrl && (
              <video
                src={active.targetVideoUrl}
                controls
                preload="metadata"
                style={{ width: '100%', maxHeight: '240px', background: '#000', marginBottom: '0.75rem' }}
              />
            )}

            {(active.targetSnapshot || active.targetImageUrl) && (
              <div className="form-group-sharp">
                <label className="form-label-sharp">
                  Nội dung bị báo cáo{active.targetExists ? '' : ` (${goneLabel(active.targetType).toLowerCase()})`}
                </label>
                {active.targetSnapshot && (
                  <div
                    style={{
                      whiteSpace: 'pre-wrap',
                      wordBreak: 'break-word',
                      maxHeight: '160px',
                      overflowY: 'auto',
                      fontSize: '0.85rem',
                      padding: '0.5rem',
                      border: '1px solid var(--admin-border)',
                    }}
                  >
                    {active.targetSnapshot}
                  </div>
                )}
                {active.targetImageUrl && (
                  <img
                    src={active.targetImageUrl}
                    alt="Ảnh trong tin nhắn bị báo cáo"
                    style={{ maxWidth: '100%', maxHeight: '240px', marginTop: '0.5rem' }}
                  />
                )}
              </div>
            )}

            <div className="form-group-sharp">
              <label className="form-label-sharp">Hành động</label>
              {actionsFor(active, isAdmin).map(a => (
                <label key={a} style={{ display: 'flex', gap: '0.5rem', alignItems: 'center', margin: '0.35rem 0' }}>
                  <input type="radio" name="report-action" checked={action === a} onChange={() => setAction(a)} />
                  <span>{ACTION_LABEL[a]}</span>
                </label>
              ))}
            </div>

            {action === 'EDIT_TRANSLATION' && (
              <div className="form-group-sharp">
                <label className="form-label-sharp">Bản dịch đã sửa</label>
                <textarea
                  className="form-input-sharp"
                  rows={3}
                  maxLength={1000}
                  value={correction.translation ?? ''}
                  onChange={e => updateCorrection({ translation: e.target.value })}
                />
              </div>
            )}

            {action === 'EDIT_GRAMMAR' && (
              <>
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Mẫu ngữ pháp</label>
                  <input
                    className="form-input-sharp"
                    maxLength={200}
                    value={correction.pattern ?? ''}
                    onChange={e => updateCorrection({ pattern: e.target.value })}
                  />
                </div>
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Ý nghĩa</label>
                  <input
                    className="form-input-sharp"
                    maxLength={500}
                    value={correction.meaning ?? ''}
                    onChange={e => updateCorrection({ meaning: e.target.value })}
                  />
                </div>
                <div className="form-group-sharp">
                  <label className="form-label-sharp">Giải thích</label>
                  <textarea
                    className="form-input-sharp"
                    rows={3}
                    maxLength={2000}
                    value={correction.explanation ?? ''}
                    onChange={e => updateCorrection({ explanation: e.target.value })}
                  />
                </div>
              </>
            )}

            <div className="form-group-sharp">
              <label className="form-label-sharp">
                Ghi chú (tuỳ chọn): gửi chủ nội dung khi xử lý, gửi người báo cáo khi bác bỏ
              </label>
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
              <button
                className="btn-success"
                disabled={isSubmitting || !isCorrectionComplete(action, correction)}
                onClick={() => submit('resolve')}
              >
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
