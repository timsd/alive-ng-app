import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/language_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/custom_app_bar.dart';

class HelpSupportScreen extends ConsumerStatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  ConsumerState<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends ConsumerState<HelpSupportScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  String _selectedFeedbackType = 'General';

  final List<TextEditingController> _feedbackControllers = [
    TextEditingController(), // email
    TextEditingController(), // message
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    for (var controller in _feedbackControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: CustomAppBar(
        title: translate('help_support'),
        showBackButton: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onPrimary,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor:
              theme.colorScheme.onPrimary.withValues(alpha: 0.7),
          labelStyle: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: theme.textTheme.labelLarge,
          tabs: [
            Tab(
              icon: const Icon(Icons.help_outline),
              text: translate('faq'),
            ),
            Tab(
              icon: const Icon(Icons.book_outlined),
              text: translate('guides'),
            ),
            Tab(
              icon: const Icon(Icons.contact_support),
              text: translate('contact'),
            ),
            Tab(
              icon: const Icon(Icons.feedback_outlined),
              text: translate('feedback'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFAQTab(context, translate),
          _buildGuidesTab(context, translate),
          _buildContactTab(context, translate),
          _buildFeedbackTab(context, translate),
        ],
      ),
    );
  }

  Widget _buildFAQTab(BuildContext context, String Function(String) translate) {
    final faqs = [
      FAQItem(
        question: translate('how_to_join_chapter'),
        answer: translate('join_chapter_answer'),
        category: 'General',
      ),
      FAQItem(
        question: translate('how_to_submit_prayer_request'),
        answer: translate('prayer_request_answer'),
        category: 'Prayer',
      ),
      FAQItem(
        question: translate('how_to_access_study_materials'),
        answer: translate('study_materials_answer'),
        category: 'Study',
      ),
      FAQItem(
        question: translate('how_to_track_health'),
        answer: translate('health_tracking_answer'),
        category: 'Health',
      ),
      FAQItem(
        question: translate('how_to_reset_password'),
        answer: translate('reset_password_answer'),
        category: 'Account',
      ),
      FAQItem(
        question: translate('how_to_change_language'),
        answer: translate('change_language_answer'),
        category: 'Settings',
      ),
    ];

    var filteredFaqs = faqs.where((faq) {
      final matchesSearch = faq.question.toLowerCase().contains(_searchQuery) ||
          faq.answer.toLowerCase().contains(_searchQuery);
      final matchesCategory =
          _selectedCategory == 'All' || faq.category == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        // Search Bar
        Container(
          margin: EdgeInsets.only(
              bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: translate('search_faq'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: Theme.of(context).colorScheme.surface,
            ),
          ),
        ),
        // FAQ Categories
        _buildFAQCategories(context, translate, faqs),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        // FAQ List
        if (filteredFaqs.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(Icons.search_off,
                      size: 48, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text(translate('no_results_found'),
                      style: Theme.of(context).textTheme.bodyLarge),
                ],
              ),
            ),
          )
        else
          ...filteredFaqs.map((faq) => _buildFAQItem(context, faq)),
      ],
    );
  }

  Widget _buildFAQCategories(BuildContext context,
      String Function(String) translate, List<FAQItem> faqs) {
    final categories = ['All', ...faqs.map((faq) => faq.category).toSet()];

    return SizedBox(
      height: ResponsiveUtils.getResponsiveValue<double>(
        context: context,
        mobile: 50,
        tablet: 50 * 1.2,
        desktop: 50 * 1.4,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          return Container(
            margin: EdgeInsets.only(
                right: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            child: FilterChip(
              label: Text(category),
              selected: _selectedCategory == category,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              side: BorderSide(
                color: _selectedCategory == category
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFAQItem(BuildContext context, FAQItem faq) {
    return CustomCard(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: ExpansionTile(
        title: Text(
          faq.question,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          faq.category,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
        ),
        children: [
          Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Text(
              faq.answer,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuidesTab(
      BuildContext context, String Function(String) translate) {
    final guides = [
      GuideItem(
        title: 'Bible Reader & Offline Translations',
        description: 'Read the Bible offline with KJV, NIV, ASV, Yoruba, Igbo, and Hausa translations.',
        icon: Icons.menu_book_rounded,
        color: Theme.of(context).colorScheme.primary,
        steps: [
          'Open the Bible Reader from the Home quick actions or the navigation bar.',
          'Tap the language or translation selector at the top to switch between English (KJV, NIV, ASV, NASB, NKJV, NLT), Yoruba (BM), Igbo (IGBOB), or Hausa (HAU).',
          'Swipe left or right or use the navigation buttons at the bottom to flip between chapters.',
          'Tap any verse to open options: highlight in custom colors, bookmark, copy, or share.',
          'Tap the Speaker icon on any chapter or verse to listen with Text-To-Speech.',
        ],
      ),
      GuideItem(
        title: 'Instant Word Memory Game',
        description: 'Memorize scripture verses through Voice Recitation and Fill-in-the-Gaps modes.',
        icon: Icons.sports_esports_rounded,
        color: Theme.of(context).colorScheme.tertiary,
        steps: [
          'Access the Bible Game under Study Guides or the Home quick action.',
          'Choose Fill Gaps or Voice Recitation mode.',
          'In Fill Gaps mode, type the missing words into the input boxes and tap Submit. You have up to 3 retries.',
          'In Voice mode, recite the verse aloud from memory using the Record button. Tap the card to flip and view the verse (-2 points deduction warning).',
          'If you need assistance after 3 attempts, unlock the Hint button to receive guidance.',
        ],
      ),
      GuideItem(
        title: 'Prayer Wall & Community Support',
        description: 'Submit prayer requests, pray for others, and share praise testimonies.',
        icon: Icons.volunteer_activism_rounded,
        color: Theme.of(context).colorScheme.secondary,
        steps: [
          'Navigate to Prayer Requests from the More menu or Home actions.',
          'Tap the + button to create a new prayer request. You can choose to post publicly or anonymously.',
          'Browse community requests and tap "I Prayed for This" to encourage your brothers and sisters.',
          'When God answers your prayer, update the request with a Praise Report to testify to His goodness.',
        ],
      ),
      GuideItem(
        title: 'Books & Tracts Interactive Reader',
        description: 'Read Christian literature, answer reflection questions, and download PDFs.',
        icon: Icons.library_books_rounded,
        color: Colors.deepOrange,
        steps: [
          'Open Books & Tracts from the More tray or study area.',
          'Tap on any tract to launch the interactive reader.',
          'Read page by page and type in answers to personal reflection questions.',
          'Tap the PDF icon at the top to view the original publication.',
          'Tap Download to save the tract offline or donate towards physical tract printing and distribution.',
        ],
      ),
      GuideItem(
        title: 'Kids Mission & Interactive Stories',
        description: 'Exciting Bible adventures, quizzes, and mission challenges for children.',
        icon: Icons.child_care_rounded,
        color: Colors.teal,
        steps: [
          'Open Kids Mission from the More drawer.',
          'Choose a mission category (Bible Stories, Memory Verses, Hero Quizzes, or Daily Action).',
          'Read the colorful illustrated stories and complete the fun quiz at the end.',
          'Earn stars and unlock achievement badges as your child completes each adventure.',
        ],
      ),
      GuideItem(
        title: 'Giving & Non-Monetary Gifts',
        description: 'Support specific projects or donate non-monetary items like equipment or books.',
        icon: Icons.favorite_rounded,
        color: Colors.green,
        steps: [
          'Open the Donate screen from the Home screen or navigation bar.',
          'Select your preferred fund designation (General Ministry, Tract Production, Missions, etc.) or enter custom split ratios.',
          'If you are donating physical items (vehicles, books, computers, medical supplies), select "Non-Monetary Gifts" to submit the donation form.',
          'Complete your payment securely via Paystack using card, bank transfer, or USSD.',
        ],
      ),
    ];

    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        Text(
          translate('user_guides'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        ...guides.map((guide) => _buildGuideItem(context, guide)),
      ],
    );
  }

  Widget _buildGuideItem(BuildContext context, GuideItem guide) {
    return CustomCard(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: guide.color.withValues(alpha: 0.12),
          child: Icon(
            guide.icon,
            color: guide.color,
            size: ResponsiveUtils.getResponsiveIconSize(context, 24),
          ),
        ),
        title: Text(
          guide.title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          guide.description,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: ResponsiveUtils.getResponsiveIconSize(context, 16),
        ),
        onTap: () {
          _openGuideViewer(context, guide);
        },
      ),
    );
  }

  Widget _buildContactTab(
      BuildContext context, String Function(String) translate) {
    final theme = Theme.of(context);
    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        // Contact Header
        Container(
          width: double.infinity,
          padding: ResponsiveUtils.getResponsivePadding(context),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(
                Icons.support_agent,
                size: ResponsiveUtils.getResponsiveIconSize(context, 48),
                color: Theme.of(context).colorScheme.primary,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Text(
                translate('need_help'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                translate('contact_us_message'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
        // Single row of clickable contact icons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildContactIconCard(
              context,
              icon: Icons.email_rounded,
              title: 'Email',
              onTap: () => _launchEmail('app@alivenigeria.org'),
            ),
            _buildContactIconCard(
              context,
              icon: Icons.phone_rounded,
              title: 'Phone',
              onTap: () => _launchPhone('+2347068548865'),
            ),
            _buildContactIconCard(
              context,
              icon: Icons.language_rounded,
              title: 'Website',
              onTap: () => _launchWebsite('https://www.alivenigeria.org'),
            ),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
        // Office Hours
        CustomCard(
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  translate('office_hours'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                _buildOfficeHour(
                    context, translate('sunday_thursday'), '9:00 AM - 5:00 PM'),
                _buildOfficeHour(
                    context, translate('friday'), '9:00 AM - 2:00 PM'),
                _buildOfficeHour(
                    context, translate('saturday'), translate('closed')),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactIconCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
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
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    icon,
                    color: theme.colorScheme.primary,
                    size: 22,
                  ),
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

  Widget _buildOfficeHour(BuildContext context, String day, String hours) {
    return Padding(
      padding: EdgeInsets.symmetric(
        vertical: ResponsiveUtils.getResponsiveSpacing(context, 4),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(day, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            hours,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab(
      BuildContext context, String Function(String) translate) {
    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        // Feedback Header
        Container(
          width: double.infinity,
          padding: ResponsiveUtils.getResponsivePadding(context),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.tertiaryContainer,
                Theme.of(context).colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(
                Icons.feedback_outlined,
                size: ResponsiveUtils.getResponsiveIconSize(context, 48),
                color: Theme.of(context).colorScheme.tertiary,
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Text(
                translate('we_value_feedback'),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                translate('feedback_message_desc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
        // Feedback Type Selection
        Text(
          translate('feedback_type'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
        Wrap(
          spacing: ResponsiveUtils.getResponsiveSpacing(context, 8),
          children: [
            _buildFeedbackTypeChip(context, translate('general'), 'General'),
            _buildFeedbackTypeChip(
                context, translate('bug_report'), 'Bug Report'),
            _buildFeedbackTypeChip(
                context, translate('feature_request'), 'Feature Request'),
            _buildFeedbackTypeChip(context, translate('other'), 'Other'),
          ],
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),
        // Email Input
        TextField(
          controller: _feedbackControllers[0],
          decoration: InputDecoration(
            labelText: translate('your_email'),
            hintText: 'name@example.com',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        // Message Input
        TextField(
          controller: _feedbackControllers[1],
          decoration: InputDecoration(
            labelText: translate('feedback_message'),
            hintText: translate('describe_feedback'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          maxLines: 5,
          maxLength: 500,
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
        // Submit Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => _submitFeedback(
              context,
              _feedbackControllers[1].text,
              _feedbackControllers[0].text,
              _selectedFeedbackType,
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveSpacing(context, 16),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              translate('submit_feedback'),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 16),
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackTypeChip(
      BuildContext context, String label, String value) {
    final isSelected = _selectedFeedbackType == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedFeedbackType = value;
          });
        }
      },
    );
  }

  void _openGuideViewer(BuildContext context, GuideItem guide) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.92,
          minChildSize: 0.5,
          builder: (_, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: theme.scaffoldBackgroundColor,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: guide.color.withValues(alpha: 0.15),
                          radius: 24,
                          child: Icon(guide.icon, color: guide.color, size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                guide.title,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                guide.description,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(20),
                      itemCount: guide.steps.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (ctx, index) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant
                                  .withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: guide.color,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  guide.steps[index],
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddressDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ALIVE Nigeria Address'),
        content: const Text(
          'ALIVE Nigeria Headquarters\n'
          'Lagos, Nigeria\n\n'
          'For specific location details, please contact us via phone or email.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ALIVE NG App Support',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    }
  }

  Future<void> _launchPhone(String phone) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    }
  }

  Future<void> _launchWebsite(String url) async {
    final Uri webUri = Uri.parse(url);
    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    }
  }

  void _submitFeedback(
      BuildContext context, String message, String email, String type) {
    if (message.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your feedback message')),
      );
      return;
    }

    // Here you would typically send the feedback to your backend
    // For now, we'll just show a success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            const Text('Thank you for your feedback! We will review it shortly.'),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
      ),
    );

    // Clear the form
    for (var controller in _feedbackControllers) {
      controller.clear();
    }
    setState(() {
      _selectedFeedbackType = 'General';
    });
  }
}

class FAQItem {
  final String question;
  final String answer;
  final String category;

  FAQItem({
    required this.question,
    required this.answer,
    required this.category,
  });
}

class GuideItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final List<String> steps;

  GuideItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    this.steps = const [],
  });
}
