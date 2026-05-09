import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'login_page.dart';
import '../services/auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  static const Duration _emailCheckDebounceDuration = Duration(milliseconds: 500);

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  final Map<String, bool> _emailExistsCache = {};

  Timer? _emailCheckDebounceTimer;
  Future<bool>? _pendingEmailCheck;
  String? _pendingEmailCheckEmail;
  int _emailCheckRequestId = 0;

  bool _obscure = true;
  bool _loading = false;
  bool _emailChecking = false;
  String? _emailStatusMessage;
  String? _emailAsyncError;

  @override
  void dispose() {
    _emailCheckDebounceTimer?.cancel();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String get _normalizedEmail => _emailCtrl.text.trim().toLowerCase();

  bool _isEmailFormatValid(String email) {
    return _validateEmail(email) == null;
  }

  void _clearEmailStatus() {
    if (!mounted) return;
    setState(() {
      _emailChecking = false;
      _emailStatusMessage = null;
      _emailAsyncError = null;
    });
  }

  void _handleEmailChanged(String value) {
    final normalizedEmail = value.trim().toLowerCase();

    _emailCheckDebounceTimer?.cancel();

    if (!_isEmailFormatValid(normalizedEmail)) {
      _clearEmailStatus();
      return;
    }

    final cachedExists = _emailExistsCache[normalizedEmail];
    if (cachedExists != null) {
      if (!mounted) return;
      setState(() {
        _emailChecking = false;
        _emailStatusMessage = cachedExists ? 'Email này đã được đăng ký' : null;
        _emailAsyncError = null;
      });
      return;
    }

    final requestId = ++_emailCheckRequestId;
    if (!mounted) return;
    setState(() {
      _emailChecking = false;
      _emailStatusMessage = null;
      _emailAsyncError = null;
    });

    _emailCheckDebounceTimer = Timer(_emailCheckDebounceDuration, () {
      unawaited(_checkEmailAvailability(normalizedEmail, requestId));
    });
  }

  Future<bool> _checkEmailAvailability(String normalizedEmail, int requestId) async {
    if (_pendingEmailCheckEmail == normalizedEmail && _pendingEmailCheck != null) {
      return _pendingEmailCheck!;
    }

    if (!mounted || requestId != _emailCheckRequestId) {
      return false;
    }

    setState(() {
      _emailChecking = true;
      _emailStatusMessage = null;
      _emailAsyncError = null;
    });

    final future = AuthRepository.instance.isEmailRegistered(normalizedEmail);
    _pendingEmailCheckEmail = normalizedEmail;
    _pendingEmailCheck = future;

    try {
      final exists = await future;
      _emailExistsCache[normalizedEmail] = exists;

      if (!mounted || requestId != _emailCheckRequestId || _normalizedEmail != normalizedEmail) {
        return !exists;
      }

      setState(() {
        _emailChecking = false;
        _emailStatusMessage = exists ? 'Email này đã được đăng ký' : null;
        _emailAsyncError = null;
      });
      return !exists;
    } catch (_) {
      if (mounted && requestId == _emailCheckRequestId && _normalizedEmail == normalizedEmail) {
        setState(() {
          _emailChecking = false;
          _emailStatusMessage = null;
          _emailAsyncError = 'Không thể kiểm tra email lúc này';
        });
      }
      return false;
    } finally {
      if (_pendingEmailCheckEmail == normalizedEmail) {
        _pendingEmailCheck = null;
        _pendingEmailCheckEmail = null;
      }
    }
  }

  Future<bool> _ensureEmailAvailableBeforeSubmit() async {
    final normalizedEmail = _normalizedEmail;
    final formatError = _validateEmail(normalizedEmail);
    if (formatError != null) return false;

    _emailCheckDebounceTimer?.cancel();

    final cachedExists = _emailExistsCache[normalizedEmail];
    if (cachedExists != null) {
      if (mounted) {
        setState(() {
          _emailChecking = false;
          _emailStatusMessage = cachedExists ? 'Email này đã được đăng ký' : null;
          _emailAsyncError = null;
        });
      }
      return !cachedExists;
    }

    if (_pendingEmailCheckEmail == normalizedEmail && _pendingEmailCheck != null) {
      final exists = await _pendingEmailCheck!;
      return !exists;
    }

    final exists = await AuthRepository.instance.isEmailRegistered(normalizedEmail);
    _emailExistsCache[normalizedEmail] = exists;

    if (mounted && _normalizedEmail == normalizedEmail) {
      setState(() {
        _emailChecking = false;
        _emailStatusMessage = exists ? 'Email này đã được đăng ký' : null;
        _emailAsyncError = null;
      });
    }

    return !exists;
  }

  Future<void> _onRegister() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final emailAvailable = await _ensureEmailAvailableBeforeSubmit();
    if (!emailAvailable) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email này đã được đăng ký. Vui lòng dùng email khác.')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      await AuthRepository.instance.registerCustomer(
        name: _nameCtrl.text,
        email: _emailCtrl.text,
        password: _passCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã gửi email xác thực. Vui lòng kiểm tra hộp thư.')),
      );
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Đăng ký thất bại: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Vui lòng nhập email';
    final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!regex.hasMatch(v.trim())) return 'Email không hợp lệ';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Vui lòng nhập mật khẩu';
    if (v.length < 6) return 'Mật khẩu phải >= 6 ký tự';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        title: const Text('Đăng ký'),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: EdgeInsets.fromLTRB(
                24,
                24,
                24,
                24 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 420),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                    TextFormField(
                      controller: _nameCtrl,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Họ và tên', border: OutlineInputBorder(), isDense: true),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vui lòng nhập tên' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      onChanged: _handleEmailChanged,
                      decoration: InputDecoration(
                        labelText: 'E-mail',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: _emailChecking
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : _emailStatusMessage == null
                                ? null
                                : const Icon(Icons.close, color: Colors.red),
                      ),
                      validator: _validateEmail,
                    ),
                    if (_emailStatusMessage != null || _emailAsyncError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _emailAsyncError ?? _emailStatusMessage!,
                            style: TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'Mật khẩu',
                        border: const OutlineInputBorder(),
                        isDense: true,
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _confirmCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(labelText: 'Xác nhận mật khẩu', border: OutlineInputBorder(), isDense: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Vui lòng xác nhận mật khẩu';
                        if (v != _passCtrl.text) return 'Mật khẩu không khớp';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _onRegister,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.secondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                        ),
                        child: _loading
                            ? const CircularProgressIndicator(color: AppColors.white)
                            : const Text('Đăng ký', style: TextStyle(color: AppColors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage())),
                      child: const Text('Đã có tài khoản? Đăng nhập'),
                    ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}