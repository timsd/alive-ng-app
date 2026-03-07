import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/admin_models.dart';
import 'admin_database_helper.dart';
import 'email_service.dart';
import '../utils/logger.dart';

class EmailNotificationService {
  static final EmailNotificationService _instance =
      EmailNotificationService._internal();
  factory EmailNotificationService() => _instance;
  EmailNotificationService._internal();

  static final Logger _logger = Logger('EmailNotificationService');

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminDatabaseHelper _dbHelper = AdminDatabaseHelper();

  // Using Brevo via EmailService; remove legacy EmailJS config
  // Admin notification emails
  static const List<String> adminEmails = [
    'admin@app.alivenigeria.org',
    'superadmin@app.alivenigeria.org',
  ];

  /// Send new user signup notification to admins
  Future<bool> sendSignupNotification({
    required String userEmail,
    required String fullName,
    String? phoneNumber,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      // Create notification for local database
      final notification = AdminNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'user_signup',
        title: 'New User Signup',
        message:
            'New user $fullName ($userEmail) has signed up and is awaiting approval.',
        createdAt: DateTime.now(),
        isRead: false,
        priority: 'normal',
        metadata: {
          'userEmail': userEmail,
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'additionalInfo': additionalInfo,
        },
      );

      // Save notification to local database
      await _dbHelper.insertAdminNotification(notification);

      // Send email notifications to all admin emails
      bool emailSent = false;
      for (final adminEmail in adminEmails) {
        final sent = await _sendEmailNotification(
          toEmail: adminEmail,
          subject: 'New User Signup - ALIVE-NG App',
          userName: fullName,
          userEmail: userEmail,
          phoneNumber: phoneNumber,
          additionalInfo: additionalInfo,
        );
        if (sent) emailSent = true;
      }

      // Also send to active admin users
      final adminUsers = await _dbHelper.getAllAdminUsers();
      for (final admin in adminUsers) {
        if (admin.isActive && admin.isApproved) {
          await _sendEmailNotification(
            toEmail: admin.email,
            subject: 'New User Signup - ALIVE-NG App',
            userName: fullName,
            userEmail: userEmail,
            phoneNumber: phoneNumber,
            additionalInfo: additionalInfo,
          );
        }
      }

      // Save notification to Firebase
      await _firestore.collection('admin_notifications').add({
        'type': 'user_signup',
        'title': 'New User Signup',
        'message':
            'New user $fullName ($userEmail) has signed up and is awaiting approval.',
        'createdAt': FieldValue.serverTimestamp(),
        'isRead': false,
        'priority': 'normal',
        'metadata': {
          'userEmail': userEmail,
          'fullName': fullName,
          'phoneNumber': phoneNumber,
          'additionalInfo': additionalInfo,
        },
      });

      return emailSent;
    } catch (e) {
      _logger.error('Error sending signup notification', e);
      return false;
    }
  }

  /// Send user approval notification
  Future<bool> sendApprovalNotification({
    required String userEmail,
    required String fullName,
    required bool isApproved,
    String? rejectionReason,
  }) async {
    try {
      final subject = isApproved
          ? 'Welcome to ALIVE-NG App - Account Approved'
          : 'ALIVE-NG App - Account Application Update';

      final message = isApproved
          ? 'Congratulations! Your account has been approved. You can now access all features of the ALIVE-NG App.'
          : 'We regret to inform you that your account application was not approved. ${rejectionReason ?? "Please contact support for more information."}';

      return await _sendEmailNotification(
        toEmail: userEmail,
        subject: subject,
        userName: fullName,
        userEmail: userEmail,
        customMessage: message,
      );
    } catch (e) {
      _logger.error('Error sending approval notification', e);
      return false;
    }
  }

  /// Send password reset notification
  Future<bool> sendPasswordResetNotification({
    required String userEmail,
    required String fullName,
  }) async {
    try {
      return await _sendEmailNotification(
        toEmail: userEmail,
        subject: 'Password Reset - ALIVE-NG App',
        userName: fullName,
        userEmail: userEmail,
        customMessage:
            'A password reset request has been initiated for your account. If you did not request this, please contact support immediately.',
      );
    } catch (e) {
      _logger.error('Error sending password reset notification', e);
      return false;
    }
  }

  /// Send admin activity notification
  Future<bool> sendAdminActivityNotification({
    required String action,
    required String adminName,
    required String targetUserEmail,
    Map<String, dynamic>? details,
  }) async {
    try {
      final notification = AdminNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'admin_activity',
        title: 'Admin Activity: $action',
        message:
            'Admin $adminName performed action "$action" on user $targetUserEmail',
        createdAt: DateTime.now(),
        isRead: false,
        priority: 'low',
        metadata: {
          'action': action,
          'adminName': adminName,
          'targetUserEmail': targetUserEmail,
          'details': details,
        },
      );

      await _dbHelper.insertAdminNotification(notification);

      // Send to super admins only for admin activities
      final adminUsers = await _dbHelper.getAllAdminUsers();
      bool emailSent = false;

      for (final admin in adminUsers) {
        if (admin.isActive && admin.isApproved && admin.role == 'super_admin') {
          final sent = await _sendEmailNotification(
            toEmail: admin.email,
            subject: 'Admin Activity Alert - ALIVE-NG App',
            userName: admin.fullName,
            userEmail: admin.email,
            customMessage:
                'Admin $adminName performed action "$action" on user $targetUserEmail. Please review the admin dashboard for more details.',
          );
          if (sent) emailSent = true;
        }
      }

      return emailSent;
    } catch (e) {
      _logger.error('Error sending admin activity notification', e);
      return false;
    }
  }

  /// Send system alert notification
  Future<bool> sendSystemAlert({
    required String title,
    required String message,
    String priority = 'normal',
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final notification = AdminNotification(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: 'system_alert',
        title: title,
        message: message,
        createdAt: DateTime.now(),
        isRead: false,
        priority: priority,
        metadata: metadata,
      );

      await _dbHelper.insertAdminNotification(notification);

      // Send to all active admins for system alerts
      final adminUsers = await _dbHelper.getAllAdminUsers();
      bool emailSent = false;

      for (final admin in adminUsers) {
        if (admin.isActive && admin.isApproved) {
          final sent = await _sendEmailNotification(
            toEmail: admin.email,
            subject: 'System Alert - ALIVE-NG App',
            userName: admin.fullName,
            userEmail: admin.email,
            customMessage: '$title\n\n$message',
          );
          if (sent) emailSent = true;
        }
      }

      return emailSent;
    } catch (e) {
      _logger.error('Error sending system alert', e);
      return false;
    }
  }

  /// Private method to send email using Brevo via EmailService
  Future<bool> _sendEmailNotification({
    required String toEmail,
    required String subject,
    required String userName,
    required String userEmail,
    String? phoneNumber,
    String? customMessage,
    Map<String, dynamic>? additionalInfo,
  }) async {
    try {
      final buffer = StringBuffer();
      buffer.writeln(
          '<p>${htmlEscape.convert(customMessage ?? 'New user signup notification')}</p>');
      buffer.writeln(
          '<p><strong>User:</strong> ${htmlEscape.convert(userName)} (${htmlEscape.convert(userEmail)})</p>');
      if (phoneNumber != null && phoneNumber.isNotEmpty) {
        buffer.writeln(
            '<p><strong>Phone:</strong> ${htmlEscape.convert(phoneNumber)}</p>');
      }
      if (additionalInfo != null && additionalInfo.isNotEmpty) {
        buffer.writeln('<p><strong>Additional Info:</strong></p>');
        buffer.writeln(
            '<pre>${htmlEscape.convert(jsonEncode(additionalInfo))}</pre>');
      }

      await EmailService.instance.sendCustomEmail(
        toEmail: toEmail,
        toName: userName,
        subject: subject,
        html: buffer.toString(),
      );
      return true;
    } catch (e) {
      _logger.error('Error sending email notification via Brevo', e);
      return false;
    }
  }

  /// Get unread notifications for admin
  Future<List<AdminNotification>> getUnreadNotifications(
      String? adminId) async {
    try {
      return await _dbHelper.getAdminNotifications(adminId, limit: 50);
    } catch (e) {
      _logger.error('Error getting unread notifications', e);
      return [];
    }
  }

  /// Mark notification as read
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      await _dbHelper.markNotificationAsRead(notificationId);
    } catch (e) {
      _logger.error('Error marking notification as read', e);
    }
  }

  /// Clear old notifications (older than 30 days)
  Future<void> clearOldNotifications() async {
    try {
      _logger.info('Clearing old notifications...');
      final count =
          await _dbHelper.deleteOldNotifications(const Duration(days: 30));
      _logger.info('Cleared $count old notifications');
    } catch (e) {
      _logger.error('Error clearing old notifications', e);
    }
  }

  /// Test email configuration
  Future<bool> testEmailConfiguration() async {
    try {
      return await _sendEmailNotification(
        toEmail: adminEmails.first,
        subject: 'Test Email - ALIVE-NG App',
        userName: 'Test User',
        userEmail: 'test@example.com',
        customMessage:
            'This is a test email to verify the email notification system is working correctly.',
      );
    } catch (e) {
      _logger.error('Error testing email configuration', e);
      return false;
    }
  }
}
