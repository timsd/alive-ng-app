import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/language_provider.dart';
import '../../utils/mobile_utils.dart';

class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(t('about_app')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: MobileUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // App Logo and Name
            Center(
              child: Column(
                children: [
                  Container(
                    width: MobileUtils.isMobileScreen(context) ? 80 : 100,
                    height: MobileUtils.isMobileScreen(context) ? 80 : 100,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      Icons.favorite,
                      color: Colors.white,
                      size: MobileUtils.isMobileScreen(context) ? 40 : 50,
                    ),
                  ),
                  SizedBox(height: MobileUtils.isMobileScreen(context) ? 12 : 16),
                  Text(
                    t('app_name'),
                    style: TextStyle(
                      fontSize: MobileUtils.getResponsiveFontSize(context, 24),
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  SizedBox(height: MobileUtils.isMobileScreen(context) ? 6 : 8),
                  Text(
                    t('app_tagline'),
                    style: TextStyle(
                      fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 24 : 32),

            // App Description
            Text(
              t('about_this_app'),
              style: TextStyle(
                fontSize: MobileUtils.getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 8 : 12),
            Text(
              t('app_description'),
              style: TextStyle(
                fontSize: MobileUtils.getResponsiveFontSize(context, 16), 
                height: 1.5
              ),
            ),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 16 : 24),

            // Developer Section
            Text(
              t('app_developer'),
              style: TextStyle(
                fontSize: MobileUtils.getResponsiveFontSize(context, 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: MobileUtils.isMobileScreen(context) ? 8 : 12),
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.green,
                          child: const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                t('developer_name'),
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                t('developer_title'),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      t('developer_message'),
                      style: const TextStyle(fontSize: 14, height: 1.4),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _launchEmail('dammyolodude@gmail.com'),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.email,
                            color: Colors.green,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            t('developer_email'),
                            style: const TextStyle(
                              color: Colors.green,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Version Info
            Center(
              child: Column(
                children: [
                  Text(
                    t('app_version'),
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    t('copyright'),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ALIVE Nigeria App Feedback',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
}




