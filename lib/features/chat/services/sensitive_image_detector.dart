import 'dart:convert';
import 'package:http/http.dart' as http;

/// Result of sensitive image detection
class SensitiveImageResult {
  final bool isSensitive;
  final String label;
  final double confidence;

  SensitiveImageResult({
    required this.isSensitive,
    required this.label,
    required this.confidence,
  });
}

/// Service to detect sensitive/inappropriate images before sending in chat.
/// Uses the same backend API as review image moderation (POST /check-review-images).
class SensitiveImageDetector {
  SensitiveImageDetector._();
  static final SensitiveImageDetector instance = SensitiveImageDetector._();

  static const String _apiBaseUrl = 'http://10.0.2.2:3000';

  /// Check if an image URL contains sensitive content via the backend API.
  /// The image must already be uploaded to Cloudinary before calling this.
  /// Returns [SensitiveImageResult] with detection details.
  Future<SensitiveImageResult> checkImageUrl(String imageUrl) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_apiBaseUrl/check-review-images'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'imageUrls': [imageUrl]}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final passed = data['passed'] == true;

        if (!passed) {
          return SensitiveImageResult(
            isSensitive: true,
            label: data['reason'] ?? 'Nội dung không phù hợp',
            confidence: 0.9,
          );
        }

        return SensitiveImageResult(
          isSensitive: false,
          label: 'An toàn',
          confidence: 1.0,
        );
      }

      // API error - allow the image (fail open for availability)
      print('SensitiveImageDetector: API returned status ${response.statusCode}');
      return SensitiveImageResult(
        isSensitive: false,
        label: 'An toàn',
        confidence: 0.5,
      );
    } catch (e) {
      print('SensitiveImageDetector: API error (allowing): $e');
      // If backend is unreachable, allow the image (fail open)
      return SensitiveImageResult(
        isSensitive: false,
        label: 'An toàn',
        confidence: 0.5,
      );
    }
  }

  /// Get a user-friendly message in Vietnamese about why the image was blocked
  static String getBlockMessage(String label) {
    return 'Ảnh không thể gửi: Phát hiện $label. Vui lòng chọn ảnh khác.';
  }
}
