import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import 'pet_detail_page.dart';
import '../services/pet_repository.dart';
import '../widgets/pet_card.dart';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  late Future<List<PetItem>> _future;
  Set<int> _favoritePetIds = {};

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
    _loadFavorites();
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
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoriteRepository.instance.listFavoritePets();
    if (!mounted) return;
    setState(() {
      _favoritePetIds = favorites.map((item) => item.petId).toSet();
    });
  }

  String _formatPrice(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1).replaceFirst('.0', '')}tr';
    }
    return '${value.toStringAsFixed(0).replaceAllMapped(RegExp(r"(\d{1,3})(?=(\d{3})+(?!\d))"), (Match m) => "${m[1]}.")}đ';
  }

  Future<void> _ensureLoggedIn() async {
    if (AuthSession.instance.currentUserId.value != null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginPage()),
    );
  }

  Future<void> _addPetToFavorites(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await FavoriteRepository.instance.togglePetFavorite(item.petId);
      setState(() {
        if (_favoritePetIds.contains(item.petId)) {
          _favoritePetIds.remove(item.petId);
        } else {
          _favoritePetIds.add(item.petId);
        }
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  Future<void> _addPetToCart(PetItem item) async {
    await _ensureLoggedIn();
    if (AuthSession.instance.currentUserId.value == null) return;
    try {
      await CartRepository.instance.addPetToCart(petId: item.petId);
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

  Widget _buildPetImage() {
    return Container(
      color: AppColors.background,
      alignment: Alignment.center,
      child: const Icon(Icons.pets, color: AppColors.textLight, size: 44),
    );
  }

  Widget _buildPetCard(PetItem item) {
    final price = item.price;
    final isFavorited = _favoritePetIds.contains(item.petId);

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
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildPetImage(),
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Column(
                      children: [
                        Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _addPetToFavorites(item),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                isFavorited ? Icons.favorite : Icons.favorite_border,
                                size: 20,
                                color: isFavorited ? Colors.red : AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Material(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(999),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () => _addPetToCart(item),
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.add_shopping_cart_outlined, size: 20, color: AppColors.textDark),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PetDetailPage(pet: item),
                    ),
                  );
                },
                child: _buildPetCard(item),
              );
            },
          );
        },
      ),
    );
  }
}
