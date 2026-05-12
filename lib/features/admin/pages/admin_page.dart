import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/main_wrapper.dart';
import '../../auth/services/auth_repository.dart';
import '../../chat/pages/admin_chat_inbox_page.dart';
import '../../chat/services/chat_repository.dart';
import 'order_management_page.dart';
import 'user_list_page.dart';
import 'admin_shell_page.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const AdminShellPage();
  }
}
