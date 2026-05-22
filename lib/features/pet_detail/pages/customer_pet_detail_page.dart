import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/pet_provider.dart';
import '../../cart/services/cart_repository.dart';
import '../../home/services/pet_repository.dart';
import '../../product_detail/widgets/customer_bottom_action.dart';
import '../widgets/pet_detail_body.dart';

/// Customer pet detail page with chat/order/purchase actions.
/// Uses the shared [PetDetailBody] for common display content
/// and [CustomerBottomAction] for customer-specific floating buttons.
class CustomerPetDetailPage extends StatefulWidget {
  const CustomerPetDetailPage({
    super.key,
    required this.pet,
  });

  final PetItem pet;

  @override
  State<CustomerPetDetailPage> createState() => _CustomerPetDetailPageState();
}

class _CustomerPetDetailPageState extends State<CustomerPetDetailPage> {
  late PetItem _currentPet;
  bool _isAddingToCart = false;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
    // Listen for updates from PetProvider for real-time sync
    PetProvider.instance.addListener(_onPetsChanged);
  }

  @override
  void dispose() {
    PetProvider.instance.removeListener(_onPetsChanged);
    super.dispose();
  }

  void _onPetsChanged() {
    if (!mounted) return;
    final updated = PetProvider.instance.pets
        .where((p) => p.petId == _currentPet.petId)
        .firstOrNull;
    if (updated != null) {
      setState(() {
        _currentPet = updated;
      });
    }
  }

  void _onChatPressed() {
    // TODO: Implement chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng chat đang được phát triển')),
    );
  }

  Future<void> _onOrderPressed() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);
    try {
      await CartRepository.instance.addPetToCart(petId: _currentPet.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  Future<void> _onBuyPressed() async {
    if (_isAddingToCart) return;
    setState(() => _isAddingToCart = true);
    try {
      await CartRepository.instance.addPetToCart(petId: _currentPet.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thêm vào giỏ hàng')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  void _onRelatedPetTap(PetItem pet) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerPetDetailPage(pet: pet),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết thú cưng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: PetDetailBody(
          pet: _currentPet,
          showAdminActions: false,
          onRelatedPetTap: _onRelatedPetTap,
          onPetChanged: (updated) {
            setState(() {
              _currentPet = updated;
            });
          },
        ),
      ),
      bottomNavigationBar: CustomerBottomAction(
        onChatPressed: _onChatPressed,
        onOrderPressed: _onOrderPressed,
        onBuyPressed: _onBuyPressed,
      ),
    );
  }
}
