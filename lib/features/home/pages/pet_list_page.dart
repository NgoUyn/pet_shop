import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class PetListPage extends StatelessWidget {
  const PetListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mua thú cưng'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Danh sách thú cưng từ các cửa hàng'),
      ),
    );
  }
}
