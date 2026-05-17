import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';

/// Displays floating bottom action buttons for customers:
/// chat, ordering, and purchase icon.
class CustomerBottomAction extends StatelessWidget {
  const CustomerBottomAction({
    super.key,
    this.onChatPressed,
    this.onOrderPressed,
    this.onBuyPressed,
  });

  final VoidCallback? onChatPressed;
  final VoidCallback? onOrderPressed;
  final VoidCallback? onBuyPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: const [
          BoxShadow(
            color: Color(0x15000000),
            blurRadius: 12,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Chat button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onChatPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF2F80ED),
                    side: const BorderSide(color: Color(0xFF2F80ED)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.chat_outlined, size: 20),
                  label: const Text(
                    'Chat',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Order button
            Expanded(
              child: SizedBox(
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: onOrderPressed,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF3E7C63),
                    side: const BorderSide(color: Color(0xFF3E7C63)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.shopping_cart_outlined, size: 20),
                  label: const Text(
                    'Đặt hàng',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Times New Roman',
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Buy button
            SizedBox(
              height: 48,
              width: 48,
              child: ElevatedButton(
                onPressed: onBuyPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  padding: EdgeInsets.zero,
                ),
                child: const Icon(Icons.sell_outlined, size: 22),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
