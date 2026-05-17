import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../admin/pages/admin_pet_form_page.dart';
import '../../home/services/pet_repository.dart';
import '../widgets/pet_detail_body.dart';

/// Backward-compatible wrapper that delegates to the appropriate page
/// based on [showAdminActions].
///
/// - When [showAdminActions] is true, behaves like [AdminPetDetailPage]
/// - When [showAdminActions] is false, behaves like [CustomerPetDetailPage]
///
/// This class is kept for backward compatibility. New code should use
/// [AdminPetDetailPage] or [CustomerPetDetailPage] directly.
class PetDetailPage extends StatefulWidget {
  const PetDetailPage({
    super.key,
    required this.pet,
    this.showAdminActions = false,
  });

  final PetItem pet;
  final bool showAdminActions;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  late PetItem _currentPet;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
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
        builder: (_) => PetDetailPage(
          pet: pet,
          showAdminActions: widget.showAdminActions,
        ),
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
          showAdminActions: widget.showAdminActions,
          onEditPressed: widget.showAdminActions ? _editPet : null,
          onDeletePressed: widget.showAdminActions ? _deletePet : null,
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
