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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('help_support'),
        showBackButton: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.onPrimary,
          labelColor: Theme.of(context).colorScheme.onPrimary,
          unselectedLabelColor: Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7),
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

    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        // Search Bar
        Container(
          margin: EdgeInsets.only(
              bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          child: TextField(
            decoration: InputDecoration(
              hintText: translate('search_faq'),
              prefixIcon: const Icon(Icons.search),
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
        ...faqs.map((faq) => _buildFAQItem(context, faq)),
      ],
    );
  }

  Widget _buildFAQCategories(BuildContext context,
      String Function(String) translate, List<FAQItem> faqs) {
    final categories = faqs.map((faq) => faq.category).toSet().toList();

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
              selected: false,
              onSelected: (selected) {
                // Filter FAQs by category
              },
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
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        subtitle: Text(
          faq.category,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 12),
              ),
        ),
        children: [
          Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Text(
              faq.answer,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
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
        title: translate('getting_started'),
        description: translate('getting_started_desc'),
        icon: Icons.play_circle_outline,
        color: Colors.green,
      ),
      GuideItem(
        title: translate('using_prayer_wall'),
        description: translate('prayer_wall_guide_desc'),
        icon: Icons.favorite_outline,
        color: Colors.purple,
      ),
      GuideItem(
        title: translate('study_guides_tutorial'),
        description: translate('study_guides_desc'),
        icon: Icons.book_outlined,
        color: Colors.blue,
      ),
      GuideItem(
        title: translate('health_tracking_guide'),
        description: translate('health_tracking_desc'),
        icon: Icons.health_and_safety_outlined,
        color: Colors.orange,
      ),
      GuideItem(
        title: translate('chapter_management'),
        description: translate('chapter_management_desc'),
        icon: Icons.group_outlined,
        color: Colors.teal,
      ),
      GuideItem(
        title: translate('notification_settings'),
        description: translate('notification_settings_desc'),
        icon: Icons.notifications_outlined,
        color: Colors.indigo,
      ),
    ];

    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        Text(
          translate('user_guides'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
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
          backgroundColor: guide.color.withValues(alpha: 0.1),
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
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        subtitle: Text(
          guide.description,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
              ),
        ),
        trailing: Icon(
          Icons.arrow_forward_ios,
          size: ResponsiveUtils.getResponsiveIconSize(context, 16),
        ),
        onTap: () {
          _showGuideDialog(context, guide);
        },
      ),
    );
  }

  Widget _buildContactTab(
      BuildContext context, String Function(String) translate) {
    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        // Contact Header
        Container(
          width: double.infinity,
          padding: ResponsiveUtils.getResponsivePadding(context),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
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
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 20),
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                translate('contact_us_message'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 14),
                    ),
              ),
            ],
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 24)),
        // Contact Methods
        _buildContactMethod(
          context,
          Icons.email_outlined,
          translate('email'),
          'alivenigeria2011@gmail.com',
          () => _launchEmail('alivenigeria2011@gmail.com'),
        ),
        _buildContactMethod(
          context,
          Icons.phone_outlined,
          translate('phone'),
          '+2347068548865',
          () => _launchPhone('+2347068548865'),
        ),
        _buildContactMethod(
          context,
          Icons.web_outlined,
          translate('website'),
          'www.alivenigeria.org',
          () => _launchWebsite('https://www.alivenigeria.org'),
        ),
        _buildContactMethod(
          context,
          Icons.location_on_outlined,
          translate('address'),
          'ALIVE Nigeria Headquarters',
          () => _showAddressDialog(context),
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
                        fontSize:
                            ResponsiveUtils.getResponsiveFontSize(context, 16),
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

  Widget _buildContactMethod(BuildContext context, IconData icon, String title,
      String subtitle, VoidCallback onTap) {
    return CustomCard(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
          child: Icon(
            icon,
            color: Theme.of(context).colorScheme.primary,
            size: ResponsiveUtils.getResponsiveIconSize(context, 24),
          ),
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
              ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
              ),
        ),
        trailing: Icon(
          Icons.launch,
          size: ResponsiveUtils.getResponsiveIconSize(context, 20),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildOfficeHour(BuildContext context, String day, String hours) {
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: ResponsiveUtils.getResponsiveSpacing(context, 4)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                ),
          ),
          Text(
            hours,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 14),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackTab(
      BuildContext context, String Function(String) translate) {
    final feedbackController = TextEditingController();
    final emailController = TextEditingController();
    String selectedFeedbackType = 'General';

    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        Text(
          translate('send_feedback'),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
              ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        // Feedback Type
        DropdownButtonFormField<String>(
          initialValue: selectedFeedbackType,
          decoration: InputDecoration(
            labelText: translate('feedback_type'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: [
            'General',
            'Bug Report',
            'Feature Request',
            'Improvement Suggestion',
            'Complaint',
          ]
              .map((type) => DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  ))
              .toList(),
          onChanged: (value) {
            setState(() {
              selectedFeedbackType = value!;
            });
          },
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        // Email Field
        TextField(
          controller: emailController,
          decoration: InputDecoration(
            labelText: translate('email_optional'),
            hintText: translate('enter_email'),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.emailAddress,
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        // Feedback Message
        TextField(
          controller: feedbackController,
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
            onPressed: () => _submitFeedback(context, feedbackController.text,
                emailController.text, selectedFeedbackType),
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
              style: TextStyle(
                fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showGuideDialog(BuildContext context, GuideItem guide) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(guide.title),
        content: Text(guide.description),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
                // Navigate to specific guide or tutorial
              }
            },
            child: const Text('View Guide'),
          ),
        ],
      ),
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
            Text('Thank you for your feedback! We will review it shortly.'),
        backgroundColor: Theme.of(context).colorScheme.tertiary,
      ),
    );

    // Clear the form
    setState(() {
      // Reset controllers would go here
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

  GuideItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
