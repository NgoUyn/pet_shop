import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/pet_provider.dart';
import '../../admin/pages/admin_pet_form_page.dart';
import '../../home/services/pet_repository.dart';
import '../../product_detail/widgets/admin_action_buttons.dart';
import '../widgets/pet_detail_body.dart';

/// Admin pet detail page with edit/delete actions.
/// Uses the shared [PetDetailBody] for common display content
/// and [AdminActionButtons] for admin-specific action buttons.
class AdminPetDetailPage extends StatefulWidget {
  const AdminPetDetailPage({
    super.key,
    required this.pet,
  });

  final PetItem pet;

  @override
  State<AdminPetDetailPage> createState() => _AdminPetDetailPageState();
}

class _AdminPetDetailPageState extends State<AdminPetDetailPage> {
  late PetItem _currentPet;

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
      });
    }
  }

  Future<void> _editPet() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminPetFormPage(pet: _currentPet)),
    );

    if (changed != true || !mounted) return;

    // Refresh pet data from database for real-time sync
    final refreshed = await PetRepository.instance.getPetById(_currentPet.petId);
    if (!mounted || refreshed == null) return;

    setState(() {
      _currentPet = refreshed;
    });
  }

  Future<void> _deletePet() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xóa thú cưng'),
        content: const Text('Bạn có chắc chắn muốn xóa thú cưng này không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await PetRepository.instance.deletePet(_currentPet.petId);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  void _onRelatedPetTap(PetItem pet) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => AdminPetDetailPage(pet: pet),
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
          showAdminActions: true,
          onEditPressed: _editPet,
          onDeletePressed: _deletePet,
          onRelatedPetTap: _onRelatedPetTap,
          onPetChanged: (updated) {
            setState(() {
              _currentPet = updated;
            });
          },
        ),
      ),
    );
  }
}
