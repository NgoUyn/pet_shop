import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/db/app_database.dart';
import '../../auth/services/auth_session.dart';

class ProfileData {
  ProfileData({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.loyaltyPoints,
    this.phone,
    this.address,
  });

  final int userId;
  final String fullName;
  final String email;
  final String role;
  final String? phone;
  final String? address;
  final int loyaltyPoints;

  bool get isCustomer => role == 'customer';
}

class ProfileRepository {
  ProfileRepository._();

  static final ProfileRepository instance = ProfileRepository._();

  String? _validateFullName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) {
      return 'Vui lòng nhập tên';
    }
    if (normalized.length < 2) {
      return 'Tên phải có ít nhất 2 ký tự';
    }
    if (normalized.length > 80) {
      return 'Tên không được vượt quá 80 ký tự';
    }
    return null;
  }

  String? _validatePhone(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return 'Vui lòng nhập số điện thoại';
    }

    if (!RegExp(r'^[0-9]+$').hasMatch(normalized)) {
      return 'Số điện thoại không được chứa chữ hoặc ký tự đặc biệt';
    }

    if (normalized.length != 10 || !normalized.startsWith('0')) {
      return 'Số điện thoại phải gồm 10 số và bắt đầu bằng 0';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.length < 5) {
      return 'Địa chỉ phải có ít nhất 5 ký tự';
    }
    return null;
  }

  Future<ProfileData?> getProfileByUserId(int userId) async {
    final db = await AppDatabase.instance;
    final rows = await db.rawQuery(
      '''
      SELECT
        u.UserID,
        u.FullName,
        u.Email,
        u.Role,
        c.Phone,
        c.Address,
        COALESCE(c.LoyaltyPoints, 0) AS LoyaltyPoints
      FROM User u
      LEFT JOIN Customer c ON c.UserID = u.UserID
      WHERE u.UserID = ?
      LIMIT 1
      ''',
      [userId],
    );

    if (rows.isEmpty) {
      return null;
    }

    final row = rows.first;
    return ProfileData(
      userId: row['UserID'] as int,
      fullName: (row['FullName'] as String?) ?? '',
      email: (row['Email'] as String?) ?? '',
      role: (row['Role'] as String?) ?? 'customer',
      phone: row['Phone'] as String?,
      address: row['Address'] as String?,
      loyaltyPoints: (row['LoyaltyPoints'] as int?) ?? 0,
    );
  }

  Future<ProfileData?> getCurrentProfile() async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      return null;
    }

    return getProfileByUserId(userId);
  }

  Future<bool> updateCurrentProfile({
    required String fullName,
    String? phone,
    String? address,
  }) async {
    final userId = AuthSession.instance.currentUserId.value;
    if (userId == null) {
      throw StateError('Không tìm thấy phiên đăng nhập');
    }

    final currentProfile = await getProfileByUserId(userId);
    if (currentProfile == null) {
      throw StateError('Không tìm thấy hồ sơ hiện tại');
    }

    final fullNameError = _validateFullName(fullName);
    if (fullNameError != null) {
      throw StateError(fullNameError);
    }

    final phoneError = _validatePhone(phone);
    if (phoneError != null) {
      throw StateError(phoneError);
    }

    final addressError = _validateAddress(address);
    if (addressError != null) {
      throw StateError(addressError);
    }

    final normalizedFullName = fullName.trim();
    final normalizedPhone = phone?.trim();
    final normalizedAddress = address?.trim();

    final currentPhone = currentProfile.phone?.trim() ?? '';
    final currentAddress = currentProfile.address?.trim() ?? '';

    final hasNameChanged = normalizedFullName != currentProfile.fullName.trim();
    final hasPhoneChanged = (normalizedPhone ?? '') != currentPhone;
    final hasAddressChanged = (normalizedAddress ?? '') != currentAddress;

    if (!hasNameChanged && !hasPhoneChanged && !hasAddressChanged) {
      return false;
    }

    if (hasNameChanged) {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser != null) {
        await firebaseUser.updateDisplayName(normalizedFullName);
      }
    }

    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'User',
        {
          'FullName': normalizedFullName,
          'UpdatedAt': now,
        },
        where: 'UserID = ?',
        whereArgs: [userId],
      );

      final customerRows = await txn.query(
        'Customer',
        columns: ['CustomerID'],
        where: 'UserID = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (customerRows.isNotEmpty) {
        await txn.update(
          'Customer',
          {
            'Phone': normalizedPhone?.isEmpty ?? true ? null : normalizedPhone,
            'Address': normalizedAddress?.isEmpty ?? true ? null : normalizedAddress,
          },
          where: 'UserID = ?',
          whereArgs: [userId],
        );
      } else {
        await txn.insert('Customer', {
          'UserID': userId,
          'Phone': normalizedPhone?.isEmpty ?? true ? null : normalizedPhone,
          'Address': normalizedAddress?.isEmpty ?? true ? null : normalizedAddress,
          'LoyaltyPoints': 0,
        });
      }
    });

    // Sync profile to Firestore for cross-device access
    _syncProfileToFirestore(
      userId: userId,
      fullName: normalizedFullName,
      phone: normalizedPhone,
      address: normalizedAddress,
      email: currentProfile.email,
      role: currentProfile.role,
      loyaltyPoints: currentProfile.loyaltyPoints,
    );

    return true;
  }

  void _syncProfileToFirestore({
    required int userId,
    required String fullName,
    String? phone,
    String? address,
    required String email,
    required String role,
    required int loyaltyPoints,
  }) {
    _doSyncProfileToFirestore(
      userId: userId,
      fullName: fullName,
      phone: phone,
      address: address,
      email: email,
      role: role,
      loyaltyPoints: loyaltyPoints,
    );
  }

  Future<void> _doSyncProfileToFirestore({
    required int userId,
    required String fullName,
    String? phone,
    String? address,
    required String email,
    required String role,
    required int loyaltyPoints,
  }) async {
    try {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) return;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(firebaseUser.uid)
          .set({
        'localUserId': userId,
        'fullName': fullName,
        'email': email,
        'role': role,
        'phone': phone,
        'address': address,
        'loyaltyPoints': loyaltyPoints,
        'updatedAt': DateTime.now().toIso8601String(),
      }, SetOptions(merge: true));
    } catch (e) {
      print('ProfileRepository._doSyncProfileToFirestore error: $e');
    }
  }
}