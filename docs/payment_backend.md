# Payment Backend

**Flutter:** `lib/features/cart/services/payment_service.dart`
**Backend:** `../payment_backend/controllers/payment.controller.js` (Node.js, port 3000)
**Cổng thanh toán:** PayOS

## Luồng dữ liệu

**Flutter → Payment Backend (Tạo link thanh toán):**
- `CartRepository.createPendingOrder(invoiceId, items, total)` → Firestore `orders/{invoiceId}` {status: "Pending"}
- `PaymentService.createPaymentLink(amount, orderId, items)` → POST `/api/payment/create` → `{amount, description, orderId, items}`
- Backend: validate amount>0 → payOS.paymentRequests.create(order) → `{checkoutUrl, orderCode, amount, description, status}`
- Flutter: mở WebView với checkoutUrl → user thanh toán

**Flutter → Payment Backend (Polling trạng thái):**
- Mỗi 3s, tối đa 2 phút: `PaymentService.getPaymentStatus(orderId)` → GET `/api/payment/status/{orderId}`
- Backend: payOS.paymentRequests.get(orderId) → `{orderCode, status, amount, transactionId}`
- status=="PAID" → `CartRepository.updateOrderToPaid(invoiceId)` → Firestore {status: "Paid"} → pop về
- status=="CANCELLED"/"FAILED" → hiển thị thông báo → pop về Unpaid
- Hết 2 phút → tự động pop về Unpaid

**Flutter → Payment Backend (Hủy):**
- POST `/api/payment/cancel/{orderId}` → payOS.paymentRequests.cancel(orderId) → pop về Unpaid

**Flutter → Payment Backend (Refund):**
- POST `/api/payment/refund` → `{orderId}` → kiểm tra status: PAID→cancel+hướng dẫn thủ công, PENDING→cancel link
