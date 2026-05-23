import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../utils/cloudinary_transform.dart';
import '../utils/image_cache_manager.dart';

/// An optimized network image widget that:
/// - Transforms Cloudinary URLs to optimal sizes
/// - Uses disk cache via [PetShopCacheManager]
/// - Uses memory cache with appropriate [memCacheHeight]
/// - Shows a lightweight placeholder instead of a spinner
/// - Handles errors gracefully
class OptimizedNetworkImage extends StatelessWidget {
  const OptimizedNetworkImage({
    super.key,
    required this.imageUrl,
    this.size = CloudinaryImageSize.thumbnail,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.memCacheHeight,
    this.memCacheWidth,
    this.color,
  });

  /// The original image URL (will be transformed if Cloudinary).
  final String imageUrl;

  /// The target display size for Cloudinary transformation.
  final CloudinaryImageSize size;

  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final int? memCacheHeight;
  final int? memCacheWidth;
  final Color? color;

  /// Returns the optimal memCacheHeight based on [size] if not explicitly set.
  int get _defaultMemCacheHeight {
    if (memCacheHeight != null) return memCacheHeight!;
    switch (size) {
      case CloudinaryImageSize.avatar:
        return 120;
      case CloudinaryImageSize.thumbnail:
        return 400;
      case CloudinaryImageSize.medium:
        return 800;
      case CloudinaryImageSize.banner:
        return 500;
      case CloudinaryImageSize.large:
        return 1200;
      case CloudinaryImageSize.original:
        return 1200;
    }
  }

  /// Returns the optimal memCacheWidth based on [size] if not explicitly set.
  int get _defaultMemCacheWidth {
    if (memCacheWidth != null) return memCacheWidth!;
    switch (size) {
      case CloudinaryImageSize.avatar:
        return 120;
      case CloudinaryImageSize.thumbnail:
        return 400;
      case CloudinaryImageSize.medium:
        return 800;
      case CloudinaryImageSize.banner:
        return 1200;
      case CloudinaryImageSize.large:
        return 1200;
      case CloudinaryImageSize.original:
        return 1200;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normalized = (imageUrl).trim();
    if (normalized.isEmpty) {
      return _buildFallback();
    }

    // Transform Cloudinary URL
    final optimizedUrl = CloudinaryTransform.transform(
      normalized,
      size: size,
    );

    // For local file paths
    if (!normalized.startsWith('http://') && !normalized.startsWith('https://')) {
      return ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Image.file(
          File(normalized),
          width: width,
          height: height,
          fit: fit,
          color: color,
          errorBuilder: (context, error, stackTrace) => _buildFallback(),
        ),
      );
    }

    final image = CachedNetworkImage(
      imageUrl: optimizedUrl,
      cacheManager: PetShopCacheManager.instance,
      width: width,
      height: height,
      fit: fit,
      color: color,
      memCacheWidth: _defaultMemCacheWidth,
      memCacheHeight: _defaultMemCacheHeight,
      placeholder: (context, url) => _buildPlaceholder(),
      errorWidget: (context, url, error) => _buildFallback(),
      imageBuilder: (context, imageProvider) {
        if (borderRadius != null) {
          return ClipRRect(
            borderRadius: borderRadius!,
            child: Image(
              image: imageProvider,
              width: width,
              height: height,
              fit: fit,
              color: color,
            ),
          );
        }
        return Image(
          image: imageProvider,
          width: width,
          height: height,
          fit: fit,
          color: color,
        );
      },
    );

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }

  Widget _buildPlaceholder() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF3F4F6),
      alignment: Alignment.center,
      child: const Icon(
        Icons.image_outlined,
        color: Color(0xFFD1D5DB),
        size: 32,
      ),
    );
  }

  Widget _buildFallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFF9FAFB),
      alignment: Alignment.center,
      child: const Icon(
        Icons.broken_image_outlined,
        color: Color(0xFFB0B8C1),
        size: 32,
      ),
    );
  }
}
