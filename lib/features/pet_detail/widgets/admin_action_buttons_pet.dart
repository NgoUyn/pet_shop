import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Displays admin action buttons (Chỉnh sửa, Xóa) for product detail pages.
class AdminActionButtons extends StatelessWidget {
  const AdminActionButtons({
    super.key,
    this.onEditPressed,
    this.onDeletePressed,
  });

  final VoidCallback? onEditPressed;
  final VoidCallback? onDeletePressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildButton(
          label: 'Chỉnh sửa',
          icon: Icons.edit_outlined,
          background: const Color(0xFFEAF3FF),
          foreground: const Color(0xFF2F80ED),
          onPressed: onEditPressed ?? () {},
        ),
        _buildButton(
          label: 'Xóa',
          icon: Icons.delete_outline,
          background: const Color(0xFFFDECEC),
          foreground: const Color(0xFFB42318),
          onPressed: onDeletePressed ?? () {},
        ),
      ],
    );
  }

  Widget _buildButton({
    required String label,
    required IconData icon,
    required Color background,
    required Color foreground,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: background,
          foregroundColor: foreground,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            fontFamily: 'Times New Roman',
          ),
        ),
      ),
    );
  }
}
