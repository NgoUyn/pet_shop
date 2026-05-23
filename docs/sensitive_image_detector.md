# Sensitive Image Detector

**File Flutter:** `lib/features/chat/services/sensitive_image_detector.dart`
**Server:** Image Moderation Server (port 8888)

## Luồng dữ liệu

**Flutter → Cloudinary (Upload ảnh):**
- `ImagePicker.pickImage()` → XFile → `CloudinaryHelper.uploadImage(filePath)` → imageUrl

**Flutter → Image Moderation Server (Kiểm tra ảnh):**
- `SensitiveImageDetector.checkImageUrl(imageUrl)` → POST `http://10.0.2.2:8888/check-review-images` → `{imageUrls: [imageUrl]}`
- Response: `{passed: true}` hoặc `{passed: false, reason: "Nội dung nhạy cảm"}`

**Flutter → Firestore (Gửi ảnh nếu an toàn):**
- passed=true → `ChatRepository.sendImageMessage(thread, imageUrl, content)` → Firestore `messages/{msgId}` {type: "image", imageUrl}
- passed=false → hiển thị dialog "Ảnh không thể gửi: Phát hiện Nội dung nhạy cảm" → không gửi
