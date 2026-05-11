import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../services/pet_repository.dart';

class PetDetailPage extends StatefulWidget {
  const PetDetailPage({super.key, required this.pet});

  final PetItem pet;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  bool _isFavorited = false;

  @override
  void initState() {
    super.initState();
    _loadFavoriteState();
  }

  Future<void> _loadFavoriteState() async {
    final isFavorited = await FavoriteRepository.instance.isPetFavorited(widget.pet.petId);
    if (!mounted) return;
    setState(() {
      _isFavorited = isFavorited;
    });
  }

  Future<void> _ensureLoggedIn() async {
    if (AuthSession.instance.currentUserId.value != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _toggleFavorite() async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.togglePetFavorite(widget.pet.petId);
      if (!mounted) return;
      setState(() {
        _isFavorited = !_isFavorited;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _addToCart() async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addPetToCart(petId: widget.pet.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm thú cưng vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết thú cưng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Yêu thích',
            onPressed: _toggleFavorite,
            icon: Icon(
              _isFavorited ? Icons.favorite : Icons.favorite_border,
              color: _isFavorited ? Colors.red : AppColors.textDark,
            ),
          ),
          IconButton(
            tooltip: 'Thêm vào giỏ hàng',
            onPressed: _addToCart,
            icon: const Icon(Icons.add_shopping_cart_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              alignment: Alignment.center,
              child: const Text('🐾', style: TextStyle(fontSize: 72)),
            ),
            const SizedBox(height: 14),
            Text(
              pet.petName,
              style: const TextStyle(
                color: AppColors.textDark,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              pet.price == null ? '-' : _formatPrice(pet.price!),
              style: const TextStyle(
                color: AppColors.secondary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Mã thú cưng', pet.petId.toString()),
                  _infoRow('Loài', pet.species),
                  _infoRow('Trạng thái', pet.isActive ? 'Đang bán' : 'Ngừng bán'),
                  _infoRow('Ngày tạo', pet.createdAt.toLocal().toString()),
                  const SizedBox(height: 8),
                  const Text(
                    'Mô tả',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    (pet.description ?? '').trim().isEmpty ? '-' : pet.description!.trim(),
                    style: const TextStyle(color: AppColors.textDark),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textLight,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: AppColors.textDark),
            ),
          ),
        ],
      ),
    );
  }
}