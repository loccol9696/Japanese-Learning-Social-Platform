import { useCallback, useEffect, useRef, useState } from 'react';
import { Edit2, Eye, EyeOff, Plus, Save, X } from 'lucide-react';
import {
  createTopic,
  getAllTopicsAdmin,
  updateTopic,
  type TopicItem,
} from '../services/adminService';

interface TopicsManagerProps {
  showToast: (message: string) => void;
}

/** Quản lý chủ đề của video / sở thích hồ sơ. Ẩn chủ đề thay vì xoá để không mất liên kết. */
export default function TopicsManager({ showToast: showToastProp }: TopicsManagerProps) {
  // Cha truyền hàm mới mỗi lần render; giữ trong ref để không kích hoạt tải lại liên tục.
  const toastRef = useRef(showToastProp);
  useEffect(() => {
    toastRef.current = showToastProp;
  });
  const showToast = useCallback((message: string) => toastRef.current(message), []);

  const [topics, setTopics] = useState<TopicItem[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [newName, setNewName] = useState('');
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editingName, setEditingName] = useState('');

  const load = useCallback(async () => {
    setIsLoading(true);
    try {
      setTopics(await getAllTopicsAdmin());
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể tải danh sách chủ đề');
    } finally {
      setIsLoading(false);
    }
  }, [showToast]);

  useEffect(() => {
    load();
  }, [load]);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    const name = newName.trim();
    if (!name) return;
    try {
      await createTopic({ name });
      setNewName('');
      showToast(`Đã tạo chủ đề "${name}"`);
      await load();
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể tạo chủ đề');
    }
  };

  const handleRename = async (topic: TopicItem) => {
    const name = editingName.trim();
    if (!name) return;
    try {
      await updateTopic(topic.id, { name, isActive: topic.isActive, sortOrder: topic.sortOrder });
      setEditingId(null);
      showToast('Đã cập nhật chủ đề');
      await load();
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể cập nhật chủ đề');
    }
  };

  const handleToggleActive = async (topic: TopicItem) => {
    try {
      await updateTopic(topic.id, {
        name: topic.name,
        isActive: !topic.isActive,
        sortOrder: topic.sortOrder,
      });
      showToast(topic.isActive ? `Đã ẩn "${topic.name}"` : `Đã hiện lại "${topic.name}"`);
      await load();
    } catch (err) {
      showToast(err instanceof Error ? err.message : 'Không thể đổi trạng thái chủ đề');
    }
  };

  return (
    <div>
      <form onSubmit={handleCreate} style={{ display: 'flex', gap: '0.75rem', marginBottom: '1.25rem' }}>
        <input
          type="text"
          className="form-input-sharp"
          style={{ maxWidth: '360px' }}
          value={newName}
          maxLength={80}
          onChange={e => setNewName(e.target.value)}
          placeholder="Tên chủ đề mới..."
        />
        <button type="submit" className="btn-solid-primary" disabled={!newName.trim()}>
          <Plus size={14} />
          <span>Thêm chủ đề</span>
        </button>
      </form>

      <div className="data-table-container">
        <table className="enterprise-table">
          <thead>
            <tr>
              <th>ID</th>
              <th>Thứ tự</th>
              <th>Tên chủ đề</th>
              <th>Trạng thái</th>
              <th style={{ textAlign: 'right' }}>Thao tác</th>
            </tr>
          </thead>
          <tbody>
            {isLoading ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8' }}>
                  Đang tải danh sách chủ đề...
                </td>
              </tr>
            ) : topics.length === 0 ? (
              <tr>
                <td colSpan={5} style={{ textAlign: 'center', padding: '2rem', color: '#94a3b8' }}>
                  Chưa có chủ đề nào.
                </td>
              </tr>
            ) : (
              topics.map(topic => (
                <tr key={topic.id}>
                  <td style={{ fontFamily: 'var(--font-mono)', color: '#64748b' }}>#{topic.id}</td>
                  <td style={{ fontFamily: 'var(--font-mono)' }}>{topic.sortOrder}</td>
                  <td style={{ fontWeight: 600 }}>
                    {editingId === topic.id ? (
                      <input
                        type="text"
                        className="form-input-sharp"
                        autoFocus
                        maxLength={80}
                        value={editingName}
                        onChange={e => setEditingName(e.target.value)}
                        onKeyDown={e => {
                          if (e.key === 'Enter') handleRename(topic);
                          if (e.key === 'Escape') setEditingId(null);
                        }}
                      />
                    ) : (
                      topic.name
                    )}
                  </td>
                  <td>
                    <span className={`status-pill ${topic.isActive ? 'success' : 'danger'}`}>
                      {topic.isActive ? 'Đang hiển thị' : 'Đã ẩn'}
                    </span>
                  </td>
                  <td style={{ textAlign: 'right' }}>
                    <div style={{ display: 'inline-flex', gap: '0.5rem' }}>
                      {editingId === topic.id ? (
                        <>
                          <button className="btn-success" onClick={() => handleRename(topic)}>
                            <Save size={14} />
                            <span>Lưu</span>
                          </button>
                          <button className="btn-outline" onClick={() => setEditingId(null)}>
                            <X size={14} />
                            <span>Huỷ</span>
                          </button>
                        </>
                      ) : (
                        <>
                          <button
                            className="btn-outline"
                            onClick={() => {
                              setEditingId(topic.id);
                              setEditingName(topic.name);
                            }}
                          >
                            <Edit2 size={14} />
                            <span>Đổi tên</span>
                          </button>
                          <button
                            className={topic.isActive ? 'btn-danger' : 'btn-success'}
                            onClick={() => handleToggleActive(topic)}
                          >
                            {topic.isActive ? <EyeOff size={14} /> : <Eye size={14} />}
                            <span>{topic.isActive ? 'Ẩn' : 'Hiện'}</span>
                          </button>
                        </>
                      )}
                    </div>
                  </td>
                </tr>
              ))
            )}
          </tbody>
        </table>
      </div>
    </div>
  );
}
