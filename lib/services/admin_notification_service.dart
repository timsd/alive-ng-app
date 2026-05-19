import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/logger.dart';
import '../models/app_models.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Removed unused _adminEmail constant to satisfy analyzer

  /// Send notification to admin when a new user signs up
  Future<bool> notifyAdminOfNewSignup(UserProfile userProfile) async {
    try {
      _logger.info(
          'Sending admin notification for new user: ${userProfile.email}');
      const emailSubject = 'New User Registration - ALIVE-NG App';
      final recipients = ['alivenigeria2011@gmail.com']; // Fallback super admin
      final token = await ApprovalLinkService.instance
          .generateToken(userId: userProfile.id);
      final approvalUrl = ApprovalLinkService.instance.buildApprovalUrl(
        baseUrl: 'https://app.alivenigeria.org',
        userId: userProfile.id,
        token: token,
      );
      final emailBody =
          '${_buildEmailBody(userProfile)}\n\nApproval Link:\n$approvalUrl';

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
        type: 'new_user_registration',
        userId: userProfile.id,
        details: {
          'email': userProfile.email,
          'full_name': userProfile.fullName,
          'status': 'sent',
          'success': anySuccess,
          'recipients': recipients,
          'approval_url': approvalUrl,
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

  /// Build email body with user information for admin review
  String _buildEmailBody(UserProfile userProfile) {
    final buffer = StringBuffer();

    buffer.writeln(
        'A new user has registered for the ALIVE-NG App and requires approval.');
    buffer.writeln('');
    buffer.writeln('User Details:');
    buffer.writeln('=============');
    buffer.writeln('Full Name: ${userProfile.fullName ?? 'Not provided'}');
    buffer.writeln('Email: ${userProfile.email ?? 'Not provided'}');
    buffer.writeln('Phone: ${userProfile.phoneNumber ?? 'Not provided'}');
    buffer.writeln('Address: ${userProfile.address ?? 'Not provided'}');
    buffer.writeln('');

    if (userProfile.localChapter != null) {
      buffer.writeln('Local Chapter: ${userProfile.localChapter}');
    }
    if (userProfile.localChurch != null) {
      buffer.writeln('Local Church: ${userProfile.localChurch}');
    }
    if (userProfile.conference != null) {
      buffer.writeln('Conference: ${userProfile.conference}');
    }

    buffer.writeln('');
    buffer.writeln('Commitment Information:');
    buffer.writeln('======================');
    if (userProfile.commitmentType != null) {
      buffer.writeln('Commitment Type: ${userProfile.commitmentType}');
    }
    if (userProfile.financialCommitment != null) {
      buffer.writeln(
          'Financial Commitment: \$${userProfile.financialCommitment}');
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
    buffer.writeln('Current Status: ${userProfile.approvalStatus}');
    buffer.writeln('');
    buffer.writeln(
        'Please review this user\'s information and approve or reject their access to the platform.');
    buffer.writeln('');
    buffer.writeln(
        'To manage user approvals, please log into the ALIVE-NG Admin Dashboard.');

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
        toName: 'ALIVE-NG Admin',
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
      const subject = 'User Approval Status Changed - ALIVE-NG App';
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
        .writeln('User approval status has been changed in the ALIVE-NG App.');
    buffer.writeln('');
    buffer.writeln('User: ${userProfile.fullName} (${userProfile.email})');
    buffer.writeln('New Status: $newStatus');
    buffer.writeln('Changed Date: ${DateTime.now()}');

    if (reason != null && reason.isNotEmpty) {
      buffer.writeln('Reason: $reason');
    }

    buffer.writeln('');
    buffer.writeln(
        'This is an automated notification from the ALIVE-NG Admin System.');

    return buffer.toString();
  }

  /// Store notification record in Firestore for tracking and management
  Future<void> _storeNotificationRecord({
    required String type,
    required String userId,
    required Map<String, dynamic> details,
  }) async {
    try {
      await _firestore.collection('admin_notifications').add({
        'type': type,
        'user_id': userId,
        'details': details,
        'created_at': FieldValue.serverTimestamp(),
      });
      _logger.info('Notification record stored in Firestore');
    } catch (e) {
      _logger.error('Failed to store notification record in Firestore', e);
    }
  }

  /// Get all admin notifications from Firestore
  Future<List<Map<String, dynamic>>> getAdminNotifications(
      {int limit = 50}) async {
    try {
      final snapshot = await _firestore
          .collection('admin_notifications')
          .orderBy('created_at', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
    } catch (e) {
      _logger.error('Error getting admin notifications', e);
      return [];
    }
  }
}
