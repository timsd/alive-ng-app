import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Service for handling native platform functionality
class NativeService {
  static const MethodChannel _channel =
      MethodChannel('com.aliveng.ministry.app/native');

  /// Open a URL in the default browser or app
  static Future<bool> openUrl(String url) async {
    try {
      // Try using url_launcher first (cross-platform)
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }

      // Fallback to native method channel
      final bool result = await _channel.invokeMethod('openUrl', {'url': url});
      return result;
    } catch (e) {
      print('Error opening URL: $e');
      return false;
    }
  }

  /// Share text content
  static Future<bool> shareText(String text, {String? subject}) async {
    try {
      final bool result = await _channel.invokeMethod('shareText', {
        'text': text,
        'subject': subject,
      });
      return result;
    } catch (e) {
      print('Error sharing text: $e');
      return false;
    }
  }

  /// Make a phone call
  static Future<bool> makePhoneCall(String phoneNumber) async {
    try {
      // Try using url_launcher first
      final Uri uri = Uri.parse('tel:$phoneNumber');
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }

      // Fallback to native method channel
      final bool result = await _channel.invokeMethod('makePhoneCall', {
        'phoneNumber': phoneNumber,
      });
      return result;
    } catch (e) {
      print('Error making phone call: $e');
      return false;
    }
  }

  /// Send an email
  static Future<bool> sendEmail({
    required String email,
    String? subject,
    String? body,
  }) async {
    try {
      // Try using url_launcher first
      String emailUrl = 'mailto:$email';
      List<String> queryParams = [];

      if (subject != null) {
        queryParams.add('subject=${Uri.encodeComponent(subject)}');
      }
      if (body != null) {
        queryParams.add('body=${Uri.encodeComponent(body)}');
      }

      if (queryParams.isNotEmpty) {
        emailUrl += '?${queryParams.join('&')}';
      }

      final Uri uri = Uri.parse(emailUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }

      // Fallback to native method channel
      final bool result = await _channel.invokeMethod('sendEmail', {
        'email': email,
        'subject': subject,
        'body': body,
      });
      return result;
    } catch (e) {
      print('Error sending email: $e');
      return false;
    }
  }

  /// Open SMS app with pre-filled message
  static Future<bool> sendSMS(String phoneNumber, {String? message}) async {
    try {
      String smsUrl = 'sms:$phoneNumber';
      if (message != null) {
        smsUrl += '?body=${Uri.encodeComponent(message)}';
      }

      final Uri uri = Uri.parse(smsUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      print('Error sending SMS: $e');
      return false;
    }
  }

  /// Open maps app with location
  static Future<bool> openMaps({
    double? latitude,
    double? longitude,
    String? address,
  }) async {
    try {
      String mapsUrl;

      if (latitude != null && longitude != null) {
        mapsUrl =
            'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
      } else if (address != null) {
        mapsUrl =
            'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}';
      } else {
        return false;
      }

      return await openUrl(mapsUrl);
    } catch (e) {
      print('Error opening maps: $e');
      return false;
    }
  }

  /// Open app settings
  static Future<bool> openAppSettings() async {
    try {
      const String settingsUrl = 'app-settings:';
      final Uri uri = Uri.parse(settingsUrl);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri);
      }
      return false;
    } catch (e) {
      print('Error opening app settings: $e');
      return false;
    }
  }

  /// Check if a URL can be launched
  static Future<bool> canLaunch(String url) async {
    try {
      final Uri uri = Uri.parse(url);
      return await canLaunchUrl(uri);
    } catch (e) {
      return false;
    }
  }
}

/// Provider for NativeService
final nativeServiceProvider = Provider<NativeService>((ref) {
  return NativeService();
});
