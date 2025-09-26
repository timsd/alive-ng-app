import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/supabase_service.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_app_bar.dart';

class TermsConditionsScreen extends ConsumerStatefulWidget {
  const TermsConditionsScreen({super.key});

  @override
  ConsumerState<TermsConditionsScreen> createState() => _TermsConditionsScreenState();
}

class _TermsConditionsScreenState extends ConsumerState<TermsConditionsScreen> {
  String? _termsContent;
  bool _isLoading = true;
  String? _error;
  bool _needsTranslation = false;
  String? _targetLanguage;

  @override
  void initState() {
    super.initState();
    _loadTermsContent();
  }

  Future<void> _translateContent() async {
    if (_termsContent == null || _targetLanguage == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the translation provider for basic translation
      final translate = ref.read(translationProvider);
      final translated = translate(_termsContent!);
      
      if (mounted) {
        setState(() {
          _termsContent = translated;
          _needsTranslation = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTermsContent() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Get current language from provider
      final currentLocale = ref.read(localeProvider);
      final languageCode = currentLocale.languageCode;
      
      final contentData = await SupabaseService.getContentPageBySlug(
        'terms-conditions', 
        languageCode: languageCode
      );
      
      if (contentData != null && mounted) {
        setState(() {
          _termsContent = contentData['content'] ?? _getDefaultTermsContent();
          _needsTranslation = contentData['needs_translation'] == true;
          _targetLanguage = contentData['target_language'];
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _termsContent = _getDefaultTermsContent();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load terms and conditions: $e';
          _termsContent = _getDefaultTermsContent();
          _isLoading = false;
        });
      }
    }
  }

  String _getDefaultTermsContent() {
    return '''
    <div style="font-family: Arial, sans-serif; line-height: 1.6; color: #333;">
      <h2>Terms and Conditions</h2>
      <p><strong>Last updated:</strong> December 2024</p>
      
      <h3>1. Acceptance of Terms</h3>
      <p>By downloading, installing, or using the ALIVE Nigeria mobile application, you agree to be bound by these Terms and Conditions.</p>
      
      <h3>2. Description of Service</h3>
      <p>ALIVE NG is a Christian mobile application that provides:</p>
      <ul>
        <li>Daily devotionals and Bible verses</li>
        <li>Prayer resources and categories</li>
        <li>Christian educational content</li>
        <li>Community features for believers</li>
        <li>Tract downloads and sharing</li>
      </ul>
      
      <h3>3. User Accounts</h3>
      <p>To access certain features, you may need to create an account. You are responsible for:</p>
      <ul>
        <li>Maintaining the confidentiality of your account information</li>
        <li>All activities that occur under your account</li>
        <li>Notifying us immediately of any unauthorized use</li>
      </ul>
      
      <h3>4. Acceptable Use</h3>
      <p>You agree not to:</p>
      <ul>
        <li>Use the app for any unlawful purpose</li>
        <li>Violate any applicable laws or regulations</li>
        <li>Infringe on the rights of others</li>
        <li>Upload or share inappropriate content</li>
        <li>Attempt to gain unauthorized access to our systems</li>
      </ul>
      
      <h3>5. Content and Intellectual Property</h3>
      <p>All content provided through the app, including but not limited to text, graphics, logos, and software, is the property of ALIVE Nigeria or its licensors and is protected by copyright and other intellectual property laws.</p>
      
      <h3>6. Privacy</h3>
      <p>Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.</p>
      
      <h3>7. Disclaimers</h3>
      <p>The app is provided "as is" without warranties of any kind. We do not guarantee that the app will be error-free or uninterrupted.</p>
      
      <h3>8. Limitation of Liability</h3>
      <p>To the fullest extent permitted by law, ALIVE Nigeria shall not be liable for any indirect, incidental, special, or consequential damages.</p>
      
      <h3>9. Termination</h3>
      <p>We may terminate or suspend your access to the app at any time, with or without cause, with or without notice.</p>
      
      <h3>10. Changes to Terms</h3>
      <p>We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting in the app.</p>
      
      <h3>11. Contact Information</h3>
      <p>If you have any questions about these Terms and Conditions, please contact us:</p>
      <ul>
        <li><strong>Email:</strong> alivenigeria2011@gmail.com</li>
        <li><strong>Phone:</strong> +2347068548865</li>
      </ul>
      
      <p><em>By using ALIVE NG, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.</em></p>
    </div>
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Terms & Conditions',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTermsContent,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareTerms(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadTermsContent,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.blue[600]!, Colors.blue[800]!],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALIVE NG Terms & Conditions',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Last updated: December 2024',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Translation Banner
                      if (_needsTranslation && _targetLanguage != null)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.orange[50],
                            border: Border.all(color: Colors.orange[200]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.translate, color: Colors.orange[700]),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This content is available in English. Tap to translate to your language.',
                                  style: TextStyle(
                                    color: Colors.orange[800],
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _translateContent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange[600],
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                ),
                                child: const Text('Translate'),
                              ),
                            ],
                          ),
                        ),
                      
                      // Terms Content
                      // Terms Content
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _termsContent!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _downloadTerms(context),
                              icon: const Icon(Icons.download),
                              label: const Text('Download PDF'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _contactLegal(context),
                              icon: const Icon(Icons.support_agent),
                              label: const Text('Legal Support'),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              );
  }

  void _shareTerms(BuildContext context) {
    Clipboard.setData(const ClipboardData(
      text: 'Check out ALIVE NG Terms & Conditions: https://alive-ng-flutter-app.web.app/terms-conditions.html',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terms & Conditions link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadTerms(BuildContext context) {
    // TODO: Implement PDF download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF download will be available soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _contactLegal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Legal Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('For legal questions or concerns:'),
            SizedBox(height: 12),
            Text('Email: alivenigeria2011@gmail.com'),
            SizedBox(height: 8),
            Text('Phone: +2347068548865'),
            SizedBox(height: 12),
            Text('We typically respond within 24 hours.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              // TODO: Open email client or contact form
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }
}



