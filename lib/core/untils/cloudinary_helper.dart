import 'package:flutter_dotenv/flutter_dotenv.dart';



class CloudinaryHelper {

  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  // Base URL
  static String get baseUrl => 'https://res.cloudinary.com/$cloudName/image/upload';

  /// Generate URL ảnh với transformation (rất quan trọng để tối ưu)
  static String getImageUrl(
      String publicId, {
        int? width,
        int? height,
        String crop = 'fill',        // fill, fit, scale, crop, pad...
        String gravity = 'auto',
        String quality = 'auto',     // auto, 80, 90...
        String format = 'auto',      // auto, webp, avif, png, jpg
      }) {
    List<String> transformations = [];

    // Quality & Format
    transformations.add('q_$quality,f_$format');

    // Resize
    if (width != null || height != null) {
      transformations.add('w_${width ?? ""},h_${height ?? ""},c_$crop');
      if (gravity.isNotEmpty) {
        transformations.add('g_$gravity');
      }
    }

    final transformString = transformations.join(',');

    return '$baseUrl/$transformString/$publicId';
  }

  /// URL cho ảnh vuông (thường dùng cho Product Card)
  static String getProductImage(String publicId, {int size = 400}) {
    return getImageUrl(
      publicId,
      width: size,
      height: size,
      crop: 'fill',
    );
  }

  /// URL cho Banner (rộng)
  static String getBannerImage(String publicId, {int width = 1080, int height = 500}) {
    return getImageUrl(
      publicId,
      width: width,
      height: height,
      crop: 'fill',
    );
  }

  /// URL thumbnail nhỏ
  static String getThumbnail(String publicId, {int size = 150}) {
    return getImageUrl(publicId, width: size, height: size, crop: 'fill');
  }
}
