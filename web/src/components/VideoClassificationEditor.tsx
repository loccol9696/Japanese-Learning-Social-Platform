import { useState } from 'react';
import {
  getActiveTopics,
  updateVideoClassification,
  type TopicItem,
  type VideoModerationItem,
} from '../services/adminService';

const MAX_TOPICS = 3;

interface VideoClassificationEditorProps {
  video: VideoModerationItem;
  onSaved: (updated: VideoModerationItem) => void;
  showToast: (message: string) => void;
}

/** Xem và sửa chủ đề / hashtag của video; sửa ở đây không đổi trạng thái kiểm duyệt. */
export default function VideoClassificationEditor({ video, onSaved, showToast }: VideoClassificationEditorProps) {
  const [isEditing, setIsEditing] = useState(false);
  const [isSaving, setIsSaving] = useState(false);
  const [topics, setTopics] = useState<TopicItem[]>([]);
  const [topicIds, setTopicIds] = useState<number[]>([]);
  const [hashtagText, setHashtagText] = useState('');

  const currentTopics = video.topics ?? [];
  const currentHashtags = video.hashtags ?? [];

  const startEditing = async () => {
    setTopicIds(currentTopics.map((t) => t.id));
    setHashtagText(currentHashtags.join(' '));
    setIsEditing(true);
    try {
      const active = await getActiveTopics();
      // Gộp cả chủ đề đang gắn để bỏ được chủ đề admin đã ẩn.
      const hidden = currentTopics.filter((t) => !active.some((a) => a.id === t.id));
      setTopics([...active, ...hidden]);
    } catch {
      setTopics(currentTopics);
    }
  };

  const toggleTopic = (id: number) => {
    if (topicIds.includes(id)) {
      setTopicIds(topicIds.filter((t) => t !== id));
    } else if (topicIds.length >= MAX_TOPICS) {
      showToast(`Chỉ được chọn tối đa ${MAX_TOPICS} chủ đề.`);
    } else {
      setTopicIds([...topicIds, id]);
    }
  };

  const save = async () => {
    setIsSaving(true);
    try {
      const updated = await updateVideoClassification(video.id, {
        topicIds,
        hashtags: hashtagText.split(/[\s,]+/).filter(Boolean),
      });
      setIsEditing(false);
      showToast('Đã cập nhật phân loại video.');
      onSaved(updated);
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể cập nhật phân loại video');
    } finally {
      setIsSaving(false);
    }
  };

  const title = (
    <span style={{ color: 'var(--admin-text-dim)', display: 'block', fontSize: '0.75rem', marginBottom: '0.3rem' }}>
      Chủ đề & Hashtag:
    </span>
  );

  if (!isEditing) {
    return (
      <div style={{ marginTop: '0.85rem' }}>
        {title}
        <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.35rem', alignItems: 'center' }}>
          {currentTopics.map((t) => (
            <span key={t.id} className="status-pill info">{t.name}</span>
          ))}
          {currentHashtags.map((tag) => (
            <span key={tag} className="status-pill pending">#{tag}</span>
          ))}
          {currentTopics.length === 0 && currentHashtags.length === 0 && (
            <span style={{ color: 'var(--admin-text-dim)', fontSize: '0.8rem' }}>Chưa gắn</span>
          )}
          <button type="button" className="btn-outline" onClick={startEditing}>Sửa</button>
        </div>
      </div>
    );
  }

  return (
    <div style={{ marginTop: '0.85rem' }}>
      {title}
      <div style={{ display: 'flex', flexWrap: 'wrap', gap: '0.6rem', marginBottom: '0.5rem' }}>
        {topics.map((t) => (
          <label key={t.id} style={{ color: 'var(--admin-text-main)', fontSize: '0.8rem', display: 'flex', gap: '0.25rem' }}>
            <input type="checkbox" checked={topicIds.includes(t.id)} onChange={() => toggleTopic(t.id)} />
            {t.name}
          </label>
        ))}
      </div>
      <input
        className="form-input-sharp"
        style={{ width: '100%', marginBottom: '0.5rem' }}
        value={hashtagText}
        onChange={(e) => setHashtagText(e.target.value)}
        placeholder="Hashtag, cách nhau bằng dấu cách (tối đa 5)"
      />
      <div style={{ display: 'flex', gap: '0.5rem' }}>
        <button type="button" className="btn-solid-primary" disabled={isSaving} onClick={save}>
          {isSaving ? 'Đang lưu...' : 'Lưu'}
        </button>
        <button type="button" className="btn-outline" disabled={isSaving} onClick={() => setIsEditing(false)}>
          Huỷ
        </button>
      </div>
    </div>
  );
}
