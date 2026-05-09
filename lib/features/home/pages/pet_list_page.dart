import 'dart:io';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/pet_repository.dart';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  late Future<List<PetItem>> _future;

  void _handlePetsChanged() {
    if (!mounted) return;
    setState(() {
      _future = PetRepository.instance.listActivePets();
    });
  }

  @override
  void initState() {
    super.initState();
    _future = PetRepository.instance.listActivePets();
    PetRepository.instance.changeToken.addListener(_handlePetsChanged);
  }

  @override
  void dispose() {
    PetRepository.instance.changeToken.removeListener(_handlePetsChanged);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = PetRepository.instance.listActivePets();
    });
  }

  String _formatPrice(double value) {
    final formatted = value.toStringAsFixed(0);
    final buffer = StringBuffer();
    for (var i = 0; i < formatted.length; i++) {
      final fromEnd = formatted.length - i;
      buffer.write(formatted[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        buffer.write('.');
      }
    }
    return '$bufferđ';
  }

  Widget _buildPetImage(String? imageUrl) {
    final normalized = (imageUrl ?? '').trim();
    if (normalized.isEmpty) {
      return Container(
        color: AppColors.background,
        alignment: Alignment.center,
        child: const Icon(Icons.pets, color: AppColors.textLight, size: 44),
      );
    }

    final image = normalized.startsWith('http://') || normalized.startsWith('https://')
        ? Image.network(
            normalized,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.background,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: AppColors.textLight, size: 44),
            ),
          )
        : Image.file(
            File(normalized),
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.background,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image_outlined, color: AppColors.textLight, size: 44),
            ),
          );

    return image;
  }

  Widget _buildPetCard(PetItem item) {
    final price = item.price;
    final ageText = item.age == null ? 'Chưa cập nhật tuổi' : '${item.age} tháng tuổi';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _buildPetImage(item.imageUrl),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.petName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDark),
                ),
                const SizedBox(height: 4),
                Text(
                  item.species,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  ageText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textDark, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusChip(label: item.isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun'),
                    _StatusChip(label: item.isVaccinated ? 'Đã tiêm phòng' : 'Chưa tiêm phòng'),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  price == null ? '-' : _formatPrice(price),
                  style: const TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mua thú cưng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<PetItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Không thể tải danh sách thú cưng'),
            );
          }

          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return const Center(
              child: Text('Chưa có thú cưng nào'),
            );
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.72,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemBuilder: (context, index) {
              final item = items[index];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {},
                child: _buildPetCard(item),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

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
        style: const TextStyle(fontSize: 11, color: Color(0xFF3E7C63), fontWeight: FontWeight.w600),
      ),
    );
  }
}
