import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() => _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  String? _privacyPolicyContent;
  bool _isLoading = true;
  String? _error;
  bool _needsTranslation = false;
  String? _targetLanguage;

  @override
  void initState() {
    super.initState();
    _loadPrivacyPolicy();
  }

  Future<void> _translateContent() async {
    if (_privacyPolicyContent == null || _targetLanguage == null) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Use the translation provider for basic translation
      final translate = ref.read(translationProvider);
      final translated = translate(_privacyPolicyContent!);
      
      if (mounted) {
        setState(() {
          _privacyPolicyContent = translated;
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

  Future<void> _loadPrivacyPolicy() async {
    
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
        'privacy-policy', 
        languageCode: languageCode
      );
      
      if (contentData != null && contentData['content'] != null && contentData['content'].toString().trim().isNotEmpty && mounted) {
        setState(() {
          _privacyPolicyContent = contentData['content'];
          _needsTranslation = contentData['needs_translation'] == true;
          _targetLanguage = contentData['target_language'];
          _isLoading = false;
        });
      } else if (mounted) {
        // Fallback to default content when database is empty
        setState(() {
          _privacyPolicyContent = _getDefaultPrivacyPolicyContent();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = null; // Don't show error, use fallback content
          _privacyPolicyContent = _getDefaultPrivacyPolicyContent();
          _isLoading = false;
        });
      }
    }
  }

  String _getDefaultPrivacyPolicyContent() {
    return '''
Privacy Policy for ALIVE Nigeria App

Last updated: September 2025

1. Introduction
ALIVE Nigeria ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.

2. Information We Collect

2.1 Personal Information
• Name, email address, phone number
• Profile information and preferences
• Chapter membership and ministry involvement
• Prayer requests and testimonies

2.2 Usage Information
• App usage statistics and analytics
• Device information and identifiers
• Location data (with your consent)
• Study progress and completion data

3. How We Use Your Information
• Provide and maintain our services
• Personalize your spiritual journey
• Send prayer updates and notifications
• Facilitate chapter activities and connections
• Improve our app and services
• Ensure security and prevent fraud

4. Information Sharing and Disclosure
We do not sell your personal information. We may share information in these circumstances:
• With your consent
• With chapter leaders for ministry purposes
• To comply with legal obligations
• To protect our rights and safety
• With service providers under strict confidentiality

5. Data Security
We implement appropriate security measures to protect your information, including encryption, secure servers, and access controls. However, no method of transmission over the internet is 100% secure.

6. Your Rights and Choices
• Access and update your personal information
• Delete your account and associated data
• Opt-out of non-essential communications
• Control location sharing and notifications

7. International Data Transfers
Your information may be transferred to and processed in countries other than Nigeria. We ensure appropriate safeguards are in place for such transfers.

8. Changes to This Policy
We may update this Privacy Policy periodically. We will notify you of significant changes through the app or email.

9. Donations and Financial Information
When you make donations through our app:
• We collect necessary payment information through secure third-party processors
• We do not store your complete payment card details
• Donation records are maintained for tax and legal compliance
• You may request donation history for your records

10. Third-Party Services
Our app may integrate with third-party services including:
• Payment processors (Paystack) for donations
• Analytics services for app improvement
• Cloud storage for data backup and synchronization
• Social media platforms for content sharing

These services have their own privacy policies, and we encourage you to review them.

11. Data Retention
We retain your personal information only as long as necessary to:
• Provide our services to you
• Comply with legal obligations
• Resolve disputes and enforce agreements
• Maintain security and prevent fraud

12. Children's Privacy
ALIVE NG is committed to protecting the privacy of children who use our services. Our platform includes content designed for children ages 3 and above to support their moral and spiritual growth.

12.1 Parental Responsibility and Consent
Parents or legal guardians are responsible for creating and managing accounts that may be shared with children. We require parental consent before collecting any personal information from children under 13 years of age.

12.2 Account Creation for Minors
Guidelines:
• Parents must create accounts on behalf of children under 13
• Children aged 13-17 may create accounts with parental supervision and consent
• All accounts for minors require ongoing parental oversight
• Parents can review, modify, or delete their child's information at any time

12.3 Information Collection from Children
We only collect information from children that is necessary to provide our educational and spiritual content services. This may include:
• Basic account information (managed by parents)
• Progress tracking for educational content
• Preferences for age-appropriate content delivery

12.4 Parental Rights
Parents have the right to:
• Review their child's personal information
• Request deletion of their child's information
• Refuse further collection of their child's information
• Control their child's access to community features

If you are a parent and believe your child has provided personal information without your consent, please contact us immediately at alivenigeria2011@gmail.com.

13. Changes to This Policy
We may update this Privacy Policy periodically to reflect changes in our practices or legal requirements. We will notify you of significant changes through the app, email, or by posting a notice on our website. Your continued use of our services after such changes constitutes acceptance of the updated policy.

14. Contact Us
For questions about this Privacy Policy or to exercise your privacy rights, contact us at:

Email: alivenigeria2011@gmail.com
Phone: +2347068548865
Organization: ALIVE Nigeria

Your privacy is important to us. We are committed to protecting your personal information and being transparent about our data practices. Please review this Privacy Policy regularly to stay informed about how we protect your information.
    ''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Privacy Policy',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPrivacyPolicy,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePrivacyPolicy(context),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: context.responsiveIconSize(64),
              color: Colors.red[300],
            ),
            SizedBox(height: context.responsivePadding.top),
            Text(
              'Error Loading Privacy Policy',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: context.responsiveFontSize(20),
              ),
            ),
            SizedBox(height: context.responsivePadding.top / 2),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: context.responsiveFontSize(16),
              ),
            ),
            SizedBox(height: context.responsivePadding.top),
            ElevatedButton(
              onPressed: _loadPrivacyPolicy,
              style: ElevatedButton.styleFrom(
                minimumSize: Size(
                  ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 120.0,
                    tablet: 140.0,
                    desktop: 160.0,
                  ),
                  ResponsiveUtils.getResponsiveButtonHeight(context),
                ),
              ),
              child: Text(
                'Retry',
                style: TextStyle(
                  fontSize: context.responsiveFontSize(16),
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (_privacyPolicyContent == null || _privacyPolicyContent!.isEmpty) {
      return Center(
        child: Text(
          'Privacy policy content not available',
          style: TextStyle(
            fontSize: context.responsiveFontSize(16),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: context.responsivePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Translation banner if needed
          if (_needsTranslation) ...[
            Container(
              width: double.infinity,
              padding: context.responsivePadding,
              margin: const EdgeInsets.only(bottom: 16.0),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: context.responsiveBorderRadius,
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.translate,
                        color: Theme.of(context).colorScheme.primary,
                        size: context.responsiveIconSize(20),
                      ),
                      SizedBox(width: context.responsivePadding.left / 2),
                      Text(
                        'Translation Available',
                        style: TextStyle(
                          fontSize: context.responsiveFontSize(16),
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: context.responsivePadding.top / 2),
                  Text(
                    'This content can be translated to ${_targetLanguage ?? 'your preferred language'}.',
                    style: TextStyle(
                      fontSize: context.responsiveFontSize(14),
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                  SizedBox(height: context.responsivePadding.top / 2),
                  ElevatedButton.icon(
                    onPressed: _translateContent,
                    icon: Icon(
                      Icons.language,
                      size: context.responsiveIconSize(16),
                    ),
                    label: Text(
                      'Translate Now',
                      style: TextStyle(
                        fontSize: context.responsiveFontSize(14),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      minimumSize: Size(
                        ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 120.0,
                          tablet: 140.0,
                          desktop: 160.0,
                        ),
                        ResponsiveUtils.getResponsiveButtonHeight(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Header Section
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            margin: const EdgeInsets.only(bottom: 24.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
              borderRadius: context.responsiveBorderRadius,
            ),
            child: Column(
              children: [
                Icon(
                  Icons.privacy_tip,
                  size: context.responsiveIconSize(48),
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                SizedBox(height: context.responsivePadding.top / 2),
                Text(
                  'ALIVE Nigeria Privacy Policy',
                  style: TextStyle(
                    fontSize: context.responsiveFontSize(24),
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          
          SizedBox(height: context.responsivePadding.top * 1.5),
          
          // Dynamic Content from Database
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
              _privacyPolicyContent!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.6,
                fontSize: context.responsiveFontSize(16),
              ),
            ),
          ),
          
          SizedBox(height: context.responsivePadding.top * 2),
          
          // Contact Information
          Container(
            width: double.infinity,
            padding: context.responsivePadding,
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: context.responsiveBorderRadius,
              border: Border.all(
                color: Theme.of(context).dividerColor,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contact_support,
                      color: Theme.of(context).colorScheme.primary,
                      size: context.responsiveIconSize(24),
                    ),
                    SizedBox(width: context.responsivePadding.left / 2),
                    Text(
                      'Need Help?',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: context.responsiveFontSize(18),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: context.responsivePadding.top / 2),
                Text(
                  'If you have any questions about this Privacy Policy, please contact us at alivenigeria2011@gmail.com',
                  style: TextStyle(
                    fontSize: context.responsiveFontSize(14),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _sharePrivacyPolicy(BuildContext context) {
    Clipboard.setData(const ClipboardData(
      text: 'Check out ALIVE NG Privacy Policy: https://alive-ng-flutter-app.web.app/privacy-policy.html',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy Policy link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}



