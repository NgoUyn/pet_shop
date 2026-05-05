import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthSession {
  AuthSession._();

  static final AuthSession instance = AuthSession._();

  static const String _currentUserIdKey = 'auth.current_user_id';

  final ValueNotifier<int?> currentUserId = ValueNotifier<int?>(null);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId.value = prefs.getInt(_currentUserIdKey);
  }

  Future<void> signIn(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_currentUserIdKey, userId);
    currentUserId.value = userId;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentUserIdKey);
    currentUserId.value = null;
  }
}