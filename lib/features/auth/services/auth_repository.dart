import 'dart:math';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sqflite/sqflite.dart';

import '../../../core/db/app_database.dart';
import 'auth_session.dart';
import 'verification_email_service.dart';

class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String password,
  }) async {
    final db = await AppDatabase.instance;
    final normalizedEmail = email.trim().toLowerCase();
    final existing = await db.query(
      'User',
      columns: ['UserID'],
      where: 'lower(Email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      throw StateError('Email đã được sử dụng');
    }

    final verificationToken = _generateToken();
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      final userId = await txn.insert('User', {
        'Role': 'customer',
        'Email': normalizedEmail,
        'PasswordHash': password,
        'FullName': name.trim(),
        'IsActive': 0,
        'VerificationToken': verificationToken,
        'VerifiedAt': null,
        'CreatedAt': now,
        'UpdatedAt': null,
      });

      await txn.insert('Customer', {
        'UserID': userId,
        'Phone': null,
        'Address': null,
        'LoyaltyPoints': 0,
      });
    });

    final verificationUrl = Uri(
      scheme: dotenv.env['APP_LINK_SCHEME'] ?? 'petshop',
      host: dotenv.env['APP_LINK_HOST'] ?? 'verify-email',
      queryParameters: {'token': verificationToken},
    ).toString();

    await VerificationEmailService.instance.sendVerificationEmail(
      toEmail: normalizedEmail,
      displayName: name.trim(),
      verificationUrl: verificationUrl,
    );
  }

  Future<int> login({required String email, required String password}) async {
    final db = await AppDatabase.instance;
    final normalizedEmail = email.trim().toLowerCase();

    final rows = await db.query(
      'User',
      columns: ['UserID', 'PasswordHash', 'IsActive'],
      where: 'lower(Email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Tài khoản không tồn tại');
    }

    final row = rows.first;
    if ((row['PasswordHash'] as String) != password) {
      throw StateError('Mật khẩu không đúng');
    }

    if ((row['IsActive'] as int) != 1) {
      throw StateError('Tài khoản chưa được xác thực. Vui lòng kiểm tra email.');
    }

    final userId = row['UserID'] as int;
    await AuthSession.instance.signIn(userId);
    return userId;
  }

  Future<int> verifyEmailByToken(String token) async {
    final db = await AppDatabase.instance;
    final rows = await db.query(
      'User',
      columns: ['UserID', 'IsActive'],
      where: 'VerificationToken = ?',
      whereArgs: [token],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Link xác thực không hợp lệ hoặc đã hết hạn');
    }

    final userId = rows.first['UserID'] as int;
    final now = DateTime.now().toIso8601String();

    await db.update(
      'User',
      {
        'IsActive': 1,
        'VerificationToken': null,
        'VerifiedAt': now,
        'UpdatedAt': now,
      },
      where: 'UserID = ?',
      whereArgs: [userId],
      conflictAlgorithm: ConflictAlgorithm.abort,
    );

    await AuthSession.instance.signIn(userId);
    return userId;
  }

  Future<void> resendVerificationEmail(String email) async {
    final db = await AppDatabase.instance;
    final normalizedEmail = email.trim().toLowerCase();
    final rows = await db.query(
      'User',
      columns: ['UserID', 'FullName', 'IsActive'],
      where: 'lower(Email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (rows.isEmpty) {
      throw StateError('Không tìm thấy tài khoản');
    }

    final row = rows.first;
    if ((row['IsActive'] as int) == 1) {
      throw StateError('Tài khoản này đã được xác thực');
    }

    final verificationToken = _generateToken();
    final now = DateTime.now().toIso8601String();
    await db.update(
      'User',
      {
        'VerificationToken': verificationToken,
        'UpdatedAt': now,
      },
      where: 'UserID = ?',
      whereArgs: [row['UserID']],
    );

    final verificationUrl = Uri(
      scheme: dotenv.env['APP_LINK_SCHEME'] ?? 'petshop',
      host: dotenv.env['APP_LINK_HOST'] ?? 'verify-email',
      queryParameters: {'token': verificationToken},
    ).toString();

    await VerificationEmailService.instance.sendVerificationEmail(
      toEmail: normalizedEmail,
      displayName: row['FullName'] as String,
      verificationUrl: verificationUrl,
    );
  }

  String _generateToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
  }
}