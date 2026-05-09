# Pet Shop Home Filter Task List

## Mục tiêu
Trích xuất các việc cần làm từ kế hoạch trang chủ và bộ lọc của Pet Shop, đồng thời liệt kê các file liên quan để triển khai mà không làm mất các chức năng đã có.

## Tình trạng hiện tại
- `HomePage` đã load dữ liệu từ `PetRepository` và `ProductRepository`.
- `AppHeader` đã có nút menu góc trái, nhưng chưa gắn drawer filter.
- App đã có giỏ hàng, thông báo, trang danh sách thú cưng và cửa hàng.
- Database hiện tại chưa đủ field để lọc nâng cao theo giống, màu lông, kích thước và loại sản phẩm.

## Todo List

### 1. Chuẩn hóa dữ liệu và model
- [ ] Tách thông tin `PetType` để phân biệt chó và mèo rõ ràng.
- [ ] Thêm field `breed` cho thú cưng.
- [ ] Thêm field `coatColor` cho thú cưng.
- [ ] Thêm field `size` cho thú cưng.
- [ ] Thêm field `imageUrl` cho thú cưng và sản phẩm nếu cần.
- [ ] Thêm field `isFeatured` hoặc `sortOrder` nếu muốn ưu tiên item nổi bật.
- [ ] Thêm field `targetPetType` hoặc `suitableFor` cho sản phẩm.
- [ ] Chuẩn hóa danh mục sản phẩm thành nhóm chó, mèo, dùng chung.

### 2. Trang chủ
- [ ] Tách trang chủ thành 2 khối chính: thú cưng và sản phẩm.
- [ ] Hiển thị danh mục rõ ràng ngay trên home.
- [ ] Tách gợi ý thú cưng và gợi ý sản phẩm thành 2 section riêng.
- [ ] Làm section horizontal scroll cho từng nhóm.
- [ ] Thêm hiệu ứng trượt ngang hoặc auto-scroll nhẹ.
- [ ] Thêm nút xem tất cả cho từng nhóm.
- [ ] Giữ UI mobile không bị tràn và dễ đọc.

### 3. Lọc và sắp xếp thú cưng
- [ ] Lọc theo `PetType`.
- [ ] Lọc theo `breed`.
- [ ] Lọc theo `coatColor`.
- [ ] Lọc theo `size`.
- [ ] Sắp xếp theo giá tăng dần và giảm dần.
- [ ] Thêm nút xóa toàn bộ filter.
- [ ] Đồng bộ filter giữa home, list page và drawer.

### 4. Lọc và sắp xếp sản phẩm
- [ ] Lọc theo nhóm sản phẩm: chó, mèo, all.
- [ ] Sắp xếp theo giá tăng dần và giảm dần.
- [ ] Tạo filter phụ nếu cần theo category hoặc mục đích sử dụng.
- [ ] Đồng bộ cách hiển thị giá trên mọi card.
- [ ] Đảm bảo load đúng nhóm sản phẩm.

### 5. Drawer filter trên header
- [ ] Gắn chức năng cho nút menu góc trái.
- [ ] Tạo drawer hoặc panel filter lớn cho toàn app.
- [ ] Trong drawer có filter cho thú cưng: chó, mèo, giống.
- [ ] Trong drawer có filter cho cửa hàng: chó, mèo, all, giá cả.
- [ ] Khi chọn filter thì danh sách hiện tại đổi ngay.
- [ ] Hiển thị trạng thái đang chọn để người dùng nhận biết.

### 6. Database và backend
- [ ] Kiểm tra lại schema bảng `Pet`.
- [ ] Kiểm tra lại schema bảng `Product`.
- [ ] Xác định cột nào có thể tái sử dụng và cột nào phải thêm mới.
- [ ] Thêm migration hoặc nâng version database nếu đang dùng SQLite local.
- [ ] Bổ sung index cho các trường lọc nhiều: loại thú cưng, giống, màu lông, kích thước, giá, nhóm sản phẩm.
- [ ] Nếu dữ liệu lấy từ Firebase hoặc API, cập nhật luôn format dữ liệu nguồn.

### 7. UI và trải nghiệm
- [ ] Làm card item thống nhất giữa pet và product.
- [ ] Hiển thị rõ tên, ảnh, giá, tag danh mục.
- [ ] Làm empty state khi không có dữ liệu lọc.
- [ ] Giữ trải nghiệm mượt trên màn hình nhỏ.
- [ ] Kiểm tra nested scroll để tránh giật UI.

### 8. Kiểm thử
- [ ] Kiểm thử dữ liệu mẫu cho chó, mèo, sản phẩm chó, sản phẩm mèo, all.
- [ ] Kiểm thử sort tăng/giảm giá.
- [ ] Kiểm thử filter nhiều điều kiện cùng lúc.
- [ ] Kiểm thử trạng thái không có dữ liệu.
- [ ] Kiểm thử drawer filter nhiều lần liên tiếp.
- [ ] Kiểm thử responsive trên nhiều kích thước màn hình.

## File liên quan

### Màn hình và wrapper
- [ ] [lib/features/home/pages/home_page.dart](../lib/features/home/pages/home_page.dart)
- [ ] [lib/features/home/pages/pet_list_page.dart](../lib/features/home/pages/pet_list_page.dart)
- [ ] [lib/features/home/pages/shop_list_page.dart](../lib/features/home/pages/shop_list_page.dart)
- [ ] [lib/core/widgets/main_wrapper.dart](../lib/core/widgets/main_wrapper.dart)
- [ ] [lib/core/widgets/app_header.dart](../lib/core/widgets/app_header.dart)

### Repository và dữ liệu
- [ ] [lib/features/home/services/pet_repository.dart](../lib/features/home/services/pet_repository.dart)
- [ ] [lib/features/home/services/product_repository.dart](../lib/features/home/services/product_repository.dart)
- [ ] [lib/core/db/app_database.dart](../lib/core/db/app_database.dart)

### Tài liệu kế hoạch
- [ ] [docs/petshop_home_filters_todolist.md](petshop_home_filters_todolist.md)

## Gợi ý thứ tự làm
1. Chuẩn hóa model và database.
2. Làm filter logic trong repository/service.
3. Làm drawer menu filter lớn.
4. Tách home thành 2 khu vực rõ ràng.
5. Thêm horizontal scroll cho gợi ý.
6. Kiểm thử dữ liệu mẫu và responsive.

## Ghi chú
- Không xóa các chức năng đã có, chỉ bổ sung và mở rộng.
- Nếu dữ liệu hiện tại còn ít, có thể tạm thêm cột trực tiếp vào bảng `Pet` và `Product` để triển khai nhanh.
- Nếu dự án sẽ mở rộng lâu dài, nên chuẩn hóa dữ liệu bằng bảng danh mục riêng thay vì lưu text tự do.
