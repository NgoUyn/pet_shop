import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

class CloudinaryHelper {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String get baseUrl => 'https://res.cloudinary.com/$cloudName/image/upload';
  static String get _uploadUrl => 'https://api.cloudinary.com/v1_1/$cloudName/image/upload';

  static String getImageUrl(
      String publicId, {
        int? width,
        int? height,
        String crop = 'fill',
        String gravity = 'auto',
        String quality = 'auto',
        String format = 'auto',
      }) {
    List<String> transformations = [];
    transformations.add('q_$quality,f_$format');
    if (width != null || height != null) {
      transformations.add('w_${width ?? ""},h_${height ?? ""},c_$crop');
      if (gravity.isNotEmpty) {
        transformations.add('g_$gravity');
      }
    }
    final transformString = transformations.join(',');
    return '$baseUrl/$transformString/$publicId';
  }

  static String getProductImage(String publicId, {int size = 400}) {
    return getImageUrl(publicId, width: size, height: size, crop: 'fill');
  }

  static String getBannerImage(String publicId, {int width = 1080, int height = 500}) {
    return getImageUrl(publicId, width: width, height: height, crop: 'fill');
  }

  static String getThumbnail(String publicId, {int size = 150}) {
    return getImageUrl(publicId, width: size, height: size, crop: 'fill');
  }

  /// Upload an image file to Cloudinary using unsigned upload preset.
  /// Returns the secure_url from the response, or null on failure.
  static Future<String?> uploadImage(String filePath) async {
    try {
      final uri = Uri.parse(_uploadUrl);
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(await http.MultipartFile.fromPath('file', filePath));

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        // Simple JSON extraction without adding a json dependency here
        final secureUrl = _extractJsonString(body, 'secure_url');
        return secureUrl;
      }
    } catch (e) {
      print('CloudinaryHelper.uploadImage error: $e');
    }
    return null;
  }

  static String? _extractJsonString(String json, String key) {
    final pattern = '"$key":"';
    final start = json.indexOf(pattern);
    if (start == -1) return null;
    final valueStart = start + pattern.length;
    final end = json.indexOf('"', valueStart);
    if (end == -1) return null;
    return json.substring(valueStart, end);
  }
}
