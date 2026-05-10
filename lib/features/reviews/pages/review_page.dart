import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../services/review_repository.dart';

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
        _isLoading = false;
      });
    }
  }

  Future<void> _submit() async {
    if (_rating == 0) return;
    setState(() => _isSubmitting = true);
    try {
      await ReviewRepository.instance.create(
        invoiceId: widget.invoiceId,
        rating: _rating,
        content: _contentController.text,
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
