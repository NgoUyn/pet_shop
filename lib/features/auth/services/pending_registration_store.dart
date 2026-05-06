import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingRegistration {
  PendingRegistration({
    required this.name,
    required this.email,
    required this.password,
    required this.createdAt,
  });

  final String name;
  final String email;
  final String password;
  final String createdAt;

  Map<String, Object?> toJson() {
    return {
      'name': name,
      'email': email,
      'password': password,
      'createdAt': createdAt,
    };
  }

  factory PendingRegistration.fromJson(Map<String, dynamic> json) {
    return PendingRegistration(
      name: json['name'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      createdAt: json['createdAt'] as String,
    );
  }
}

class PendingRegistrationStore {
  PendingRegistrationStore._();

  static final PendingRegistrationStore instance = PendingRegistrationStore._();

  static const String _storageKey = 'auth.pending_registrations';

  Future<Map<String, PendingRegistration>> _readAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      return {};
    }

    return decoded.map(
      (email, value) => MapEntry(
        email,
        PendingRegistration.fromJson(Map<String, dynamic>.from(value as Map)),
      ),
    );
  }

  Future<void> _writeAll(Map<String, PendingRegistration> items) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = items.map((email, item) => MapEntry(email, item.toJson()));
    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<bool> hasEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final items = await _readAll();
    return items.containsKey(normalizedEmail);
  }

  Future<void> save(PendingRegistration registration) async {
    final items = await _readAll();
    items[registration.email] = registration;
    await _writeAll(items);
  }

  Future<PendingRegistration?> findByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final items = await _readAll();
    return items[normalizedEmail];
  }

  Future<void> removeByEmail(String email) async {
    final normalizedEmail = email.trim().toLowerCase();
    final items = await _readAll();
    items.remove(normalizedEmail);
    await _writeAll(items);
  }
}
