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

    final row = Map<String, Object?>.from(rows.first);
    await _mergeFirestoreProfileIntoLocalCache(row);

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

  Future<void> _mergeFirestoreProfileIntoLocalCache(Map<String, Object?> row) async {
    final localFirebaseUid = (row['FirebaseUID'] as String?)?.trim();
    final currentFirebaseUid = FirebaseAuth.instance.currentUser?.uid.trim();
    final firebaseUid = (localFirebaseUid != null && localFirebaseUid.isNotEmpty)
        ? localFirebaseUid
        : (currentFirebaseUid?.isNotEmpty == true ? currentFirebaseUid : null);

    if (firebaseUid == null) {
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(firebaseUid).get();
      final data = doc.data();
      if (!doc.exists || data == null) {
        return;
      }

      final firestoreFullName = (data['fullName'] as String?)?.trim();
      final firestoreEmail = (data['email'] as String?)?.trim();
      final firestoreRole = (data['role'] as String?)?.trim();
      final firestorePhone = (data['phone'] as String?)?.trim();
      final firestoreAddress = (data['address'] as String?)?.trim();
      final firestoreLoyaltyPoints = (data['loyaltyPoints'] as num?)?.toInt();

      final localRole = (row['Role'] as String?)?.trim().toLowerCase() ?? 'customer';

      if (firestoreFullName != null && firestoreFullName.isNotEmpty) {
        row['FullName'] = firestoreFullName;
      }
      if (firestoreEmail != null && firestoreEmail.isNotEmpty) {
        row['Email'] = firestoreEmail;
      }
      if (firestoreRole != null && firestoreRole.isNotEmpty && localRole != 'admin') {
        row['Role'] = firestoreRole;
      }
      if (firestorePhone != null && firestorePhone.isNotEmpty) {
        row['Phone'] = firestorePhone;
      }
      if (firestoreAddress != null && firestoreAddress.isNotEmpty) {
        row['Address'] = firestoreAddress;
      }
      if (firestoreLoyaltyPoints != null) {
        row['LoyaltyPoints'] = firestoreLoyaltyPoints;
      }

      await _updateLocalCacheFromFirestore(
        userId: row['UserID'] as int,
        firebaseUid: firebaseUid,
        fullName: firestoreFullName,
        email: firestoreEmail,
        role: firestoreRole,
        phone: firestorePhone,
        address: firestoreAddress,
        loyaltyPoints: firestoreLoyaltyPoints,
      );
    } catch (e) {
      print('ProfileRepository._mergeFirestoreProfileIntoLocalCache error: $e');
    }
  }

  Future<void> _updateLocalCacheFromFirestore({
    required int userId,
    required String firebaseUid,
    String? fullName,
    String? email,
    String? role,
    String? phone,
    String? address,
    int? loyaltyPoints,
  }) async {
    final db = await AppDatabase.instance;
    final now = DateTime.now().toIso8601String();

    final userUpdates = <String, Object?>{
      'FirebaseUID': firebaseUid,
      'UpdatedAt': now,
    };

    if (fullName != null && fullName.isNotEmpty) {
      userUpdates['FullName'] = fullName;
    }
    if (email != null && email.isNotEmpty) {
      userUpdates['Email'] = email.toLowerCase();
    }
    if (role != null && role.isNotEmpty) {
      userUpdates['Role'] = role;
    }

    await db.update(
      'User',
      userUpdates,
      where: 'UserID = ?',
      whereArgs: [userId],
    );

    final customerUpdates = <String, Object?>{};
    if (phone != null) {
      customerUpdates['Phone'] = phone.isEmpty ? null : phone;
    }
    if (address != null) {
      customerUpdates['Address'] = address.isEmpty ? null : address;
    }
    if (loyaltyPoints != null) {
      customerUpdates['LoyaltyPoints'] = loyaltyPoints;
    }

    if (customerUpdates.isNotEmpty) {
      final customerRows = await db.query(
        'Customer',
        columns: ['CustomerID'],
        where: 'UserID = ?',
        whereArgs: [userId],
        limit: 1,
      );

      if (customerRows.isNotEmpty) {
        await db.update(
          'Customer',
          customerUpdates,
          where: 'UserID = ?',
          whereArgs: [userId],
        );
      }
    }
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