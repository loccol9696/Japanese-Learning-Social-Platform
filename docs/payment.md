# Thanh toán mua gói thành viên (VietQR + SePay)

Người dùng chuyển khoản vào tài khoản ngân hàng theo mã QR; SePay báo biến động số dư về backend qua webhook; backend
tự kích hoạt gói. Không có đường nào để app hay người dùng tự đánh dấu "đã thanh toán".

## Luồng

```
App ── POST /api/v1/payments/orders {planId} ─► Backend tạo đơn (mã JLSPxxxxxxxx, số tiền, hạn 15 phút, link QR)
App hiện QR + số tài khoản + nội dung chuyển khoản, rồi hỏi GET /api/v1/payments/orders/{mã} mỗi 3 giây (chỉ đọc)
Khách chuyển khoản ──► Ngân hàng ──► SePay ── POST /api/v1/payments/webhook/sepay ─► Backend
                                         (Authorization: Apikey <SEPAY_WEBHOOK_KEY>)
Backend: xác thực khoá ► đúng tài khoản nhận, tiền vào ► ghi sổ cái (mỗi giao dịch một lần) ► tìm mã JLSP trong nội dung
         ► đủ tiền thì đơn SUCCESS và cộng hạn VIP; thiếu tiền thì NEEDS_REVIEW (cộng dồn, chuyển bù được)
```

Trạng thái đơn: `PENDING` (chờ), `SUCCESS`, `EXPIRED` (quá 15 phút, tiền về trong 24 giờ sau vẫn được nhận),
`NEEDS_REVIEW` (thiếu tiền hoặc về quá muộn, admin xem xét), `CANCELLED`, `FAILED`.

## Cấu hình (biến môi trường, xem `backend/.env.example`)

| Biến | Ý nghĩa |
|---|---|
| `PAYMENT_BANK_BIN` | Mã BIN ngân hàng nhận tiền (ACB = 970416; danh sách: https://api.vietqr.io/v2/banks) |
| `PAYMENT_BANK_NAME` | Tên ngân hàng hiển thị |
| `PAYMENT_ACCOUNT_NO` | Số tài khoản nhận tiền (webhook sai số này bị bỏ qua) |
| `PAYMENT_ACCOUNT_NAME` | Tên chủ tài khoản (không dấu, viết hoa) |
| `SEPAY_WEBHOOK_KEY` | Khoá bí mật dài, ngẫu nhiên; **bắt buộc**, để trống thì webhook từ chối mọi yêu cầu |
| `PAYMENT_ENABLED` | `false` để tắt tạo đơn |
| `PAYMENT_ORDER_TTL_MINUTES` | Hạn thanh toán của đơn (mặc định 15) |
| `PAYMENT_LATE_GRACE_HOURS` | Thời gian ân hạn nhận tiền về muộn (mặc định 24) |
| `PAYMENT_MAX_ORDERS_PER_HOUR` | Số đơn tối đa một người tạo trong một giờ (mặc định 10) |

Thiếu thông tin tài khoản nhận thì tạo đơn trả 503.

## Cài SePay

1. Vào https://my.sepay.vn, liên kết tài khoản ngân hàng nhận tiền.
2. Mục **Tích hợp Webhooks** > thêm webhook:
   - URL: `https://<tên-miền-backend>/api/v1/payments/webhook/sepay`
   - Kiểu chứng thực: **API Key**, nhập đúng giá trị `SEPAY_WEBHOOK_KEY` (SePay sẽ gửi header `Authorization: Apikey <khoá>`).
   - Chỉ gửi khi **tiền vào**.
3. Backend phải truy cập được từ Internet (ngrok / Cloudflare Tunnel khi chạy thử, xem `tools/phone-test`).

Webhook luôn trả `200 {"success": true}` cho giao dịch hợp lệ (kể cả không khớp đơn nào) để SePay không gửi lại vô ích;
sai khoá trả 401; lỗi tạm thời (DB...) trả 5xx để SePay gửi lại.

## Chạy migration

`ddl-auto: update` (dev) tự thêm cột và bảng, **nhưng không sửa ràng buộc CHECK** của cột `status`, nên cả dev lẫn prod
đều cần chạy tay một lần:

```
backend/src/main/resources/payment-migration.sql
```

Không chạy file này thì lưu đơn có trạng thái mới (`EXPIRED`, `NEEDS_REVIEW`) sẽ bị cơ sở dữ liệu từ chối.

## Xử lý tình huống

| Tình huống | Cách xử lý |
|---|---|
| Khách chuyển thiếu | Đơn thành `NEEDS_REVIEW`, ghi số đã nhận. Khách chuyển bù đúng nội dung thì tự kích hoạt khi đủ; hoặc admin duyệt tay |
| Khách chuyển sai nội dung | Giao dịch ghi sổ cái trạng thái `UNMATCHED`. Admin đối chiếu rồi **duyệt tay** đơn của khách (ghi lý do) |
| Khách chuyển hai lần cho cùng đơn | Lần hai ghi `EXTRA_PAYMENT`, không cộng hạn thêm; cần hoàn tiền thủ công |
| Tiền về sau 24 giờ | Đơn thành `NEEDS_REVIEW` (`LATE`); admin quyết định |
| Webhook bị mất | Admin duyệt tay đơn sau khi đối chiếu sao kê |

Duyệt tay: trang Admin Web, tab **Giao dịch**, nút **Duyệt tay** (bắt buộc ghi lý do; người duyệt được lưu trong
`confirmed_by` và `note`). API: `POST /api/v1/admin/payments/{mã đơn}/confirm` `{ "note": "..." }`.

## Thử nghiệm

- Tạo một gói thử giá nhỏ (vd. 2.000đ) trong trang Admin, **không dùng cho người dùng thật**, rồi mua và chuyển khoản thật.
- Thử webhook bằng curl (khoá lấy từ `.env`, tuyệt đối không dán khoá vào tài liệu hay chat):

```
curl -X POST https://<tên-miền>/api/v1/payments/webhook/sepay \
  -H "Authorization: Apikey $SEPAY_WEBHOOK_KEY" -H "Content-Type: application/json" \
  -d '{"id":1,"transferType":"in","transferAmount":2000,"accountNumber":"<số tài khoản>","content":"JLSPxxxxxxxx"}'
```

## Bảo mật (điều đã chủ ý)

- Mọi API thanh toán cần đăng nhập, người dùng lấy từ token; không nhận `userId` từ body, header hay tham số.
- Chỉ webhook đã xác thực khoá hoặc admin mới đổi đơn thành công; `GET` đơn không bao giờ kích hoạt gói.
- Mỗi giao dịch ngân hàng (`gateway` + `external_id`) chỉ ghi một lần nhờ ràng buộc duy nhất: gửi lại không cộng hạn thêm.
- Phải đủ tiền; thiếu thì cộng dồn chứ không kích hoạt.
- Khoá dòng đơn và dòng người dùng khi kích hoạt để hai xử lý đồng thời không cộng hạn hai lần.
- `SecurityMatrixTest` kiểm tra các đường dẫn thanh toán cũ (`/confirm`, `/approve`, `/sepay-token`, alias
  `/api/v1/subscriptions/**`, `/api/payment/**`) không được mở lại.
