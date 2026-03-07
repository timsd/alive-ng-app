import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';

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
      
      final firebaseService = ref.read(firebaseDatabaseServiceProvider);
      final contentData = await firebaseService.getContentPageBySlug(
        'terms-conditions', 
        languageCode: languageCode
      );
      
      if (contentData != null && contentData['content'] != null && contentData['content'].toString().trim().isNotEmpty && mounted) {
        setState(() {
          _termsContent = contentData['content'];
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
          _error = null; // Don't show error, use fallback content
          _termsContent = _getDefaultTermsContent();
          _isLoading = false;
        });
      }
    }
  }

  String _getDefaultTermsContent() {
    return '''
ALIVE-NG Terms & Conditions

Last updated: September 2025

1. Acceptance of Terms
By downloading, installing, or using the ALIVE Nigeria mobile application, you agree to be bound by these Terms and Conditions.

2. Description of Service
ALIVE-NG is a Christian mobile application that provides:
• Daily devotionals and Bible verses
• Prayer resources and categories
• Christian educational content
• Community features for believers
• Tract downloads and sharing

3. User Accounts
To access certain features, you may need to create an account. You are responsible for:
• Maintaining the confidentiality of your account information
• All activities that occur under your account
• Notifying us immediately of any unauthorized use

4. Acceptable Use
You agree not to:
• Use the app for any unlawful purpose
• Violate any applicable laws or regulations
• Infringe on the rights of others
• Upload or share inappropriate content
• Attempt to gain unauthorized access to our systems

5. Content and Intellectual Property
All content provided through the app, including but not limited to text, graphics, logos, and software, is the property of ALIVE Nigeria or its licensors and is protected by copyright and other intellectual property laws.

6. Donations and Payments
When making donations through our app:
• All donations are processed through secure third-party payment processors
• Donations are voluntary and non-refundable unless required by law
• You are responsible for any applicable taxes on your donations
• Donation receipts will be provided for tax purposes where applicable

7. Privacy
Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.

8. Disclaimers
The app is provided "as is" without warranties of any kind. We do not guarantee that the app will be error-free or uninterrupted.

9. Limitation of Liability
To the fullest extent permitted by law, ALIVE Nigeria shall not be liable for any indirect, incidental, special, or consequential damages.

10. Termination
We may terminate or suspend your access to the app at any time, with or without cause, with or without notice.

11. Changes to Terms
We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting in the app.

12. Contact Information
If you have any questions about these Terms and Conditions, please contact us:

Email: alivenigeria2011@gmail.com
Phone: +2347068548865
Organization: ALIVE Nigeria

By using ALIVE-NG, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Terms & Conditions',
        toolbarHeight: context.responsiveAppBarHeight,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, size: context.responsiveIconSize(24.0)),
            onPressed: _loadTermsContent,
          ),
          IconButton(
            icon: Icon(Icons.share, size: context.responsiveIconSize(24.0)),
            onPressed: () => _shareTerms(context),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: context.responsivePadding,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: context.responsiveIconSize(24.0) * 2,
                          color: Colors.grey[400],
                        ),
                        SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: context.responsiveFontSize(16.0),
                          ),
                        ),
                        SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                        ElevatedButton(
                          onPressed: _loadTermsContent,
                          style: ElevatedButton.styleFrom(
                            minimumSize: Size(double.infinity, context.responsiveButtonHeight),
                          ),
                          child: Text('Retry', style: TextStyle(fontSize: context.responsiveFontSize(16.0))),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: context.responsivePadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: context.responsivePadding,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).colorScheme.primary,
                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: context.responsiveBorderRadius,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ALIVE-NG Terms & Conditions',
                              style: TextStyle(
                                fontSize: context.responsiveFontSize(16.0) * 1.5,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                            SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0) * 0.5),
                            Text(
                              'Last updated: September 2025',
                              style: TextStyle(
                                fontSize: context.responsiveFontSize(16.0) * 0.9,
                            color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                      
                      // Translation Banner
                      if (_needsTranslation && _targetLanguage != null)
                        Container(
                          width: double.infinity,
                          padding: context.responsivePadding,
                          margin: const EdgeInsets.only(bottom: 16.0),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                            borderRadius: context.responsiveBorderRadius,
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.translate, 
                                color: Colors.orange[700], 
                                size: context.responsiveIconSize(24.0)),
                              SizedBox(width: context.getResponsiveValue(mobile: 16.0, tablet: 24.0, desktop: 32.0) * 0.75),
                              Expanded(
                                child: Text(
                                  'This content is available in English. Tap to translate to your language.',
                                  style: TextStyle(
                                    color: Colors.orange[700],
                                    fontSize: context.responsiveFontSize(16.0) * 0.9,
                                  ),
                                ),
                              ),
                              ElevatedButton(
                                onPressed: _translateContent,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.orange,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0, 
                                    vertical: 8.0
                                  ),
                                  minimumSize: Size(0, context.responsiveButtonHeight * 0.8),
                                ),
                                child: Text('Translate', style: TextStyle(fontSize: context.responsiveFontSize(16.0) * 0.9)),
                              ),
                            ],
                          ),
                        ),
                      
                      // Terms Content
                      Container(
                        padding: context.responsivePadding,
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardColor,
                          borderRadius: context.responsiveBorderRadius,
                          border: Border.all(
                            color: Theme.of(context).dividerColor,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          _termsContent!,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            fontSize: context.responsiveFontSize(16.0),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0) * 2),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _contactLegal(context),
                              icon: Icon(Icons.support_agent, size: context.responsiveIconSize(24.0)),
                              label: Text('Legal Support', style: TextStyle(fontSize: context.responsiveFontSize(16.0))),
                              style: OutlinedButton.styleFrom(
                                minimumSize: Size(0, context.responsiveButtonHeight),
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                      
                      // Contact Information
                      Container(
                        width: double.infinity,
                        padding: context.responsivePadding,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: context.responsiveBorderRadius,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Contact Information',
                              style: TextStyle(
                                fontSize: context.responsiveFontSize(16.0) * 1.2,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                            SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0) * 0.75),
                            Row(
                              children: [
                                Icon(Icons.email, 
                                  size: context.responsiveIconSize(24.0), 
                                  color: Theme.of(context).colorScheme.primary),
                                SizedBox(width: context.getResponsiveValue(mobile: 16.0, tablet: 24.0, desktop: 32.0) * 0.5),
                                Expanded(
                                  child: Text(
                                    'alivenigeria2011@gmail.com',
                                    style: TextStyle(
                                      fontSize: context.responsiveFontSize(16.0),
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0) * 0.5),
                            Row(
                              children: [
                                Icon(Icons.phone, 
                                  size: context.responsiveIconSize(24.0), 
                                  color: Theme.of(context).colorScheme.primary),
                                SizedBox(width: context.getResponsiveValue(mobile: 16.0, tablet: 24.0, desktop: 32.0) * 0.5),
                                Expanded(
                                  child: Text(
                                    '+2347068548865',
                                    style: TextStyle(
                                      fontSize: context.responsiveFontSize(16.0),
                                      color: Theme.of(context).colorScheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: context.getResponsiveValue(mobile: 8.0, tablet: 12.0, desktop: 16.0)),
                    ],
                  ),
                ),
              );
  }

  void _shareTerms(BuildContext context) {
    Clipboard.setData(const ClipboardData(
      text: 'Check out ALIVE-NG Terms & Conditions: https://alive-ng-flutter-app.web.app/terms-conditions.html',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terms & Conditions link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _contactLegal(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Legal Support'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('For legal questions or concerns:'),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            )),
            const Text('Email: alivenigeria2011@gmail.com'),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 8.0,
              tablet: 10.0,
              desktop: 12.0,
            )),
            const Text('Phone: +2347068548865'),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(
              context: context,
              mobile: 12.0,
              tablet: 14.0,
              desktop: 16.0,
            )),
            const Text('We typically respond within 24 hours.'),
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
              _openEmailClient();
            },
            child: const Text('Send Email'),
          ),
        ],
      ),
    );
  }

  Future<void> _openEmailClient() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'alivenigeria2011@gmail.com',
      query: 'subject=Legal Support - Terms and Conditions Inquiry&body=Hello ALIVE Nigeria Team,%0A%0AI have a question regarding the Terms and Conditions:%0A%0A[Please describe your question here]%0A%0AThank you.',
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri);
      } else {
        // Fallback: Copy email to clipboard
        await Clipboard.setData(const ClipboardData(text: 'alivenigeria2011@gmail.com'));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Email address copied to clipboard: alivenigeria2011@gmail.com'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      // Fallback: Copy email to clipboard
      await Clipboard.setData(const ClipboardData(text: 'alivenigeria2011@gmail.com'));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email address copied to clipboard: alivenigeria2011@gmail.com'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
}



