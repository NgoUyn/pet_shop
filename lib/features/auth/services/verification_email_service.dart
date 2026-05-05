import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';

class VerificationEmailService {
  VerificationEmailService._();

  static final VerificationEmailService instance = VerificationEmailService._();

  Future<void> sendVerificationEmail({
    required String toEmail,
    required String displayName,
    required String verificationUrl,
  }) async {
    final host = dotenv.env['SMTP_HOST'];
    final port = int.tryParse(dotenv.env['SMTP_PORT'] ?? '');
    final username = dotenv.env['SMTP_USERNAME'];
    final password = dotenv.env['SMTP_PASSWORD'];
    final fromEmail = dotenv.env['SMTP_FROM'];
    final fromName = dotenv.env['SMTP_FROM_NAME'] ?? 'Pet Shop';

    if (host == null || port == null || username == null || password == null || fromEmail == null) {
      throw StateError('Thiếu cấu hình SMTP trong file .env');
    }

    final smtpServer = SmtpServer(
      host,
      port: port,
      username: username,
      password: password,
      ssl: port == 465,
      allowInsecure: port != 465,
    );

    final message = Message()
      ..from = Address(fromEmail, fromName)
      ..recipients.add(toEmail)
      ..subject = 'Xác thực tài khoản Pet Shop'
      ..text = _buildPlainText(displayName, verificationUrl)
      ..html = _buildHtml(displayName, verificationUrl);

    await send(message, smtpServer);
  }

  String _buildPlainText(String displayName, String verificationUrl) {
    return [
      'Xin chào $displayName,',
      '',
      'Vui lòng nhấn vào link sau để xác thực tài khoản Pet Shop:',
      verificationUrl,
      '',
      'Nếu bạn không đăng ký tài khoản này, hãy bỏ qua email.',
    ].join('\n');
  }

  String _buildHtml(String displayName, String verificationUrl) {
    return '''
      <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #1f2937;">
        <p>Xin chào <strong>$displayName</strong>,</p>
        <p>Vui lòng nhấn vào nút bên dưới để xác thực tài khoản Pet Shop:</p>
        <p><a href="$verificationUrl" style="display:inline-block;padding:12px 20px;border-radius:999px;background:#2f7d5b;color:#ffffff;text-decoration:none;">Xác thực tài khoản</a></p>
        <p>Nếu nút không hoạt động, bạn có thể mở link này:</p>
        <p><a href="$verificationUrl">$verificationUrl</a></p>
      </div>
    ''';
  }
}