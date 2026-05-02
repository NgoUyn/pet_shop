import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class AppHeader extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final bool profileMode;
  final String? avatarUrl;
  final String? displayName;
  final VoidCallback? onEditProfile;
  final ValueChanged<String>? onSearchText;
  final VoidCallback? onImageSearch;
  final VoidCallback? onCartPressed;
  final int cartCount;
  final double height;

  const AppHeader({
    super.key,
    this.title,
    this.profileMode = false,
    this.avatarUrl,
    this.displayName,
    this.onEditProfile,
    this.onSearchText,
    this.onImageSearch,
    this.onCartPressed,
    this.cartCount = 0,
    this.height = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  void _showSearchDialog(BuildContext context) {
    final ctrl = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tìm sản phẩm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Nhập tên, mô tả...'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (onImageSearch != null) onImageSearch!();
                  },
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Tìm bằng ảnh'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () {
                    final q = ctrl.text.trim();
                    Navigator.of(ctx).pop();
                    if (onSearchText != null) onSearchText!(q);
                  },
                  icon: const Icon(Icons.search),
                  label: const Text('Tìm'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCart(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          onPressed: onCartPressed,
          icon: const Icon(Icons.shopping_cart_outlined),
        ),
        if (cartCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: Text(
                  cartCount > 99 ? '99+' : cartCount.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          if (!profileMode) ...[
            IconButton(
              icon: const Icon(Icons.menu, color: AppColors.textDark),
              onPressed: () {},
            ),
            const SizedBox(width: 4),
          ],

          // Search box
          Expanded(
            child: GestureDetector(
              onTap: () => _showSearchDialog(context),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(28),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.search, size: 20, color: AppColors.textLight),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title != null && title!.isNotEmpty ? title! : 'Tìm kiếm ...',
                        style: const TextStyle(color: AppColors.textLight),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        if (onImageSearch != null) onImageSearch!();
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(6.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          padding: const EdgeInsets.all(6),
                          child: const Icon(Icons.camera_alt, size: 20, color: AppColors.textDark),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 8),
          // Cart
          _buildCart(context),
        ],
      ),
      // Profile mode top-right extras
      bottom: profileMode
          ? PreferredSize(
              preferredSize: const Size.fromHeight(0),
              child: Container(),
            )
          : null,
    );
  }
}
