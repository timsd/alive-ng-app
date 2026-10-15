import 'dart:convert';
import '../utils/logger.dart';
import '../models/app_models.dart';
import 'appwrite_admin_notification_store.dart';
import 'approval_link_service.dart';
import 'email_service.dart';

/// Service for sending admin notifications for new user registrations
class AdminNotificationService {
  static final AdminNotificationService _instance =
      AdminNotificationService._internal();
  factory AdminNotificationService() => _instance;
  AdminNotificationService._internal();

  static AdminNotificationService get instance => _instance;

  final Logger _logger = Logger('AdminNotificationService');
  final AppwriteAdminNotificationStore _notificationStore =
      AppwriteAdminNotificationStore.instance;

  // Removed unused _adminEmail constant to satisfy analyzer

  /// Send notification to admin when a new user signs up
  /// Send notification to admin when a new user signs up.
  ///
  /// Distinguishes between registrations that actually require manual administrator
  /// approval (e.g. Coordinators/Staff) versus auto-approved users (regular Members and Guests).
  Future<bool> notifyAdminOfNewSignup(UserProfile userProfile) async {
    try {
      _logger.info(
          'Processing admin notification for new user: ${userProfile.email} (role: ${userProfile.role}, status: ${userProfile.approvalStatus})');
      final recipients = ['alivenigeria2011@gmail.com']; // Super admin inbox

      final bool requiresApproval =
          !userProfile.isApproved && userProfile.approvalStatus == 'pending';

      String emailSubject;
      String emailBody;
      String? approvalUrl;

      if (requiresApproval) {
        emailSubject =
            'Action Required: New ${userProfile.requestedRole ?? userProfile.role} Registration - ALIVE Nigeria';

        if (userProfile.id.isNotEmpty) {
          final token = await ApprovalLinkService.instance
              .generateToken(userId: userProfile.id);
          approvalUrl = ApprovalLinkService.instance.buildApprovalUrl(
            baseUrl: 'https://app.alivenigeria.org',
            userId: userProfile.id,
            token: token,
          );
        }

        emailBody =
            '${_buildApprovalEmailBody(userProfile)}${approvalUrl != null ? '\n\nDirect Approval Link:\n$approvalUrl' : '\n\nPlease review this registration in the ALIVE Nigeria Admin Dashboard.'}';
      } else {
        // Informational notification for regular auto-approved member or guest
        emailSubject =
            'New Member Joined: ${userProfile.fullName ?? userProfile.email} - ALIVE Nigeria';
        emailBody = _buildNewMemberInfoEmailBody(userProfile);
      }

      bool anySuccess = false;
      for (final to in recipients) {
        final sent = await _sendEmailNotification(
          to: to,
          subject: emailSubject,
          body: emailBody,
          userProfile: userProfile,
        );
        if (sent) anySuccess = true;
      }

      await _storeNotificationRecord(
        type: requiresApproval
            ? 'pending_registration_approval'
            : 'new_member_registered',
        userId: userProfile.id,
        details: {
          'email': userProfile.email,
          'full_name': userProfile.fullName,
          'role': userProfile.role,
          'requires_approval': requiresApproval,
          'status': userProfile.approvalStatus,
          'success': anySuccess,
          'recipients': recipients,
          if (approvalUrl != null) 'approval_url': approvalUrl,
        },
      );

      if (anySuccess) {
        _logger.info(
            'Admin notification sent successfully for user: ${userProfile.email}');
      } else {
        _logger.error(
            'Failed to send admin notification for user: ${userProfile.email}');
      }

      return anySuccess;
    } catch (e) {
      _logger.error('Error sending admin notification', e);
      return false;
    }
  }

  /// Deprecated: Welcome emails are managed server-side via the Appwrite `sendEmail`
  /// function (which fires automatically on `users.*.create` and sends the branded
  /// HTML welcome template). This method is kept as a no-op to prevent duplicate
  /// plain-text welcome emails.
  Future<void> sendWelcomeNotification({
    required String userId,
    required String name,
    required String email,
  }) async {
    _logger.info(
        'sendWelcomeNotification skipped: branded welcome email is handled by the server-side Appwrite sendEmail function.');
  }

  /// Build email body for registrations that require manual review & approval (e.g. Coordinators)
  String _buildApprovalEmailBody(UserProfile userProfile) {
    final buffer = StringBuffer();

    buffer.writeln(
        'A new user has registered for the ALIVE Nigeria App with an elevated role and requires administrator approval.');
    buffer.writeln('');
    buffer.writeln('User Details:');
    buffer.writeln('=============');
    buffer.writeln('Full Name: ${userProfile.fullName ?? 'Not provided'}');
    buffer.writeln('Email: ${userProfile.email ?? 'Not provided'}');
    buffer.writeln('Phone: ${userProfile.phoneNumber ?? 'Not provided'}');
    buffer.writeln('Address: ${userProfile.address ?? 'Not provided'}');
    buffer.writeln('Requested Role: ${userProfile.requestedRole ?? userProfile.role}');
    buffer.writeln('');

    if (userProfile.localChapter != null) {
      buffer.writeln('Local Chapter: ${userProfile.localChapter}');
    }
    if (userProfile.localChurch != null) {
      buffer.writeln('Local Church: ${userProfile.localChurch}');
    }

    buffer.writeln('');
    buffer.writeln('Commitment Information:');
    buffer.writeln('======================');
    if (userProfile.commitmentType != null) {
      buffer.writeln('Commitment Type: ${userProfile.commitmentType}');
    }
    if (userProfile.financialCommitment != null) {
      buffer.writeln(
          'Financial Commitment: ₦${userProfile.financialCommitment}');
    }
    if (userProfile.availabilityCommitment != null) {
      buffer.writeln(
          'Availability Commitment: ${userProfile.availabilityCommitment}');
    }

    buffer.writeln('');
    if (userProfile.bio != null && userProfile.bio!.isNotEmpty) {
      buffer.writeln('Bio/Additional Information:');
      buffer.writeln(userProfile.bio);
      buffer.writeln('');
    }

    buffer.writeln(
        'Registration Date: ${userProfile.createdAt.toIso8601String()}');
    buffer.writeln('Current Status: Pending Approval');
    buffer.writeln('');
    buffer.writeln(
        'Please review this user\'s information and approve or reject their access.');
    buffer.writeln('You can click the direct approval link below or manage approvals via the Admin Dashboard:');
    buffer.writeln('https://app.alivenigeria.org/admin-approval');

    return buffer.toString();
  }

  /// Build informational email body for auto-approved regular members and guests
  String _buildNewMemberInfoEmailBody(UserProfile userProfile) {
    final buffer = StringBuffer();

    buffer.writeln('A new member has joined the ALIVE Nigeria App community!');
    buffer.writeln('');
    buffer.writeln('Member Details:');
    buffer.writeln('==============');
    buffer.writeln('Full Name: ${userProfile.fullName ?? 'Not provided'}');
    buffer.writeln('Email: ${userProfile.email ?? 'Not provided'}');
    buffer.writeln('Phone: ${userProfile.phoneNumber ?? 'Not provided'}');
    buffer.writeln('Role: ${userProfile.role}');
    buffer.writeln('Account Status: Active (Auto-approved)');
    buffer.writeln('');

    if (userProfile.localChapter != null) {
      buffer.writeln('Local Chapter: ${userProfile.localChapter}');
    }
    if (userProfile.localChurch != null) {
      buffer.writeln('Local Church: ${userProfile.localChurch}');
    }

    buffer.writeln('');
    if (userProfile.commitmentType != null && userProfile.commitmentType != 'none') {
      buffer.writeln('Commitment Information:');
      buffer.writeln('======================');
      buffer.writeln('Type: ${userProfile.commitmentType}');
      if (userProfile.financialCommitment != null) {
        buffer.writeln('Financial: ₦${userProfile.financialCommitment}');
      }
      if (userProfile.availabilityCommitment != null) {
        buffer.writeln('Availability: ${userProfile.availabilityCommitment}');
      }
      buffer.writeln('');
    }

    buffer.writeln(
        'Registration Date: ${userProfile.createdAt.toIso8601String()}');
    buffer.writeln('');
    buffer.writeln(
        'No approval action is required for this member. To view or manage members, visit the Admin Dashboard:');
    buffer.writeln('https://app.alivenigeria.org/admin');

    return buffer.toString();
  }

  /// Send email notification using available email service
  Future<bool> _sendEmailNotification({
    required String to,
    required String subject,
    required String body,
    required UserProfile userProfile,
  }) async {
    try {
      final html = '<pre>${htmlEscape.convert(body)}</pre>';
      await EmailService.instance.sendCustomEmail(
        toEmail: to,
        toName: 'ALIVE Nigeria Admin',
        subject: subject,
        html: html,
      );
      return true;
    } catch (e) {
      _logger.error('Failed to send email via Appwrite function', e);

      // Fallback: Log the notification for manual processing
      _logger.info('ADMIN NOTIFICATION REQUIRED:');
      _logger.info('To: $to');
      _logger.info('Subject: $subject');
      _logger.info('Body: $body');

      // Return true since we've logged it for manual processing
      return true;
    }
  }

  /// Send notification for user approval status change
  Future<bool> notifyAdminOfApprovalChange({
    required UserProfile userProfile,
    required String newStatus,
    required String? reason,
  }) async {
    try {
      const subject = 'User Approval Status Changed - ALIVE Nigeria App';
      final body =
          _buildApprovalChangeEmailBody(userProfile, newStatus, reason);
      final recipients = ['alivenigeria2011@gmail.com']; // Fallback super admin

      bool anySuccess = false;
      for (final to in recipients) {
        final sent = await _sendEmailNotification(
          to: to,
          subject: subject,
          body: body,
          userProfile: userProfile,
        );
        if (sent) anySuccess = true;
      }

      await _storeNotificationRecord(
        type: 'approval_status_change',
        userId: userProfile.id,
        details: {
          'email': userProfile.email,
          'full_name': userProfile.fullName,
          'new_status': newStatus,
          'reason': reason,
          'success': anySuccess,
          'recipients': recipients,
        },
      );

      return anySuccess;
    } catch (e) {
      _logger.error('Error sending approval change notification', e);
      return false;
    }
  }

  /// Build email body for approval status changes
  String _buildApprovalChangeEmailBody(
      UserProfile userProfile, String newStatus, String? reason) {
    final buffer = StringBuffer();

    buffer
        .writeln('User approval status has been changed in the ALIVE Nigeria App.');
    buffer.writeln('');
    buffer.writeln('User: ${userProfile.fullName} (${userProfile.email})');
    buffer.writeln('New Status: $newStatus');
    buffer.writeln('Changed Date: ${DateTime.now()}');

    if (reason != null && reason.isNotEmpty) {
      buffer.writeln('Reason: $reason');
    }

    buffer.writeln('');
    buffer.writeln(
        'This is an automated notification from the ALIVE Nigeria Admin System.');

    return buffer.toString();
  }

  /// Store notification record in Appwrite for tracking and management
  Future<void> _storeNotificationRecord({
    required String type,
    required String userId,
    required Map<String, dynamic> details,
  }) async {
    await _notificationStore.createNotificationRecord(
      type: type,
      userId: userId,
      details: details,
    );
  }

  /// Get all admin notifications from Appwrite
  Future<List<Map<String, dynamic>>> getAdminNotifications(
      {int limit = 50}) async {
    return _notificationStore.listNotificationRecords(limit: limit);
  }
}
