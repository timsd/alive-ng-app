import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
                    Icons.privacy_tip,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ALIVE NG Privacy Policy',
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
            
            // Privacy Policy Content
            _buildSection(
              'Introduction',
              'ALIVE NG ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application and related services.',
            ),
            
            _buildSection(
              'Information We Collect',
              '''We may collect the following types of information:

Personal Information:
• Name and contact information
• Email address and phone number
• Profile information and bio
• Date of birth and gender
• Location information (city, state, country)
• Emergency contact details

Usage Information:
• App usage patterns and preferences
• Prayer requests and testimonies
• Study progress and achievements
• Chat messages and interactions
• Device information and identifiers

Religious Information:
• Baptism date and church membership
• Spiritual gifts and ministry interests
• Bible study progress and scores
• Prayer requests and answered prayers''',
            ),
            
            _buildSection(
              'How We Use Your Information',
              '''We use your information to:

• Provide and maintain our services
• Facilitate communication between users
• Track your spiritual growth and progress
• Send notifications and reminders
• Improve our app and user experience
• Ensure security and prevent fraud
• Comply with legal obligations
• Provide customer support''',
            ),
            
            _buildSection(
              'Information Sharing',
              '''We may share your information in the following circumstances:

With Your Consent:
• When you explicitly agree to share information
• When participating in community features

Service Providers:
• Third-party services that help us operate our app
• Analytics and performance monitoring services
• Cloud storage and database providers

Legal Requirements:
• When required by law or legal process
• To protect our rights and safety
• In case of emergency situations

We do not sell your personal information to third parties.''',
            ),
            
            _buildSection(
              'Data Security',
              '''We implement appropriate security measures to protect your information:

• Encryption of data in transit and at rest
• Secure authentication and access controls
• Regular security audits and updates
• Limited access to personal information
• Secure cloud infrastructure (Supabase)

However, no method of transmission over the internet is 100% secure.''',
            ),
            
            _buildSection(
              'Your Rights and Choices',
              '''You have the following rights regarding your information:

• Access: Request a copy of your personal information
• Correction: Update or correct inaccurate information
• Deletion: Request deletion of your account and data
• Portability: Export your data in a readable format
• Opt-out: Unsubscribe from notifications and communications

To exercise these rights, contact us at privacy@aliveng.org''',
            ),
            
            _buildSection(
              'Children\'s Privacy',
              '''Our app is designed for users of all ages, including children. We take special care to protect children\'s privacy:

• Parental consent for users under 13
• Limited data collection for minors
• No targeted advertising to children
• Safe communication features
• Educational content appropriate for all ages''',
            ),
            
            _buildSection(
              'International Users',
              '''If you are located outside Nigeria, please note:

• Your information may be transferred to and processed in Nigeria
• We comply with applicable international privacy laws
• Data transfers are protected by appropriate safeguards
• You may have additional rights under local laws''',
            ),
            
            _buildSection(
              'Changes to This Policy',
              '''We may update this Privacy Policy from time to time. We will notify you of any changes by:

• Posting the new Privacy Policy in the app
• Sending you a notification
• Updating the "Last updated" date

Your continued use of the app after changes constitutes acceptance of the new policy.''',
            ),
            
            _buildSection(
              'Contact Us',
              '''If you have questions about this Privacy Policy, please contact us:

Email: alivenigeria2011@gmail.com
Phone: +2347068548865
Address: No 6, Faniyi Street, 
Ebute-Ikorodu, Lagos

For technical support: alivenigeria2011@gmail.com
For general inquiries: alivenigeria2011@gmail.com''',
            ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _downloadPolicy(context),
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
                    onPressed: () => _contactSupport(context),
                    icon: const Icon(Icons.support_agent),
                    label: const Text('Contact Us'),
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

  void _sharePrivacyPolicy(BuildContext context) {
    Clipboard.setData(const ClipboardData(
      text: 'Check out ALIVE NG Privacy Policy: https://alive-ng-legal.web.app/privacy-policy.html',
    ));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Privacy Policy link copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _downloadPolicy(BuildContext context) {
    // TODO: Implement PDF download functionality
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF download will be available soon'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _contactSupport(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Contact Support'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Email: alivenigeria2011@gmail.com'),
            SizedBox(height: 8),
            Text('Phone:+2347068548865'),
            SizedBox(height: 8),
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