import { useState, useMemo } from 'react';
import { updateVideoSubtitles, type VideoModerationItem } from '../services/adminService';

interface SubtitleEditorProps {
  video: VideoModerationItem;
  onSaved: (updated: VideoModerationItem) => void;
  showToast: (message: string) => void;
}

interface SubtitleCue {
  start?: string;
  end?: string;
  text?: string;
  translation?: string;
  [key: string]: any;
}

export default function SubtitleEditor({ video, onSaved, showToast }: SubtitleEditorProps) {
  const [editingIndex, setEditingIndex] = useState<number | null>(null);
  const [editText, setEditText] = useState('');
  const [editTranslation, setEditTranslation] = useState('');
  const [isSaving, setIsSaving] = useState(false);

  const parsedSubs: SubtitleCue[] = useMemo(() => {
    if (!video.subtitles || video.subtitles === '[]') return [];
    try {
      const parsed = typeof video.subtitles === 'string'
        ? JSON.parse(video.subtitles)
        : video.subtitles;
      return Array.isArray(parsed) ? parsed : [];
    } catch {
      return [];
    }
  }, [video.subtitles]);

  const handleStartEdit = (idx: number) => {
    const cue = parsedSubs[idx];
    if (!cue) return;
    setEditingIndex(idx);
    setEditText(cue.text || '');
    setEditTranslation(cue.translation || '');
  };

  const handleCancel = () => {
    setEditingIndex(null);
    setEditText('');
    setEditTranslation('');
  };

  const handleSave = async (idx: number) => {
    if (!editText.trim()) {
      showToast('Câu thoại tiếng Nhật không được để trống.');
      return;
    }

    setIsSaving(true);
    try {
      const updatedList = parsedSubs.map((cue, i) => {
        if (i !== idx) return cue;
        const newCue: Record<string, any> = { ...cue, text: editText.trim() };
        if (editTranslation.trim()) {
          newCue.translation = editTranslation.trim();
        }
        delete newCue.ruby;
        delete newCue.tokens;
        return newCue as SubtitleCue;
      });

      const updatedVideo = await updateVideoSubtitles(video.id, JSON.stringify(updatedList));
      onSaved(updatedVideo);
      setEditingIndex(null);
      showToast('Đã cập nhật câu thoại thành công.');
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể cập nhật phụ đề');
    } finally {
      setIsSaving(false);
    }
  };

  if (parsedSubs.length === 0 && !video.japaneseTranscription && !video.vietnameseTranslation) {
    return null;
  }

  return (
    <div style={{ marginTop: '0.85rem' }}>
      <label
        className="form-label-sharp"
        style={{ marginBottom: '0.4rem', display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}
      >
        <span style={{ display: 'flex', alignItems: 'center', gap: '0.4rem' }}>
          <span>Trích xuất lời thoại AI & Phụ đề:</span>
          {parsedSubs.length > 0 && (
            <span style={{ fontSize: '0.72rem', color: '#0284c7', fontWeight: 600 }}>
              ({parsedSubs.length} câu)
            </span>
          )}
        </span>
        <span style={{ fontSize: '0.72rem', color: 'var(--admin-text-dim)' }}>
          Click "Sửa" trên câu để chỉnh lại nếu AI tách sai
        </span>
      </label>

      {parsedSubs.length > 0 ? (
        <div className="mod-subtitles-list">
          {parsedSubs.map((sub, idx) => {
            const isEditing = editingIndex === idx;

            if (isEditing) {
              return (
                <div
                  key={idx}
                  className="mod-subtitle-item"
                  style={{
                    flexDirection: 'column',
                    alignItems: 'stretch',
                    background: 'rgba(59, 130, 246, 0.08)',
                    border: '1px solid #3b82f6',
                    borderRadius: '4px',
                    padding: '0.6rem',
                    gap: '0.5rem',
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                    <span style={{ fontSize: '0.75rem', fontWeight: 600, color: '#3b82f6' }}>
                      Đang sửa câu #{idx + 1} {sub.start ? `(${sub.start} - ${sub.end || ''})` : ''}
                    </span>
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.72rem', color: 'var(--admin-text-dim)', marginBottom: '0.2rem' }}>
                      Lời thoại tiếng Nhật:
                    </label>
                    <input
                      type="text"
                      className="form-input-sharp"
                      style={{ width: '100%' }}
                      value={editText}
                      onChange={(e) => setEditText(e.target.value)}
                      placeholder="Nhập câu tiếng Nhật chuẩn..."
                    />
                  </div>
                  <div>
                    <label style={{ display: 'block', fontSize: '0.72rem', color: 'var(--admin-text-dim)', marginBottom: '0.2rem' }}>
                      Bản dịch tiếng Việt (tuỳ chọn):
                    </label>
                    <input
                      type="text"
                      className="form-input-sharp"
                      style={{ width: '100%' }}
                      value={editTranslation}
                      onChange={(e) => setEditTranslation(e.target.value)}
                      placeholder="Nhập bản dịch tiếng Việt..."
                    />
                  </div>
                  <div style={{ display: 'flex', gap: '0.4rem', justifyContent: 'flex-end', marginTop: '0.2rem' }}>
                    <button
                      type="button"
                      className="btn-outline"
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.6rem' }}
                      onClick={handleCancel}
                      disabled={isSaving}
                    >
                      Huỷ
                    </button>
                    <button
                      type="button"
                      className="btn-primary"
                      style={{ fontSize: '0.75rem', padding: '0.25rem 0.6rem' }}
                      onClick={() => handleSave(idx)}
                      disabled={isSaving}
                    >
                      {isSaving ? 'Đang lưu...' : 'Lưu câu này'}
                    </button>
                  </div>
                </div>
              );
            }

            return (
              <div key={idx} className="mod-subtitle-item" style={{ alignItems: 'flex-start' }}>
                {(sub.start || sub.end) && (
                  <div className="mod-subtitle-time">
                    {sub.start || '00:00'} - {sub.end || ''}
                  </div>
                )}
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div className="mod-subtitle-text">{sub.text}</div>
                  {sub.translation && (
                    <div className="mod-subtitle-trans">"{sub.translation}"</div>
                  )}
                </div>
                <button
                  type="button"
                  className="btn-outline"
                  style={{ fontSize: '0.72rem', padding: '0.15rem 0.45rem', marginLeft: '0.5rem', flexShrink: 0 }}
                  onClick={() => handleStartEdit(idx)}
                >
                  Sửa
                </button>
              </div>
            );
          })}
        </div>
      ) : (
        <div className="mod-transcript-box">
          {video.japaneseTranscription && (
            <div className="mod-transcript-jp">{video.japaneseTranscription}</div>
          )}
          {video.vietnameseTranslation && (
            <div className="mod-transcript-vn">"{video.vietnameseTranslation}"</div>
          )}
        </div>
      )}
    </div>
  );
}
