import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class FavoritesPage extends StatelessWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.favorite_border, size: 80, color: AppColors.textLight),
              SizedBox(height: 16),
              Text('Chưa có sản phẩm yêu thích', style: TextStyle(color: AppColors.textLight)),
            ],
          ),
        ),
      ),
    );
  }
}
