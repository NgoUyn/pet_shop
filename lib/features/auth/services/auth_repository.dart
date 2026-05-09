import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/db/app_database.dart';
import 'auth_session.dart';
import 'pending_registration_store.dart';
import 'verification_email_service.dart';

class AuthRepository {
  AuthRepository._();

  static final AuthRepository instance = AuthRepository._();

  String _normalizeEmail(String email) => email.trim().toLowerCase();

  Future<int> _ensureLocalUserFromFirebase({
    required User firebaseUser,
    String? passwordHash,
    String? displayName,
  }) async {
    final db = await AppDatabase.instance;
    final normalizedEmail = _normalizeEmail(firebaseUser.email ?? '');

    if (normalizedEmail.isEmpty) {
      throw StateError('Firebase user không có email hợp lệ');
    }

    final rows = await db.query(
      'User',
      columns: ['UserID', 'Email', 'FullName'],
      where: 'lower(Email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      final existingUserId = rows.first['UserID'] as int;
      final existingEmail = (rows.first['Email'] as String?)?.trim().toLowerCase();
      final existingFullName = (rows.first['FullName'] as String?) ?? '';
      final resolvedName = (displayName ?? firebaseUser.displayName ?? existingFullName).trim();

      final updates = <String, Object?>{};
      if (existingEmail != normalizedEmail) {
        updates['Email'] = normalizedEmail;
      }
      if (resolvedName.isNotEmpty && resolvedName != existingFullName) {
        updates['FullName'] = resolvedName;
      }
      if (updates.isNotEmpty) {
        updates['UpdatedAt'] = DateTime.now().toIso8601String();
        await db.update(
          'User',
          updates,
          where: 'UserID = ?',
          whereArgs: [existingUserId],
        );
      }

      final customerRows = await db.query(
        'Customer',
        columns: ['CustomerID'],
        where: 'UserID = ?',
        whereArgs: [existingUserId],
        limit: 1,
      );

      if (customerRows.isEmpty) {
        await db.insert('Customer', {
          'UserID': existingUserId,
          'Phone': null,
          'Address': null,
          'LoyaltyPoints': 0,
        });
      }

      await PendingRegistrationStore.instance.removeByEmail(normalizedEmail);
      return existingUserId;
    }

    final pending = await PendingRegistrationStore.instance.findByEmail(normalizedEmail);
    final now = DateTime.now().toIso8601String();
    final userName = (displayName ?? pending?.name ?? firebaseUser.displayName ?? normalizedEmail.split('@').first).trim();
    final localPassword = passwordHash ?? pending?.password ?? 'firebase:${firebaseUser.uid}';
    final createdAt = pending?.createdAt ?? now;

    final userId = await db.transaction((txn) async {
      final insertedUserId = await txn.insert('User', {
        'Role': 'customer',
        'Email': normalizedEmail,
        'PasswordHash': localPassword,
        'FullName': userName,
        'IsActive': 1,
        'VerificationToken': null,
        'VerifiedAt': now,
        'CreatedAt': createdAt,
        'UpdatedAt': now,
      });

      await txn.insert('Customer', {
        'UserID': insertedUserId,
        'Phone': null,
        'Address': null,
        'LoyaltyPoints': 0,
      });

      return insertedUserId;
    });

    await PendingRegistrationStore.instance.removeByEmail(normalizedEmail);
    return userId;
  }

  Future<bool> isEmailRegistered(String email) async {
    final db = await AppDatabase.instance;
    final normalizedEmail = _normalizeEmail(email);
    final rows = await db.query(
      'User',
      columns: ['UserID'],
      where: 'lower(Email) = ?',
      whereArgs: [normalizedEmail],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      return true;
    }

    return false;
  }

  Future<void> registerCustomer({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = _normalizeEmail(email);

    if (await isEmailRegistered(normalizedEmail)) {
      throw StateError('Email đã được sử dụng');
    }

    final firebaseAuth = FirebaseAuth.instance;
    final pending = await PendingRegistrationStore.instance.findByEmail(normalizedEmail);
    UserCredential credential;

    if (pending != null) {
      credential = await firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: pending.password,
      );

      await PendingRegistrationStore.instance.save(
        PendingRegistration(
          name: name.trim(),
          email: normalizedEmail,
          password: pending.password,
          createdAt: pending.createdAt,
        ),
      );
    } else {
      try {
        credential = await firebaseAuth.createUserWithEmailAndPassword(
          email: normalizedEmail,
          password: password,
        );
      } on FirebaseAuthException catch (error) {
        if (error.code != 'email-already-in-use') {
          throw StateError(error.message ?? 'Không thể tạo tài khoản Firebase');
        }

        try {
          credential = await firebaseAuth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: password,
          );
        } on FirebaseAuthException catch (_) {
          final existingPending = await PendingRegistrationStore.instance.findByEmail(normalizedEmail);
          if (existingPending == null) {
            throw StateError('Email đã được sử dụng');
          }

          credential = await firebaseAuth.signInWithEmailAndPassword(
            email: normalizedEmail,
            password: existingPending.password,
          );
        }
      }

      await PendingRegistrationStore.instance.save(
        PendingRegistration(
          name: name.trim(),
          email: normalizedEmail,
          password: password,
          createdAt: DateTime.now().toIso8601String(),
        ),
      );
    }

    final user = credential.user;
    if (user == null) {
      throw StateError('Không thể tạo phiên Firebase cho tài khoản');
    }

    await VerificationEmailService.instance.sendVerificationEmail(
      email: normalizedEmail,
      displayName: name.trim(),
    );
  }

  Future<int> login({required String email, required String password}) async {
    final normalizedEmail = _normalizeEmail(email);

    final firebaseAuth = FirebaseAuth.instance;
    UserCredential credential;

    try {
      credential = await firebaseAuth.signInWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      if (error.code == 'user-not-found' || error.code == 'wrong-password' || error.code == 'invalid-credential') {
        throw StateError('Tài khoản không tồn tại hoặc mật khẩu không đúng');
      }

      throw StateError(error.message ?? 'Không thể đăng nhập bằng Firebase');
    }

    final user = credential.user;
    if (user == null) {
      throw StateError('Không thể lấy phiên đăng nhập Firebase');
    }

    await user.reload();
    final refreshedUser = firebaseAuth.currentUser;
    if (refreshedUser == null) {
      throw StateError('Không thể xác minh trạng thái email');
    }

    if (!refreshedUser.emailVerified) {
      throw StateError('Tài khoản chưa được xác thực. Vui lòng kiểm tra email.');
    }

    final userId = await _ensureLocalUserFromFirebase(
      firebaseUser: refreshedUser,
      passwordHash: password,
      displayName: refreshedUser.displayName,
    );
    await AuthSession.instance.signIn(userId);
    return userId;
  }

  Future<int> signInWithGoogle() async {
    final provider = GoogleAuthProvider()
      ..setCustomParameters({'prompt': 'select_account'});

    final userCredential = await FirebaseAuth.instance.signInWithProvider(provider);
    final firebaseUser = userCredential.user;
    if (firebaseUser == null) {
      throw StateError('Không thể lấy thông tin tài khoản Google');
    }

    final userId = await _ensureLocalUserFromFirebase(
      firebaseUser: firebaseUser,
      displayName: firebaseUser.displayName,
    );
    await AuthSession.instance.signIn(userId);
    return userId;
  }

  Future<int?> syncVerifiedFirebaseUser() async {
    final firebaseAuth = FirebaseAuth.instance;
    final currentUser = firebaseAuth.currentUser;
    if (currentUser == null) {
      return null;
    }

    await currentUser.reload();
    final refreshedUser = firebaseAuth.currentUser;
    if (refreshedUser == null || !refreshedUser.emailVerified) {
      return null;
    }

    final userId = await _ensureLocalUserFromFirebase(
      firebaseUser: refreshedUser,
      displayName: refreshedUser.displayName,
    );
    await AuthSession.instance.signIn(userId);
    return userId;
  }

  Future<void> resendVerificationEmail(String email) async {
    final normalizedEmail = _normalizeEmail(email);
    final firebaseAuth = FirebaseAuth.instance;
    final pending = await PendingRegistrationStore.instance.findByEmail(normalizedEmail);

    if (pending == null) {
      final currentUser = firebaseAuth.currentUser;
      if (currentUser == null || currentUser.email?.trim().toLowerCase() != normalizedEmail) {
        throw StateError('Không tìm thấy tài khoản chờ xác thực');
      }

      await currentUser.reload();
      if (firebaseAuth.currentUser?.emailVerified == true) {
        throw StateError('Tài khoản này đã được xác thực');
      }

      await VerificationEmailService.instance.sendVerificationEmail(
        email: normalizedEmail,
        displayName: currentUser.displayName ?? normalizedEmail.split('@').first,
      );
      return;
    }

    final credential = await firebaseAuth.signInWithEmailAndPassword(
      email: normalizedEmail,
      password: pending.password,
    );

    final user = credential.user;
    if (user == null) {
      throw StateError('Không thể tải phiên Firebase');
    }

    await user.reload();
    if (firebaseAuth.currentUser?.emailVerified == true) {
      throw StateError('Tài khoản này đã được xác thực');
    }

    await VerificationEmailService.instance.sendVerificationEmail(
      email: normalizedEmail,
      displayName: pending.name,
    );
  }

  Future<void> signOut() async {
    await FirebaseAuth.instance.signOut();
    await AuthSession.instance.signOut();
  }
}