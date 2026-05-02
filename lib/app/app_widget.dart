import 'package:flutter/material.dart';
import 'package:pet_shop/features/home/pages/home_page.dart';
import '../core/constants/app_colors.dart';
import '../features/auth/pages/login_page.dart';
import '../core/widgets/main_wrapper.dart';

class AppWidget extends StatelessWidget {
  const AppWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Shop App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      // Đặt LoginPage làm màn hình gốc để khi từ RegisterPage pop() sẽ quay về đây
      home: const MainWrapper(),
    );
  }
}
