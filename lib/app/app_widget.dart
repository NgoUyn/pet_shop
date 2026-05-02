import 'package:flutter/material.dart';
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
      home: const LoginPage(),
    );
  }
}
