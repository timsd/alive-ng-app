import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;

import '../config/appwrite_backend_config.dart';
import '../main.dart';
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
  ///
  /// [replyTo] defaults to the monitored support mailbox so replies from
  /// recipients always land in a human inbox. Every mail is also CC'd to
  /// that same address for a complete archive.
  Future<void> sendCustomEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String html,
    String replyTo = AppwriteBackendConfig.supportEmail,
  }) async {
    try {
      final execution = await _functions.createExecution(
        functionId: AppwriteBackendConfig.sendEmailFunctionId,
        body: jsonEncode(<String, dynamic>{
          'to': toEmail,
          'subject': subject,
          'html': html,
          'reply_to': replyTo,
          'cc': replyTo,
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

  /// Notify a member that their account and profile data were deleted.
  ///
  /// Must be invoked *before* the profile row is removed, because the
  /// recipient address is read from the profile payload.
  Future<void> sendAccountDeletionEmail({
    required String toEmail,
    required String toName,
  }) async {
    final displayName = toName.trim().isEmpty ? 'Friend' : toName.trim();
    final subject = 'Your ALIVE Nigeria App account has been deleted';
    final safeName = htmlEscape.convert(displayName);
    final supportLink =
        '<a href="mailto:${AppwriteBackendConfig.supportEmail}">'
        '${AppwriteBackendConfig.supportEmail}</a>';

    final html = '<!DOCTYPE html><html><body style="font-family:Arial,Helvetica,sans-serif;'
        'color:#17263B;max-width:600px;margin:0 auto;padding:24px;">'
        '<h2 style="color:#233E5F;margin:0 0 16px;">Account deletion confirmed</h2>'
        '<p>Dear $safeName,</p>'
        '<p>This confirms that your ALIVE Nigeria App account and all associated '
        'profile data, reading history and achievements have been permanently '
        'deleted at your request.</p>'
        '<p>If you did not request this deletion, or if you believe this was a '
        'mistake, contact us immediately at $supportLink so we can assist you.</p>'
        '<p>Thank you for being part of the ALIVE Nigeria community. You are '
        'always welcome to create a new account at '
        '<a href="https://app.alivenigeria.org">app.alivenigeria.org</a>.</p>'
        '<p style="color:#64748B;font-size:13px;">— ALIVE Nigeria App Support</p>'
        '</body></html>';

    await sendCustomEmail(
      toEmail: toEmail,
      toName: displayName,
      subject: subject,
      html: html,
    );
  }

  /// Send a password-reset email with a branded Resend message.
  ///
  /// Appwrite's `createRecovery` always generates the recovery token itself,
  /// so we let it mint the token, then rebuild the clickable link from the
  /// returned `userId`/`secret` and send the actual email through Resend —
  /// guaranteeing our verified From + support Reply-To.
  Future<void> sendPasswordResetEmail({
    required String toEmail,
    required String toName,
    required String userId,
    required String secret,
  }) async {
    final displayName =
        toName.trim().isEmpty ? 'there' : toName.trim();
    final resetUrl =
        '${AppwriteBackendConfig.passwordRecoveryUrl}?userId=${Uri.encodeComponent(userId)}'
        '&secret=${Uri.encodeComponent(secret)}';
    final html =
        '<!DOCTYPE html><html><body style="font-family:Arial,Helvetica,sans-serif;'
        'color:#17263B;max-width:600px;margin:0 auto;padding:24px;">'
        '<h2 style="color:#233E5F;margin:0 0 16px;">Reset your password</h2>'
        '<p>Hi ${htmlEscape.convert(displayName)},</p>'
        '<p>We received a request to reset the password for your ALIVE Nigeria '
        'App account. Tap the button below to choose a new password. '
        'The link expires in about one hour and can only be used once.</p>'
        '<p style="margin:24px 0;text-align:center;">'
        '<a href="$resetUrl" style="display:inline-block;background:#233E5F;'
        'color:#fff;text-decoration:none;padding:12px 28px;border-radius:8px;'
        'font-weight:700;">Reset my password</a></p>'
        '<p style="color:#64748B;font-size:13px;">If the button does not work, '
        'copy and paste this link into your browser:<br>$resetUrl</p>'
        '<p style="color:#64748B;font-size:13px;">Did not request this? '
        'You can safely ignore this email — contact us at '
        '<a href="mailto:${AppwriteBackendConfig.supportEmail}">'
        '${AppwriteBackendConfig.supportEmail}</a> if you are concerned.</p>'
        '</body></html>';

    await sendCustomEmail(
      toEmail: toEmail,
      toName: displayName,
      subject: 'Reset your ALIVE Nigeria App password',
      html: html,
    );
  }
}
