Tài liệu này mô tả lại giao diện **Admin mobile** theo hướng dễ điều hướng, đúng nghiệp vụ và phù hợp với cửa hàng thú cưng một chi nhánh.

---

## 1. Mục tiêu giao diện

- Header gọn, thao tác nhanh.
- Mục lục dạng danh sách để quản trị viên truy cập chức năng rõ ràng.
- Footer chỉ giữ các mục dùng thường xuyên nhất.
- Nhóm sản phẩm phải tách rõ giữa thú cưng và phụ kiện.
- Màu sắc cần thân thiện, tin cậy, không quá chói.

---

## 2. Cấu trúc màn hình tổng thể

### Header

- Bên trái: nút 3 gạch để mở mục lục.
- Bên phải: icon thông báo và icon tin nhắn.
- Trung tâm: có thể để tiêu đề ngắn của màn đang mở hoặc logo cửa hàng nếu cần.

Gợi ý bố cục:

```text
┌────────────────────────────────────┐
│ ☰   [Tiêu đề / Logo]        🔔 💬   │
└────────────────────────────────────┘
```

### Mục lục

Mục lục nên ưu tiên theo quy trình vận hành của shop, từ việc xử lý đơn đến quản lý dữ liệu và khuyến mãi:

1. Trang chủ
2. Quản lí đơn hàng
3. Quản lí kho
4. Quản lí khách hàng
5. Quản lí ưu đãi
6. Điểm
7. Quản lí sản phẩm
8. Tài khoản
9. Đăng xuất

Trong đó, **Quản lí sản phẩm** nên có 2 mục con:

- Thú cưng
- Phụ kiện

Nếu muốn hợp lý hơn về nghiệp vụ, có thể hiển thị như sau:

```text
Trang chủ
Quản lí đơn hàng
Quản lí kho
Quản lí khách hàng
Quản lí ưu đãi
Điểm
Quản lí sản phẩm
	├─ Thú cưng
	└─ Phụ kiện
Tài khoản
Đăng xuất
```

### Footer

Footer chỉ nên giữ 3 nhóm chính:

- Trang chủ
- Phân tích
- Cài đặt

Trong mục Cài đặt, gom các hành động phụ:

- Tài khoản
- Đăng xuất

Gợi ý bố cục footer:

```text
[ Trang chủ ] [ Phân tích ] [ Cài đặt ]
											└─ Tài khoản
											└─ Đăng xuất
```

---

## 3. Wireframe đề xuất

### 3.1 Trang chủ admin

```text
┌────────────────────────────────────┐
│ ☰   Admin Home              🔔 💬   │
├────────────────────────────────────┤
│ KPI: Đơn hàng | Doanh thu | Điểm   │
│ KPI: Khách hàng | Tồn kho | Ưu đãi  │
├────────────────────────────────────┤
│ Cảnh báo nhanh                      │
│ - Đơn chờ xử lý                     │
│ - Sản phẩm sắp hết hàng             │
│ - Tin nhắn chờ phản hồi             │
├────────────────────────────────────┤
│ Lối tắt nghiệp vụ                   │
│ [Đơn hàng] [Kho] [Khách hàng]       │
│ [Ưu đãi]  [Điểm]   [Sản phẩm]       │
└────────────────────────────────────┘

[ Trang chủ ] [ Phân tích ] [ Cài đặt ]
```

### 3.2 Quản lí đơn hàng

Ưu tiên các trạng thái theo vòng đời xử lý:

1. Chờ xác nhận
2. Chờ lấy hàng
3. Đang giao
4. Đã giao
5. Đã hủy
6. Đánh giá

Gợi ý hiển thị:

```text
┌────────────────────────────────────┐
│ ☰   Quản lí đơn hàng         🔔 💬  │
├────────────────────────────────────┤
│ [Chờ xác nhận] [Chờ lấy hàng]      │
│ [Đang giao] [Đã giao] [Đã hủy]     │
├────────────────────────────────────┤
│ Danh sách đơn theo trạng thái       │
└────────────────────────────────────┘
```

### 3.3 Quản lí kho

Nên tập trung vào tồn kho và cảnh báo:

- Tồn kho thấp
- Sắp hết hàng
- Hết hàng
- Hàng nhập mới

### 3.4 Quản lí khách hàng

Nên có:

- Thông tin khách hàng
- Lịch sử mua hàng
- Điểm tích lũy
- Phân nhóm khách hàng

### 3.5 Quản lí ưu đãi

Nên tách:

- Đang áp dụng
- Sắp diễn ra
- Đã kết thúc

### 3.6 Điểm

Màn này chỉ nên làm rõ:

- Điểm đã phát
- Điểm còn lại của khách
- Quy đổi điểm
- Lịch sử cộng / trừ điểm

### 3.7 Quản lí sản phẩm

Quản lí sản phẩm cần tách thành 2 mục con rõ ràng:

- Thú cưng
- Phụ kiện

Nếu chọn mục con Thú cưng, nên hiện thêm:

- Tên thú cưng
- Loại
- Giá
- Số lượng
- Trạng thái

Nếu chọn mục con Phụ kiện, nên hiện thêm:

- Tên phụ kiện
- Danh mục
- Giá
- Tồn kho
- Trạng thái

---

## 4. Gợi ý màu sắc

Màu nên hướng tới cảm giác **sạch, thân thiện, tin cậy, ấm áp**.

### Bộ màu chính

| Tên màu | Mã HEX | Dùng cho |
|---|---|---|
| Xanh lá dịu | `#3A7D44` | Header, CTA chính, tab đang chọn |
| Xanh mint nhạt | `#5FBF72` | Badge, trạng thái tích cực |
| Xanh nền nhạt | `#EAF7EC` | Nền highlight, card nhẹ |

### Bộ màu phụ

| Tên màu | Mã HEX | Dùng cho |
|---|---|---|
| Cam ấm | `#F4A261` | Ưu đãi, điểm thưởng, nhấn nhẹ |
| Vàng cảnh báo | `#FFB703` | Chờ xử lý, lưu ý |
| Đỏ lỗi | `#E63946` | Hủy, xóa, cảnh báo quan trọng |

### Bộ màu trung tính

| Tên màu | Mã HEX | Dùng cho |
|---|---|---|
| Trắng | `#FFFFFF` | Card, nền chính |
| Xám nền | `#F8F9FA` | Nền tổng thể |
| Xám viền | `#E9ECEF` | Border, divider |
| Xám chữ phụ | `#6C757D` | Mô tả, thời gian |
| Xám chữ chính | `#212529` | Tiêu đề, nội dung chính |

### Quy ước áp dụng nhanh

| Thành phần | Màu khuyên dùng |
|---|---|
| Header | `#3A7D44` |
| Footer active | `#3A7D44` |
| Footer inactive | `#6C757D` |
| Card nền | `#FFFFFF` |
| Nền tổng thể | `#F8F9FA` |
| Nút xác nhận | `#3A7D44` |
| Nút ưu đãi / điểm | `#F4A261` |
| Nút hủy / xóa | `#E63946` |
| Badge cảnh báo | `#FFB703` |

---

## 5. Gợi ý triển khai UI

- Giữ header và footer cố định, nội dung cuộn ở giữa.
- Mục lục mở bằng drawer hoặc bottom sheet, tùy code hiện tại.
- Với quản lí sản phẩm, nên hiển thị 2 tab con thay vì 1 danh sách lẫn lộn.
- Các hành động nguy hiểm như xóa, hủy đơn, tắt ưu đãi nên dùng màu đỏ.
- Các hành động tạo mới hoặc khuyến mãi nên dùng màu cam ấm để tránh quá gắt.

---

## 6. Kết luận

Thiết kế phù hợp nhất cho admin mobile ở dự án này là:

- Header: menu trái, thông báo + chat phải.
- Mục lục: ưu tiên nghiệp vụ, có nhóm sản phẩm con.
- Footer: Trang chủ, Phân tích, Cài đặt.
- Màu sắc: xanh lá dịu làm chủ đạo, cam ấm cho ưu đãi, đỏ cho thao tác nguy hiểm.

