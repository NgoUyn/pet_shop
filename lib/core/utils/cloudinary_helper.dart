import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryHelper {
  static String get cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'] ?? '';
  static String get uploadPreset => dotenv.env['CLOUDINARY_UPLOAD_PRESET'] ?? '';

  static String get baseUrl => 'https://res.cloudinary.com/$cloudName/image/upload';

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
}
