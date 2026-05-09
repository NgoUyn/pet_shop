# Todo List: Trang chủ, gợi ý ngang và bộ lọc nâng cao cho Pet Shop

## Mục tiêu
Xây dựng lại trải nghiệm trang chủ và luồng lọc để đáp ứng 4 yêu cầu chính:

1. Hiển thị gợi ý động vật và sản phẩm theo dạng lướt ngang từ phải sang trái.
2. Trang chủ hiển thị rõ 2 nhóm nội dung: thú cưng và vật phẩm cho thú cưng theo từng danh mục.
3. Có lọc và sắp xếp theo giá; riêng thú cưng có thêm lọc theo kích thước, màu lông, giống.
4. Nút menu ba gạch ở góc trái mở bộ lọc lớn cho toàn app: chó, mèo, cửa hàng, giá cả.

## Trạng thái hiện tại

- Đã có nền tảng home với `HomePage` load dữ liệu từ `PetRepository` và `ProductRepository`.
- Đã có header chung trong `AppHeader` và có nút menu góc trái, nhưng chưa gắn drawer filter.
- Đã có luồng giỏ hàng, thông báo, trang danh sách pet và shop, nên không cần xóa hay thay thế các chức năng đó.
- Chưa có bộ lọc chuẩn hóa theo giống, màu lông, kích thước, loại sản phẩm và sắp xếp theo giá.

Mục tiêu khi hoàn thành todolist này là bổ sung tính năng mới mà không phá vỡ các luồng hiện có.

---

## 1. Chuẩn bị dữ liệu và chuẩn hóa model

### Việc cần làm
- [x] Rà soát lại model `Pet` và `Product` hiện có.
- [x] Xác định dữ liệu nào đang nằm trong `Species`, `Description` nhưng cần tách ra thành field riêng.
- [ ] Chuẩn hóa cách lưu `PetType` để phân biệt rõ chó / mèo.
- [ ] Thêm field cho thú cưng:
  - [ ] `breed` / giống
  - [ ] `coatColor` / màu lông
  - [ ] `size` / kích thước
  - [ ] `imageUrl`
  - [ ] `isFeatured` hoặc `sortOrder` nếu cần item nổi bật
- [ ] Thêm field cho sản phẩm:
  - [ ] `targetPetType` hoặc `suitableFor`
  - [ ] `imageUrl` nếu chưa đủ dữ liệu ảnh
  - [ ] `isFeatured` nếu muốn đẩy sản phẩm nổi bật lên đầu
- [ ] Chuẩn hóa danh mục sản phẩm thành các nhóm rõ ràng: sản phẩm cho chó, sản phẩm cho mèo, dùng chung.

### Kết quả mong đợi
- Dữ liệu đủ để lọc đúng theo giống, màu lông, kích thước, loại thú cưng và loại sản phẩm.
- Không còn phải suy luận filter chỉ từ `Species` hoặc mô tả text.

---

## 2. Làm trang chủ theo từng khu vực nội dung

### Việc cần làm
- [ ] Tách trang chủ thành 2 khối chính:
  - [ ] Khối thú cưng
  - [ ] Khối cửa hàng / sản phẩm
- [ ] Hiển thị các danh mục rõ ràng ngay trên home.
- [x] Có nền tảng section gợi ý trên `HomePage`.
- [ ] Tách thành 2 section riêng biệt thay vì trộn chung.
- [ ] Tạo section gợi ý động vật dạng horizontal scroll.
- [ ] Tạo section gợi ý sản phẩm dạng horizontal scroll.
- [ ] Đảm bảo 2 section này có hiệu ứng trượt ngang từ phải sang trái hoặc auto-scroll nhẹ.
- [ ] Thêm nút xem tất cả cho từng nhóm.
- [ ] Bảo đảm UI trên mobile không bị tràn và vẫn đọc được tên, giá, hình.

### Kết quả mong đợi
- Người dùng mở app là thấy ngay 2 luồng chính: mua thú cưng và mua sản phẩm.
- Gợi ý ngang tạo cảm giác “bán hàng” rõ ràng hơn thay vì danh sách tĩnh.

---

## 3. Bộ lọc và sắp xếp cho thú cưng

### Việc cần làm
- [ ] Tạo bộ lọc theo `PetType` để tách chó và mèo.
- [ ] Tạo bộ lọc theo `breed`.
- [ ] Tạo bộ lọc theo `coatColor`.
- [ ] Tạo bộ lọc theo `size`.
- [ ] Tạo sắp xếp theo giá tăng dần và giảm dần.
- [ ] Có nút xóa toàn bộ filter.
- [ ] Đồng bộ filter giữa home, trang danh sách và drawer nếu dùng chung luồng.

### Kết quả mong đợi
- Có thể lọc thú cưng theo tiêu chí thực tế người dùng hay tìm.
- Sort theo giá hoạt động ổn định, không ảnh hưởng đến filter khác.

---

## 4. Bộ lọc và sắp xếp cho sản phẩm

### Việc cần làm
- [ ] Tạo lọc theo nhóm sản phẩm: chó, mèo, all.
- [ ] Tạo sắp xếp theo giá tăng dần và giảm dần.
- [ ] Nếu cần, thêm lọc theo category phụ hoặc mục đích sử dụng.
- [ ] Đồng bộ cách hiển thị giá trên mọi card.
- [ ] Đảm bảo sản phẩm load đúng theo phân loại, không lấy nhầm nhóm.

### Kết quả mong đợi
- Người dùng dễ tìm đúng sản phẩm theo đối tượng sử dụng.
- Danh sách sản phẩm có thể lọc nhanh mà không cần vào nhiều màn hình.

---

## 5. Nút menu ba gạch ở header

### Việc cần làm
- [x] Có sẵn nút menu góc trái trên header.
- [ ] Gắn chức năng cho nút menu góc trái trên header.
- [ ] Tạo drawer hoặc panel filter lớn cho toàn app.
- [ ] Trong drawer có 2 cụm chính:
  - [ ] Thú cưng: chó, mèo, lọc theo giống
  - [ ] Cửa hàng: sản phẩm cho chó, sản phẩm cho mèo, all, giá cả
- [ ] Khi bấm một mục trong drawer, danh sách hiện tại phải đổi theo filter.
- [ ] Có trạng thái đang chọn để người dùng biết filter nào đang bật.

### Kết quả mong đợi
- Drawer trở thành bộ lọc tổng điều hướng chính cho app.
- Người dùng không phải tìm filter ở nhiều nơi khác nhau.

---

## 6. Chuẩn bị cho backend / database

### Việc cần làm
- [x] Kiểm tra lại schema bảng `Pet`.
- [x] Kiểm tra lại schema bảng `Product`.
- [ ] Xác định cột nào cần thêm mới, cột nào có thể tái sử dụng.
- [ ] Thêm migration hoặc nâng version database nếu app đang dùng SQLite local.
- [ ] Bổ sung index cho các trường hay lọc:
  - [ ] loại thú cưng
  - [ ] giống
  - [ ] màu lông
  - [ ] kích thước
  - [ ] giá
  - [ ] nhóm sản phẩm
- [ ] Nếu dữ liệu đồng bộ từ Firebase hoặc API, cần cập nhật luôn format dữ liệu nguồn.

### Nên cải thiện gì ở database
- Bảng `Pet` hiện tại chưa đủ field để lọc nâng cao.
- Bảng `Product` cũng chưa thể hiện rõ sản phẩm dành cho chó hay mèo nếu chỉ dựa vào tên hoặc mô tả.
- Nếu app có admin nhập dữ liệu, nên chuẩn hóa ngay từ đầu để tránh dữ liệu rác sau này.

### Gợi ý schema tối thiểu
- `Pet`:
  - `PetType`
  - `Breed`
  - `CoatColor`
  - `Size`
  - `ImageURL`
  - `IsFeatured`
- `Product`:
  - `TargetPetType`
  - `ImageURL`
  - `IsFeatured`

---

## 7. Đồng bộ UI và trải nghiệm

### Việc cần làm
- [ ] Làm card item thống nhất giữa pet và product.
- [ ] Hiển thị rõ tên, ảnh, giá, tag danh mục.
- [ ] Khi chưa có dữ liệu lọc, hiển thị trạng thái empty state thân thiện.
- [ ] Giữ trải nghiệm mượt trên điện thoại màn hình nhỏ.
- [ ] Kiểm tra scroll ngang, scroll dọc, và nested scroll để tránh giật UI.

### Kết quả mong đợi
- Giao diện thống nhất, dễ dùng, rõ ràng.
- Tránh tình trạng filter có nhưng UI khó hiểu hoặc khó thao tác.

---

## 8. Kiểm thử

### Việc cần làm
- [ ] Kiểm thử dữ liệu mẫu cho chó, mèo, sản phẩm chó, sản phẩm mèo, all.
- [ ] Kiểm thử sort tăng/giảm giá.
- [ ] Kiểm thử filter nhiều điều kiện cùng lúc.
- [ ] Kiểm thử trạng thái không có dữ liệu.
- [ ] Kiểm thử mở drawer và chọn filter nhiều lần liên tiếp.
- [ ] Kiểm thử responsive trên nhiều kích thước màn hình.

### Kết quả mong đợi
- Không còn lỗi lọc sai dữ liệu.
- UI không vỡ khi danh sách dài hoặc khi không có item.

---

## Thứ tự triển khai khuyến nghị

1. Chuẩn hóa model và database.
2. Làm filter logic ở repository hoặc service.
3. Làm drawer menu filter lớn.
4. Tách trang chủ thành 2 nhóm nội dung rõ ràng.
5. Làm section gợi ý ngang cho pet và product.
6. Viết test và kiểm tra dữ liệu mẫu.

---

## Ghi chú kỹ thuật
- Nếu dữ liệu hiện tại còn ít, có thể tạm thêm cột trực tiếp vào bảng `Pet` và `Product` để triển khai nhanh.
- Nếu dự án sẽ mở rộng lâu dài, nên chuẩn hóa dữ liệu bằng bảng danh mục riêng thay vì lưu text tự do.
- Bộ lọc sẽ ổn định hơn nếu mỗi tiêu chí là một giá trị chuẩn hóa, không phụ thuộc vào cách người nhập mô tả.

- mô tả của thú cưng được sử dụng thành các thẻ: tính cách, tình trạng tieem phòng, giới tính, tuổi, tình trạng tẩy giun
