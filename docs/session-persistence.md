# Luồng lưu & phục hồi phiên đăng nhập

Mô tả ngắn: Khi người dùng đăng nhập, app lưu thông tin phiên cục bộ và (nếu dùng Firebase) Firebase SDK cũng tự duy trì session. Khi app mở lại, app đọc lại dữ liệu này và phục hồi trạng thái đăng nhập.

## Các bước chính

- Đăng nhập:
  - `AuthRepository.login()` hoặc `signInWithGoogle()` thực hiện xác thực.
  - Sau khi xác thực thành công, `AuthRepository` gọi `AuthSession.instance.signIn(userId)` để lưu `userId` vào `SharedPreferences` (khóa `auth.current_user_id`).
  - Với Firebase user, `_ensureLocalUserFromFirebase()` sẽ ghi thông tin user vào SQLite (cột `PasswordHash` cho admin được lưu cục bộ).

- Khởi động app:
  - `main()` gọi `AuthSession.instance.load()` trước khi khởi chạy UI.
  - `AuthSession.load()` đọc `auth.current_user_id` từ `SharedPreferences` và đặt `AuthSession.instance.currentUserId` (ValueNotifier) — UI và repository dùng giá trị này để biết trạng thái đang đăng nhập.
  - Nếu dùng Firebase, SDK sẽ tự giữ session/token; code có những chỗ gọi `FirebaseAuth.instance.currentUser` và `currentUser.reload()` để kiểm tra/đồng bộ lại trạng thái xác thực.

- Đăng xuất / xóa phiên:
  - `AuthRepository.instance.signOut()` gọi `FirebaseAuth.instance.signOut()` và `AuthSession.instance.signOut()` (xóa key trong `SharedPreferences`).
  - Ngoài ra có thể xóa toàn bộ DB SQLite hoặc gỡ cài đặt app để xóa `PasswordHash` và dữ liệu cục bộ.

## File liên quan (trong codebase)
- `lib/main.dart`
- `lib/features/auth/services/auth_session.dart`
- `lib/features/auth/services/auth_repository.dart`
- `lib/core/db/app_database.dart` (SQLite user table)
- `lib/features/chat/services/chat_repository.dart` (đồng bộ profile lên Firestore)

## Ghi chú bảo mật
- Mật khẩu không được ghi vào Firestore; chỉ lưu `PasswordHash` cục bộ trong SQLite (dùng cho admin/local fallback).
- Để xóa hoàn toàn phiên, gọi `AuthRepository.instance.signOut()` hoặc gỡ app/clear app data.

---
Ngắn gọn, dễ hiểu — cần bổ sung hướng dẫn xóa session hoặc hướng dẫn migration không?