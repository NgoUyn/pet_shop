Câu hỏi	Trả lời
App gửi lên Firestore thế nào?	Gọi .set() / .add() để ghi dữ liệu
Firestore xác thực app thế nào?	Dùng Firestore Rules kiểm tra request.auth != null
App nhận diện dữ liệu từ Firestore thế nào?	Gọi .where() để lọc, .doc().get() để lấy 1 cái, hoặc merge với SQLite