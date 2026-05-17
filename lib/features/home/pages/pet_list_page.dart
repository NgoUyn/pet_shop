import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/pet_provider.dart';
import '../../../core/utils/price_helper.dart';
import '../../auth/pages/login_page.dart';
import '../../auth/services/auth_session.dart';
import '../../cart/services/cart_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../services/pet_repository.dart';
import '../widgets/pet_card.dart';
import '../../pet_detail/pages/pet_detail_page.dart';

class PetListPage extends StatefulWidget {
  const PetListPage({super.key});

  @override
  State<PetListPage> createState() => _PetListPageState();
}

class _PetListPageState extends State<PetListPage> {
  Set<int> _favoritePetIds = {};

  @override
  void initState() {
    super.initState();
    // Load pets via PetProvider (single source of truth)
    PetProvider.instance.loadPets();
    PetProvider.instance.addListener(_onPetsChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    PetProvider.instance.removeListener(_onPetsChanged);
    super.dispose();
  }

  void _onPetsChanged() {
    if (mounted) setState(() {});
  }

  void _reload() {
    PetProvider.instance.reload();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final favorites = await FavoriteRepository.instance.listFavoritePets();
    if (!mounted) return;
    setState(() {
      _favoritePetIds = favorites.map((item) => item.petId).toSet();
    });
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final provider = PetProvider.instance;

    if (provider.isLoading && provider.pets.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && provider.pets.isEmpty) {
      return const Center(
        child: Text('Không thể tải danh sách thú cưng'),
      );
    }

    final items = provider.pets;
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
        return PetCard(
          item: item,
          compact: true,
          isFavorited: _favoritePetIds.contains(item.petId),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PetDetailPage(pet: item),
              ),
            );
          },
          onFavoriteTap: () => _addPetToFavorites(item),
          onCartTap: () => _addPetToCart(item),
        );
      },
    );
  }
}
