import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Danh sách yêu thích'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: AppColors.textLight),
            SizedBox(height: 16),
            Text('Chưa có sản phẩm yêu thích', style: TextStyle(color: AppColors.textLight)),
          ],
        ),
      ),
    );
  }
}
