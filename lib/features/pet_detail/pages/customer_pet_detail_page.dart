import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/pet_provider.dart';
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
  bool _isUnavailable = false;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
    _isUnavailable = _currentPet.status != 'đang bán';
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
        _isUnavailable = updated.status != 'đang bán';
      });
    } else {
      // Pet not in active list — may have been sold, fetch directly
      _refreshFromRepo();
    }
  }

  Future<void> _refreshFromRepo() async {
    final refreshed = await PetRepository.instance.getPetById(_currentPet.petId);
    if (!mounted) return;
    if (refreshed != null) {
      setState(() {
        _currentPet = refreshed;
        _isUnavailable = refreshed.status != 'đang bán';
      });
    }
  }

  void _onChatPressed() {
    // TODO: Implement chat functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng chat đang được phát triển')),
    );
  }

  void _onOrderPressed() {
    // TODO: Implement order functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng đặt hàng đang được phát triển')),
    );
  }

  void _onBuyPressed() {
    // TODO: Implement buy functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Tính năng mua hàng đang được phát triển')),
    );
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
    final isUnavailable = _isUnavailable || _currentPet.status != 'đang bán';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết thú cưng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Status banner for sold/stopped pets
          if (isUnavailable)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: _currentPet.status == 'đã bán'
                  ? Colors.red.shade50
                  : Colors.orange.shade50,
              child: Row(
                children: [
                  Icon(
                    _currentPet.status == 'đã bán'
                        ? Icons.shopping_cart_checkout
                        : Icons.block,
                    size: 18,
                    color: _currentPet.status == 'đã bán'
                        ? Colors.red.shade700
                        : Colors.orange.shade700,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _currentPet.status == 'đã bán'
                        ? 'Thú cưng này đã được bán'
                        : 'Thú cưng này hiện không có sẵn',
                    style: TextStyle(
                      color: _currentPet.status == 'đã bán'
                          ? Colors.red.shade700
                          : Colors.orange.shade700,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: PetDetailBody(
                pet: _currentPet,
                showAdminActions: false,
                onRelatedPetTap: _onRelatedPetTap,
                onPetChanged: (updated) {
                  setState(() {
                    _currentPet = updated;
                    _isUnavailable = updated.status != 'đang bán';
                  });
                },
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: isUnavailable
          ? null
          : CustomerBottomAction(
              onChatPressed: _onChatPressed,
              onOrderPressed: _onOrderPressed,
              onBuyPressed: _onBuyPressed,
            ),
    );
  }
}
