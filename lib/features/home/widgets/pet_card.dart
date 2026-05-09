import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/pet_repository.dart';

class PetCard extends StatelessWidget {
  const PetCard({
    super.key,
    required this.item,
    required this.formatPrice,
    this.onTap,
  });

  final PetItem item;
  final String Function(double value) formatPrice;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
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
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: _buildImage(item.imageUrl),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.petName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _GenderBadge(label: _genderLabel(item.gender)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_ageLabel(item.age)} · ${item.species} · ${_genderLabel(item.gender)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF666666)),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _PetInfoChip(label: _ageLabel(item.age), accent: const Color(0xFFD8EEE4), textColor: const Color(0xFF3E7C63)),
                        _PetInfoChip(label: item.isVaccinated ? 'Đã tiêm phòng' : 'Chưa tiêm phòng'),
                        _PetInfoChip(label: item.isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      item.price == null ? '-' : formatPrice(item.price!),
                      style: const TextStyle(fontSize: 15, color: Color(0xFF5BAA7C), fontWeight: FontWeight.bold),
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

String _ageLabel(int? age) => age == null ? 'Chưa rõ tuổi' : '$age tháng tuổi';

String _genderLabel(String? gender) {
  final normalized = (gender ?? '').trim();
  return normalized.isEmpty ? 'Chưa rõ giới tính' : normalized;
}

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
      placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
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
    child: const Icon(Icons.broken_image_outlined, color: Color(0xFFB0B8C1), size: 44),
  );
}

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
        style: const TextStyle(fontSize: 11, color: Color(0xFF3E7C63), fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _PetInfoChip extends StatelessWidget {
  const _PetInfoChip({required this.label, this.accent, this.textColor});
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

Future<void> showPetDetailSheet(BuildContext context, PetItem item, String Function(double value) formatPrice) async {
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
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AspectRatio(
                        aspectRatio: 1.1,
                        child: _buildImage(item.imageUrl),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.petName,
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(width: 12),
                        _GenderBadge(label: _genderLabel(item.gender)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _DetailGrid(item: item, formatPrice: formatPrice),
                    const SizedBox(height: 18),
                    const Text('Mô tả chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      (item.description ?? '').trim().isEmpty ? 'Chưa có mô tả cho thú cưng này.' : item.description!.trim(),
                      style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 18),
                    const Text('Tính cách', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text(
                      (item.personality ?? '').trim().isEmpty ? 'Chưa cập nhật tính cách.' : item.personality!.trim(),
                      style: const TextStyle(fontSize: 14, height: 1.45, color: Color(0xFF4B5563)),
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _infoTag(item.isVaccinated ? 'Đã tiêm phòng' : 'Chưa tiêm phòng', item.isVaccinated),
                        _infoTag(item.isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun', item.isDewormed),
                      ],
                    ),
                    const SizedBox(height: 24),
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
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF3E7C63)),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5BAA7C),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
      color: selected ? const Color(0xFFD8EEE4) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: selected ? const Color(0xFF3E7C63) : const Color(0xFF6B7280),
        fontSize: 12,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.item, required this.formatPrice});
  final PetItem item;
  final String Function(double value) formatPrice;

  @override
  Widget build(BuildContext context) {
    final cells = [
      _DetailCell(title: 'Tuổi', value: _ageLabel(item.age)),
      _DetailCell(title: 'Giống', value: item.species),
      _DetailCell(title: 'Giới tính', value: _genderLabel(item.gender)),
      _DetailCell(title: 'Giá', value: item.price == null ? 'Chưa cập nhật' : formatPrice(item.price!)),
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
          Text(title, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
