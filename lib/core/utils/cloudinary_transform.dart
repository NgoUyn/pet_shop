import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Image size categories for Cloudinary transformations.
enum CloudinaryImageSize {
  /// Tiny avatar / icon (~120px)
  avatar,

  /// Thumbnail for cards / grid items (~400px)
  thumbnail,

  /// Medium for detail pages (~800px)
  medium,

  /// Banner / hero image (~1200x500px)
  banner,

  /// Large for banners / full-width (~1200px)
  large,

  /// Original – no transformation
  original,
}

/// Helper to transform Cloudinary image URLs for optimal loading.
///
/// Usage:
/// ```dart
/// final url = CloudinaryTransform.transform(
///   'https://res.cloudinary.com/.../image/upload/v123/abc.jpg',
///   size: CloudinaryImageSize.thumbnail,
/// );
/// ```
class CloudinaryTransform {
  CloudinaryTransform._();

  static String? get _cloudName => dotenv.env['CLOUDINARY_CLOUD_NAME'];

  /// Returns the optimal Cloudinary URL for the given [size].
  ///
  /// If the URL is not a Cloudinary URL, returns it unchanged.
  /// If [size] is [CloudinaryImageSize.original], returns the URL unchanged.
  static String transform(String url, {CloudinaryImageSize size = CloudinaryImageSize.thumbnail}) {
    if (url.isEmpty) return url;
    if (size == CloudinaryImageSize.original) return url;

    final cloudName = _cloudName;
    if (cloudName == null || cloudName.isEmpty) return url;

    // Only transform Cloudinary URLs
    final cloudinaryPattern = 'res.cloudinary.com/$cloudName/image/upload/';
    if (!url.contains(cloudinaryPattern)) return url;

    // Build transformation string
    final transformStr = _buildTransform(size);

    // Insert transformation after "upload/" in the URL
    // URL format: .../image/upload/v123/folder/image.jpg
    // Insert:     .../image/upload/f_auto,q_auto,w_400,h_400,c_fill/v123/folder/image.jpg
    final uploadIndex = url.indexOf('upload/');
    if (uploadIndex == -1) return url;

    final before = url.substring(0, uploadIndex + 'upload/'.length);
    final after = url.substring(uploadIndex + 'upload/'.length);

    return '$before$transformStr$after';
  }

  /// Build the Cloudinary transformation string for the given size.
  static String _buildTransform(CloudinaryImageSize size) {
    switch (size) {
      case CloudinaryImageSize.avatar:
        return 'f_auto,q_auto,w_120,h_120,c_fill,g_face/';
      case CloudinaryImageSize.thumbnail:
        return 'f_auto,q_auto,w_400,h_400,c_fill/';
      case CloudinaryImageSize.medium:
        return 'f_auto,q_auto,w_800,c_limit/';
      case CloudinaryImageSize.banner:
        return 'f_auto,q_auto,w_1200,h_500,c_fill/';
      case CloudinaryImageSize.large:
        return 'f_auto,q_auto,w_1200,c_limit/';
      case CloudinaryImageSize.original:
        return '';
    }
  }
}
