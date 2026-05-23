# Luồng Đăng Ký Tài Khoản (Register Flow)

**Giải thích từng bước:**
1. **Flutter App** gửi request lên Firebase (kèm token JWT của user đã đăng nhập)
2. **Firebase Auth** xác thực token (có phải user hợp lệ không?)
3. **Firestore Rules** kiểm tra quyền (user này có được đọc/ghi không?)
4. **Firestore** xử lý: lưu dữ liệu mới hoặc trả về dữ liệu có sẵn
5. **Flutter** nhận JSON → chuyển thành object Dart (Model) → đổ lên UI

---

## Tổng quan

Luồng đăng ký có **2 bên** tham gia:

| Bên | Vai trò |
|-----|---------|
| **App (Flutter)** | Code Dart trong project, xử lý UI, gọi API Firebase, lưu SQLite local |
| **Firebase** | Hệ thống cloud của Google (Firebase Auth + Firestore) |

---

## Sơ đồ luồng chi tiết (phân tách App vs Firebase)

```
┌─────────────────────────────────────────────────────────────────┐
│  🟦 APP (Flutter)                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  UI Đăng ký: User nhập Họ tên, Email, Mật khẩu            │  │
│  └──────────────────────┬────────────────────────────────────┘  │
│                         │                                       │
│                         ▼                                       │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  AuthRepository.registerCustomer(name, email, password)    │  │
│  │                                                           │  │
│  │  1. Chuẩn hóa email (lowercase, trim)                     │  │
│  │  2. Kiểm tra email trong SQLite local                     │  │
│  │     → Nếu có: Báo lỗi "Email đã được sử dụng"             │  │
│  │                                                           │  │
│  │  3. GỌI FIREBASE: createUserWithEmailAndPassword() ───────┼──┼──┐
│  └───────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
                                                                     ▼
              ┌──────────────────────────────────────────────────────────┐
              │  🔴 FIREBASE AUTH                                        │
              │                                                          │
              │  4. Nhận request từ App                                  │
              │  5. Tạo tài khoản mới trên cloud                         │
              │  6. Trả về UserCredential (có UID) ──────────────────┐   │
              │                                                      │   │
              └──────────────────────────────────────────────────────┘   │
                                                                         │
┌─────────────────────────────────────────────────────────────────┐      │
│  🟦 APP (Flutter)                                               │      │
│  ┌───────────────────────────────────────────────────────────┐  │      │
│  │  7. Nhận UserCredential từ Firebase                       │◄─┼──────┘
│  │                                                           │  │
│  │  8. Lưu PendingRegistration vào SharedPreferences         │  │
│  │     (lưu tạm: name, email, password, createdAt)           │  │
│  │                                                           │  │
│  │  9. GỌI FIREBASE: sendEmailVerification() ────────────────┼──┼──┐
│  │                                                           │  │  │
│  │  ⚠️ Chưa tạo user trong SQLite, chưa cho đăng nhập       │  │  │
│  └───────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
                                                                     ▼
              ┌──────────────────────────────────────────────────────────┐
              │  🔴 FIREBASE AUTH                                        │
              │                                                          │
              │  10. Gửi email xác thực đến hộp thư user                 │
              │                                                          │
              │  ┌──────────────────────────────────────────────┐        │
              │  │  From: Firebase Auth                          │        │
              │  │  To: user@email.com                           │        │
              │  │  Subject: Xác thực email cho Pet Shop         │        │
              │  │                                               │        │
              │  │  [Verify Email] ← Nhấn vào link này          │        │
              │  └──────────────────────────────────────────────┘        │
              │                                                          │
              │  11. User nhấn link → Firebase đánh dấu                  │
              │      emailVerified = true                                │
              │                                                          │
              └──────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────┐
│  🟦 APP (Flutter)                                               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │  User quay lại app và ĐĂNG NHẬP                           │  │
│  │                                                           │  │
│  │  AuthRepository.login(email, password)                    │  │
│  │                                                           │  │
│  │  12. GỌI FIREBASE: signInWithEmailAndPassword() ──────────┼──┼──┐
│  └───────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
                                                                     ▼
              ┌──────────────────────────────────────────────────────────┐
              │  🔴 FIREBASE AUTH                                        │
              │                                                          │
              │  13. Xác thực email + password                          │
              │  14. Trả về UserCredential (kèm emailVerified) ──────┐   │
              │                                                      │   │
              └──────────────────────────────────────────────────────┘   │
                                                                         │
┌─────────────────────────────────────────────────────────────────┐      │
│  🟦 APP (Flutter)                                               │      │
│  ┌───────────────────────────────────────────────────────────┐  │      │
│  │  15. Nhận UserCredential                                  │◄─┼──────┘
│  │                                                           │  │
│  │  16. Kiểm tra: user.emailVerified == true ?               │  │
│  │      ├── FALSE → Báo lỗi "Chưa xác thực email"            │  │
│  │      └── TRUE  → Tiếp tục                                 │  │
│  │                                                           │  │
│  │  17. _ensureLocalUserFromFirebase():                      │  │
│  │      a. Tìm user trong SQLite theo email                  │  │
│  │         ├── Có  → Cập nhật FirebaseUID, Role              │  │
│  │         └── Không → Tạo mới user + customer trong SQLite  │  │
│  │                                                           │  │
│  │      b. GỌI FIRESTORE: đọc collection 'users' ────────────┼──┼──┐
│  │         (để kiểm tra role admin)                          │  │  │
│  │                                                           │  │  │
│  │      c. Xóa PendingRegistration khỏi SharedPreferences    │  │  │
│  │                                                           │  │  │
│  │  18. AuthSession.signIn(userId) → Lưu userId vào          │  │  │
│  │      SharedPreferences                                    │  │  │
│  │                                                           │  │  │
│  │  19. ✅ Đăng nhập thành công                              │  │  │
│  └───────────────────────────────────────────────────────────┘  │  │
└─────────────────────────────────────────────────────────────────┘  │
                                                                     │
                                                                     ▼
              ┌──────────────────────────────────────────────────────────┐
              │  🔴 FIRESTORE                                            │
              │                                                          │
              │  20. Nhận request từ App                                 │
              │  21. Kiểm tra Firestore Rules: request.auth != null?     │
              │      ├── Không → TỪ CHỐI (PERMISSION_DENIED)            │
              │      └── Có  → Trả về document 'users/{uid}'            │
              │                                                          │
              └──────────────────────────────────────────────────────────┘
```

---

## Tổng hợp: Bước nào thuộc App, bước nào thuộc Firebase?

| Bước | Nội dung | Thuộc |
|------|----------|-------|
| 1 | User nhập thông tin trên UI | 🟦 **App** |
| 2 | Kiểm tra email trong SQLite local | 🟦 **App** |
| 3 | Gọi `createUserWithEmailAndPassword()` | 🟦 **App** gọi → 🔴 **Firebase** xử lý |
| 4-6 | Firebase tạo tài khoản, trả về UserCredential | 🔴 **Firebase** |
| 7 | App nhận UserCredential | 🟦 **App** |
| 8 | Lưu PendingRegistration vào SharedPreferences | 🟦 **App** |
| 9 | Gọi `sendEmailVerification()` | 🟦 **App** gọi → 🔴 **Firebase** gửi email |
| 10-11 | Firebase gửi email, user nhấn link xác thực | 🔴 **Firebase** |
| 12 | Gọi `signInWithEmailAndPassword()` | 🟦 **App** gọi → 🔴 **Firebase** xử lý |
| 13-14 | Firebase xác thực, trả về UserCredential | 🔴 **Firebase** |
| 15 | App nhận UserCredential | 🟦 **App** |
| 16 | Kiểm tra `emailVerified` | 🟦 **App** |
| 17a | Tìm/tạo user trong SQLite | 🟦 **App** |
| 17b | Gọi Firestore đọc collection 'users' | 🟦 **App** gọi → 🔴 **Firestore** trả về |
| 17c | Xóa PendingRegistration | 🟦 **App** |
| 18 | Lưu userId vào SharedPreferences | 🟦 **App** |
| 19 | ✅ Đăng nhập thành công | 🟦 **App** |

---

## Tóm tắt bằng hình ảnh

```
🟦 APP (Flutter)                          🔴 FIREBASE
─────────────────                        ────────────────
registerCustomer() ──createUserWithEmailAndPassword──▶  Tạo tài khoản
                    ◀────UserCredential──────────────
                    ──sendEmailVerification──────────▶  Gửi email
                                                        (User nhấn link)
login()            ──signInWithEmailAndPassword──────▶  Xác thực
                    ◀────UserCredential──────────────
Kiểm tra emailVerified
Tạo/Cập nhật SQLite
Đăng nhập thành công ✅
```

---

## Các file code tương ứng

| File | Thuộc | Chức năng |
|------|-------|-----------|
| `lib/features/auth/services/auth_repository.dart` | 🟦 App | Xử lý đăng ký, đăng nhập, gọi Firebase Auth API |
| `lib/features/auth/services/verification_email_service.dart` | 🟦 App | Gọi `sendEmailVerification()` của Firebase |
| `lib/features/auth/services/pending_registration_store.dart` | 🟦 App | Lưu tạm thông tin đăng ký vào SharedPreferences |
| `lib/features/auth/services/auth_session.dart` | 🟦 App | Quản lý trạng thái đăng nhập trong app |
| Firebase Auth SDK (package `firebase_auth`) | 🔴 Firebase | Tạo tài khoản, xác thực email, đăng nhập |
| Firebase Firestore (package `cloud_firestore`) | 🔴 Firebase | Lưu dữ liệu user, kiểm tra role admin |
