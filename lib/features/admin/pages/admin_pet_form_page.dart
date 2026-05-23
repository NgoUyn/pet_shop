import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../../home/services/pet_repository.dart';

class AdminPetFormPage extends StatefulWidget {
  const AdminPetFormPage({super.key, this.pet});

  final PetItem? pet;

  @override
  State<AdminPetFormPage> createState() => _AdminPetFormPageState();
}

class _AdminPetFormPageState extends State<AdminPetFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _petNameController = TextEditingController();
  final _breedController = TextEditingController();
  final _priceController = TextEditingController();
  final _ageController = TextEditingController();
  final _personalityController = TextEditingController();
  final _descriptionController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  String _species = 'Chó';
  String? _initialImageUrl;
  String _gender = 'Cái';
  bool _isDewormed = false;
  bool _isVaccinated = false;
  bool _isSaving = false;
  String? _imagePath;

  bool get _isEditing => widget.pet != null;

  @override
  void initState() {
    super.initState();
    final pet = widget.pet;
    if (pet != null) {
      _petNameController.text = pet.petName;
      _species = pet.species;
      _breedController.text = pet.breed ?? '';
      _priceController.text = pet.price?.toStringAsFixed(0) ?? '';
      _ageController.text = pet.age?.toString() ?? '';
      _personalityController.text = pet.personality ?? '';
      _descriptionController.text = pet.description ?? '';
      _gender = pet.gender ?? 'Chưa xác định';
      _isDewormed = pet.isDewormed;
      _isVaccinated = pet.isVaccinated;
      _initialImageUrl = pet.imageUrl;
    }
  }

  @override
  void dispose() {
    _petNameController.dispose();
    _breedController.dispose();
    _priceController.dispose();
    _ageController.dispose();
    _personalityController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1080,
      );
      if (file == null) return;
      setState(() {
        _imagePath = file.path;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể chọn ảnh: $e')),
      );
    }
  }

  Widget _buildPreviewPlaceholder() {
    return Container(
      height: 180,
      width: double.infinity,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7F8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE0E7EF)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 44, color: Color(0xFF9AA5B1)),
          SizedBox(height: 8),
          Text(
            'Chưa chọn ảnh',
            style: TextStyle(color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    final hasNewImage = (_imagePath?.trim().isNotEmpty == true);
    final hasExistingImage = (_initialImageUrl ?? '').trim().isNotEmpty;

    Widget imageWidget;
    if (hasNewImage) {
      imageWidget = ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image.file(
          File(_imagePath!.trim()),
          height: 180,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
        ),
      );
    } else if (hasExistingImage) {
      final url = _initialImageUrl!.trim();
      final isNetwork = url.startsWith('http://') || url.startsWith('https://');
      if (isNetwork) {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: CachedNetworkImage(
            imageUrl: url,
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorWidget: (_, __, ___) => _buildPreviewPlaceholder(),
          ),
        );
      } else {
        imageWidget = ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Image.file(
            File(url),
            height: 180,
            width: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPreviewPlaceholder(),
          ),
        );
      }
    } else {
      imageWidget = _buildPreviewPlaceholder();
    }

    return InkWell(
      onTap: _isSaving ? null : _pickImage,
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          imageWidget,
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                color: Colors.black.withValues(alpha: 0.45),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(
                    hasNewImage || hasExistingImage ? 'Chạm để đổi ảnh' : 'Chạm để thêm ảnh',
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _savePet() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Upload to Cloudinary if a new image was picked, otherwise use existing URL
      String? imageUrl;
      if (_imagePath?.trim().isNotEmpty == true) {
        imageUrl = await CloudinaryHelper.uploadImage(_imagePath!.trim());
        if (imageUrl == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể tải ảnh lên Cloudinary. Vui lòng thử lại.')),
          );
          setState(() => _isSaving = false);
          return;
        }
      } else {
        imageUrl = _initialImageUrl;
      }

      final breed = _breedController.text.trim();
      final resolvedBreed = breed.isEmpty ? null : breed;

      if (_isEditing) {
        await PetRepository.instance.updatePet(
          petId: widget.pet!.petId,
          petName: _petNameController.text.trim(),
          species: _species,
          breed: resolvedBreed,
          gender: _gender,
          price: double.parse(_priceController.text.trim()),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          age: int.tryParse(_ageController.text.trim()),
          personality: _personalityController.text.trim().isEmpty ? null : _personalityController.text.trim(),
          isDewormed: _isDewormed,
          isVaccinated: _isVaccinated,
          imageUrl: imageUrl,
        );
      } else {
        await PetRepository.instance.addPet(
          petName: _petNameController.text.trim(),
          species: _species,
          breed: resolvedBreed,
          gender: _gender,
          price: double.parse(_priceController.text.trim()),
          description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
          age: int.tryParse(_ageController.text.trim()),
          personality: _personalityController.text.trim().isEmpty ? null : _personalityController.text.trim(),
          isDewormed: _isDewormed,
          isVaccinated: _isVaccinated,
          imageUrl: imageUrl,
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể lưu thú cưng: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Chỉnh sửa thú cưng' : 'Nhập thú cưng mới'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Image Picker ──────────────────────────────────────
                      _buildImagePreview(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isSaving ? null : _pickImage,
                          icon: const Icon(Icons.upload_outlined),
                          label: const Text('Tải ảnh thú cưng'),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // ── Pet Name ──────────────────────────────────────────
                      _buildTextField(
                        controller: _petNameController,
                        label: 'Tên thú cưng',
                        hintText: 'Ví dụ: Milu',
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Vui lòng nhập tên thú cưng' : null,
                      ),
                      const SizedBox(height: 12),

                      // ── Species (Category) Selector ───────────────────────
                      DropdownButtonFormField<String>(
                        value: _species,
                        decoration: InputDecoration(
                          labelText: 'Loài',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Chó', child: Text('Chó')),
                          DropdownMenuItem(value: 'Mèo', child: Text('Mèo')),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _species = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),

                      // ── Breed ─────────────────────────────────────────────
                      _buildTextField(
                        controller: _breedController,
                        label: 'Giống',
                        hintText: 'Ví dụ: Poodle, Husky, Anh lông ngắn',
                      ),
                      const SizedBox(height: 12),

                      // ── Gender Selector ───────────────────────────────────
                      DropdownButtonFormField<String>(
                        value: _gender,
                        decoration: InputDecoration(
                          labelText: 'Giới tính',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Đực', child: Text('Đực')),
                          DropdownMenuItem(value: 'Cái', child: Text('Cái')),
                          DropdownMenuItem(value: 'Chưa xác định', child: Text('Chưa xác định')),
                        ],
                        onChanged: _isSaving
                            ? null
                            : (value) {
                                if (value == null) return;
                                setState(() {
                                  _gender = value;
                                });
                              },
                      ),
                      const SizedBox(height: 12),

                      // ── Price & Age (side by side) ────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: _buildTextField(
                              controller: _priceController,
                              label: 'Giá',
                              hintText: '3.500.000',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final parsed = double.tryParse((value ?? '').trim());
                                if (parsed == null || parsed <= 0) {
                                  return 'Vui lòng nhập giá hợp lệ';
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTextField(
                              controller: _ageController,
                              label: 'Tuổi',
                              hintText: '3',
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                final text = (value ?? '').trim();
                                if (text.isEmpty) return null;
                                final parsed = int.tryParse(text);
                                if (parsed == null || parsed < 0) {
                                  return 'Tuổi không hợp lệ';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── Personality ───────────────────────────────────────
                      _buildTextField(
                        controller: _personalityController,
                        label: 'Tính cách',
                        hintText: 'Thân thiện, hiền, năng động...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),

                      // ── Detailed Description ──────────────────────────────
                      _buildTextField(
                        controller: _descriptionController,
                        label: 'Mô tả chi tiết',
                        hintText: 'Ghi chú thêm về ngoại hình, thói quen, sức khỏe...',
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // ── Health Status Toggles ─────────────────────────────
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.medical_services_outlined,
                                    size: 20, color: AppColors.primary),
                                const SizedBox(width: 8),
                                const Text(
                                  'Tình trạng y tế',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Dewormed Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isDewormed
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _isDewormed,
                                onChanged: _isSaving
                                    ? null
                                    : (value) =>
                                        setState(() => _isDewormed = value),
                                title: const Text(
                                  'Đã tẩy giun',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  _isDewormed
                                      ? 'Thú cưng đã được tẩy giun'
                                      : 'Chưa tẩy giun',
                                  style: TextStyle(
                                      color: _isDewormed
                                          ? Colors.green.shade700
                                          : AppColors.textLight,
                                      fontSize: 12),
                                ),
                                activeColor: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            // Vaccinated Toggle
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: _isVaccinated
                                    ? const Color(0xFFE8F5E9)
                                    : const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: SwitchListTile.adaptive(
                                contentPadding: EdgeInsets.zero,
                                value: _isVaccinated,
                                onChanged: _isSaving
                                    ? null
                                    : (value) =>
                                        setState(() => _isVaccinated = value),
                                title: const Text(
                                  'Đã tiêm phòng',
                                  style: TextStyle(fontWeight: FontWeight.w600),
                                ),
                                subtitle: Text(
                                  _isVaccinated
                                      ? 'Thú cưng đã được tiêm phòng đầy đủ'
                                      : 'Chưa tiêm phòng',
                                  style: TextStyle(
                                      color: _isVaccinated
                                          ? Colors.green.shade700
                                          : AppColors.textLight,
                                      fontSize: 12),
                                ),
                                activeColor: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Save Button ───────────────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving ? null : _savePet,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_outlined),
                          label: Text(
                            _isSaving
                                ? 'Đang lưu...'
                                : (_isEditing
                                    ? 'Cập nhật thú cưng'
                                    : 'Lưu thú cưng'),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}
