import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../services/review_repository.dart';

const _apiBaseUrl = 'http://10.0.2.2:3000';

class ReviewPage extends StatefulWidget {
  final int invoiceId;

  const ReviewPage({super.key, required this.invoiceId});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  int _rating = 0;
  final _contentController = TextEditingController();
  bool _isLoading = true;
  bool _isSubmitting = false;
  ReviewItem? _existingReview;
  final List<File> _images = [];
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _checkExisting() async {
    final review = await ReviewRepository.instance.getByInvoiceId(widget.invoiceId);
    if (mounted) {
      setState(() {
        _existingReview = review;
        if (review != null) {
          _rating = review.rating;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImages() async {
    if (_images.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tối đa 3 ảnh')),
      );
      return;
    }

    final picked = await _picker.pickMultiImage(limit: 3 - _images.length);
    if (picked.isNotEmpty) {
      setState(() {
        for (final file in picked) {
          if (_images.length < 3) {
            _images.add(File(file.path));
          }
        }
      });
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _isSubmitting = true);

    try {
      // Upload images to Cloudinary
      final imageUrls = <String>[];
      for (final image in _images) {
        final url = await CloudinaryHelper.uploadImage(image.path);
        if (url != null) {
          imageUrls.add(url);
        }
      }

      // Check images for inappropriate content
      var moderationStatus = 'approved';
      if (imageUrls.isNotEmpty) {
        final passed = await _checkImagesModeration(imageUrls);
        if (!passed) {
          moderationStatus = 'flagged';
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Cảnh báo: Ảnh của bạn có thể chứa nội dung không phù hợp và đang được xem xét.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
        }
      }

      await ReviewRepository.instance.create(
        invoiceId: widget.invoiceId,
        rating: _rating,
        content: _contentController.text,
        imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
        moderationStatus: moderationStatus,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gửi đánh giá thành công')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e')),
        );
      }
    }
  }

  Future<bool> _checkImagesModeration(List<String> imageUrls) async {
    try {
      final response = await http.post(
        Uri.parse('$_apiBaseUrl/check-review-images'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'imageUrls': imageUrls}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['passed'] == true;
      }
      // If API unavailable, allow submission (fail open)
      return true;
    } catch (e) {
      print('Moderation check failed, allowing submission: $e');
      return true; // Fail open if API unreachable
    }
  }

  Widget _buildStar(int index) {
    final filled = index <= _rating;
    return GestureDetector(
      onTap: _existingReview != null ? null : () => setState(() => _rating = index),
      child: Icon(
        filled ? Icons.star : Icons.star_border,
        size: 40,
        color: filled ? const Color(0xFFFFB300) : Colors.grey.shade300,
      ),
    );
  }

  Widget _buildImagePreview() {
    if (_images.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _images.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _images[index],
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: GestureDetector(
                      onTap: () => setState(() => _images.removeAt(index)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReviewImages(List<String> urls) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  urls[index],
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Đánh giá đơn hàng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 16),
                  Text(
                    'Đơn hàng #${widget.invoiceId}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Star rating
                  if (_existingReview != null) ...[
                    const Icon(Icons.check_circle, size: 48, color: AppColors.primary),
                    const SizedBox(height: 8),
                    const Text(
                      'Bạn đã đánh giá đơn hàng này',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => _buildStar(i + 1)),
                    ),
                    if (_existingReview!.content != null &&
                        _existingReview!.content!.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _existingReview!.content!,
                          style: const TextStyle(fontSize: 14, color: AppColors.textDark),
                        ),
                      ),
                    ],
                    _buildReviewImages(_existingReview!.imageUrls),
                  ] else ...[
                    const Text(
                      'Bạn thấy đơn hàng này thế nào?',
                      style: TextStyle(fontSize: 16, color: AppColors.textLight),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(5, (i) => _buildStar(i + 1)),
                    ),
                    const SizedBox(height: 24),

                    // Review content
                    TextField(
                      controller: _contentController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Chia sẻ trải nghiệm của bạn...',
                        filled: true,
                        fillColor: AppColors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Image picker button
                    Row(
                      children: [
                        IconButton.outlined(
                          onPressed: _images.length >= 3 ? null : _pickImages,
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          tooltip: 'Thêm ảnh (tối đa 3)',
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_images.length}/3 ảnh',
                          style: const TextStyle(fontSize: 13, color: AppColors.textLight),
                        ),
                      ],
                    ),
                    _buildImagePreview(),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting || _rating == 0 ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            : const Text('Gửi đánh giá', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
