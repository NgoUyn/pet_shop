# Luồng Đăng Nhập (Login Flow)

## Luồng tổng quát: App giao tiếp với Firebase như thế nào?
App đăng nhập → Firebase Auth cấp thẻ (JWT token)
     ↓
App gửi request kèm thẻ lên Firestore
     ↓
Firestore Rules kiểm tra: "Có thẻ không?" 
     ↓
Có thẻ → OK. Không thẻ → Từ chối.
```
┌─────────────────────────────────────────────────────────────────────┐
│                        🟦 FLUTTER APP                               │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  UI: User thao tác (bấm nút, nhập liệu, ...)                 │  │
│  └──────────────────────┬────────────────────────────────────────┘  │
│                         │                                           │
│                         ▼                                           │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Gửi request + Token (JWT từ Firebase Auth)                   │  │
│  │  ──▶ Firebase Auth xác thực token                             │  │
│  │  ──▶ Firestore Rules kiểm tra quyền (request.auth != null?)   │  │
│  │  ──▶ Nếu hợp lệ → Firestore lưu/trả dữ liệu                  │  │
│  └──────────────────────┬────────────────────────────────────────┘  │
│                         │                                           │
│                         ▼                                           │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │  Flutter nhận JSON từ Firestore                                │  │
│  │                                                               │  │
│  │  Map JSON thành object Dart (Model)                           │  │
│  │  Ví dụ: {productName, price} → ProductItem(name, price)       │  │
│  │                                                               │  │
│  │  Hiển thị lên UI (ListView, GridView, ...)                    │  │
│  └───────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Tổng quan

Luồng đăng nhập có **2 bên** tham gia:

| Bên | Vai trò |
|-----|---------|
| **App (Flutter)** | Code Dart, UI, gọi Firebase Auth, lưu session vào SharedPreferences |
| **Firebase** | Firebase Auth xác thực email/password, trả về UserCredential |

App có **2 loại user**:
- **Customer** (khách hàng) → Đăng nhập qua Firebase Auth (email/password hoặc Google)
- **Admin** (quản trị) → Đăng nhập bằng cách so sánh password trong SQLite local (không qua Firebase)

---

## Sơ đồ luồng chi tiết

```
┌─────────────────────────────────────────────────────────────────┐
│  🟦 APP (Flutter)                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  UI Đăng nhập: User nhập Email, Mật khẩu                  │  │
│  └──────────────────────┬────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AuthRepository.login(email, password)                     │  │
│  │                                                           │  │
│  │  1. Chuẩn hóa email (lowercase, trim)                     │  │
│  │                                                           │  │
│  │  2. Kiểm tra: Có phải tài khoản ADMIN không?              │  │
│  │     (Tra trong SQLite: Role = 'admin')                    │  │
│  │     ├── CÓ → So sánh password với SQLite                  │  │
│  │     │       ├── Đúng → Đăng nhập (không qua Firebase)    │  │
│  │     │       └── Sai  → Báo lỗi                            │  │
│  │     └── KHÔNG → Tiếp tục bước 3 (đăng nhập Firebase)     │  │
│  │                                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Nhánh A: Đăng nhập ADMIN

```
┌─────────────────────────────────────────────────────────────────┐
│  🟦 APP (Flutter) - ADMIN                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  Admin đã xác thực password với SQLite local              │  │
│  │                                                           │  │
│  │  3a. AuthSession.signIn(userId)                           │  │
│  │      → Lưu userId vào SharedPreferences                   │  │
│  │                                                           │  │
│  │  4a. ✅ Đăng nhập ADMIN thành công                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### Nhánh B: Đăng nhập CUSTOMER (qua Firebase)

```
┌─────────────────────────────────────────────────────────────────┐
│  🟦 APP (Flutter) - CUSTOMER                                    │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  3b. GỌI FIREBASE: signInWithEmailAndPassword() ──────────┼──┼──┐
│  └───────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
                                                                     ▼
              ┌──────────────────────────────────────────────────────────┐
              │  🔴 FIREBASE AUTH                                        │
              │                                                          │
              │  4b. Nhận request từ App                                 │
              │  5b. Kiểm tra email + password trên cloud                │
              │      ├── Sai → Báo lỗi "Tài khoản không tồn tại..."     │
              │      └── Đúng → Trả về UserCredential ──────────────┐    │
              │                                                      │    │
              └──────────────────────────────────────────────────────┘    │
                                                                          │
┌─────────────────────────────────────────────────────────────────┐       │
│  🟦 APP (Flutter)                                               │       │
│  ┌───────────────────────────────────────────────────────────┐  │       │
│  │  6b. Nhận UserCredential từ Firebase                      │◄─┼───────┘
│  │                                                           │  │
│  │  7b. Reload user để lấy trạng thái mới nhất               │  │
│  │      await user.reload()                                  │  │
│  │                                                           │  │
│  │  8b. Kiểm tra: user.emailVerified == true ?               │  │
│  │      ├── FALSE → Báo lỗi "Chưa xác thực email"            │  │
│  │      └── TRUE  → Tiếp tục                                 │  │
│  │                                                           │  │
│  │  9b. _ensureLocalUserFromFirebase(firebaseUser):          │  │
│  │      a. Tìm user trong SQLite theo email                  │  │
│  │         ├── Có  → Cập nhật FirebaseUID, Role, ...         │  │
│  │         └── Không → Tạo mới user + customer trong SQLite  │  │
│  │                                                           │  │
│  │      b. GỌI FIRESTORE: đọc collection 'users' ────────────┼──┼──┐
│  │         (kiểm tra role admin từ Firestore)                │  │  │
│  │                                                           │  │  │
│  │      c. Xóa PendingRegistration khỏi SharedPreferences    │  │  │
│  │                                                           │  │  │
│  │  10b. AuthSession.signIn(userId)                          │  │  │
│  │       → Lưu userId vào SharedPreferences                  │  │  │
│  │                                                           │  │  │
│  │  11b. ✅ Đăng nhập CUSTOMER thành công                    │  │  │
│  └───────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
                                                                     ▼
              ┌──────────────────────────────────────────────────────────┐
              │  🔴 FIRESTORE                                            │
              │                                                          │
              │  12b. Nhận request từ App                                │
              │  13b. Kiểm tra Firestore Rules: request.auth != null?    │
              │       ├── Không → TỪ CHỐI (PERMISSION_DENIED)           │
              │       └── Có  → Trả về document 'users/{uid}'           │
              │                                                          │
              └──────────────────────────────────────────────────────────┘
```

---

## Đăng nhập bằng Google

```
┌─────────────────────────────────────────────────────────────────┐
│  🟦 APP (Flutter)                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  User bấm "Đăng nhập bằng Google"                         │  │
│  │                                                           │  │
│  │  1. GỌI FIREBASE: signInWithPopup(GoogleAuthProvider)     │  │
│  │     (Web) hoặc signInWithProvider(GoogleAuthProvider)     │  │
│  │     (Mobile)                                              │  │
│  └──────────────────────┬────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  2. Firebase hiện popup chọn tài khoản Google             │  │
│  │  3. User chọn tài khoản → Firebase xác thực               │  │
│  │  4. Trả về UserCredential (không cần emailVerified)       │  │
│  │                                                           │  │
│  │  5. _ensureLocalUserFromFirebase(firebaseUser):           │  │
│  │     (giống bước 9b ở trên)                                │  │
│  │                                                           │  │
│  │  6. AuthSession.signIn(userId)                            │  │
│  │  7. ✅ Đăng nhập Google thành công                        │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Tổng hợp: Bước nào thuộc App, bước nào thuộc Firebase?

| Bước | Nội dung | Thuộc |
|------|----------|-------|
| 1 | User nhập email/password trên UI | 🟦 **App** |
| 2 | Kiểm tra admin trong SQLite | 🟦 **App** |
| 3a | Admin: AuthSession.signIn() | 🟦 **App** |
| 3b | Gọi `signInWithEmailAndPassword()` | 🟦 **App** gọi → 🔴 **Firebase** xử lý |
| 4b-5b | Firebase xác thực, trả về UserCredential | 🔴 **Firebase** |
| 6b | App nhận UserCredential | 🟦 **App** |
| 7b | Reload user | 🟦 **App** |
| 8b | Kiểm tra `emailVerified` | 🟦 **App** |
| 9b-a | Tìm/tạo user trong SQLite | 🟦 **App** |
| 9b-b | Gọi Firestore đọc collection 'users' | 🟦 **App** gọi → 🔴 **Firestore** trả về |
| 9b-c | Xóa PendingRegistration | 🟦 **App** |
| 10b | Lưu userId vào SharedPreferences | 🟦 **App** |
| 11b | ✅ Đăng nhập thành công | 🟦 **App** |

---

## Tóm tắt bằng hình ảnh

```
┌────────── NHÁNH ADMIN ─────────────────────────────────────┐
│  App kiểm tra SQLite → password đúng → Đăng nhập thẳng     │
│  (Không gọi Firebase)                                      │
└────────────────────────────────────────────────────────────┘

┌────────── NHÁNH CUSTOMER ──────────────────────────────────┐
│  🟦 APP                          🔴 FIREBASE               │
│  login() ──signInWithEmailAndPassword──▶  Xác thực         │
│           ◀────UserCredential──────────                    │
│  Kiểm tra emailVerified                                   │
│  _ensureLocalUserFromFirebase()                            │
│  AuthSession.signIn()                                      │
│  ✅ Đăng nhập thành công                                   │
└────────────────────────────────────────────────────────────┘
```

---

## Các file code tương ứng

| File | Thuộc | Chức năng |
|------|-------|-----------|
| `lib/features/auth/services/auth_repository.dart` | 🟦 App | Xử lý login, phân biệt admin/customer, gọi Firebase Auth |
| `lib/features/auth/services/auth_session.dart` | 🟦 App | Quản lý trạng thái đăng nhập (userId trong SharedPreferences) |
| `lib/features/auth/services/pending_registration_store.dart` | 🟦 App | Lưu tạm thông tin đăng ký (xóa sau khi login thành công) |
| Firebase Auth SDK (`firebase_auth`) | 🔴 Firebase | Xác thực email/password, Google, trả về UserCredential |
| Firebase Firestore (`cloud_firestore`) | 🔴 Firebase | Lưu role admin trong collection 'users' |
