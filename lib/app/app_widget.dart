import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/widgets/main_wrapper.dart';
import '../features/auth/services/auth_repository.dart';
import '../features/auth/services/auth_session.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> with WidgetsBindingObserver {
  bool _bootstrapping = true;

  void _showVerificationSuccessMessage() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      rootScaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Xác thực email thành công')),
      );
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _bootstrap();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final previousUserId = AuthSession.instance.currentUserId.value;
      AuthRepository.instance.syncVerifiedFirebaseUser().then((syncedUserId) {
        if (!mounted) {
          return;
        }

        if (previousUserId == null && syncedUserId != null) {
          _showVerificationSuccessMessage();
        }
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final previousUserId = AuthSession.instance.currentUserId.value;
    int? syncedUserId;
    try {
      syncedUserId = await AuthRepository.instance.syncVerifiedFirebaseUser().timeout(
        const Duration(seconds: 10),
      );
    } catch (_) {
      // Firebase / network unavailable — proceed with local session
    }
    if (mounted) {
      setState(() {
        _bootstrapping = false;
      });

      if (previousUserId == null && syncedUserId != null) {
        _showVerificationSuccessMessage();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Shop App',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
      ),
      home: _bootstrapping ? const _StartupScreen() : const MainWrapper(),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
