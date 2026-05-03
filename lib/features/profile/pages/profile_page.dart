import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../favorites/pages/favorites_page.dart';
import 'profile_detail_page.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              // Header area (kept inside body; top app header provided by MainWrapper)
              Container(
                color: AppColors.primary,
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.white,
                      child: Icon(Icons.person, size: 50, color: AppColors.primary),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Username_Petshop',
                          style: TextStyle(color: AppColors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const ProfileDetailPage()),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.white,
                            foregroundColor: AppColors.primary,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Chỉnh sửa hồ sơ'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Order Status Section
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.symmetric(vertical: 15),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 15),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Đơn mua', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('Xem lịch sử >', style: TextStyle(color: AppColors.textLight, fontSize: 12)),
                        ],
                      ),
                    ),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStatusItem(Icons.payment, 'Chờ xác nhận'),
                        _buildStatusItem(Icons.inventory_2_outlined, 'Chờ lấy hàng'),
                        _buildStatusItem(Icons.local_shipping_outlined, 'Đang giao'),
                        _buildStatusItem(Icons.star_outline, 'Đánh giá'),
                      ],
                    ),
                  ],
                ),
              ),

              // Features List
              _buildMenuItem(context, Icons.favorite, 'Danh sách yêu thích', 'Sản phẩm bạn đã thích', destination: const FavoritesPage()),
              _buildMenuItem(context, Icons.history, 'Lịch sử mua hàng', '24 đơn hàng'),
              _buildMenuItem(context, Icons.card_membership, 'Điểm tích lũy', '1.500 điểm'),
              _buildMenuItem(context, Icons.confirmation_number_outlined, 'Kho Voucher', '12 mã giảm giá'),
              _buildMenuItem(context, Icons.storefront, 'Đăng ký thành người bán', 'Kiếm tiền ngay'),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusItem(IconData icon, String label) {
    return Column(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(height: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  Widget _buildMenuItem(BuildContext context, IconData icon, String title, String subtitle, {Widget? destination}) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primary),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          if (destination != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => destination),
            );
          }
        },
      ),
    );
  }
}

