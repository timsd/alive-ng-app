import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat('MMMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Privacy Policy',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _sharePrivacyPolicy(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for ALIVE Nigeria App',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            Text(
              'Last updated: $updated',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color:
                        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
            _policyText(context),
          ],
        ),
      ),
    );
  }

  Widget _policyText(BuildContext context) {
    return Text(
      '''
1. Introduction
ALIVE Nigeria ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and services.

2. Information We Collect
2.1 Personal Information
- Name, email address, phone number
- Profile information and preferences
- Chapter membership and ministry involvement
- Prayer requests and testimonies

2.2 Usage Information
- App usage statistics and analytics
- Device information and identifiers
- Location data (with your consent)
- Study progress and completion data

3. How We Use Your Information
- Provide and maintain our services
- Personalize your spiritual journey
- Send prayer updates and notifications
- Facilitate chapter activities and connections
- Improve our app and services
- Ensure security and prevent fraud

4. Information Sharing and Disclosure
We do not sell your personal information. We may share information in these circumstances:
- With your consent
- With chapter leaders for ministry purposes
- To comply with legal obligations
- To protect our rights and safety
- With service providers under strict confidentiality

5. Data Security
We implement appropriate security measures to protect your information, including encryption, secure servers, and access controls. However, no method of transmission over the internet is 100% secure.

6. Your Rights and Choices
- Access and update your personal information
- Delete your account and associated data
- Opt-out of non-essential communications
- Control location sharing and notifications

7. International Data Transfers
Your information may be transferred to and processed in countries other than Nigeria. We ensure appropriate safeguards are in place for such transfers.

8. Changes to This Policy
We may update this Privacy Policy periodically. We will notify you of significant changes through the app or email.

9. Donations and Financial Information
When you make donations through our app:
- We collect necessary payment information through secure third-party processors
- We do not store your complete payment card details
- Donation records are maintained for tax and legal compliance
- We use Google reCAPTCHA to protect forms; use is subject to Google's Privacy Policy and Terms of Service. By interacting with our forms, you consent to this protection.
- You may request donation history for your records

10. Third-Party Services
Our app may integrate with third-party services including:
- Payment processors (Paystack) for donations
- Analytics services for app improvement
- Cloud storage for data backup and synchronization
- Social media platforms for content sharing

These services have their own privacy policies, and we encourage you to review them.

11. Data Retention
We retain your personal information only as long as necessary to:
- Provide our services to you
- Comply with legal obligations
- Resolve disputes and enforce agreements
- Maintain security and prevent fraud

12. Children's Privacy
ALIVE-NG is committed to protecting the privacy of children who use our services. Our platform includes content designed for children ages 3 and above to support their moral and spiritual growth.

12.1 Parental Responsibility and Consent
Parents or legal guardians are responsible for creating and managing accounts that may be shared with children. We require parental consent before collecting any personal information from children under 13 years of age.

12.2 Account Creation for Minors
Guidelines:
- Parents must create accounts on behalf of children under 13
- Children aged 13-17 may create accounts with parental supervision and consent
- All accounts for minors require ongoing parental oversight
- Parents can review, modify, or delete their child's information at any time

12.3 Information Collection from Children
We only collect information from children that is necessary to provide our educational and spiritual content services. This may include:
- Basic account information (managed by parents)
- Progress tracking for educational content
- Preferences for age-appropriate content delivery

12.4 Parental Rights
Parents have the right to:
- Review their child's personal information
- Request deletion of their child's information
- Refuse further collection of their child's information
- Control their child's access to community features

If you are a parent and believe your child has provided personal information without your consent, please contact us immediately at alivenigeria2011@gmail.com.

13. Changes to This Policy
We may update this Privacy Policy periodically to reflect changes in our practices or legal requirements. We will notify you of significant changes through the app, email, or by posting a notice on our website. Your continued use of our services after such changes constitutes acceptance of the updated policy.

14. Contact Us
For questions about this Privacy Policy or to exercise your privacy rights, contact us at:
- Email: alivenigeria2011@gmail.com
- Phone: +2347068548865
- Organization: ALIVE Nigeria

Your privacy is important to us. We are committed to protecting your personal information and being transparent about our data practices. Please review this Privacy Policy regularly to stay informed about how we protect your information.
      ''',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            fontSize: context.responsiveFontSize(16),
          ),
    );
  }

  void _sharePrivacyPolicy(BuildContext context) {
    Clipboard.setData(
      const ClipboardData(
        text: 'https://app.alivenigeria.org/privacy-policy.html',
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy Policy link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
