import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/cloudinary_helper.dart';
import '../../../core/widgets/optimized_network_image.dart';
import '../../../core/utils/cloudinary_transform.dart';
import '../../admin/services/banner_repository.dart';

class BannerManagementPage extends StatefulWidget {
  const BannerManagementPage({super.key});

  @override
  State<BannerManagementPage> createState() => _BannerManagementPageState();
}

class _BannerManagementPageState extends State<BannerManagementPage> {
  final BannerRepository _repo = BannerRepository.instance;
  List<BannerItem> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final items = await _repo.listAll();
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _addBanner() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 800,
      imageQuality: 80,
    );
    if (picked == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = await CloudinaryHelper.uploadImage(picked.path);
      Navigator.pop(context);
      if (url == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Upload ảnh thất bại')));
        return;
      }

      await _repo.create(name: 'Banner', imageUrl: url);
      await _load();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã thêm banner')));
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
    }
  }

  Future<void> _deleteBanner(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Xóa banner'),
        content: const Text('Bạn có chắc muốn xóa banner này?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Xóa')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repo.delete(id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý banner'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addBanner,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: _items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final it = _items[index];
                return Card(
                  child: ListTile(
                    leading: it.imageUrl.isNotEmpty
                        ? OptimizedNetworkImage(imageUrl: it.imageUrl, size: CloudinaryImageSize.avatar, width: 72, fit: BoxFit.cover)
                        : const Icon(Icons.image_outlined),
                    title: Text(it.name ?? 'Banner ${it.id}'),
                    subtitle: Text('ID: ${it.id} • Tạo: ${it.createdAt}'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () => _deleteBanner(it.id),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
