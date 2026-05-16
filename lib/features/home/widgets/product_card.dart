import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/price_helper.dart';
import '../services/product_repository.dart';

/// Reusable Product Card widget used across all pages.
/// Integrates CachedNetworkImage with cacheHeight: 400 to reduce CPU load.
/// Layout: Grid style — image on top, information below.
/// Bottom row: cart icon on the left, "Buy" button on the right.
class ProductCard extends StatelessWidget {
  const ProductCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavoriteTap,
    this.onCartTap,
    this.onBuyTap,
    this.isFavorited = false,
    this.showFavoriteIcon = true,
  });

  final ProductItem item;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onBuyTap;
  final bool isFavorited;
  final bool showFavoriteIcon;


  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area with heart icon overlay
              Expanded(
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(14)),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _buildImage(item.imageUrl),
                      // Heart icon button in top-right corner
                      if (showFavoriteIcon && onFavoriteTap != null)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Material(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(999),
                            elevation: 1,
                            shadowColor: Colors.black26,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onFavoriteTap,
                              child: Padding(
                                padding: const EdgeInsets.all(7),
                                child: Icon(
                                  isFavorited
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: 18,
                                  color: isFavorited
                                      ? Colors.red
                                      : AppColors.textDark,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product name
                    Text(
                      item.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Price (orange/yellow text, without a surrounding box)
                    Text(
                      formatPrice(item.price),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Bottom row: Shopping cart icon + Buy button
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Shopping cart icon button
                        if (onCartTap != null)
                          Material(
                            color: AppColors.accentLight,
                            borderRadius: BorderRadius.circular(999),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(999),
                              onTap: onCartTap,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.shopping_cart_outlined,
                                  size: 18,
                                  color: AppColors.accent,
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(width: 8),
                        // Buy button
                        SizedBox(
                          height: 32,
                          width: 60,
                          child: ElevatedButton(
                            onPressed: onBuyTap ?? onCartTap,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.white,
                              elevation: 0,
                              padding: EdgeInsets.zero,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: const Text(
                              'Mua',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Image builder with CachedNetworkImage ────────────────────────────────

Widget _buildImage(String? imageUrl) {
  final normalized = (imageUrl ?? '').trim();
  if (normalized.isEmpty) {
    return Container(
      color: const Color(0xFFF9FAFB),
      alignment: Alignment.center,
      child: const Icon(Icons.shopping_bag_outlined, color: Color(0xFFB0B8C1), size: 48),
    );
  }

  if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
    return CachedNetworkImage(
      imageUrl: normalized,
      width: double.infinity,
      fit: BoxFit.cover,
      // memCacheHeight reduces CPU load by decoding at a fixed resolution
      memCacheHeight: 400,
      placeholder: (context, url) => const Center(
        child: CircularProgressIndicator(),
      ),
      errorWidget: (context, url, error) => _buildFallback(),
    );
  }

  return Image.file(
    File(normalized),
    width: double.infinity,
    fit: BoxFit.cover,
    errorBuilder: (context, error, stackTrace) => _buildFallback(),
  );
}

Widget _buildFallback() {
  return Container(
    color: const Color(0xFFF9FAFB),
    alignment: Alignment.center,
    child: const Icon(Icons.broken_image_outlined,
        color: Color(0xFFB0B8C1), size: 44),
  );
}
