import 'package:firebase_auth/firebase_auth.dart';

class VerificationEmailService {
  VerificationEmailService._();

  static final VerificationEmailService instance = VerificationEmailService._();

  Future<void> sendVerificationEmail({
    required String email,
    required String displayName,
  }) async {
    final auth = FirebaseAuth.instance;
    final currentUser = auth.currentUser;

    if (currentUser == null) {
      throw StateError('Chưa có phiên Firebase để gửi email xác thực');
    }

    final currentEmail = currentUser.email?.trim().toLowerCase();
    final normalizedEmail = email.trim().toLowerCase();
    if (currentEmail != normalizedEmail) {
      throw StateError('Phiên Firebase không khớp với email cần xác thực');
    }

    await currentUser.updateDisplayName(displayName);
    await currentUser.sendEmailVerification();
  }
}
