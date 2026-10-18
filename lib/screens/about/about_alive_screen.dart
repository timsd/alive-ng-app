import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/language_provider.dart';
import '../../config/org_structure.dart';
import '../../services/role_access_service.dart';
import '../../utils/app_theme.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_card.dart';

class AboutAliveScreen extends ConsumerWidget {
  const AboutAliveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    // Trustee names are for leaders and above only. Everyone else sees the
    // board as a single "Leadership team" row.
    final canSeeLeadership = RoleAccessService.instance.canAccessLeadership();
    final horizontalPadding = ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      mobile: 16,
      tablet: 24,
      desktop: 32,
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: t('about_alive'),
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
                _AliveHeroCard(
                  title: 'ALIVE Nigeria',
                  subtitle: t('app_tagline'),
                  description:
                      'A.L.I.V.E is an acronym for Africans Living In View of Eternity. ALIVE-Nigeria is the Nigerian chapter of this movement, committed to a Bible-based, youth-led revival across Africa.',
                ),
                const SizedBox(height: 20),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns = constraints.maxWidth >= 780;
                    final content = [
                      const _StatementCard(
                        title: 'Mission Statement',
                        icon: Icons.flag_rounded,
                        description:
                            'Our mission is to prepare Africa for the imminent return of Jesus Christ. Through biblical spiritual training and evangelistic efforts, we challenge African Seventh-day Adventist young adults to live with authentic biblical excellence, develop a missionary volunteer spirit, support missionary movements across Africa, and make meaningful impact in neglected areas.',
                      ),
                      const _StatementCard(
                        title: 'Vision Statement',
                        icon: Icons.visibility_rounded,
                        description:
                            'At ALIVE, our vision is to ignite and sustain a Bible-based, youth-led revival movement across the continent of Africa, empowering every Seventh-day Adventist young professional to become a dedicated missionary with a deep personal relationship with Jesus Christ and commitment to His Great Commission.',
                      ),
                    ];

                    if (!twoColumns) {
                      return Column(
                        children: content
                            .expand(
                                (child) => [child, const SizedBox(height: 16)])
                            .take(content.length * 2 - 1)
                            .toList(),
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: content[0]),
                        const SizedBox(width: 16),
                        Expanded(child: content[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
                CustomCard(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'About ALIVE',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'We are men, women, graduates, working professionals, and student volunteers whose hearts are burdened for spreading God\'s Word and works. ALIVE Nigeria exists to challenge and equip believers with tools for individual missionary work, spiritual growth, mentorship, and service.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.7,
                        ),
                      ),
                      const SizedBox(height: 14),
                      const _QuoteBlock(
                        text:
                            'The Lord has appointed the youth to be His helping hand. {ChS 30.1}',
                      ),
                      const SizedBox(height: 12),
                      const _QuoteBlock(
                        text:
                            'With such an army of workers as our youth, rightly trained, how soon the message of a crucified, risen, and soon-coming Saviour might be carried to the whole world. Education, p. 271. {ChS 30.2}',
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Join us today and let us take the good news of the Gospel to places where no one wants to go.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: colorScheme.primary,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'What ALIVE emphasizes',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _PillarCard(
                      icon: Icons.campaign_rounded,
                      title: 'Evangelism',
                      description:
                          'Taking the Gospel seriously and making outreach part of everyday ministry life.',
                    ),
                    _PillarCard(
                      icon: Icons.school_rounded,
                      title: 'Discipleship',
                      description:
                          'Helping people mature in Scripture, character, and practical obedience to Christ.',
                    ),
                    _PillarCard(
                      icon: Icons.volunteer_activism_rounded,
                      title: 'Prayer and care',
                      description:
                          'Supporting members spiritually while building a culture of intercession and encouragement.',
                    ),
                    _PillarCard(
                      icon: Icons.health_and_safety_rounded,
                      title: 'Wholesome living',
                      description:
                          'Promoting healthy, balanced living that reflects stewardship of body, mind, and mission.',
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                CustomCard(
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Leadership team',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 18),
                      // ── Executive & Directors ──────────────────────────────
                      Text(
                        'Executive & Directors',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...leadershipPeople
                          .where((p) => !p.isRestricted)
                          .map(
                        (person) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LeaderTile(
                            name: person.name,
                            role: person.offices
                                .map((o) => o.title)
                                .join(' • '),
                            icon: _officeIcon(
                              person.offices.first.iconName,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 24),
                      const SizedBox(height: 8),
                      // ── Board of Trustees ─────────────────────────────────
                      Text(
                        'Board of Trustees',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'The Board of Trustees provides governance, spiritual counsel, and oversight.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (canSeeLeadership)
                        ...leadershipPeople
                            .where((p) => p.isRestricted)
                            .map(
                          (person) => Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LeaderTile(
                              name: person.name,
                              role: person.offices
                                  .map((o) => o.title)
                                  .join(' • '),
                              icon: _officeIcon(
                                person.isBoardChair
                                    ? 'shield'
                                    : person.offices.first.iconName,
                              ),
                            ),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _LeaderTile(
                            name: 'Leadership team',
                            role: 'Board of Trustees',
                            icon: _officeIcon('shield'),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                CustomCard(
                  variant: CardVariant.filled,
                  borderRadius: BorderRadius.circular(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'How the app supports the ministry',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'The ALIVE Nigeria app extends the ministry beyond physical gatherings. It helps members access study materials, testimonies, events, prayer support, donation options, conference participation, and resources from one organized place.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.65,
                        ),
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
                        'Contact ALIVE Nigeria',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildAliveContactIcon(
                            context,
                            icon: Icons.email_rounded,
                            title: 'Email',
                            onTap: () =>
                                _launchEmail('alivenigeria2011@gmail.com'),
                          ),
                          _buildAliveContactIcon(
                            context,
                            icon: Icons.phone_rounded,
                            title: 'Phone',
                            onTap: () => _launchPhone('+2347068548865'),
                          ),
                          _buildAliveContactIcon(
                            context,
                            icon: Icons.public_rounded,
                            title: 'Website',
                            onTap: () =>
                                _launchWebsite('https://alivenigeria.org'),
                          ),
                        ],
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

  Widget _buildAliveContactIcon(
    BuildContext context, {
    required IconData icon,
    required String title,
    String subtitle = '',
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(icon, color: theme.colorScheme.primary, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
      query: 'subject=ALIVE Nigeria Inquiry',
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final phoneUri = Uri(
      scheme: 'tel',
      path: phone,
    );

    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _launchWebsite(String url) async {
    final websiteUri = Uri.parse(url);
    if (await canLaunchUrl(websiteUri)) {
      await launchUrl(websiteUri, mode: LaunchMode.externalApplication);
    }
  }
}

class _AliveHeroCard extends StatelessWidget {
  const _AliveHeroCard({
    required this.title,
    required this.subtitle,
    required this.description,
  });

  final String title;
  final String subtitle;
  final String description;

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
                  Color(0xFFFFFFFF),
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
          final stacked = constraints.maxWidth < 700;
          final intro = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 78,
                height: 78,
                decoration: BoxDecoration(
                  gradient: AppTheme.getPrimaryGradient(context),
                  borderRadius: BorderRadius.circular(22),
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
              const SizedBox(height: 14),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.65,
                ),
              ),
            ],
          );

          final sideCard = Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Core heartbeat',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                const _MiniPoint(text: 'Gospel-centered witness'),
                const _MiniPoint(text: 'Prayerful community life'),
                const _MiniPoint(text: 'Training for mission'),
                const _MiniPoint(text: 'Healthy Christian living'),
              ],
            ),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                intro,
                const SizedBox(height: 18),
                sideCard,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: intro),
              const SizedBox(width: 24),
              SizedBox(
                width: 280,
                child: sideCard,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatementCard extends StatelessWidget {
  const _StatementCard({
    required this.title,
    required this.icon,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String description;

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
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillarCard extends StatelessWidget {
  const _PillarCard({
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
    final width = ResponsiveUtils.getResponsiveValue<double>(
      context: context,
      mobile: double.infinity,
      tablet: 320,
      desktop: 240,
    );

    return SizedBox(
      width: width,
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
                color: colorScheme.onSurfaceVariant,
                height: 1.55,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Maps an office's icon key from `kOrgOffices` to a Material icon.
///
/// The registry stores a string rather than an `IconData` so it can be mirrored
/// into the `org_offices` table by scripts/seed_org_offices.mjs without
/// dragging a Flutter dependency into Node.
IconData _officeIcon(String name) {
  switch (name) {
    case 'shield':
      return Icons.shield_rounded;
    case 'verified_user':
      return Icons.verified_user_rounded;
    case 'person':
      return Icons.person_rounded;
    case 'description':
      return Icons.description_rounded;
    case 'chat':
      return Icons.chat_rounded;
    case 'record_voice_over':
      return Icons.record_voice_over_rounded;
    case 'school':
      return Icons.school_rounded;
    case 'account_balance_wallet':
      return Icons.account_balance_wallet_rounded;
    case 'local_shipping':
      return Icons.local_shipping_rounded;
    case 'campaign':
      return Icons.campaign_rounded;
    case 'event_note':
      return Icons.event_note_rounded;
    case 'health_and_safety':
      return Icons.health_and_safety_rounded;
    default:
      return Icons.badge_rounded;
  }
}

class _LeaderTile extends StatelessWidget {
  const _LeaderTile({
    required this.name,
    required this.role,
    required this.icon,
  });

  final String name;
  final String role;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.outline.withValues(alpha: 0.7),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
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
                  name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPoint extends StatelessWidget {
  const _MiniPoint({
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(
              Icons.circle,
              size: 8,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuoteBlock extends StatelessWidget {
  const _QuoteBlock({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: colorScheme.onSurface,
          height: 1.65,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
