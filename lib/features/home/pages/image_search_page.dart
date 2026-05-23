import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/image_search_service.dart';
import '../../../core/widgets/optimized_network_image.dart';
import '../../../core/utils/cloudinary_transform.dart';
import '../services/product_repository.dart';
import '../services/pet_repository.dart';
import '../../product_detail/pages/customer_product_detail_page.dart';
import '../../pet_detail/pages/customer_pet_detail_page.dart';

/// Page for searching products/pets by image using CLIP model.
class ImageSearchPage extends StatefulWidget {
  const ImageSearchPage({super.key});

  @override
  State<ImageSearchPage> createState() => _ImageSearchPageState();
}

class _ImageSearchPageState extends State<ImageSearchPage> {
  final ImageSearchService _searchService = ImageSearchService.instance;

  // State
  bool _isLoading = false;
  bool _hasSearched = false;
  String? _errorMessage;
  XFile? _selectedImage;
  List<ImageSearchResult> _results = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tìm kiếm bằng hình ảnh'),
        centerTitle: true,
        actions: [
          if (_hasSearched)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _resetSearch,
              tooltip: 'Tìm lại',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildImagePickerSection(),
            const SizedBox(height: 16),
            if (_isLoading) _buildLoadingIndicator(),
            if (_errorMessage != null) _buildErrorCard(),
            if (_hasSearched && !_isLoading) _buildResultsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePickerSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text(
              'Chọn ảnh để tìm kiếm',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tải lên hình ảnh thú cưng hoặc sản phẩm\nđể tìm các mặt hàng tương tự',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
            const SizedBox(height: 20),

            // Image preview
            if (_selectedImage != null)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_selectedImage!.path),
                    fit: BoxFit.cover,
                    width: double.infinity,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image,
                      size: 80,
                      color: Colors.grey,
                    ),
                  ),
                ),
              )
            else
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.grey.shade300,
                    style: BorderStyle.solid,
                  ),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.image_search, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text(
                        'Chưa chọn ảnh',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(false),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Thư viện'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () => _pickImage(true),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Chụp ảnh'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),

            if (_selectedImage != null) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _performSearch,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.search),
                  label: Text(_isLoading ? 'Đang tìm...' : 'Tìm kiếm'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Đang tìm kiếm sản phẩm tương tự...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard() {
    return Card(
      color: Colors.red.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsSection() {
    if (_results.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              const Text(
                'Không tìm thấy sản phẩm tương tự',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thử chọn ảnh khác hoặc chụp ảnh rõ nét hơn',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 20, color: Colors.amber),
            const SizedBox(width: 8),
            Text(
              'Kết quả tìm kiếm (${_results.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ..._results.map((result) => _buildResultCard(result)),
      ],
    );
  }

  Widget _buildResultCard(ImageSearchResult result) {
    final similarityPercent = (result.similarity * 100).toStringAsFixed(1);
    final isProduct = result.type == 'product';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _navigateToDetail(result),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: OptimizedNetworkImage(
                  imageUrl: result.imageUrl,
                  size: CloudinaryImageSize.avatar,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 12),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          isProduct ? Icons.shopping_bag : Icons.pets,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isProduct ? 'Sản phẩm' : 'Thú cưng',
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                        if (result.category.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              result.category,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          '${result.price.toStringAsFixed(0)}đ',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 15,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Phù hợp: $similarityPercent%',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Actions ──────────────────────────────────────────────────────────

  Future<void> _pickImage(bool fromCamera) async {
    final image = await _searchService.pickImage(fromCamera: fromCamera);
    if (image != null) {
      setState(() {
        _selectedImage = image;
        _hasSearched = false;
        _results = [];
        _errorMessage = null;
      });
    }
  }

  Future<void> _performSearch() async {
    if (_selectedImage == null) return;
    if (!mounted) return;

    print('=' * 60);
    print('[ImageSearchPage] _performSearch called');
    print('[ImageSearchPage] Image path: ${_selectedImage!.path}');
    print('[ImageSearchPage] Image name: ${_selectedImage!.name}');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      print('[ImageSearchPage] Calling searchByImageFile...');
      final results = await _searchService.searchByImageFile(
        _selectedImage!,
        topK: 20,
      );

      print('[ImageSearchPage] searchByImageFile returned ${results.length} results');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _results = results;
        if (results.isEmpty) {
          _errorMessage = 'Không tìm thấy kết quả phù hợp';
        }
      });
    } catch (e) {
      print('[ImageSearchPage] EXCEPTION in _performSearch: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _hasSearched = true;
        _errorMessage = 'Có lỗi xảy ra: ${e.toString()}';
      });
    }
  }

  void _resetSearch() {
    setState(() {
      _selectedImage = null;
      _hasSearched = false;
      _results = [];
      _errorMessage = null;
    });
  }

  void _navigateToDetail(ImageSearchResult result) async {
    if (result.type == 'product') {
      final product = await ProductRepository.instance.getProductById(result.id);
      if (product != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerProductDetailPage(
              product: product,
            ),
          ),
        );
      }
    } else {
      final pet = await PetRepository.instance.getPetById(result.id);
      if (pet != null && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => CustomerPetDetailPage(
              pet: pet,
            ),
          ),
        );
      }
    }
  }
}
