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
  final VoidCallback? onNotificationsPressed;
  final VoidCallback? onCartPressed;
  final int notificationCount;
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
    this.onNotificationsPressed,
    this.onCartPressed,
    this.notificationCount = 0,
    this.cartCount = 0,
    this.height = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  void _showSearchDialog(BuildContext context) {
    showSearch<String?>(
      context: context,
      delegate: _ProductSearchDelegate(
        initialQuery: title,
        onSearchText: onSearchText,
        onImageSearch: onImageSearch,
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

  Widget _buildNotifications(BuildContext context) {
    return Stack(
      alignment: Alignment.topRight,
      children: [
        IconButton(
          onPressed: onNotificationsPressed,
          icon: const Icon(Icons.notifications_outlined),
        ),
        if (notificationCount > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: Text(
                  notificationCount > 99 ? '99+' : notificationCount.toString(),
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
          // Notifications
          _buildNotifications(context),
          const SizedBox(width: 2),
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

class _ProductSearchDelegate extends SearchDelegate<String?> {
  final ValueChanged<String>? onSearchText;
  final VoidCallback? onImageSearch;
  final String? initialQuery;

  _ProductSearchDelegate({this.onSearchText, this.onImageSearch, this.initialQuery}) {
    if (initialQuery != null && initialQuery!.isNotEmpty) query = initialQuery!;
  }

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(Icons.camera_alt),
        onPressed: () {
          // Close search and trigger image search handler
          close(context, null);
          if (onImageSearch != null) onImageSearch!();
        },
        tooltip: 'Tìm bằng ảnh',
      ),
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (onSearchText != null) onSearchText!(query.trim());
      close(context, query);
    });
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: query.isEmpty
          ? const Text('Nhập tên, mô tả sản phẩm để tìm...')
          : ListView(
              children: [
                ListTile(
                  title: Text('Tìm "$query"'),
                  leading: const Icon(Icons.search),
                  onTap: () => showResults(context),
                ),
              ],
            ),
    );
  }
}
