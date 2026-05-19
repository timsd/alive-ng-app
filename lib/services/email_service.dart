import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/donation_models.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Unified email service using Resend via Appwrite Functions.
///
/// All emails are sent server-side through the `send_email` Appwrite Function
/// which uses the Resend API, keeping the API key out of Flutter clients.
class EmailService {
  EmailService._();
  static final EmailService instance = EmailService._();

  static final Logger _logger = Logger('EmailService');
  final Functions _functions = Functions(appwriteClient);

  /// Send a custom email via the Appwrite Function.
  Future<void> sendCustomEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String html,
  }) async {
    try {
      final execution = await _functions.createExecution(
        functionId: AppwriteBackendConfig.sendEmailFunctionId,
        body: jsonEncode(<String, dynamic>{
          'to': toEmail,
          'subject': subject,
          'html': html,
        }),
        xasync: false,
        method: appwrite_enums.ExecutionMethod.pOST,
      );

      final data = jsonDecode(execution.responseBody) as Map<String, dynamic>;
      if (data['error'] != null) {
        throw NetworkException('${data['error']}');
      }
    } catch (e) {
      _logger.error('Unexpected error sending email', e);
      throw NetworkException('Email send failed', originalError: e);
    }
  }

  /// Send a donation receipt email.
  Future<void> sendDonationReceipt(
    DonationRecord record, {
    DownloadableMaterial? material,
  }) async {
    const subject = 'Thank you for your donation';
    final html = _buildDonationReceiptHtml(record, material: material);
    await sendCustomEmail(
      toEmail: record.userEmail,
      toName: record.userName,
      subject: subject,
      html: html,
    );
  }

  /// Send an admin alert email.
  Future<void> sendAdminAlert({
    required String subject,
    required String message,
    String adminEmail = 'alivenigeria2011@gmail.com',
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

  String _buildDonationReceiptHtml(
    DonationRecord record, {
    DownloadableMaterial? material,
  }) {
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
      '<p>— ALIVE-NG Treasury</p>',
    ];
    return '<html><body>${lines.join()}</body></html>';
  }
}
