import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/donation_models.dart';
import '../utils/app_exception.dart';

enum EmailProvider { server }

class EmailProviderConfig {
  final EmailProvider provider;
  final String serverBaseUrl;
  final Duration timeout;

  const EmailProviderConfig({
    required this.provider,
    required this.serverBaseUrl,
    this.timeout = const Duration(seconds: 10),
  });

  static const EmailProviderConfig fromEnv = EmailProviderConfig(
    provider: EmailProvider.server,
    serverBaseUrl:
        String.fromEnvironment('EMAIL_SERVER_URL', defaultValue: 'http://localhost:8080'),
  );
}

class EmailService {
  EmailService._({EmailProviderConfig? config})
      : _config = config ?? EmailProviderConfig.fromEnv;
  static final EmailService instance = EmailService._();

  final EmailProviderConfig _config;

  Future<void> sendCustomEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String html,
  }) async {
    if (_config.provider == EmailProvider.server) {
      await _sendViaServer(
        toEmail: toEmail,
        toName: toName,
        subject: subject,
        html: html,
      );
      return;
    }

    throw AppException('Unsupported email provider');
  }

  Future<void> sendDonationReceipt(DonationRecord record,
      {DownloadableMaterial? material}) async {
    const subject = 'Thank you for your donation';
    final html = _buildDonationReceiptHtml(record, material: material);
    await sendCustomEmail(
      toEmail: record.userEmail,
      toName: record.userName,
      subject: subject,
      html: html,
    );
  }

  Future<void> sendAdminAlert({
    required String subject,
    required String message,
    String adminEmail = 'zavolah@gmail.com',
    String adminName = 'Admin',
  }) async {
    final html = '<p>${htmlEscape.convert(message)}</p>';
    await sendCustomEmail(
      toEmail: adminEmail,
      toName: adminName,
      subject: subject,
      html: html,
    );
  }

  String _buildDonationReceiptHtml(DonationRecord record,
      {DownloadableMaterial? material}) {
    final lines = <String>[
      '<h2>Donation Receipt</h2>',
      '<p>Dear ${htmlEscape.convert(record.userName)},</p>',
      '<p>Thank you for supporting ALIVE-NG ministry. Here are your receipt details:</p>',
      '<ul>',
      '<li><strong>Amount:</strong> ${record.formattedAmount} ${htmlEscape.convert(record.currency)}</li>',
      '<li><strong>Type:</strong> ${htmlEscape.convert(record.typeDisplayName)}</li>',
      if (material != null)
        '<li><strong>Material:</strong> ${htmlEscape.convert(material.title)}</li>',
      if (record.transactionId != null)
        '<li><strong>Transaction ID:</strong> ${htmlEscape.convert(record.transactionId!)}</li>',
      '</ul>',
      '<p>Date: ${record.createdAt.toIso8601String()}</p>',
      '<p>— ALIVE-NG Treasure</p>',
    ];
    return '<html><body>${lines.join()}<body></html>';
  }

  Future<void> _sendViaServer({
    required String toEmail,
    required String toName,
    required String subject,
    required String html,
  }) async {
    final base = _config.serverBaseUrl.trim();
    if (base.isEmpty) {
      throw AppException(
          'Email server URL not configured. Set EMAIL_SERVER_URL via --dart-define.');
    }
    final uri = Uri.parse('$base/email/send');
    final payload = {
      'to': toEmail,
      'subject': subject,
      'html': html,
    };
    final res = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(payload),
        )
        .timeout(_config.timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw NetworkException('Server email failed: ${res.statusCode} ${res.body}');
    }
  }
}
