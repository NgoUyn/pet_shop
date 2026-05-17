import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/pet_provider.dart';
import '../../../core/utils/price_helper.dart';
import '../../home/services/pet_repository.dart';
import '../../reviews/services/review_repository.dart';

/// Shared body widget for pet detail pages.
/// Displays hero image, pet information (left/right columns),
/// reviews section, and related pets section.
class PetDetailBody extends StatefulWidget {
  const PetDetailBody({
    super.key,
    required this.pet,
    this.showAdminActions = false,
    this.onEditPressed,
    this.onDeletePressed,
    this.onPetChanged,
    this.onRelatedPetTap,
  });

  final PetItem pet;
  final bool showAdminActions;
  final VoidCallback? onEditPressed;
  final VoidCallback? onDeletePressed;
  final ValueChanged<PetItem>? onPetChanged;
  final ValueChanged<PetItem>? onRelatedPetTap;

  @override
  State<PetDetailBody> createState() => _PetDetailBodyState();
}

class _PetDetailBodyState extends State<PetDetailBody> {
  late PetItem _currentPet;
  List<ReviewItem> _reviews = [];
  List<PetItem> _relatedPets = [];
  bool _isLoadingReviews = true;

  // Admin-only editable state
  bool _isDewormed = false;
  bool _isVaccinated = false;
  bool _isActive = true;
  bool _isSavingMedical = false;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
    _syncMedicalState();
    _loadReviews();
    _loadRelatedPets();
    // Listen for updates from PetProvider for real-time sync
    PetProvider.instance.addListener(_onPetsChanged);
  }

  @override
  void dispose() {
    PetProvider.instance.removeListener(_onPetsChanged);
    super.dispose();
  }

  void _syncMedicalState() {
    _isDewormed = _currentPet.isDewormed;
    _isVaccinated = _currentPet.isVaccinated;
    _isActive = _currentPet.isActive;
  }

  @override
  void didUpdateWidget(PetDetailBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pet.petId != widget.pet.petId) {
      _currentPet = widget.pet;
      _syncMedicalState();
      _loadReviews();
      _loadRelatedPets();
    } else if (oldWidget.pet.price != widget.pet.price ||
               oldWidget.pet.isActive != widget.pet.isActive ||
               oldWidget.pet.petName != widget.pet.petName ||
               oldWidget.pet.description != widget.pet.description ||
               oldWidget.pet.imageUrl != widget.pet.imageUrl ||
               oldWidget.pet.isDewormed != widget.pet.isDewormed ||
               oldWidget.pet.isVaccinated != widget.pet.isVaccinated) {
      setState(() {
        _currentPet = widget.pet;
        _syncMedicalState();
      });
    }
  }

  void _onPetsChanged() {
    if (!mounted) return;
    final updated = PetProvider.instance.pets
        .where((p) => p.petId == _currentPet.petId)
        .firstOrNull;
    if (updated != null) {
      setState(() {
        _currentPet = updated;
        _syncMedicalState();
      });
      widget.onPetChanged?.call(updated);
    }
  }

  Future<void> _loadReviews() async {
    try {
      // Use the same review repository but query by petId
      // Reviews are stored with invoice details that may reference PetID
      final reviews = await ReviewRepository.instance.getByProductId(_currentPet.petId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingReviews = false);
      }
    }
  }

  Future<void> _loadRelatedPets() async {
    try {
      final allPets = await PetRepository.instance.listActivePets(limit: 20);
      final related = allPets
          .where((p) =>
              p.petId != _currentPet.petId &&
              p.species == _currentPet.species)
          .take(6)
          .toList();
      if (mounted) {
        setState(() {
          _relatedPets = related;
        });
      }
    } catch (_) {}
  }

  /// Public method to refresh pet data from the database
  Future<void> refreshPet() async {
    final refreshed = await PetRepository.instance.getPetById(_currentPet.petId);
    if (refreshed != null && mounted) {
      setState(() {
        _currentPet = refreshed;
        _syncMedicalState();
      });
      widget.onPetChanged?.call(refreshed);
    }
  }

  String _formatDateTime(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  // ── Admin: Save medical condition toggle ──────────────────────────────

  Future<void> _saveMedicalCondition() async {
    setState(() => _isSavingMedical = true);
    try {
      final updated = await PetRepository.instance.updatePet(
        petId: _currentPet.petId,
        petName: _currentPet.petName,
        species: _currentPet.species,
        breed: _currentPet.breed,
        gender: _currentPet.gender ?? '',
        price: _currentPet.price ?? 0,
        description: _currentPet.description,
        age: _currentPet.age,
        personality: _currentPet.personality,
        isDewormed: _isDewormed,
        isVaccinated: _isVaccinated,
        imageUrl: _currentPet.imageUrl,
        isActive: _isActive,
      );
      if (mounted) {
        setState(() {
          _currentPet = updated;
        });
        widget.onPetChanged?.call(updated);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật tình trạng y tế'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingMedical = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _currentPet;
    final description = (pet.description ?? '').trim();
    final personality = (pet.personality ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Hero Image ──────────────────────────────────────────────
        _buildHeroImage(pet),
        const SizedBox(height: 12),

        // ── Admin: Edit/Delete buttons (right below image, far right) ─
        if (widget.showAdminActions) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildActionButton(
                label: 'Chỉnh sửa',
                icon: Icons.edit_outlined,
                background: const Color(0xFFEAF3FF),
                foreground: const Color(0xFF2F80ED),
                onPressed: widget.onEditPressed ?? () {},
              ),
              const SizedBox(width: 8),
              _buildActionButton(
                label: 'Xóa',
                icon: Icons.delete_outline,
                background: const Color(0xFFFDECEC),
                foreground: const Color(0xFFB42318),
                onPressed: widget.onDeletePressed ?? () {},
              ),
            ],
          ),
          const SizedBox(height: 18),
        ],

        // ── Info Card ──────────────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Line 1: Name (left) + Price (right, yellow) ──────
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      pet.petName,
                      style: const TextStyle(
                        color: AppColors.textDark,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    pet.price == null ? 'Chưa có giá' : formatPrice(pet.price!),
                    style: const TextStyle(
                      color: Color(0xFFF59E0B),
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // ── Information Section ───────────────────────────────
              // Species + Breed (aligned far right)
              _buildInfoRow(
                'Loài',
                '${pet.species}${pet.breed != null && pet.breed!.trim().isNotEmpty ? ' - ${pet.breed}' : ''}',
              ),
              const SizedBox(height: 12),

              // Age
              _buildInfoRow(
                'Tuổi',
                pet.age == null ? 'Chưa cập nhật' : formatAge(pet.age),
              ),
              const SizedBox(height: 12),

              // Gender
              _buildInfoRow(
                'Giới tính',
                genderLabel(pet.gender),
              ),
              const SizedBox(height: 12),

              // Personality
              if (personality.isNotEmpty) ...[
                _buildSectionLabel('Tính cách'),
                const SizedBox(height: 8),
                Text(
                  personality,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    height: 1.45,
                    fontFamily: 'Times New Roman',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Detailed Description (multi-line)
              if (description.isNotEmpty) ...[
                _buildSectionLabel('Mô tả chi tiết'),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppColors.textDark,
                    fontSize: 15,
                    height: 1.45,
                    fontFamily: 'Times New Roman',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Medical Condition ─────────────────────────────────
              if (widget.showAdminActions) ...[
                // Admin: Editable toggle mode
                _buildSectionLabel('Tình trạng y tế'),
                const SizedBox(height: 8),
                _buildMedicalSwitch(
                  label: 'Đã tẩy giun',
                  subtitle: _isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun',
                  value: _isDewormed,
                  onChanged: (val) {
                    setState(() => _isDewormed = val);
                    _saveMedicalCondition();
                  },
                ),
                const SizedBox(height: 8),
                _buildMedicalSwitch(
                  label: 'Đã tiêm phòng',
                  subtitle: _isVaccinated ? 'Đã tiêm phòng đầy đủ' : 'Chưa tiêm phòng',
                  value: _isVaccinated,
                  onChanged: (val) {
                    setState(() => _isVaccinated = val);
                    _saveMedicalCondition();
                  },
                ),
                const SizedBox(height: 16),

                // ── Status (For Sale / Not For Sale) ────────────────
                _buildSectionLabel('Trạng thái'),
                const SizedBox(height: 8),
                _buildStatusDropdown(),
              ] else ...[
                // Customer: Read-only medical condition
                _buildSectionLabel('Tình trạng y tế'),
                const SizedBox(height: 8),
                _buildBadge(
                  pet.isVaccinated ? 'Đã tiêm phòng' : 'Chưa tiêm phòng',
                  background: pet.isVaccinated ? const Color(0xFFD8EEE4) : const Color(0xFFF3F4F6),
                  foreground: pet.isVaccinated ? const Color(0xFF3E7C63) : const Color(0xFF6B7280),
                ),
                const SizedBox(height: 8),
                _buildBadge(
                  pet.isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun',
                  background: pet.isDewormed ? const Color(0xFFD8EEE4) : const Color(0xFFF3F4F6),
                  foreground: pet.isDewormed ? const Color(0xFF3E7C63) : const Color(0xFF6B7280),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── Đánh giá ────────────────────────────────────────────────
        _buildReviewsSection(),

        const SizedBox(height: 24),

        // ── Thú cưng liên quan ──────────────────────────────────────
        _buildRelatedPetsSection(),
      ],
    );
  }

  // ── Section Label ────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: Color(0xFF7A7A7A),
        fontSize: 15,
        fontWeight: FontWeight.w600,
        fontFamily: 'Times New Roman',
      ),
    );
  }

  // ── Hero Image ─────────────────────────────────────────────────────

  Widget _buildHeroImage(PetItem pet) {
    final imageUrl = (pet.imageUrl ?? '').trim();

    return Container(
      height: 340,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: imageUrl.isEmpty
          ? const Center(
              child: Icon(
                Icons.pets,
                size: 96,
                color: Color(0xFF2F80ED),
              ),
            )
          : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return const Center(
                  child: Icon(
                    Icons.pets,
                    size: 96,
                    color: Color(0xFF2F80ED),
                  ),
                );
              },
            ),
    );
  }

  // ── Info Row ──────────────────────────────────────────────────────

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF7A7A7A),
              fontSize: 15,
              fontWeight: FontWeight.w600,
              fontFamily: 'Times New Roman',
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppColors.textDark,
              fontSize: 15,
              fontWeight: FontWeight.w500,
              fontFamily: 'Times New Roman',
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  // ── Badge ─────────────────────────────────────────────────────────

  Widget _buildBadge(String text, {Color background = const Color(0xFFF2F8F4), Color foreground = const Color(0xFF3E7C63)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          fontFamily: 'Times New Roman',
        ),
      ),
    );
  }

  // ── Action Button ─────────────────────────────────────────────────

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Times New Roman',
          ),
        ),
      ),
    );
  }

  // ── Medical Switch (Admin) ─────────────────────────────────────────

  Widget _buildMedicalSwitch({
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: value ? const Color(0xFFE8F5E9) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: _isSavingMedical ? null : onChanged,
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: value ? Colors.green.shade700 : AppColors.textLight,
            fontSize: 12,
          ),
        ),
        activeTrackColor: AppColors.primary,
      ),
    );
  }

  // ── Status Dropdown (Admin) ────────────────────────────────────────

  Widget _buildStatusDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<bool>(
          value: _isActive,
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down),
          onChanged: _isSavingMedical
              ? null
              : (val) async {
                  if (val == null) return;
                  setState(() => _isActive = val);
                  await _saveMedicalCondition();
                },
          items: const [
            DropdownMenuItem(
              value: true,
              child: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Đang bán',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            DropdownMenuItem(
              value: false,
              child: Row(
                children: [
                  Icon(Icons.cancel, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Ngưng bán',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Reviews Section ──────────────────────────────────────────────────

  Widget _buildReviewsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 24),
            const SizedBox(width: 6),
            Text(
              'Đánh giá (${_reviews.length})',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFamily: 'Times New Roman',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoadingReviews)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_reviews.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Text(
                'Chưa có đánh giá nào cho thú cưng này',
                style: TextStyle(
                  color: AppColors.textLight,
                  fontSize: 15,
                  fontFamily: 'Times New Roman',
                ),
              ),
            ),
          )
        else
          ..._reviews.map(_buildReviewCard),
      ],
    );
  }

  Widget _buildReviewCard(ReviewItem review) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer name + date
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEAF3FF),
                child: Text(
                  (review.customerName ?? '?')[0].toUpperCase(),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2F80ED),
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName ?? 'Khách hàng',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                    Text(
                      _formatDateTime(review.createdAt.toLocal()),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                  ],
                ),
              ),
              // Stars
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (i) {
                  return Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: const Color(0xFFFFB300),
                  );
                }),
              ),
            ],
          ),

          // Content
          if ((review.content ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              review.content!,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textDark,
                height: 1.4,
                fontFamily: 'Times New Roman',
              ),
            ),
          ],

          // Images
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    review.imageUrls[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Related Pets Section ─────────────────────────────────────────────

  Widget _buildRelatedPetsSection() {
    if (_relatedPets.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thú cưng liên quan',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            fontFamily: 'Times New Roman',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _relatedPets.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final related = _relatedPets[index];
              return SizedBox(
                width: 150,
                child: _buildRelatedPetCard(related),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRelatedPetCard(PetItem pet) {
    final imageUrl = (pet.imageUrl ?? '').trim();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (widget.onRelatedPetTap != null) {
          widget.onRelatedPetTap!(pet);
        } else {
          // Default behavior: navigate using the same context
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => _buildDefaultRelatedPage(pet),
            ),
          );
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: imageUrl.isEmpty
                    ? const Center(
                        child: Icon(Icons.pets, size: 40, color: Color(0xFF9AA5B1)),
                      )
                    : Image.network(
                        imageUrl,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => const Center(
                          child: Icon(Icons.pets, size: 40, color: Color(0xFF9AA5B1)),
                        ),
                      ),
              ),
            ),

            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.petName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pet.price == null ? 'Liên hệ' : formatPrice(pet.price!),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFFF59E0B),
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Default fallback when no onRelatedPetTap is provided
  Widget _buildDefaultRelatedPage(PetItem pet) {
    return _buildOriginalDetailPage(pet);
  }

  Widget _buildOriginalDetailPage(PetItem pet) {
    try {
      return _PetDetailPageRedirector(pet: pet, showAdminActions: widget.showAdminActions);
    } catch (_) {
      return const SizedBox.shrink();
    }
  }
}

/// Helper widget to redirect to the original PetDetailPage
class _PetDetailPageRedirector extends StatelessWidget {
  const _PetDetailPageRedirector({
    required this.pet,
    this.showAdminActions = false,
  });

  final PetItem pet;
  final bool showAdminActions;

  @override
  Widget build(BuildContext context) {
    // This widget is a placeholder - the actual navigation is handled
    // by the parent page's onRelatedPetTap callback
    return const SizedBox.shrink();
  }
}
