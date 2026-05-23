# Toxic Moderation Service

**File Flutter:** `lib/features/reviews/services/toxic_moderation_service.dart`
**Server:** Toxic Moderation (port 8080) + Image Moderation (port 8888)

## Luồng dữ liệu

**Flutter → Cloudinary (Upload ảnh):**
- `CloudinaryHelper.uploadImages(files)` → imageUrls

**Flutter → Image Moderation Server (Kiểm tra ảnh):**
- `_checkImagesModeration(imageUrls)` → POST `http://10.0.2.2:8888/check-review-images` → `{imageUrls: [...]}`
- Response: `{passed: true}` hoặc `{passed: false, reason: "Nội dung nhạy cảm"}`

**Flutter → Toxic Moderation Server (Kiểm tra text):**
- Nếu ảnh passed: `ToxicModerationService.checkText(content)` → POST `http://10.0.2.2:8080/models/ban3_baseline_lr/predict_batch` → `{"texts": ["..."]}`
- Response: `{results: [{label, probability, threshold}]}` (label=1 là toxic)

**Flutter → Firestore (Lưu kết quả):**
- Ảnh bị flag hoặc text toxic → `moderationStatus = "flagged"`
- Không vấn đề → `moderationStatus = "approved"`
- `ReviewRepository.create(reviewData + moderationStatus)` → Firestore `reviews/{reviewId}`
- Nếu flagged → `NotificationRepository.sendNotification(userId, "...")` → Firestore `notifications/{notifId}`
