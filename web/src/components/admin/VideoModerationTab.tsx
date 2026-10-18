import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, ChevronRight, CheckCircle2, XCircle, RefreshCw, Shield, Eye, Play } from 'lucide-react';
import {
  getModerationVideos,
  approveVideo,
  rejectVideo,
  type VideoModerationItem
} from '../../services/adminService';
import type { AdminTabProps } from './types';

/** Tab duyệt video bài học (chỉ MODERATOR). */
export const VideoModerationTab: React.FC<AdminTabProps> = ({ isActive, showToast, modalsSlot }) => {
  // ==================== VIDEO MODERATION (MODERATOR ONLY) ====================
  const [videos, setVideos] = useState<VideoModerationItem[]>([]);
  const [videoModFilter, setVideoModFilter] = useState<'PENDING' | 'APPROVED' | 'REJECTED'>('PENDING');
  const [isLoadingVideos, setIsLoadingVideos] = useState(false);
  const [selectedRejectVideo, setSelectedRejectVideo] = useState<VideoModerationItem | null>(null);
  const [selectedDetailVideo, setSelectedDetailVideo] = useState<VideoModerationItem | null>(null);
  const [rejectReason, setRejectReason] = useState('Vi phạm bản quyền âm thanh / video');
  const [customRejectReason, setCustomRejectReason] = useState('');
  const [isSubmittingReject, setIsSubmittingReject] = useState(false);

  // Pagination for video moderation table (Limit 10 per page)
  const [videosPage, setVideosPage] = useState(0);
  const [videosTotalPages, setVideosTotalPages] = useState(1);
  const [videosTotalElements, setVideosTotalElements] = useState(0);

  const loadModerationVideos = async () => {
    setIsLoadingVideos(true);
    try {
      const data = await getModerationVideos(videoModFilter, videosPage, 10);
      setVideos(data.content || []);
      setVideosTotalPages(data.totalPages || 1);
      setVideosTotalElements(data.totalElements || 0);
    } catch (err: any) {
      console.error(err);
    } finally {
      setIsLoadingVideos(false);
    }
  };

  useEffect(() => {
    if (isActive) {
      loadModerationVideos();
    }
  }, [isActive, videoModFilter, videosPage]);

  const handleApproveVideo = async (videoId: number) => {
    try {
      await approveVideo(videoId);
      showToast('Đã phê duyệt video bài học thành công! Video đã chuyển sang mục Đã thông qua (APPROVED).');
      if (selectedDetailVideo && selectedDetailVideo.id === videoId) {
        setSelectedDetailVideo(null);
      }
      if (videoModFilter === 'PENDING') {
        setVideosPage(0);
        setVideoModFilter('APPROVED');
      } else {
        loadModerationVideos();
      }
    } catch (err: any) {
      alert('Lỗi phê duyệt: ' + err.message);
    }
  };

  const handleConfirmRejectVideo = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedRejectVideo) return;
    const finalReason = rejectReason === 'Lý do khác' ? customRejectReason.trim() : rejectReason;
    if (!finalReason) {
      alert('Vui lòng cung cấp lý do từ chối kiểm duyệt!');
      return;
    }

    setIsSubmittingReject(true);
    try {
      await rejectVideo(selectedRejectVideo.id, finalReason);
      showToast(`Đã từ chối video "${selectedRejectVideo.title}"! Đã chuyển sang mục Đã từ chối (REJECTED).`);
      if (selectedDetailVideo && selectedDetailVideo.id === selectedRejectVideo.id) {
        setSelectedDetailVideo(null);
      }
      setSelectedRejectVideo(null);
      setCustomRejectReason('');
      if (videoModFilter === 'PENDING') {
        setVideosPage(0);
        setVideoModFilter('REJECTED');
      } else {
        loadModerationVideos();
      }
    } catch (err: any) {
      alert('Lỗi từ chối video: ' + err.message);
    } finally {
      setIsSubmittingReject(false);
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
          gap: '0.75rem',
          marginBottom: '1rem'
        }}>
          <Shield size={18} style={{ color: 'var(--admin-primary)', flexShrink: 0 }} />
          <div>
            <strong>Quy chuẩn Kiểm duyệt:</strong> Moderator chỉ tiếp nhận và kiểm duyệt các video ở chế độ <strong>Công khai (PUBLIC)</strong> trước khi phát hành lên Bảng tin cộng đồng (For-You Feed). Các video riêng tư (PRIVATE) của học viên sẽ không đưa vào hàng đợi kiểm duyệt.
          </div>
        </div>

        <div className="toolbar-row">
          <div style={{ display: 'flex', gap: '0.5rem', flexWrap: 'wrap', alignItems: 'center' }}>
            <button
              className={`btn-outline ${videoModFilter === 'PENDING' ? 'btn-solid-primary' : ''}`}
              onClick={() => {
                setVideosPage(0);
                setVideoModFilter('PENDING');
              }}
            >
              Chờ duyệt (PENDING)
            </button>
            <button
              className={`btn-outline ${videoModFilter === 'APPROVED' ? 'btn-solid-primary' : ''}`}
              onClick={() => {
                setVideosPage(0);
                setVideoModFilter('APPROVED');
              }}
            >
              Đã thông qua (APPROVED)
            </button>
            <button
              className={`btn-outline ${videoModFilter === 'REJECTED' ? 'btn-solid-primary' : ''}`}
              onClick={() => {
                setVideosPage(0);
                setVideoModFilter('REJECTED');
              }}
            >
              Đã từ chối (REJECTED)
            </button>
          </div>

          <div style={{ display: 'flex', gap: '0.75rem', alignItems: 'center' }}>
            <span style={{ fontSize: '0.8rem', color: '#94a3b8', fontFamily: 'var(--font-mono)' }}>
              Tổng: {videosTotalElements} video
            </span>
            <button onClick={loadModerationVideos} className="btn-outline">
              <RefreshCw size={15} className={isLoadingVideos ? 'spin' : ''} />
              <span>Làm mới danh sách</span>
            </button>
          </div>
        </div>

        {isLoadingVideos ? (
          <div style={{ padding: '3rem', textAlign: 'center', color: '#94a3b8' }}>
            Đang tải danh sách video bài học từ server...
          </div>
        ) : videos.length === 0 ? (
          <div style={{
            padding: '3rem',
            textAlign: 'center',
            background: 'var(--admin-bg-surface)',
            border: '1px solid var(--admin-border)',
            borderRadius: '2px',
            color: 'var(--admin-text-muted)'
          }}>
            Không có video nào trong danh mục <strong>{videoModFilter}</strong>.
          </div>
        ) : (
          <>
            <div className="data-table-container">
              <table className="enterprise-table mod-table">
                <thead>
                  <tr>
                    <th style={{ width: '45px', textAlign: 'center' }}>ID</th>
                    <th style={{ width: '210px' }}>Video Bài Học</th>
                    <th style={{ width: '100px', textAlign: 'center' }}>Cấp độ</th>
                    <th style={{ width: '80px', textAlign: 'center' }}>Thời lượng</th>
                    <th style={{ width: '120px' }}>Người đăng</th>
                    <th style={{ width: '100px', textAlign: 'center' }}>Chế độ</th>
                    <th style={{ width: '90px', textAlign: 'center' }}>Ngày gửi</th>
                    <th style={{ width: '100px', textAlign: 'center' }}>Trạng thái</th>
                    <th style={{ width: '155px', textAlign: 'center' }}>Thao tác</th>
                  </tr>
                </thead>
                <tbody>
                  {videos.map(v => (
                    <tr
                      key={v.id}
                      className="clickable-row"
                      onClick={() => setSelectedDetailVideo(v)}
                      title="Click vào hàng để xem chi tiết video và phụ đề AI"
                    >
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                        <div className="mod-cell-center">
                          <span style={{ fontFamily: 'var(--font-mono)', fontWeight: 600, color: 'var(--admin-text-dim)' }}>
                            #{v.id}
                          </span>
                        </div>
                      </td>
                      <td style={{ verticalAlign: 'middle' }}>
                        <div className="mod-table-video-cell" style={{ minHeight: '44px', display: 'flex', alignItems: 'center' }}>
                          <div className="video-thumb-preview">
                            <img
                              src={v.thumbnailUrl}
                              alt={v.title}
                              onError={(e) => { (e.target as HTMLElement).style.display = 'none'; }}
                            />
                            <div className="video-thumb-play-overlay">
                              <Play size={11} color="#ffffff" fill="#ffffff" />
                            </div>
                          </div>
                          <div className="mod-table-video-info">
                            <strong className="mod-table-video-title" title={v.title}>
                              {v.title}
                            </strong>
                            {(() => {
                              let preview = '';
                              if (v.subtitles && v.subtitles !== '[]') {
                                try {
                                  const parsed = typeof v.subtitles === 'string' ? JSON.parse(v.subtitles) : v.subtitles;
                                  if (Array.isArray(parsed) && parsed.length > 0) {
                                    preview = parsed[0]?.text || parsed[0]?.translation || '';
                                  }
                                } catch {
                                  preview = v.subtitles;
                                }
                              }
                              if (!preview && v.description) preview = v.description;
                              if (!preview) return null;
                              return (
                                <span className="mod-table-video-subtitle" title={preview}>
                                  💬 {preview.length > 14 ? preview.substring(0, 14) + '...' : preview}
                                </span>
                              );
                            })()}
                          </div>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                        <div className="mod-cell-center">
                          <span className={`status-pill ${
                            v.jlptLevel === 'N1' ? 'danger' :
                            v.jlptLevel === 'N2' ? 'warning' :
                            v.jlptLevel === 'N3' ? 'info' : 'success'
                          }`}>
                            JLPT {v.jlptLevel || 'N5'}
                          </span>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                        <div className="mod-cell-center">
                          <span style={{ fontSize: '0.8rem', fontFamily: 'var(--font-mono)' }}>
                            {v.duration ? `${Math.floor(v.duration / 60)}m ${v.duration % 60}s` : '0s'}
                          </span>
                        </div>
                      </td>
                      <td style={{ verticalAlign: 'middle' }}>
                        <div className="mod-table-user-cell" style={{ minHeight: '44px', display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
                          <strong className="mod-table-user-name" title={v.creatorDisplayName || v.creatorUsername || 'Creator'}>
                            {v.creatorDisplayName || v.creatorUsername || v.user?.displayName || v.user?.username || 'Creator'}
                          </strong>
                          <span className="mod-table-user-handle">
                            @{v.creatorUsername || v.user?.username || 'creator'}
                          </span>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                        <div className="mod-cell-center">
                          <span className="status-pill info">
                            🌐 {v.status || 'PUBLIC'}
                          </span>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                        <div className="mod-cell-center">
                          <span style={{ fontSize: '0.78rem', color: 'var(--admin-text-dim)', whiteSpace: 'nowrap' }}>
                            {v.createdAt ? new Date(v.createdAt).toLocaleDateString('vi-VN') : '—'}
                          </span>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }}>
                        <div className="mod-cell-center">
                          <span className={`status-pill ${
                            v.modStatus === 'APPROVED' ? 'success' : v.modStatus === 'REJECTED' ? 'danger' : 'pending'
                          }`}>
                            {v.modStatus === 'APPROVED' ? 'ĐÃ DUYỆT' : v.modStatus === 'REJECTED' ? 'TỪ CHỐI' : 'CHỜ DUYỆT'}
                          </span>
                        </div>
                      </td>
                      <td style={{ textAlign: 'center', verticalAlign: 'middle' }} onClick={(e) => e.stopPropagation()}>
                        <div className="mod-cell-center" style={{ gap: '0.25rem' }}>
                          <button
                            onClick={() => setSelectedDetailVideo(v)}
                            className="btn-outline"
                            style={{ padding: '0 0.45rem', fontSize: '0.72rem', height: '26px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                            title="Xem chi tiết video và phụ đề"
                          >
                            <Eye size={12} />
                            <span>Chi tiết</span>
                          </button>

                          {v.modStatus === 'PENDING' && (
                            <>
                              <button
                                onClick={() => handleApproveVideo(v.id)}
                                className="btn-success"
                                style={{ padding: '0 0.45rem', fontSize: '0.72rem', height: '26px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                                title="Phê duyệt video công khai"
                              >
                                <CheckCircle2 size={12} />
                                <span>Duyệt</span>
                              </button>
                              <button
                                onClick={() => setSelectedRejectVideo(v)}
                                className="btn-danger"
                                style={{ padding: '0 0.45rem', fontSize: '0.72rem', height: '26px', display: 'inline-flex', alignItems: 'center', gap: '0.25rem' }}
                                title="Từ chối video vi phạm"
                              >
                                <XCircle size={12} />
                                <span>Từ chối</span>
                              </button>
                            </>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>

            {/* Table Pagination Bar */}
            {videosTotalPages > 1 && (
              <div className="pagination-bar">
                <span className="pagination-info">
                  Trang <strong>{videosPage + 1}</strong> / {videosTotalPages} • Tổng <strong>{videosTotalElements}</strong> video
                </span>
                <div className="pagination-actions">
                  <button
                    disabled={videosPage === 0}
                    onClick={() => setVideosPage(prev => Math.max(0, prev - 1))}
                    className="pagination-btn"
                    title="Trang trước"
                  >
                    <ChevronLeft size={14} />
                    <span>Trước</span>
                  </button>
                  <button
                    disabled={videosPage >= videosTotalPages - 1}
                    onClick={() => setVideosPage(prev => Math.min(videosTotalPages - 1, prev + 1))}
                    className="pagination-btn"
                    title="Trang sau"
                  >
                    <span>Sau</span>
                    <ChevronRight size={14} />
                  </button>
                </div>
              </div>
            )}
          </>
        )}
      </>
      {modalsSlot && createPortal(
        <>
          {/* ==================== MODAL: TỪ CHỐI DUYỆT VIDEO (REASON PICKER) ==================== */}
          {selectedRejectVideo && (
            <div className="modal-overlay">
              <div className="modal-sharp-box" style={{ maxWidth: '480px' }}>
                <div className="modal-sharp-header">
                  <h3 className="modal-sharp-title">Từ Chối Duyệt Video Bài Học</h3>
                  <button onClick={() => setSelectedRejectVideo(null)} className="btn-icon-square">✕</button>
                </div>
                <form onSubmit={handleConfirmRejectVideo}>
                  <div className="modal-sharp-body">
                    <div style={{ fontSize: '0.84rem', color: 'var(--admin-text-main)' }}>
                      Video: <strong>{selectedRejectVideo.title}</strong>
                    </div>

                    <div className="form-group-sharp">
                      <label className="form-label-sharp">Chọn lý do vi phạm:</label>
                      <select
                        className="form-select-sharp"
                        value={rejectReason}
                        onChange={e => setRejectReason(e.target.value)}
                      >
                        <option value="Vi phạm bản quyền âm thanh / video">Vi phạm bản quyền âm thanh / video</option>
                        <option value="Nội dung không liên quan đến học tiếng Nhật">Nội dung không liên quan đến học tiếng Nhật</option>
                        <option value="Ngôn từ thù ghét, thô tục hoặc không phù hợp giáo dục">Ngôn từ thù ghét, thô tục hoặc không phù hợp giáo dục</option>
                        <option value="Chất lượng âm thanh/hình ảnh quá kém, không nhận diện được giọng">Chất lượng âm thanh/hình ảnh quá kém, không nhận diện được giọng</option>
                        <option value="Phát âm hoặc ngữ pháp sai lệch nghiêm trọng">Phát âm hoặc ngữ pháp sai lệch nghiêm trọng</option>
                        <option value="Lý do khác">Lý do khác (Nhập chi tiết bên dưới)</option>
                      </select>
                    </div>

                    {rejectReason === 'Lý do khác' && (
                      <div className="form-group-sharp">
                        <label className="form-label-sharp">Chi tiết vi phạm gửi cho User:</label>
                        <textarea
                          required
                          rows={3}
                          className="form-textarea-sharp"
                          placeholder="Mô tả cụ thể vi phạm để người đăng video biết và chỉnh sửa..."
                          value={customRejectReason}
                          onChange={e => setCustomRejectReason(e.target.value)}
                        />
                      </div>
                    )}
                  </div>
                  <div className="modal-sharp-footer">
                    <button type="button" onClick={() => setSelectedRejectVideo(null)} className="btn-outline">Hủy</button>
                    <button type="submit" disabled={isSubmittingReject} className="btn-danger">
                      {isSubmittingReject ? 'Đang gửi...' : 'Xác nhận Từ chối Duyệt'}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
          {/* ==================== MODAL: CHI TIẾT VIDEO KIỂM DUYỆT ==================== */}
          {selectedDetailVideo && (
            <div className="modal-overlay" onClick={() => setSelectedDetailVideo(null)}>
              <div className="modal-sharp-box" style={{ maxWidth: '780px' }} onClick={e => e.stopPropagation()}>
                <div className="modal-sharp-header">
                  <div style={{ display: 'flex', alignItems: 'center', gap: '0.6rem' }}>
                    <span className={`status-pill ${
                      selectedDetailVideo.modStatus === 'APPROVED' ? 'success' : selectedDetailVideo.modStatus === 'REJECTED' ? 'danger' : 'pending'
                    }`}>
                      {selectedDetailVideo.modStatus === 'APPROVED' ? 'ĐÃ DUYỆT' : selectedDetailVideo.modStatus === 'REJECTED' ? 'TỪ CHỐI' : 'CHỜ DUYỆT'}
                    </span>
                    <h3 className="modal-sharp-title" style={{ fontSize: '1.05rem', margin: 0 }}>
                      {selectedDetailVideo.title}
                    </h3>
                  </div>
                  <button onClick={() => setSelectedDetailVideo(null)} className="btn-icon-square">✕</button>
                </div>

                <div className="modal-sharp-body" style={{ maxHeight: '78vh', overflowY: 'auto' }}>
                  {/* Video Player - Compact, centered, 100% full frame without cropping */}
                  <div className="mod-detail-video-box">
                    <div className="mod-detail-video-player-wrap">
                      <video
                        src={selectedDetailVideo.videoUrl}
                        poster={selectedDetailVideo.thumbnailUrl}
                        controls
                        autoPlay
                        playsInline
                      />
                    </div>
                  </div>

                  {/* Meta Grid */}
                  <div style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fit, minmax(170px, 1fr))',
                    gap: '0.75rem',
                    marginTop: '1rem',
                    background: 'var(--admin-bg-base)',
                    padding: '0.85rem',
                    borderRadius: 'var(--radius-sharp)',
                    border: '1px solid var(--admin-border-subtle)',
                    fontSize: '0.82rem'
                  }}>
                    <div>
                      <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Người đăng:</span>
                      <strong style={{ color: 'var(--admin-text-main)' }}>
                        {selectedDetailVideo.creatorDisplayName || selectedDetailVideo.creatorUsername || selectedDetailVideo.user?.displayName || selectedDetailVideo.user?.username || 'Creator'}
                      </strong>
                      <span style={{ display: 'block', fontSize: '0.72rem', color: '#94a3b8' }}>
                        @{selectedDetailVideo.creatorUsername || selectedDetailVideo.user?.username || 'creator'}
                      </span>
                    </div>

                    <div>
                      <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Cấp độ & Thời lượng:</span>
                      <strong style={{ color: 'var(--admin-text-main)' }}>
                        JLPT {selectedDetailVideo.jlptLevel || 'N5'} • {Math.floor((selectedDetailVideo.duration || 0) / 60)}m {(selectedDetailVideo.duration || 0) % 60}s
                      </strong>
                    </div>

                    <div>
                      <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Ngày đăng bài:</span>
                      <strong style={{ color: 'var(--admin-text-main)' }}>
                        {selectedDetailVideo.createdAt ? new Date(selectedDetailVideo.createdAt).toLocaleString('vi-VN') : '—'}
                      </strong>
                    </div>

                    <div>
                      <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem', marginBottom: '0.2rem' }}>Chế độ hiển thị:</span>
                      <span className="status-pill info">
                        🌐 {selectedDetailVideo.status || 'PUBLIC'}
                      </span>
                    </div>

                    <div>
                      <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem' }}>Tương tác:</span>
                      <span style={{ color: 'var(--admin-text-main)' }}>
                        {selectedDetailVideo.viewCount || 0} xem • {selectedDetailVideo.likeCount || 0} like • {selectedDetailVideo.saveCount || 0} save
                      </span>
                    </div>
                  </div>

                  {/* Description */}
                  {selectedDetailVideo.description && (
                    <div style={{ marginTop: '0.85rem' }}>
                      <label className="form-label-sharp" style={{ marginBottom: '0.3rem' }}>Mô tả bài học:</label>
                      <p style={{
                        margin: 0,
                        padding: '0.65rem 0.85rem',
                        background: 'var(--admin-bg-base)',
                        border: '1px solid var(--admin-border-subtle)',
                        borderRadius: 'var(--radius-sharp)',
                        fontSize: '0.83rem',
                        color: 'var(--admin-text-muted)'
                      }}>
                        {selectedDetailVideo.description}
                      </p>
                    </div>
                  )}

                  {/* Speech-to-text Transcription / Subtitles block */}
                  {(selectedDetailVideo.japaneseTranscription || selectedDetailVideo.vietnameseTranslation || (selectedDetailVideo.subtitles && selectedDetailVideo.subtitles !== '[]')) && (
                    <div style={{ marginTop: '0.85rem' }}>
                      {(() => {
                        let parsedSubs: Array<{ start?: string; end?: string; text?: string; translation?: string }> = [];
                        if (selectedDetailVideo.subtitles && selectedDetailVideo.subtitles !== '[]') {
                          try {
                            const parsed = typeof selectedDetailVideo.subtitles === 'string'
                              ? JSON.parse(selectedDetailVideo.subtitles)
                              : selectedDetailVideo.subtitles;
                            if (Array.isArray(parsed) && parsed.length > 0) {
                              parsedSubs = parsed;
                            }
                          } catch {
                            // ignore json parse error
                          }
                        }

                        return (
                          <>
                            <label className="form-label-sharp" style={{ marginBottom: '0.35rem', display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
                              <span>Trích xuất lời thoại AI (Speech-to-Text) & Phụ đề:</span>
                              {parsedSubs.length > 0 && (
                                <span style={{ fontSize: '0.72rem', color: '#0284c7', fontWeight: 600 }}>
                                  ({parsedSubs.length} đoạn hội thoại)
                                </span>
                              )}
                            </label>

                            {parsedSubs.length > 0 ? (
                              <div className="mod-subtitles-list">
                                {parsedSubs.map((sub, idx) => (
                                  <div key={idx} className="mod-subtitle-item">
                                    {(sub.start || sub.end) && (
                                      <div className="mod-subtitle-time">
                                        {sub.start || '00:00'} - {sub.end || ''}
                                      </div>
                                    )}
                                    <div style={{ flex: 1 }}>
                                      <div className="mod-subtitle-text">{sub.text}</div>
                                      {sub.translation && (
                                        <div className="mod-subtitle-trans">"{sub.translation}"</div>
                                      )}
                                    </div>
                                  </div>
                                ))}
                              </div>
                            ) : (
                              <div className="mod-transcript-box">
                                {selectedDetailVideo.japaneseTranscription && (
                                  <div className="mod-transcript-jp">{selectedDetailVideo.japaneseTranscription}</div>
                                )}
                                {selectedDetailVideo.vietnameseTranslation && (
                                  <div className="mod-transcript-vn">"{selectedDetailVideo.vietnameseTranslation}"</div>
                                )}
                                {!selectedDetailVideo.japaneseTranscription && !selectedDetailVideo.vietnameseTranslation && selectedDetailVideo.subtitles && (
                                  <div className="mod-transcript-jp">{selectedDetailVideo.subtitles}</div>
                                )}
                              </div>
                            )}
                          </>
                        );
                      })()}
                    </div>
                  )}

                  {/* Rejection Reason if any */}
                  {selectedDetailVideo.rejectionReason && (
                    <div style={{
                      marginTop: '0.85rem',
                      background: 'rgba(239, 68, 68, 0.1)',
                      border: '1px solid #ef4444',
                      padding: '0.75rem',
                      borderRadius: 'var(--radius-sharp)',
                      color: '#f87171',
                      fontSize: '0.82rem'
                    }}>
                      <strong>Lý do từ chối:</strong> {selectedDetailVideo.rejectionReason}
                    </div>
                  )}
                </div>

                <div className="modal-sharp-footer" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                  <button
                    type="button"
                    onClick={() => setSelectedDetailVideo(null)}
                    className="btn-outline"
                  >
                    Đóng
                  </button>

                  <div style={{ display: 'flex', gap: '0.5rem' }}>
                    {selectedDetailVideo.modStatus === 'PENDING' && (
                      <>
                        <button
                          type="button"
                          onClick={() => setSelectedRejectVideo(selectedDetailVideo)}
                          className="btn-danger"
                        >
                          <XCircle size={15} />
                          <span>Từ chối</span>
                        </button>
                        <button
                          type="button"
                          onClick={() => handleApproveVideo(selectedDetailVideo.id)}
                          className="btn-success"
                        >
                          <CheckCircle2 size={15} />
                          <span>Phê duyệt video</span>
                        </button>
                      </>
                    )}
                  </div>
                </div>
              </div>
            </div>
          )}
        </>,
        modalsSlot
      )}
    </>
  );
};
