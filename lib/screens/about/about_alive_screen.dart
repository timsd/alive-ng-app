import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/language_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';

class AboutAliveScreen extends ConsumerWidget {
  const AboutAliveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);
    return Scaffold(
      appBar: CustomAppBar(
        title: t('About ALIVE'),
        showBackButton: true,
      ),
      body: SingleChildScrollView(
        padding: context.responsivePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ALIVE Logo and Title
            Center(
              child: Column(
                children: [
                  Container(
                    width: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 120.0,
                      tablet: 140.0,
                      desktop: 160.0,
                    ),
                    height: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 120.0,
                      tablet: 140.0,
                      desktop: 160.0,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: context.responsiveBorderRadius,
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).shadowColor.withValues(alpha: 0.3),
                          spreadRadius: 2,
                          blurRadius: 5,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: context.responsivePadding,
                      child: SvgPicture.asset(
                        'assets/images/alive_logo.svg',
                        fit: BoxFit.contain,
                        colorFilter: ColorFilter.mode(
                          Theme.of(context).colorScheme.primary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: context.responsivePadding.top),
                  Text(
                    t('ALIVE NG'),
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  SizedBox(height: context.responsivePadding.top / 2),
                  Text(
                    t('app_tagline'),
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: context.responsivePadding.top * 1.5),

            // Mission Section
            _buildSection(
              context,
              'Our Mission',
              'To reach every soul with the Gospel of Jesus Christ and train them to become effective disciples.',
            ),

            // Vision Section
            _buildSection(
              context,
              'Our Vision',
              'A Nigeria where every person has heard the Gospel and has the opportunity to accept Jesus Christ as their personal Savior.',
            ),

            // Why Join Us Section
            _buildSection(
              context,
              'Why Join Us',
              'Join a community of believers committed to spiritual growth, evangelism, and making a lasting impact for Christ in Nigeria and beyond.',
            ),

            // Leadership Section
            Text(
              'Leadership Team',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: context.responsivePadding.top),

            _buildLeaderCard(
              context,
              'Nwoko Patience Mfon',
              'Executive President',
              Icons.person,
            ),

            _buildLeaderCard(
              context,
              'Caleb Peters',
              'Secretary/Communication Director',
              Icons.chat,
            ),

            _buildLeaderCard(
              context,
              'Godstime Esuku',
              'Speaker / Director: ALIVE Mission Training Center (AMTC)',
              Icons.school,
            ),

            _buildLeaderCard(
              context,
              'Timothy Olodude',
              'Treasure / Director of Logistics',
              Icons.account_balance_wallet,
            ),

            _buildLeaderCard(
              context,
              'Emenike Ekechi',
              'Director: Evangelism/Programming/Health',
              Icons.health_and_safety,
            ),

            SizedBox(height: context.responsivePadding.top * 1.5),

            // Contact Section
            Text(
              'Contact Us',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            SizedBox(height: context.responsivePadding.top),

            Card(
              elevation: 4,
              margin: context.responsiveMargin,
              child: Padding(
                padding: context.responsivePadding,
                child: Column(
                  children: [
                    InkWell(
                      onTap: () => _launchEmail('alivenigeria2011@gmail.com'),
                      child: Row(
                        children: [
                          Icon(
                            Icons.email,
                            color: Theme.of(context).colorScheme.primary,
                            size: context.responsiveIconSize(24),
                          ),
                          SizedBox(width: context.responsivePadding.left / 2),
                          Expanded(
                            child: Text(
                              'alivenigeria2011@gmail.com',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: context.responsivePadding.top / 2),
                    InkWell(
                      onTap: () => _launchPhone('+2347068548865'),
                      child: Row(
                        children: [
                          Icon(
                            Icons.phone,
                            color: Theme.of(context).colorScheme.primary,
                            size: context.responsiveIconSize(24),
                          ),
                          SizedBox(width: context.responsivePadding.left / 2),
                          Text(
                            '+2347068548865',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
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

            // Developer attribution removed per request
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(height: context.responsivePadding.top / 2),
        Text(
          content,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            height: 1.6,
          ),
          textAlign: TextAlign.justify,
        ),
        SizedBox(height: context.responsivePadding.top * 1.5),
      ],
    );
  }

  Widget _buildLeaderCard(BuildContext context, String name, String position, IconData icon) {
    return Card(
      margin: EdgeInsets.only(bottom: context.responsivePadding.top / 2),
      child: ListTile(
        contentPadding: context.responsivePadding,
        leading: CircleAvatar(
          radius: ResponsiveUtils.getResponsiveValue(
            context: context,
            mobile: 20.0,
            tablet: 24.0,
            desktop: 28.0,
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.onPrimary,
            size: context.responsiveIconSize(20),
          ),
        ),
        title: Text(
          name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Text(
          position,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ALIVE Nigeria Inquiry',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  void _launchPhone(String phone) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }
}




