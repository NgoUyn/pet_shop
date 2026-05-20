import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/price_helper.dart';
import '../services/pet_repository.dart';

/// Reusable Pet Card widget used across all pages.
/// Integrates CachedNetworkImage with cacheHeight: 400 to reduce CPU load.
/// Handles text overflow with TextOverflow.ellipsis.
class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.item,
    this.onTap,
    this.onFavoriteTap,
    this.onCartTap,
    this.onBuyTap,
    this.isFavorited = false,
    this.compact = false,
    showFavoriteIcon= true,
  });

  final PetItem item;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteTap;
  final VoidCallback? onCartTap;
  final VoidCallback? onBuyTap;
  final bool isFavorited;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactCard();
    }
    return _buildFullCard();
  }

  Widget _buildFullCard() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              SizedBox(
                height: 140,
                width: 80,
                child: ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: _buildImage(item.imageUrl),
                ),
              ),
              // Info area
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name + gender badge
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.petName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GenderBadge(label: genderLabel(item.gender)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Age · Species · Gender
                    Text(
                      '${formatAge(item.age)} · ${item.species} · ${genderLabel(item.gender)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Info chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PetInfoChip(
                          label: formatAge(item.age).isEmpty
                              ? 'Chưa rõ tuổi'
                              : formatAge(item.age),
                          accent: const Color(0xFFD8EEE4),
                          textColor: const Color(0xFF3E7C63),
                        ),
                        _PetInfoChip(
                          label: item.isVaccinated
                              ? 'Đã tiêm phòng'
                              : 'Chưa tiêm phòng',
                        ),
                        _PetInfoChip(
                          label: item.isDewormed
                              ? 'Đã tẩy giun'
                              : 'Chưa tẩy giun',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Price
                    Text(
                      item.price == null ? '-' : formatPrice(item.price!),
                      style: const TextStyle(
                        fontSize: 15,
                        color: Color(0xFF5BAA7C),
                        fontWeight: FontWeight.bold,
                      ),
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

  /// Compact card variant used in grid layouts (PetListPage, HomePage).
  /// Redesigned with the new pink/salmon color scheme.
  Widget _buildCompactCard() {
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
                      // "Đã bán" overlay badge for sold pets
                      if (item.status == 'đã bán')
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.35),
                              borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(14)),
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Đã bán',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Heart icon button in top-right corner
                      if (onFavoriteTap != null)
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
                    // Row 1: Pet name (bold, left) + Age tag (right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Text(
                            item.petName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Age tag
                        if (formatAge(item.age).isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.accentLight,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              formatAge(item.age),
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    // Row 2: Price (bold accent, left) + Breed (right)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Price with rounded tag background

                          Text(
                            item.price == null
                                ? '-'
                                : formatPrice(item.price!),
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(width: 40),
                        // Breed
                        Flexible(
                          child: Text(
                            item.breed ?? item.species,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: AppColors.textDark,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Bottom row: Shopping cart icon + Buy button
                    // Hidden for sold pets
                    if (item.status != 'đã bán')
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
                            child: SizedBox(
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
      child: const Icon(Icons.pets, color: Color(0xFFB0B8C1), size: 48),
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

// ── Supporting widgets ───────────────────────────────────────────────────

class _GenderBadge extends StatelessWidget {
  const _GenderBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7F5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF3E7C63),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PetInfoChip extends StatelessWidget {
  const _PetInfoChip({
    required this.label,
    this.accent,
    this.textColor,
  });
  final String label;
  final Color? accent;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: accent ?? const Color(0xFFF5E8C9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor ?? const Color(0xFF8A6A23),
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ── Bottom Sheet Detail ──────────────────────────────────────────────────

Future<void> showPetDetailSheet(
  BuildContext context,
  PetItem item,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      return SafeArea(
        child: Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: DraggableScrollableSheet(
            initialChildSize: 0.84,
            minChildSize: 0.6,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Drag handle
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1.1,
                        child: _buildImage(item.imageUrl),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Name + gender
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.petName,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GenderBadge(label: genderLabel(item.gender)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DetailGrid(item: item),
                    const SizedBox(height: 18),
                    // Description
                    const Text(
                      'Mô tả chi tiết',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (item.description ?? '').trim().isEmpty
                          ? 'Chưa có mô tả cho thú cưng này.'
                          : item.description!.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Personality
                    const Text(
                      'Tính cách',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (item.personality ?? '').trim().isEmpty
                          ? 'Chưa cập nhật tính cách.'
                          : item.personality!.trim(),
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.45,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Health tags
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoTag(
                          item.isVaccinated
                              ? 'Đã tiêm phòng'
                              : 'Chưa tiêm phòng',
                          item.isVaccinated,
                        ),
                        _infoTag(
                          item.isDewormed
                              ? 'Đã tẩy giun'
                              : 'Chưa tẩy giun',
                          item.isDewormed,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Price
                    if (item.price != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F7F5),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'Giá tham khảo: ${formatPrice(item.price!)}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF3E7C63),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    // Close button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5BAA7C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Đóng'),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    },
  );
}

Widget _infoTag(String label, bool selected) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: selected
          ? const Color(0xFFD8EEE4)
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: selected
            ? const Color(0xFF3E7C63)
            : const Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.item});
  final PetItem item;

  @override
  Widget build(BuildContext context) {
    final cells = [
      _DetailCell(
        title: 'Tuổi',
        value: formatAge(item.age).isEmpty
            ? 'Chưa rõ tuổi'
            : formatAge(item.age),
      ),
      _DetailCell(title: 'Giống', value: item.species),
      _DetailCell(
        title: 'Giới tính',
        value: genderLabel(item.gender),
      ),
      _DetailCell(
        title: 'Giá',
        value: item.price == null
            ? 'Chưa cập nhật'
            : formatPrice(item.price!),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: cells,
    );
  }
}

class _DetailCell extends StatelessWidget {
  const _DetailCell({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
