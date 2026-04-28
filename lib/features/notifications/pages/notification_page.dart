import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Thông báo'),
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
      ),
      body: ListView.separated(
        itemCount: 5,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          return ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.secondary,
              child: Icon(Icons.notifications, color: AppColors.white),
            ),
            title: Text('Voucher giảm giá ${index + 1}0%'),
            subtitle: const Text('Bạn vừa nhận được một voucher mới. Sử dụng ngay!'),
            trailing: const Text('10:00', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            onTap: () {},
          );
        },
      ),
    );
  }
}
