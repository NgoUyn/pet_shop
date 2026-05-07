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
  final VoidCallback? onFavoritesPressed;
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
    this.onFavoritesPressed,
    this.notificationCount = 0,
    this.cartCount = 0,
    this.height = kToolbarHeight + 10,
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

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.textDark,
      elevation: 0,
      automaticallyImplyLeading: false,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          children: [
            if (!profileMode)
              IconButton(
                icon: const Icon(Icons.menu, color: Colors.black54),
                onPressed: () {},
              ),

            // Search box
            Expanded(
              child: GestureDetector(
                onTap: () => _showSearchDialog(context),
                child: Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 22, color: Colors.black45),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title != null && title!.isNotEmpty ? title! : 'Tìm kiếm ...',
                          style: const TextStyle(color: Colors.black45, fontSize: 16),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Camera Button inside search
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        elevation: 1,
                        child: InkWell(
                          onTap: onImageSearch,
                          borderRadius: BorderRadius.circular(16),
                          child: const Padding(
                            padding: EdgeInsets.all(6.0),
                            child: Icon(Icons.camera_alt, size: 20, color: Colors.black87),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 4),

            // Favorites (Heart)
            IconButton(
              icon: const Icon(Icons.favorite_outline, color: Colors.black54),
              onPressed: onFavoritesPressed,
            ),

            // Notifications
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  onPressed: onNotificationsPressed,
                  icon: const Icon(Icons.notifications_outlined, color: Colors.black54),
                ),
                if (notificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          notificationCount > 99 ? '99+' : notificationCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Cart
            Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  onPressed: onCartPressed,
                  icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black54),
                ),
                if (cartCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Center(
                        child: Text(
                          cartCount > 99 ? '99+' : cartCount.toString(),
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
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
          close(context, null);
          if (onImageSearch != null) onImageSearch!();
        },
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
          ? const Text('Nhập tên để tìm kiếm...')
          : ListTile(
              title: Text('Tìm "$query"'),
              leading: const Icon(Icons.search),
              onTap: () => showResults(context),
            ),
    );
  }
}
