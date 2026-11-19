import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/app_exception.dart';
import '../utils/logger.dart';
import 'leadership_email_settings_service.dart';

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
  /// [cc] (or replyTo if cc is omitted) for a complete archive.
  Future<void> sendCustomEmail({
    required String toEmail,
    required String toName,
    required String subject,
    required String html,
    String replyTo = AppwriteBackendConfig.supportEmail,
    String? cc,
  }) async {
    try {
      final execution = await _functions.createExecution(
        functionId: AppwriteBackendConfig.sendEmailFunctionId,
        body: jsonEncode(<String, dynamic>{
          'to': toEmail,
          'subject': subject,
          'html': html,
          'reply_to': replyTo,
          'cc': cc ?? replyTo,
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

  // ---------------------------------------------------------------------------
  // Board Meeting Minutes Email — Duplicate Prevention
  // ---------------------------------------------------------------------------

  /// In-memory set of keys for which a board email was already dispatched
  /// during this app session.  Prevents the same meeting from being emailed
  /// twice when both auto-save (livekit) and manual save (transcription screen)
  /// trigger the call.
  final Set<String> _sentBoardEmailKeys = {};

  /// Persistent SharedPreferences prefix so we don't re-send even after an
  /// app restart (e.g. user opens the transcription screen for a past meeting
  /// and presses save again).
  static const String _boardEmailSentPrefix = 'board_email_sent_';

  /// Generates a stable deduplication key from the meeting title + date.
  String _boardEmailKey(String meetingTitle) {
    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final cleanTitle = meetingTitle
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return '${cleanTitle}_$dateStr';
  }

  /// Returns `true` if board meeting minutes email was already sent for this
  /// meeting today.
  Future<bool> wasBoardEmailAlreadySent(String meetingTitle) async {
    final key = _boardEmailKey(meetingTitle);
    if (_sentBoardEmailKeys.contains(key)) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_boardEmailSentPrefix$key') == true;
    } catch (_) {
      return false;
    }
  }

  /// Marks a board email as sent so it won't be dispatched again.
  Future<void> _markBoardEmailSent(String meetingTitle) async {
    final key = _boardEmailKey(meetingTitle);
    _sentBoardEmailKeys.add(key);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_boardEmailSentPrefix$key', true);
    } catch (_) {}
  }

  /// Send Board & Leadership Meeting Minutes to ALIVE leadership team.
  /// Automatically called whenever minutes of a Board or Leadership Meeting channel are saved.
  /// Reads editable recipients from [LeadershipEmailSettingsService].
  ///
  /// **Duplicate prevention**: The same meeting (by title + date) is never
  /// emailed twice—both in the same session and across app restarts.
  /// Pass [force] = true to bypass the guard (e.g. user explicitly re-sends).
  Future<void> sendBoardMeetingMinutesEmail({
    required String meetingTitle,
    required String markdownMinutes,
    String? docxFileName,
    List<String>? toEmails,
    bool force = false,
  }) async {
    // ── Deduplication guard ──────────────────────────────────────────────
    if (!force) {
      final alreadySent = await wasBoardEmailAlreadySent(meetingTitle);
      if (alreadySent) {
        _logger.info(
            'Board/Leadership minutes email for "$meetingTitle" already sent today — skipping.');
        return;
      }
    }

    final recipients = toEmails ??
        await LeadershipEmailSettingsService.instance.getLeadershipRecipients();
    if (recipients.isEmpty) return;

    final now = DateTime.now();
    final dateStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final subject = 'ALIVE Board Meeting Minutes: $meetingTitle ($dateStr)';

    final safeTitle = htmlEscape.convert(meetingTitle);
    final htmlBody = _convertMarkdownToHtml(markdownMinutes);

    final html = '<!DOCTYPE html><html><body style="font-family:Arial,Helvetica,sans-serif;'
        'color:#17263B;max-width:760px;margin:0 auto;padding:24px;line-height:1.6;">'
        '<div style="background-color:#032B20;color:#FACC15;padding:18px 24px;border-radius:10px 10px 0 0;">'
        '<span style="font-size:11px;font-weight:900;letter-spacing:1px;background:#EAB308;color:#0F172A;padding:3px 8px;border-radius:4px;">ALIVE NIGERIA</span>'
        '<h2 style="color:#FFFFFF;margin:12px 0 4px;font-size:22px;">$safeTitle</h2>'
        '<p style="color:#A7F3D0;margin:0;font-size:12px;">Board of Directors Council Minutes &amp; Resolutions • $dateStr</p>'
        '</div>'
        '<div style="border:1px solid #E2E8F0;border-top:none;padding:24px;border-radius:0 0 10px 10px;background:#FFFFFF;">'
        '<p style="color:#334155;font-size:14px;">Dear Board Member,</p>'
        '<p style="color:#334155;font-size:14px;">The minutes and synthesized resolutions for <strong>$safeTitle</strong> '
        'have been officially recorded and archived in the Meeting Files repository${docxFileName != null ? " ($docxFileName)" : ""}. '
        'Below is the full synthesized record of the session:</p>'
        '<hr style="border:none;border-top:1px solid #E2E8F0;margin:16px 0;">'
        '<div style="font-size:13.5px;color:#1E293B;">$htmlBody</div>'
        '<hr style="border:none;border-top:1px solid #E2E8F0;margin:24px 0 16px;">'
        '<p style="color:#64748B;font-size:12px;">This document was automatically compiled and verified via <strong>ALIVE Scribe</strong> on ALIVE Meet.</p>'
        '</div>'
        '</body></html>';

    final primary = recipients.first;
    final ccRecipients = recipients.length > 1
        ? recipients.sublist(1).join(', ')
        : primary;

    await sendCustomEmail(
      toEmail: primary,
      toName: 'ALIVE Board of Directors',
      subject: subject,
      html: html,
      cc: ccRecipients,
    );

    // Mark as sent so neither auto-save nor manual save sends it again
    await _markBoardEmailSent(meetingTitle);
  }

  /// Converts simple Markdown syntax from Scribe into clean HTML.
  static String _convertMarkdownToHtml(String markdown) {
    if (markdown.trim().isEmpty) {
      return '<p><em>No transcript content available.</em></p>';
    }
    final lines = markdown.split('\n');
    final buf = StringBuffer();
    bool inList = false;

    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        if (inList) {
          buf.writeln('</ul>');
          inList = false;
        }
        continue;
      }

      if (line.startsWith('# ')) {
        if (inList) {
          buf.writeln('</ul>');
          inList = false;
        }
        buf.writeln(
            '<h1 style="color:#064E3B;margin:18px 0 8px;font-size:20px;">${htmlEscape.convert(line.substring(2).trim())}</h1>');
      } else if (line.startsWith('## ')) {
        if (inList) {
          buf.writeln('</ul>');
          inList = false;
        }
        buf.writeln(
            '<h2 style="color:#14532D;margin:16px 0 6px;font-size:17px;border-bottom:1px solid #E2E8F0;padding-bottom:4px;">${htmlEscape.convert(line.substring(3).trim())}</h2>');
      } else if (line.startsWith('### ')) {
        if (inList) {
          buf.writeln('</ul>');
          inList = false;
        }
        buf.writeln(
            '<h3 style="color:#166534;margin:12px 0 4px;font-size:15px;">${htmlEscape.convert(line.substring(4).trim())}</h3>');
      } else if (line.startsWith('* ') || line.startsWith('- ')) {
        if (!inList) {
          buf.writeln('<ul style="margin:6px 0 12px 20px;padding:0;">');
          inList = true;
        }
        final itemText = _formatInline(line.substring(2).trim());
        buf.writeln('<li style="margin-bottom:4px;">$itemText</li>');
      } else {
        if (inList) {
          buf.writeln('</ul>');
          inList = false;
        }
        buf.writeln('<p style="margin:6px 0 10px;">${_formatInline(line)}</p>');
      }
    }
    if (inList) {
      buf.writeln('</ul>');
    }
    return buf.toString();
  }

  static String _formatInline(String text) {
    var escaped = htmlEscape.convert(text);
    // Bold
    escaped = escaped.replaceAllMapped(
      RegExp(r'\*\*(.+?)\*\*'),
      (m) => '<strong>${m.group(1)}</strong>',
    );
    // Italic
    escaped = escaped.replaceAllMapped(
      RegExp(r'\*(.+?)\*'),
      (m) => '<em>${m.group(1)}</em>',
    );
    return escaped;
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
        'profile data, reading history, and achievements have been permanently '
        'deleted at your request.</p>'
        '<p>Please note that this action is final and permanent; deleted accounts '
        'cannot be restored. If you wish to rejoin ALIVE Nigeria in the future, '
        'you are always warmly welcome to register afresh with a new account on a '
        'clean slate at <a href="https://app.alivenigeria.org">app.alivenigeria.org</a>.</p>'
        '<p>For any general inquiries, our team is available at $supportLink.</p>'
        '<p>Thank you for the time you shared with us, and may God bless your journey.</p>'
        '<p style="color:#64748B;font-size:13px;">— ALIVE Nigeria App Ministry</p>'
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
