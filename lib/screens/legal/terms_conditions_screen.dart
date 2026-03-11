import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final updated = DateFormat('MMMM d, y').format(DateTime.now());

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Terms & Conditions',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () => _shareTerms(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ALIVE-NG Terms & Conditions',
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
            _termsText(context),
          ],
        ),
      ),
    );
  }

  Widget _termsText(BuildContext context) {
    return Text(
      '''
1. Acceptance of Terms
By downloading, installing, or using the ALIVE-NG mobile application, you agree to be bound by these Terms and Conditions.

2. Description of Service
ALIVE-NG is a Christian mobile application that provides:
- Daily devotionals and Bible verses
- Prayer resources and categories
- Christian educational content
- Community features for believers
- Tract downloads and sharing

3. User Accounts
To access certain features, you may need to create an account. You are responsible for:
- Maintaining the confidentiality of your account information
- All activities that occur under your account
- Notifying us immediately of any unauthorized use

4. Acceptable Use
You agree not to:
- Use the app for any unlawful purpose
- Violate any applicable laws or regulations
- Infringe on the rights of others
- Upload or share inappropriate content
- Attempt to gain unauthorized access to our systems

5. Content and Intellectual Property
All content provided through the app, including but not limited to text, graphics, logos, and software, is the property of ALIVE-NG or its licensors and is protected by copyright and other intellectual property laws.

6. Donations and Payments
When making donations through our app:
- All donations are processed through secure third-party payment processors
- Donations are voluntary and non-refundable unless required by law
- You are responsible for any applicable taxes on your donations
- Donation receipts will be provided for tax purposes where applicable

7. Privacy
Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information.

8. Disclaimers
The app is provided "as is" without warranties of any kind. We do not guarantee that the app will be error-free or uninterrupted.

9. Limitation of Liability
To the fullest extent permitted by law, ALIVE-NG shall not be liable for any indirect, incidental, special, or consequential damages.

10. Termination
We may terminate or suspend your access to the app at any time, with or without cause, with or without notice.

11. Changes to Terms
We reserve the right to modify these terms at any time. Changes will be effective immediately upon posting in the app.

12. Contact Information
If you have any questions about these Terms and Conditions, please contact us:
- Email: alivenigeria2011@gmail.com
- Phone: +2347068548865
- Organization: ALIVE-Nigeria

By using ALIVE-NG, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.
      ''',
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
            fontSize: context.responsiveFontSize(16),
          ),
    );
  }

  void _shareTerms(BuildContext context) {
    Clipboard.setData(
      const ClipboardData(
        text: 'https://app.alivenigeria.org/terms-conditions.html',
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terms & Conditions link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
