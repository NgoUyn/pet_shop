import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

class ActivityPage extends StatelessWidget {
  const ActivityPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Hoạt động'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: const Center(
        child: Text('Hoạt động gần đây'),
      ),
    );
  }
}
