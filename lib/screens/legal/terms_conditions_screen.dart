import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';

class TermsConditionsScreen extends StatelessWidget {
  const TermsConditionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withOpacity(0.8),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.gavel,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ALIVE NG Terms & Conditions',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Last updated: ${DateTime.now().toString().split(' ')[0]}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Terms and Conditions Content
            _buildSection(
              'Agreement to Terms',
              '''By downloading, installing, or using the ALIVE NG mobile application, you agree to be bound by these Terms and Conditions ("Terms"). If you do not agree to these Terms, please do not use our app.

These Terms constitute a legally binding agreement between you and ALIVE NG Ministry regarding your use of our services.''',
            ),
            
            _buildSection(
              'Description of Service',
              '''ALIVE NG is a Christian mobile application designed to:

• Facilitate spiritual growth and discipleship
• Provide Bible study materials and resources
• Enable prayer requests and testimonies sharing
• Connect believers in a faith-based community
• Track spiritual milestones and achievements
• Offer Christian educational content
• Provide church and ministry information''',
            ),
            
            _buildSection(
              'User Accounts and Registration',
              '''To use certain features, you must create an account by providing:

• Accurate and complete information
• A valid email address
• Secure password protection
• Profile information as requested

You are responsible for:
• Maintaining the confidentiality of your account
• All activities that occur under your account
• Notifying us of any unauthorized use
• Keeping your information up to date''',
            ),
            
            _buildSection(
              'Acceptable Use Policy',
              '''You agree to use ALIVE NG only for lawful purposes and in accordance with Christian values. You will NOT:

• Post offensive, inappropriate, or harmful content
• Harass, threaten, or intimidate other users
• Share false or misleading information
• Violate any applicable laws or regulations
• Attempt to hack or disrupt our services
• Use the app for commercial purposes without permission
• Share content that violates intellectual property rights
• Engage in spam or unsolicited communications''',
            ),
            
            _buildSection(
              'Content Guidelines',
              '''All content shared on ALIVE NG must:

• Align with Christian values and teachings
• Be respectful and encouraging
• Be truthful and accurate
• Respect others\' privacy and dignity
• Comply with copyright laws

We reserve the right to:
• Review and moderate all content
• Remove inappropriate content
• Suspend or terminate accounts for violations
• Report illegal activities to authorities''',
            ),
            
            _buildSection(
              'Privacy and Data Protection',
              '''Your privacy is important to us. Our data practices are governed by our Privacy Policy, which includes:

• How we collect and use your information
• Data security measures we implement
• Your rights regarding your personal data
• How to contact us about privacy concerns

By using ALIVE NG, you consent to our Privacy Policy.''',
            ),
            
            _buildSection(
              'Intellectual Property Rights',
              '''ALIVE NG and its content are protected by intellectual property laws:

Our Rights:
• App design, features, and functionality
• Original content and materials
• Trademarks and logos
• Software and technology

Your Rights:
• Content you create and share
• Personal information and data
• Right to use the app as intended

You grant us a license to use content you share for app functionality and improvement.''',
            ),
            
            _buildSection(
              'Payment and Subscriptions',
              '''Some features may require payment:

• Donations to support the ministry through the app
• Event registrations and payments

Payment Terms:
• All payments are processed securely''',
            ),
            
            _buildSection(
              'Disclaimers and Limitations',
              '''ALIVE NG is provided "as is" without warranties:

• We do not guarantee uninterrupted service
• Content accuracy is not guaranteed
• Third-party links are not our responsibility
• Users are responsible for their own decisions
• Spiritual guidance should complement, not replace, pastoral care

Our liability is limited to the maximum extent permitted by law.''',
            ),
            
            _buildSection(
              'Termination',
              '''Either party may terminate this agreement:

We may terminate your account if you:
• Violate these Terms
• Engage in harmful behavior
• Provide false information
• Remain inactive for extended periods

You may terminate by:
• Deleting your account
• Uninstalling the app
• Contacting our support team

Upon termination, your access to the app will cease, but certain provisions will survive.''',
            ),
            
            _buildSection(
              'Governing Law',
              '''These Terms are governed by the laws of Nigeria:

• Disputes will be resolved in Nigerian courts
• Nigerian law applies to interpretation
• International users subject to local laws
• Arbitration may be required for certain disputes''',
            ),
            
            _buildSection(
              'Changes to Terms',
              '''We may update these Terms periodically:

• Changes will be posted in the app
• Significant changes will be notified
• Continued use constitutes acceptance
• You may terminate if you disagree with changes

We encourage you to review these Terms regularly.''',
            ),
            
            _buildSection(
              'Contact Information',
              '''For questions about these Terms, contact us:

Email: alivenigeria2011@gmail.com
Phone: +2347068548865
Address: No 6, Faniyi Street, Ebute-Ikorodu, Lagos''',
            ),
            
            const SizedBox(height: 32),
            
            // Acceptance Notice
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue[700],
                    size: 32,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'By continuing to use ALIVE NG, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue[800],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
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

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 14,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _shareTerms(BuildContext context) {
    Clipboard.setData(const ClipboardData(
      text: 'Check out ALIVE NG Terms & Conditions: https://alive-ng-legal.web.app/terms-conditions.html',
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
            Text('Legal Department'),
            SizedBox(height: 8),
            Text('Email: alivenigeria2011@gmail.com'),
            SizedBox(height: 8),
            Text('Phone: +2347068548865'),
            SizedBox(height: 8),
            Text('We respond to legal inquiries within 48 hours.'),
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