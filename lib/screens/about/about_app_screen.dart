import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/language_provider.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_card.dart';

class AboutAppScreen extends ConsumerWidget {
  const AboutAppScreen({super.key});

  String _formatVersionLabel(PackageInfo packageInfo) {
    final build = packageInfo.buildNumber.trim();
    if (build.isEmpty || build == '0') {
      return 'Version ${packageInfo.version}';
    }
    return 'Version ${packageInfo.version} • Build $build';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final horizontalPadding = ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      mobile: 16,
      tablet: 24,
      desktop: 32,
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: t('about_app'),
        showBackButton: true,
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              colorScheme.surface,
              theme.scaffoldBackgroundColor,
            ],
          ),
        ),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1080),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                32,
              ),
              children: [
                _HeroCard(
                  title: 'ALIVE-NG App',
                  subtitle: 'Bible study, prayer, and ministry community',
                  description:
                      'ALIVE-NG brings Bible study, prayer, resources, testimonies, podcasts, events, and discipleship tools into one clear experience for the ministry community.',
                  chips: const [
                    'Daily verse',
                    'Prayer support',
                    'Study tools',
                    'Resources',
                  ],
                  versionBuilder: FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      final versionText = snapshot.hasData
                          ? _formatVersionLabel(snapshot.data!)
                          : 'Version information loading...';
                      return _VersionBadge(text: versionText);
                    },
                  ),
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 760;
                    const children = [
                      _InfoBlock(
                        icon: Icons.auto_stories_rounded,
                        title: 'Why this app exists',
                        body:
                            'The app helps members and guests stay connected to ALIVE wherever they are. It makes it easier to learn, pray, listen, read, and participate without depending on one physical location.',
                      ),
                      _InfoBlock(
                        icon: Icons.groups_2_rounded,
                        title: 'Built for real ministry use',
                        body:
                            'From chapters and conference access to testimonies, donation, kids content, and support, the app is structured to serve both everyday spiritual habits and ministry coordination.',
                      ),
                    ];

                    if (!twoColumns) {
                      return Column(
                        children: children
                            .expand(
                                (child) => [child, const SizedBox(height: 16)])
                            .take(children.length * 2 - 1)
                            .toList(),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: children[0]),
                        const SizedBox(width: 16),
                        Expanded(child: children[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  'What you can do inside the app',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _FeatureTile(
                      icon: Icons.menu_book_rounded,
                      title: 'Study and read',
                      description:
                          'Open Bible content, follow study guides, and continue learning with a more focused reading flow.',
                    ),
                    _FeatureTile(
                      icon: Icons.favorite_rounded,
                      title: 'Pray and encourage',
                      description:
                          'Share prayer requests, pray with others, and keep the community spiritually connected.',
                    ),
                    _FeatureTile(
                      icon: Icons.mic_rounded,
                      title: 'Listen and grow',
                      description:
                          'Use podcasts, testimonies, and featured resources to keep spiritual growth active throughout the week.',
                    ),
                    _FeatureTile(
                      icon: Icons.event_available_rounded,
                      title: 'Stay connected',
                      description:
                          'Find conference access, chapter resources, support tools, and the latest ministry touchpoints in one place.',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomCard(
                  variant: CardVariant.filled,
                  borderRadius: BorderRadius.circular(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About this release',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'This app version focuses on keeping ALIVE members equipped with a simpler layout, stronger readability, and a cleaner experience across both light and dark themes.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 16),
                      FutureBuilder<PackageInfo>(
                        future: PackageInfo.fromPlatform(),
                        builder: (context, snapshot) {
                          final versionText = snapshot.hasData
                              ? _formatVersionLabel(snapshot.data!)
                              : 'Version information loading...';
                          return Row(
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                size: 18,
                                color: colorScheme.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                versionText,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CustomCard(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About the developer',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Timothy Olodude',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Treasurer / Director of Logistics',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Created by Timothy Olodude as his way to see the organization marching forward. For suggestions and feedback, please contact:',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Feedback and support',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'If you notice missing information, styling issues, or anything that should work better, you can reach the team directly.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      CustomButton(
                        text: 'Send Feedback',
                        icon: Icons.email_rounded,
                        isFullWidth: !isDark,
                        onPressed: () => _launchEmail('dammyolodude@gmail.com'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ALIVE Nigeria App Feedback',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.title,
    required this.subtitle,
    required this.description,
    required this.chips,
    this.versionBuilder,
  });

  final String title;
  final String subtitle;
  final String description;
  final List<String> chips;
  final Widget? versionBuilder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        gradient: isDark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF182238),
                  colorScheme.surface,
                ],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white,
                  Color(0xFFF7FAFC),
                ],
              ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.22)
                : colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 24,
            spreadRadius: -10,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: AppTheme.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                padding: const EdgeInsets.all(16),
                child: SvgPicture.asset(
                  'assets/images/alive_logo.svg',
                  colorFilter: ColorFilter.mode(
                    colorScheme.onPrimary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (versionBuilder != null) ...[
                const SizedBox(height: 12),
                versionBuilder!,
              ],
              const SizedBox(height: 12),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.65,
                ),
              ),
            ],
          );

          final chipsWrap = Wrap(
            spacing: 10,
            runSpacing: 10,
            children: chips
                .map(
                  (chip) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Text(
                      chip,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                )
                .toList(),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                chipsWrap,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 24),
              SizedBox(
                width: 260,
                child: chipsWrap,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: colorScheme.secondary.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.secondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return CustomCard(
      borderRadius: BorderRadius.circular(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tileWidth = ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      mobile: double.infinity,
      tablet: 320,
      desktop: 240,
    );

    return SizedBox(
      width: tileWidth,
      child: CustomCard(
        variant: CardVariant.outlined,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              color: colorScheme.primary,
              size: 24,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.55,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.7),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
