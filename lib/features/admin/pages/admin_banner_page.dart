import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../../../core/constants/app_colors.dart';
import '../services/banner_repository.dart';

class AdminBannerPage extends StatefulWidget {
  const AdminBannerPage({super.key});

  @override
  State<AdminBannerPage> createState() => _AdminBannerPageState();
}

class _AdminBannerPageState extends State<AdminBannerPage> {
  bool _isUploading = false;

  Future<void> _pickAndAddBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked == null) return;

    String title = '';
    final titleController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Đặt tên banner'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            hintText: 'Tiêu đề (tuỳ chọn)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            onPressed: () {
              title = titleController.text.trim();
              Navigator.pop(ctx, true);
            },
            child: const Text('Thêm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isUploading = true);
    try {
      final result = await BannerRepository.instance.addBanner(
        localFilePath: picked.path,
        title: title,
      );
      if (!mounted) return;
      if (result == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tải ảnh lên thất bại'), backgroundColor: Colors.red),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã thêm banner'), backgroundColor: Colors.green),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _deleteBanner(BannerItem banner) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xóa banner'),
        content: Text('Bạn có chắc muốn xóa banner "${banner.title.isNotEmpty ? banner.title : 'này'}" không?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await BannerRepository.instance.deleteBanner(banner.bannerId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã xóa banner')),
      );
    }
  }

  Future<void> _editTitle(BannerItem banner) async {
    final ctrl = TextEditingController(text: banner.title);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Chỉnh sửa tiêu đề'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'Tiêu đề banner',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Huỷ')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lưu')),
        ],
      ),
    );
    if (confirmed != true) return;
    await BannerRepository.instance.updateTitle(banner.bannerId, ctrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Quản lý Banner'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        surfaceTintColor: AppColors.white,
        actions: [
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else
            IconButton(
              onPressed: _pickAndAddBanner,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              tooltip: 'Thêm banner',
            ),
        ],
      ),
      body: StreamBuilder<List<BannerItem>>(
        stream: BannerRepository.instance.watchAllBanners(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final banners = snapshot.data ?? [];

          if (banners.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.image_not_supported_outlined, size: 64, color: AppColors.textLight),
                  const SizedBox(height: 16),
                  const Text('Chưa có banner nào', style: TextStyle(color: AppColors.textLight, fontSize: 16)),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _isUploading ? null : _pickAndAddBanner,
                    icon: const Icon(Icons.add),
                    label: const Text('Thêm banner đầu tiên'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              // ── Preview carousel ────────────────────────────────────
              _BannerPreview(banners: banners.where((b) => b.isActive).toList()),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.drag_indicator, size: 16, color: AppColors.textLight),
                    const SizedBox(width: 6),
                    Text(
                      'Kéo thả để thay đổi thứ tự',
                      style: const TextStyle(color: AppColors.textLight, fontSize: 13),
                    ),
                  ],
                ),
              ),
              // ── Reorderable list ────────────────────────────────────
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 80),
                  itemCount: banners.length,
                  onReorder: (oldIndex, newIndex) async {
                    if (newIndex > oldIndex) newIndex--;
                    final updated = List<BannerItem>.from(banners);
                    final item = updated.removeAt(oldIndex);
                    updated.insert(newIndex, item);
                    await BannerRepository.instance.updateSortOrders(updated);
                  },
                  itemBuilder: (context, index) {
                    final banner = banners[index];
                    return _BannerListTile(
                      key: ValueKey(banner.bannerId),
                      banner: banner,
                      index: index,
                      onDelete: () => _deleteBanner(banner),
                      onToggleActive: (val) => BannerRepository.instance
                          .toggleActive(banner.bannerId, isActive: val),
                      onEditTitle: () => _editTitle(banner),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: _isUploading
          ? null
          : FloatingActionButton.extended(
              onPressed: _pickAndAddBanner,
              icon: const Icon(Icons.add),
              label: const Text('Thêm banner'),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
    );
  }
}

// ── Preview carousel ──────────────────────────────────────────────────────

class _BannerPreview extends StatefulWidget {
  const _BannerPreview({required this.banners});
  final List<BannerItem> banners;

  @override
  State<_BannerPreview> createState() => _BannerPreviewState();
}

class _BannerPreviewState extends State<_BannerPreview> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Text('Xem trước (${widget.banners.length} banner hoạt động)',
                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textDark, fontSize: 13)),
          ),
          SizedBox(
            height: 120,
            child: PageView.builder(
              itemCount: widget.banners.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (context, i) {
                final b = widget.banners[i];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: b.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      placeholder: (_, __) => Container(color: AppColors.background),
                      errorWidget: (_, __, ___) => Container(
                        color: AppColors.background,
                        child: const Center(child: Icon(Icons.broken_image, color: AppColors.textLight)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.banners.length, (i) => Container(
              width: _currentIndex == i ? 18 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
              decoration: BoxDecoration(
                color: _currentIndex == i ? AppColors.primary : AppColors.textLight.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ],
      ),
    );
  }
}

// ── Banner list tile ──────────────────────────────────────────────────────

class _BannerListTile extends StatelessWidget {
  const _BannerListTile({
    super.key,
    required this.banner,
    required this.index,
    required this.onDelete,
    required this.onToggleActive,
    required this.onEditTitle,
  });

  final BannerItem banner;
  final int index;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onEditTitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.white,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            // Drag handle
            const Icon(Icons.drag_indicator, color: AppColors.textLight),
            const SizedBox(width: 8),
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: banner.imageUrl,
                width: 72,
                height: 54,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(width: 72, height: 54, color: AppColors.background),
                errorWidget: (_, __, ___) => Container(
                  width: 72,
                  height: 54,
                  color: AppColors.background,
                  child: const Icon(Icons.broken_image, color: AppColors.textLight),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          banner.title.isNotEmpty ? banner.title : 'Banner ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      GestureDetector(
                        onTap: onEditTitle,
                        child: const Icon(Icons.edit_outlined, size: 16, color: AppColors.textLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Thứ tự: ${index + 1}',
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                  ),
                ],
              ),
            ),
            // Active toggle
            Switch.adaptive(
              value: banner.isActive,
              onChanged: onToggleActive,
              activeColor: AppColors.primary,
            ),
            // Delete
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline, color: Color(0xFFB42318)),
              tooltip: 'Xóa',
            ),
          ],
        ),
      ),
    );
  }
}
