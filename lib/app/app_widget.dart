import 'dart:async';

import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';

import '../core/constants/app_colors.dart';
import '../features/auth/services/auth_repository.dart';
import '../core/widgets/main_wrapper.dart';

final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class AppWidget extends StatefulWidget {
  const AppWidget({super.key});

  @override
  State<AppWidget> createState() => _AppWidgetState();
}

class _AppWidgetState extends State<AppWidget> {
  final AppLinks _appLinks = AppLinks();

  StreamSubscription<Uri?>? _linkSubscription;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _initLinkHandling();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initLinkHandling() async {
    try {
      final initialUri = await _appLinks.getInitialLink();

      if (initialUri != null) {
        await _handleIncomingUri(initialUri);
      }
    } catch (_) {}

    _linkSubscription = _appLinks.uriLinkStream.listen(
          (uri) {
        _handleIncomingUri(uri);
      },
      onError: (_) {},
    );

    if (mounted) {
      setState(() {
        _bootstrapping = false;
      });
    }
  }

  Future<void> _handleIncomingUri(Uri uri) async {
    final scheme = uri.scheme.toLowerCase();
    final host = uri.host.toLowerCase();
    if (scheme != 'petshop' || host != 'verify-email') {
      return;
    }

    final token = uri.queryParameters['token'];
    if (token == null || token.isEmpty) {
      _showMessage('Link xác thực thiếu token');
      return;
    }

    try {
      await AuthRepository.instance.verifyEmailByToken(token);
      if (!mounted) return;
      _showMessage('Xác thực thành công');
    } catch (error) {
      _showMessage(error.toString().replaceFirst('StateError: ', ''));
    }
  }

  void _showMessage(String message) {
    rootScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
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
