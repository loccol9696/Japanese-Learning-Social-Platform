import React, { useState, useEffect } from 'react';
import { createPortal } from 'react-dom';
import { ChevronLeft, ChevronRight, QrCode, RefreshCw, ArrowUpDown } from 'lucide-react';
import {
  getAllPlansAdmin,
  getSubscriptionOrders,
  createQrOrder,
  confirmPayment,
  type SubscriptionPlanItem,
  type SubscriptionOrderItem
} from '../../services/adminService';
import type { AdminTabProps } from './types';

/** Tab lịch sử mua gói & giả lập thanh toán QR local (chỉ ADMIN). */
export const SubscriptionsTab: React.FC<AdminTabProps> = ({ isActive, showToast, actionsSlot, modalsSlot }) => {
  // ==================== SUBSCRIPTION HISTORY & QR LOCAL SIMULATOR ====================
  const [orders, setOrders] = useState<SubscriptionOrderItem[]>([]);
  const [isLoadingOrders, setIsLoadingOrders] = useState(false);
  const [orderSortField, setOrderSortField] = useState<'createdAt' | 'amount' | 'status'>('createdAt');
  const [orderSortDir, setOrderSortDir] = useState<'asc' | 'desc'>('desc');

  // QR Test Simulator State
  const [isQrModalOpen, setIsQrModalOpen] = useState(false);
  const [selectedPlanCode, setSelectedPlanCode] = useState('PRO_MONTHLY');
  const [activeQrOrder, setActiveQrOrder] = useState<{
    orderCode: string;
    verificationCode: string;
    planName: string;
    amount: number;
    qrCodeUrl: string;
    status: string;
  } | null>(null);
  const [verificationInput, setVerificationInput] = useState('');
  const [isProcessingPayment, setIsProcessingPayment] = useState(false);
  const [paymentSuccessData, setPaymentSuccessData] = useState<any | null>(null);

  // Pagination state for subscription orders table (Limit 10 per page)
  const [ordersPage, setOrdersPage] = useState(0);
  const [ordersTotalPages, setOrdersTotalPages] = useState(1);
  const [ordersTotalElements, setOrdersTotalElements] = useState(0);

  const loadSubscriptionOrders = async () => {
    setIsLoadingOrders(true);
    try {
      const sortParam = `${orderSortField},${orderSortDir}`;
      const data = await getSubscriptionOrders(ordersPage, 10, sortParam);
      setOrders(data.content || []);
      setOrdersTotalPages(data.totalPages || 1);
      setOrdersTotalElements(data.totalElements || 0);
    } catch (err: any) {
      console.error(err);
    } finally {
      setIsLoadingOrders(false);
    }
  };

  useEffect(() => {
    if (isActive) {
      loadSubscriptionOrders();
    }
  }, [isActive, orderSortField, orderSortDir, ordersPage]);

  const handleToggleSort = (field: 'createdAt' | 'amount' | 'status') => {
    setOrdersPage(0);
    if (orderSortField === field) {
      setOrderSortDir(prev => (prev === 'asc' ? 'desc' : 'asc'));
    } else {
      setOrderSortField(field);
      setOrderSortDir('desc');
    }
  };

  const handleCreateQrOrder = async () => {
    try {
      const data = await createQrOrder(selectedPlanCode);
      setActiveQrOrder(data);
      setVerificationInput(data.verificationCode); // Tiện ích điền sẵn mã dưới QR để test nhanh
      setPaymentSuccessData(null);
    } catch (err: any) {
      alert('Lỗi tạo mã QR: ' + err.message);
    }
  };

  const handleConfirmQrPayment = async () => {
    if (!activeQrOrder) return;
    if (!verificationInput.trim()) {
      alert('Vui lòng nhập mã xác thực hiện ở dưới QR!');
      return;
    }
    setIsProcessingPayment(true);
    try {
      const result = await confirmPayment(activeQrOrder.orderCode, verificationInput.trim());
      setPaymentSuccessData(result);
      showToast('Thanh toán thành công! Gói VIP và hạn mức Token ngày đã được nâng cấp.');
      loadSubscriptionOrders();
    } catch (err: any) {
      alert('Xác thực thất bại: ' + err.message);
    } finally {
      setIsProcessingPayment(false);
    }
  };

  // Danh sách gói cho bộ chọn trong modal QR
  const [plans, setPlans] = useState<SubscriptionPlanItem[]>([]);

  useEffect(() => {
    if (isActive) {
      getAllPlansAdmin().then(setPlans).catch(err => console.error(err));
    }
  }, [isActive]);

  if (!isActive) return null;

  return (
    <>
      {actionsSlot && createPortal(
        <>
        <button
          onClick={() => {
            setIsQrModalOpen(true);
            handleCreateQrOrder();
          }}
          className="btn-solid-primary"
        >
          <QrCode size={15} />
          <span>⚡ Giả lập Quét QR Thanh toán Local</span>
        </button>
        </>,
        actionsSlot
      )}
      <>
        <div className="toolbar-row">
          <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
            <span style={{ fontSize: '0.82rem', color: '#94a3b8', fontWeight: 600 }}>Sắp xếp theo:</span>
            <button
              onClick={() => handleToggleSort('createdAt')}
              className={`btn-outline ${orderSortField === 'createdAt' ? 'btn-solid-primary' : ''}`}
            >
              <ArrowUpDown size={14} />
              <span>Ngày tạo ({orderSortDir})</span>
            </button>
            <button
              onClick={() => handleToggleSort('amount')}
              className={`btn-outline ${orderSortField === 'amount' ? 'btn-solid-primary' : ''}`}
            >
              <ArrowUpDown size={14} />
              <span>Số tiền ({orderSortDir})</span>
            </button>
            <button
              onClick={() => handleToggleSort('status')}
              className={`btn-outline ${orderSortField === 'status' ? 'btn-solid-primary' : ''}`}
            >
              <ArrowUpDown size={14} />
              <span>Trạng thái</span>
            </button>
          </div>

          <button onClick={loadSubscriptionOrders} className="btn-outline">
            <RefreshCw size={15} />
            <span>Làm mới</span>
          </button>
        </div>

        <div className="data-table-container">
          <table className="enterprise-table">
            <thead>
              <tr>
                <th>Mã Đơn Hàng</th>
                <th>Người Dùng</th>
                <th>Gói Đăng Ký</th>
                <th className="sortable" onClick={() => handleToggleSort('amount')}>
                  Số Tiền (VND) ↕
                </th>
                <th>Mã Xác Thực (Dưới QR)</th>
                <th className="sortable" onClick={() => handleToggleSort('status')}>
                  Trạng Thái ↕
                </th>
                <th className="sortable" onClick={() => handleToggleSort('createdAt')}>
                  Thời Gian ↕
                </th>
              </tr>
            </thead>
            <tbody>
              {isLoadingOrders ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '2.5rem', color: '#94a3b8' }}>
                    Đang tải lịch sử giao dịch gói...
                  </td>
                </tr>
              ) : orders.length === 0 ? (
                <tr>
                  <td colSpan={7} style={{ textAlign: 'center', padding: '2.5rem', color: '#94a3b8' }}>
                    Chưa có lịch sử giao dịch nào. Bấm nút <strong>"⚡ Giả lập Quét QR Thanh toán Local"</strong> ở trên để tạo giao dịch thử nghiệm!
                  </td>
                </tr>
              ) : (
                orders.map(o => (
                  <tr key={o.id}>
                    <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, color: '#38bdf8' }}>
                      {o.orderCode}
                    </td>
                    <td style={{ fontWeight: 600 }}>{o.userDisplayName || o.username}</td>
                    <td>
                      <span style={{ fontWeight: 600, color: '#ffffff' }}>{o.planName}</span>
                    </td>
                    <td style={{ fontFamily: 'var(--font-mono)', fontWeight: 700, fontSize: '0.9rem' }}>
                      {o.amount?.toLocaleString('vi-VN')} đ
                    </td>
                    <td>
                      <span style={{
                        fontFamily: 'var(--font-mono)',
                        fontWeight: 800,
                        background: '#1e293b',
                        border: '1px solid #38bdf8',
                        padding: '0.2rem 0.5rem',
                        borderRadius: '2px',
                        color: '#38bdf8'
                      }}>
                        {o.verificationCode}
                      </span>
                    </td>
                    <td>
                      <span className={`status-pill ${
                        o.status === 'SUCCESS' ? 'success' : o.status === 'PENDING' ? 'pending' : 'danger'
                      }`}>
                        {o.status}
                      </span>
                    </td>
                    <td style={{ fontSize: '0.8rem', color: '#94a3b8' }}>
                      {o.createdAt ? new Date(o.createdAt).toLocaleString('vi-VN') : '—'}
                    </td>
                  </tr>
                ))
              )}
            </tbody>
          </table>
        </div>

        {/* Phân trang bảng Lịch Sử Mua Gói (Giới hạn 10 giao dịch / trang, mũi tên chuyển tab) */}
        <div className="pagination-bar">
          <div className="pagination-info">
            Hiển thị <strong>{orders.length > 0 ? (ordersPage * 10) + 1 : 0}</strong> - <strong>{Math.min((ordersPage + 1) * 10, ordersTotalElements)}</strong> trên tổng số <strong>{ordersTotalElements}</strong> giao dịch (10/trang)
          </div>
          <div className="pagination-actions">
            <button
              className="pagination-btn"
              disabled={ordersPage === 0 || isLoadingOrders}
              onClick={() => setOrdersPage(prev => Math.max(0, prev - 1))}
              title="Trang trước"
            >
              <ChevronLeft size={16} />
              <span>Trang trước</span>
            </button>
            <span className="pagination-page-indicator">
              Trang <strong>{ordersPage + 1}</strong> / {Math.max(1, ordersTotalPages)}
            </span>
            <button
              className="pagination-btn"
              disabled={ordersPage >= ordersTotalPages - 1 || isLoadingOrders}
              onClick={() => setOrdersPage(prev => prev + 1)}
              title="Trang sau"
            >
              <span>Trang sau</span>
              <ChevronRight size={16} />
            </button>
          </div>
        </div>
      </>
      {modalsSlot && createPortal(
        <>
          {/* ==================== MODAL: GIẢ LẬP THANH TOÁN QR LOCAL ==================== */}
          {isQrModalOpen && (
            <div className="modal-overlay">
              <div className="modal-sharp-box" style={{ maxWidth: '520px' }}>
                <div className="modal-sharp-header">
                  <h3 className="modal-sharp-title">⚡ Giả Lập Quét QR Thanh Toán Local</h3>
                  <button onClick={() => setIsQrModalOpen(false)} className="btn-icon-square">✕</button>
                </div>
                <div className="modal-sharp-body">
                  <div style={{ display: 'flex', gap: '0.5rem', alignItems: 'center' }}>
                    <label className="form-label-sharp" style={{ minWidth: '90px' }}>Chọn gói mua:</label>
                    <select
                      className="form-select-sharp"
                      style={{ flex: 1 }}
                      value={selectedPlanCode}
                      onChange={e => {
                        setSelectedPlanCode(e.target.value);
                      }}
                    >
                      {plans && plans.length > 0 ? (
                        plans.map(p => (
                          <option key={p.id} value={p.code}>
                            {p.name} ({p.price.toLocaleString('vi-VN')} đ - {p.dailyTokenLimit} token/ngày)
                          </option>
                        ))
                      ) : (
                        <>
                          <option value="FREE">Gói 1 Năm (419.000 đ - 50 token/ngày)</option>
                          <option value="PRO_YEARLY">Gói 3 Tháng (299.000 đ - 50 token/ngày)</option>
                          <option value="PRO_MONTHLY">Gói Trọn Đời (699.000 đ - 50 token/ngày)</option>
                        </>
                      )}
                    </select>
                    <button onClick={handleCreateQrOrder} className="btn-outline">
                      Tạo QR
                    </button>
                  </div>

                  {activeQrOrder && (
                    <div className="qr-display-box">
                      <div style={{ fontWeight: 700, fontSize: '1rem', color: '#0f172a' }}>
                        {activeQrOrder.planName} • {activeQrOrder.amount?.toLocaleString('vi-VN')} đ
                      </div>

                      {/* Clean SVG QR Representation */}
                      <div className="qr-code-canvas-wrap">
                        <svg width="150" height="150" viewBox="0 0 150 150">
                          <rect width="150" height="150" fill="#ffffff" />
                          {/* Top-left position marker */}
                          <rect x="10" y="10" width="35" height="35" fill="#0f172a" />
                          <rect x="15" y="15" width="25" height="25" fill="#ffffff" />
                          <rect x="20" y="20" width="15" height="15" fill="#0f172a" />
                          {/* Top-right position marker */}
                          <rect x="105" y="10" width="35" height="35" fill="#0f172a" />
                          <rect x="110" y="15" width="25" height="25" fill="#ffffff" />
                          <rect x="115" y="20" width="15" height="15" fill="#0f172a" />
                          {/* Bottom-left position marker */}
                          <rect x="10" y="105" width="35" height="35" fill="#0f172a" />
                          <rect x="15" y="110" width="25" height="25" fill="#ffffff" />
                          <rect x="20" y="115" width="15" height="15" fill="#0f172a" />
                          {/* Simulated QR data grid */}
                          <rect x="55" y="15" width="12" height="12" fill="#0284c7" />
                          <rect x="75" y="15" width="12" height="12" fill="#0f172a" />
                          <rect x="55" y="35" width="12" height="12" fill="#0f172a" />
                          <rect x="55" y="60" width="40" height="40" fill="#0284c7" />
                          <rect x="65" y="70" width="20" height="20" fill="#ffffff" />
                          <rect x="105" y="60" width="15" height="15" fill="#0f172a" />
                          <rect x="125" y="80" width="15" height="15" fill="#0f172a" />
                          <rect x="55" y="115" width="15" height="15" fill="#0f172a" />
                          <rect x="80" y="115" width="15" height="15" fill="#0284c7" />
                          <rect x="110" y="115" width="25" height="20" fill="#0f172a" />
                        </svg>
                      </div>

                      {/* THE PROMINENT VERIFICATION CODE DISPLAYED UNDER THE QR CODE AS REQUESTED */}
                      <div className="verification-code-banner">
                        <span className="verification-code-title">
                          Mã xác thực hiển thị ở dưới mã QR:
                        </span>
                        <span className="verification-code-display">
                          {activeQrOrder.verificationCode}
                        </span>
                        <span style={{ fontSize: '0.72rem', color: '#94a3b8' }}>
                          (Người dùng quét QR ngân hàng hoặc nhập mã này vào trang thanh toán để kích hoạt)
                        </span>
                      </div>

                      {/* Payment Confirmation Form */}
                      <div style={{ width: '100%', marginTop: '0.5rem' }}>
                        <label className="form-label-sharp" style={{ color: '#0f172a', marginBottom: '0.3rem', display: 'block' }}>
                          Nhập mã xác thực để hoàn tất thanh toán:
                        </label>
                        <div style={{ display: 'flex', gap: '0.5rem' }}>
                          <input
                            type="text"
                            className="form-input-sharp"
                            style={{
                              flex: 1,
                              background: '#f1f5f9',
                              color: '#0f172a',
                              border: '1px solid #cbd5e1',
                              fontFamily: 'var(--font-mono)',
                              fontWeight: 700,
                              fontSize: '1rem',
                              textAlign: 'center'
                            }}
                            value={verificationInput}
                            onChange={e => setVerificationInput(e.target.value)}
                            placeholder="e.g. JLSP-XXXXX"
                          />
                          <button
                            onClick={handleConfirmQrPayment}
                            disabled={isProcessingPayment}
                            className="btn-solid-primary"
                            style={{ whiteSpace: 'nowrap' }}
                          >
                            {isProcessingPayment ? 'Đang xác thực...' : 'Xác nhận thanh toán'}
                          </button>
                        </div>
                      </div>

                      {paymentSuccessData && (
                        <div style={{
                          background: 'rgba(16, 185, 129, 0.15)',
                          border: '1px solid #10b981',
                          padding: '0.75rem',
                          borderRadius: '2px',
                          color: '#047857',
                          fontSize: '0.85rem',
                          width: '100%',
                          textAlign: 'center',
                          fontWeight: 600
                        }}>
                          ✓ Giao dịch thành công! Tài khoản đã được nâng cấp VIP và mở rộng hạn mức Token ngày.
                        </div>
                      )}
                    </div>
                  )}
                </div>
                <div className="modal-sharp-footer">
                  <button onClick={() => setIsQrModalOpen(false)} className="btn-outline">
                    Đóng
                  </button>
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
