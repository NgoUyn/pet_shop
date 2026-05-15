import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Helper to upload images to Cloudinary
class CloudinaryHelper {
  CloudinaryHelper._();
  static final CloudinaryHelper instance = CloudinaryHelper._();

  String? get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'];
  String? get _uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'];

  /// Upload an image file to Cloudinary and return the secure URL.
  /// Returns null if upload fails.
  Future<String?> _uploadFile(File imageFile) async {
    final cloudName = _cloudName;
    final uploadPreset = _uploadPreset;

    if (cloudName == null || cloudName.isEmpty || uploadPreset == null || uploadPreset.isEmpty) {
      print('CloudinaryHelper: Missing cloud name or upload preset');
      return null;
    }

    try {
      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);
      request.fields['upload_preset'] = uploadPreset;
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['secure_url'] as String?;
      } else {
        print('CloudinaryHelper: Upload failed with status ${response.statusCode}: ${response.body}');
        return null;
      }
    } catch (e) {
      print('CloudinaryHelper: Upload error: $e');
      return null;
    }
  }

  /// Static method: upload an image file and return the URL.
  /// Used by review_page.dart and other existing code.
  static Future<String?> uploadImage(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) {
      print('CloudinaryHelper.uploadImage: File not found: $filePath');
      return null;
    }
    return instance._uploadFile(file);
  }

  /// Static method: get a banner image URL by name.
  /// Used by home_page.dart.
  static String getBannerImage(String bannerName) {
    final cloudName = dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? 'dyk8jc0nq';
    return 'https://res.cloudinary.com/$cloudName/image/upload/v1/banners/$bannerName';
  }
}
