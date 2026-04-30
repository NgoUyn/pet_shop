import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class ShopListPage extends StatelessWidget {
  const ShopListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Cửa hàng vật phẩm'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Danh sách các vật phẩm cho thú cưng'),
      ),
    );
  }
}
