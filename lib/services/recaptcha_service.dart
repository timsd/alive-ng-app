// reCAPTCHA Service for ALIVE NG
// Modern implementation using dart:js_interop instead of deprecated dart:html

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:js_interop';
import '../utils/logger.dart';

@JS('executeRecaptcha')
external JSPromise<JSString> _executeRecaptcha(JSString action);

@JS('grecaptcha')
external JSObject? get _grecaptcha;

class RecaptchaService {
  static String get siteKey {
    return const String.fromEnvironment('RECAPTCHA_SITE_KEY', defaultValue: '');
  }

  static const String verifyEndpoint = '/api/verify-recaptcha';

  static RecaptchaService? _instance;
  static RecaptchaService get instance => _instance ??= RecaptchaService._();

  static final Logger _logger = Logger('RecaptchaService');

  RecaptchaService._();

  /// Execute reCAPTCHA for web platform
  Future<String?> executeRecaptcha(String action) async {
    if (kIsWeb) {
      try {
        if (_grecaptcha == null) {
          _logger.warning('reCAPTCHA not loaded yet');
          return null;
        }
        final completer = Completer<String?>();
        final promise = _executeRecaptcha(action.toJS);
        promise.toDart.then((jsToken) {
          final token = jsToken.toDart;
          completer.complete(token);
        }).catchError((error) {
          _logger.error('reCAPTCHA execution error', error);
          completer.complete(null);
        });
        return await completer.future;
      } catch (e) {
        _logger.error('reCAPTCHA execution error', e);
        return null;
      }
    } else {
      _logger.info('reCAPTCHA not supported on mobile platforms');
      return null;
    }
  }

  /// Verify reCAPTCHA token with backend
  Future<RecaptchaVerificationResult> verifyToken(
    String token, {
    String? action,
    double minScore = 0.5,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${_getBaseUrl()}$verifyEndpoint'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'token': token,
          'action': action,
          'minScore': minScore,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return RecaptchaVerificationResult.fromJson(data);
      } else {
        return RecaptchaVerificationResult(
          success: false,
          error: 'HTTP ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      return RecaptchaVerificationResult(
        success: false,
        error: 'Network error: $e',
      );
    }
  }

  String _getBaseUrl() {
    if (kIsWeb) {
      return ''; // Use relative URL for web
    }
    // Use the same base URL as the API service for consistency
    if (kDebugMode) {
      return 'https://dev-api.alive-app.com';
    }
    return 'https://api.alive-app.com';
  }
}

/// Result of reCAPTCHA verification
class RecaptchaVerificationResult {
  final bool success;
  final double? score;
  final String? action;
  final String? error;
  final DateTime? challengeTs;
  final String? hostname;

  RecaptchaVerificationResult({
    required this.success,
    this.score,
    this.action,
    this.error,
    this.challengeTs,
    this.hostname,
  });

  factory RecaptchaVerificationResult.fromJson(Map<String, dynamic> json) {
    return RecaptchaVerificationResult(
      success: json['success'] ?? false,
      score: json['score']?.toDouble(),
      action: json['action'],
      error: json['error'],
      challengeTs: json['challenge_ts'] != null
          ? DateTime.parse(json['challenge_ts'])
          : null,
      hostname: json['hostname'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'score': score,
      'action': action,
      'error': error,
      'challenge_ts': challengeTs?.toIso8601String(),
      'hostname': hostname,
    };
  }
}

/// Mixin for easy reCAPTCHA integration in Flutter widgets
mixin RecaptchaMixin {
  static final Logger _logger = Logger('RecaptchaMixin');

  /// Execute reCAPTCHA and handle the result
  Future<bool> executeRecaptchaAction(String action,
      {double minScore = 0.5}) async {
    try {
      final token = await RecaptchaService.instance.executeRecaptcha(action);

      if (token == null) {
        _logger.warning('Failed to get reCAPTCHA token');
        return false;
      }

      final result = await RecaptchaService.instance.verifyToken(
        token,
        action: action,
        minScore: minScore,
      );

      if (!result.success) {
        _logger.warning('reCAPTCHA verification failed: ${result.error}');
        return false;
      }

      if (result.score != null && result.score! < minScore) {
        _logger.warning('reCAPTCHA score too low: ${result.score}');
        return false;
      }

      return true;
    } catch (e) {
      _logger.error('reCAPTCHA action error', e);
      return false;
    }
  }
}

/// Example usage in a Flutter widget
class ContactFormWidget extends StatefulWidget {
  const ContactFormWidget({super.key});

  @override
  State<ContactFormWidget> createState() => _ContactFormWidgetState();
}

class _ContactFormWidgetState extends State<ContactFormWidget>
    with RecaptchaMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  bool _isSubmitting = false;

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      // Execute reCAPTCHA before form submission
      final recaptchaSuccess = await executeRecaptchaAction('contact_form');

      if (!recaptchaSuccess) {
        _showError('Security verification failed. Please try again.');
        return;
      }

      // Proceed with form submission
      await _submitContactForm();

      _showSuccess('Message sent successfully!');
      _clearForm();
    } catch (e) {
      _showError('Failed to send message. Please try again.');
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _submitContactForm() async {
    // Implement your form submission logic here
    await Future.delayed(const Duration(seconds: 2)); // Simulate API call
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _clearForm() {
    _nameController.clear();
    _emailController.clear();
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Name is required' : null,
          ),
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(labelText: 'Email'),
            validator: (value) =>
                value?.isEmpty ?? true ? 'Email is required' : null,
          ),
          TextFormField(
            controller: _messageController,
            decoration: const InputDecoration(labelText: 'Message'),
            maxLines: 4,
            validator: (value) =>
                value?.isEmpty ?? true ? 'Message is required' : null,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _submitForm,
            child: _isSubmitting
                ? const CircularProgressIndicator()
                : const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}
