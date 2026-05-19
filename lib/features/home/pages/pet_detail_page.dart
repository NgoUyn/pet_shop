import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../admin/pages/admin_pet_form_page.dart';
import '../../reviews/services/review_repository.dart';
import '../../profile/services/profile_repository.dart';
import '../../favorites/services/favorite_repository.dart';
import '../../cart/services/cart_repository.dart';
import '../services/pet_repository.dart';

class PetDetailPage extends StatefulWidget {
  const PetDetailPage({super.key, required this.pet});

  final PetItem pet;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  late PetItem _currentPet;
  List<ReviewItem> _reviews = [];
  bool _isAdmin = false;
  bool _isFavorited = false;
  bool _isProcessingFavorite = false;
  bool _isAddingToCart = false;
  bool _isLoadingReviews = true;

  @override
  void initState() {
    super.initState();
    _currentPet = widget.pet;
    _loadReviews();
    _checkAdmin();
    _loadFavoriteStatus();
  }

  Future<void> _loadFavoriteStatus() async {
    try {
      final fav = await FavoriteRepository.instance.isPetFavorited(_currentPet.petId);
      if (!mounted) return;
      setState(() {
        _isFavorited = fav;
      });
    } catch (_) {
      // ignore
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isProcessingFavorite) return;
    setState(() {
      _isProcessingFavorite = true;
    });

    try {
      await FavoriteRepository.instance.togglePetFavorite(_currentPet.petId);
      final fav = await FavoriteRepository.instance.isPetFavorited(_currentPet.petId);
      if (!mounted) return;
      setState(() {
        _isFavorited = fav;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _isProcessingFavorite = false;
      });
    }
  }

  Future<void> _addToCart() async {
    if (_isAddingToCart) return;
    setState(() { _isAddingToCart = true; });
    try {
      await CartRepository.instance.addPetToCart(petId: _currentPet.petId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm thú cưng vào giỏ hàng')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    } finally {
      if (!mounted) return;
      setState(() { _isAddingToCart = false; });
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

  String _formatDateTime(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year} ${twoDigits(value.hour)}:${twoDigits(value.minute)}';
  }

  String _genderLabel(String? gender) {
    final normalized = (gender ?? '').trim();
    if (normalized.isEmpty) {
      return 'Chưa cập nhật';
    }

    final lower = normalized.toLowerCase();
    if (lower.contains('female') || lower.contains('cái')) {
      return 'Cái';
    }
    if (lower.contains('male') || lower.contains('đực')) {
      return 'Đực';
    }
    return normalized;
  }

  String _ageLabel(int? age) {
    if (age == null) {
      return 'Chưa cập nhật';
    }
    return '$age tháng tuổi';
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await ReviewRepository.instance.getByPetId(_currentPet.petId);
      if (mounted) {
        setState(() {
          _reviews = reviews;
          _isLoadingReviews = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
        });
      }
    }
  }

  Future<void> _checkAdmin() async {
    try {
      final profile = await ProfileRepository.instance.getCurrentProfile();
      if (!mounted) return;
      setState(() {
        _isAdmin = profile?.role.toLowerCase() == 'admin';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isAdmin = false;
      });
    }
  }

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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
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
      ),
    );
  }

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

  Future<void> _editPet() async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => AdminPetFormPage(pet: _currentPet)),
    );

    if (changed != true || !mounted) {
      return;
    }

    final refreshed = await PetRepository.instance.getPetById(_currentPet.petId);
    if (!mounted || refreshed == null) {
      return;
    }

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

    if (confirmed != true) {
      return;
    }

    try {
      await PetRepository.instance.deletePet(_currentPet.petId);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('StateError: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pet = _currentPet;
    final description = (pet.description ?? '').trim();
    final personality = (pet.personality ?? '').trim();

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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroImage(pet),
            const SizedBox(height: 18),
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 720;

                  final leftColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_isAdmin)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildActionButton(
                              label: 'Chỉnh sửa',
                              icon: Icons.edit_outlined,
                              background: const Color(0xFFEAF3FF),
                              foreground: const Color(0xFF2F80ED),
                              onPressed: _editPet,
                            ),
                            _buildActionButton(
                              label: 'Xóa',
                              icon: Icons.delete_outline,
                              background: const Color(0xFFFDECEC),
                              foreground: const Color(0xFFB42318),
                              onPressed: _deletePet,
                            ),
                          ],
                        )
                      else
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: _isProcessingFavorite ? null : _toggleFavorite,
                              icon: Icon(
                                _isFavorited ? Icons.favorite : Icons.favorite_border,
                                color: _isFavorited ? const Color(0xFFFF2D55) : AppColors.textLight,
                              ),
                              tooltip: 'Yêu thích',
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _isAddingToCart ? null : _addToCart,
                              icon: const Icon(Icons.add_shopping_cart, color: Color(0xFF2F80ED)),
                              tooltip: 'Thêm vào giỏ',
                            ),
                          ],
                        ),
                      const SizedBox(height: 18),
                      _buildInfoRow('Mã thú cưng', pet.petId.toString()),
                      _buildInfoRow('Loài', pet.species),
                      _buildInfoRow('Giới tính', _genderLabel(pet.gender)),
                      _buildInfoRow('Tuổi', _ageLabel(pet.age)),
                      _buildInfoRow('Trạng thái', pet.isActive ? 'Đang bán' : 'Ngừng bán'),
                      _buildInfoRow('Ngày tạo', _formatDateTime(pet.createdAt.toLocal())),
                      if (description.isNotEmpty) ...[
                        const Text(
                          'Mô tả',
                          style: TextStyle(
                            color: Color(0xFF7A7A7A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
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
                      ],
                    ],
                  );

                  final rightColumn = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(
                        pet.price == null ? 'Chưa có giá' : _formatPrice(pet.price!),
                        style: const TextStyle(
                          color: Color(0xFFF59E0B),
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          fontFamily: 'Times New Roman',
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildBadge(
                        pet.isVaccinated ? 'Đã tiêm phòng' : 'Chưa tiêm phòng',
                        background: pet.isVaccinated ? const Color(0xFFD8EEE4) : const Color(0xFFF3F4F6),
                        foreground: pet.isVaccinated ? const Color(0xFF3E7C63) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 10),
                      _buildBadge(
                        pet.isDewormed ? 'Đã tẩy giun' : 'Chưa tẩy giun',
                        background: pet.isDewormed ? const Color(0xFFD8EEE4) : const Color(0xFFF3F4F6),
                        foreground: pet.isDewormed ? const Color(0xFF3E7C63) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 10),
                      _buildBadge(
                        pet.isActive ? 'Đang bán' : 'Ngừng bán',
                        background: pet.isActive ? const Color(0xFFEAF3FF) : const Color(0xFFF3F4F6),
                        foreground: pet.isActive ? const Color(0xFF2F80ED) : const Color(0xFF6B7280),
                      ),
                      const SizedBox(height: 10),
                      if (pet.price != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8F9FB),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFE7EAF0)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.sell_outlined, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 10),
                              const Text(
                                'Giá',
                                style: TextStyle(
                                  color: AppColors.textLight,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  fontFamily: 'Times New Roman',
                                ),
                              ),
                              const Spacer(),
                              Text(
                                _formatPrice(pet.price!),
                                style: const TextStyle(
                                  color: Color(0xFFF59E0B),
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  fontFamily: 'Times New Roman',
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (personality.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        const Text(
                          'Tính cách',
                          style: TextStyle(
                            color: Color(0xFF7A7A7A),
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            fontFamily: 'Times New Roman',
                          ),
                        ),
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
                      ],
                    ],
                  );

                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        leftColumn,
                        const SizedBox(height: 20),
                        rightColumn,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: leftColumn),
                      const SizedBox(width: 16),
                      Expanded(child: rightColumn),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            _buildReviewsSection(),
          ],
        ),
      ),
    );
  }

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

  String _reviewDateLabel(DateTime value) {
    String twoDigits(int input) => input.toString().padLeft(2, '0');
    return '${twoDigits(value.day)}/${twoDigits(value.month)}/${value.year}';
  }

  Widget _buildReviewCard(ReviewItem review) {
    final customerName = (review.customerName ?? '').trim();
    final displayName = customerName.isNotEmpty ? customerName : 'Khách hàng';
    final avatarText = displayName.isNotEmpty ? displayName[0].toUpperCase() : '?';

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
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFFEAF3FF),
                child: Text(
                  avatarText,
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
                      displayName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                    Text(
                      _reviewDateLabel(review.createdAt.toLocal()),
                      style: const TextStyle(
                        color: AppColors.textLight,
                        fontSize: 12,
                        fontFamily: 'Times New Roman',
                      ),
                    ),
                  ],
                ),
              ),
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
          if (review.imageUrls.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 80,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: review.imageUrls.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) => ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    review.imageUrls[i],
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 32, color: Colors.grey),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
