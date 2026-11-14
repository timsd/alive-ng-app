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
      // 1. General & Chapters
      FAQItem(
        question: 'How do I join or transfer to a local ALIVE chapter?',
        answer:
            'Navigate to the "Chapters" section on the Home screen or More menu. Browse the directory of university and state chapters across Nigeria, and tap "Join Chapter". If you relocate or transfer chapters, you can update your primary chapter anytime from your Profile screen.',
        category: 'General',
      ),
      FAQItem(
        question: 'Does ALIVE Nigeria work offline without internet?',
        answer:
            'Yes! The Bible reader, downloaded gospel tracts, cached audio podcasts, study guides, and saved Health+ recipes work seamlessly offline. When an internet connection is re-established, your study achievements, quiz scores, and prayer logs synchronize automatically with the cloud.',
        category: 'General',
      ),
      FAQItem(
        question: 'What do the different user roles mean in the app?',
        answer:
            'User roles reflect ministry assignments: Member (fellowship and general participation), Chapter Leader / Worker (coordinating local chapter activities), Coordinator (regional/functional discipleship lead), Director (national and departmental leadership), and Board of Trustees (governance & board administration).',
        category: 'General',
      ),

      // 2. Conferencing (ALIVE Meet)
      FAQItem(
        question: 'How do I join or start a meeting on ALIVE Meet?',
        answer:
            'Tap "ALIVE Meet" from the Home quick actions, drawer, or open a shared meeting link. Enter the room code or title, test your camera and microphone in the pre-join lobby, and tap "Join Meeting". Hosts can initiate secure plenary meetings with one tap.',
        category: 'Conferencing',
      ),
      FAQItem(
        question: 'How does the Waiting Room work in ALIVE Meet?',
        answer:
            'When a meeting host enables the Waiting Room in meeting settings, new attendees wait in a secure lobby until admitted by the meeting host or co-host. This provides security and order for committee and leadership discussions.',
        category: 'Conferencing',
      ),
      FAQItem(
        question: 'How do I switch between Gallery View and List View on ALIVE Meet?',
        answer:
            'Tap the "Gallery" or "List View" icon on the bottom control bar to toggle views. Gallery View arranges active video streams in an interactive video tile grid, while List View displays presentations, screen shares, and detailed participant status.',
        category: 'Conferencing',
      ),
      FAQItem(
        question: 'Can I share my screen and record meeting minutes?',
        answer:
            'Yes! Hosts and permitted attendees can tap "Share" to broadcast presentations. During leadership and Board meetings, ALIVE Scribe automatically captures notes and minutes, auto-saving documents directly to Meeting File Sharing.',
        category: 'Conferencing',
      ),

      // 3. Prayer & Testimonies
      FAQItem(
        question: 'Where do my prayer requests go, and who can see them?',
        answer:
            'Public prayer requests appear on the community Prayer Wall where members nationwide can intercede for you. You can also submit requests anonymously. Requests created within Private Prayer Rooms are strictly restricted to authorized room members.',
        category: 'Prayer',
      ),
      FAQItem(
        question: 'When a prayer is answered, where does it go?',
        answer:
            'When you tap "Mark as Answered", you can write a praise testimony celebrating God\'s faithfulness. Answered prayers move into the dedicated "Answered" tab on the Prayer Wall and the Discipleship Tracker with a green praise badge so all brethren can rejoice with you.',
        category: 'Prayer',
      ),
      FAQItem(
        question: 'What are Private Prayer Rooms and how do I access them?',
        answer:
            'Private Prayer Rooms are confidential intercession chambers designed for specialized pastoral care, leadership teams, and chapter prayer bands. They are protected with role-based permissions or secret room access tokens.',
        category: 'Prayer',
      ),
      FAQItem(
        question: 'How does the intercession counter ("I Prayed for This") work?',
        answer:
            'When you tap "Pray" on any prayer card, the intercession counter increments and the requester receives an encouraging notification that a brother or sister has prayed for their request.',
        category: 'Prayer',
      ),

      // 4. Discipleship Tracker
      FAQItem(
        question: 'What is the Discipleship Tracker and who is it for?',
        answer:
            'The Discipleship Tracker equips every Adventist young adult to mentor seekers and new believers. You can register contacts, track spiritual stages (Prospect, Contact, Discipleship, Baptized, Discipler), schedule Bible studies, log prayer points, and submit monthly discipleship reports.',
        category: 'Discipleship',
      ),
      FAQItem(
        question: 'How do I request deletion of a disciple contact?',
        answer:
            'To ensure data integrity, disciple-makers can submit a deletion request with an explanatory note (e.g., contact relocated, duplicate entry). Coordinators and Directors review and approve or reject these requests in the Discipleship Operations Hub.',
        category: 'Discipleship',
      ),

      // 5. Study, Bible & Tracts
      FAQItem(
        question: 'What Bible versions and indigenous translations are available?',
        answer:
            'The Bible Reader includes King James Version (KJV), New King James (NKJV), New International Version (NIV), American Standard Version (ASV), and complete Nigerian indigenous translations: Yoruba (Bibeli Mimo), Igbo (Bible Nso), and Hausa (Littafi Mai Tsarki).',
        category: 'Study',
      ),
      FAQItem(
        question: 'How do I play the Instant Word Memory Game?',
        answer:
            'Select either Fill-in-the-Gaps (typing missing scripture words) or Voice Recitation (reciting the verse aloud from memory using speech recognition). You earn points, daily streaks, and achievement badges as you master verses.',
        category: 'Study',
      ),
      FAQItem(
        question: 'Can I download gospel tracts and share them?',
        answer:
            'Yes! Gospel tracts can be read interactively with reflection questions, downloaded as full-color high-resolution PDFs for print outreach, or shared as digital links with friends on WhatsApp and social media.',
        category: 'Study',
      ),
      FAQItem(
        question: 'How do Interactive Lessons work?',
        answer:
            'Interactive Lessons guide you through structured, topic-by-topic doctrinal and devotional studies. You answer reflection questions at the end of each section, track chapter completion, and earn study milestone badges.',
        category: 'Study',
      ),

      // 6. Health+
      FAQItem(
        question: 'What is Health+ and are all recipes plant-based?',
        answer:
            'Health+ promotes total wellness through wholesome 100% plant-based recipes crafted from authentic Nigerian produce (beans, grains, tubers, indigenous vegetables), alongside natural therapeutic remedies for common conditions.',
        category: 'Health',
      ),
      FAQItem(
        question: 'Can I submit my own healthy recipes?',
        answer:
            'Yes! Tap "Submit Recipe" in the Health+ area to contribute your favorite plant-based dish. Once reviewed by the Health Ministries team, your recipe will be published to the entire community.',
        category: 'Health',
      ),

      // 7. Giving & Financial Support
      FAQItem(
        question: 'Is giving on the ALIVE Nigeria app secure?',
        answer:
            'All donations are processed securely through certified, bank-grade Paystack gateways supporting debit cards, bank transfers, and USSD. Your payment information is never stored on the device or application servers.',
        category: 'Giving',
      ),
      FAQItem(
        question: 'Can I split my donation across multiple ministry projects?',
        answer:
            'Yes! You can designate your gift to General Ministry, Tracts & Literature, Missions, or Campus Outreaches, or specify custom percentage splits across projects on the Donation screen.',
        category: 'Giving',
      ),
      FAQItem(
        question: 'How do I donate non-monetary items (vehicles, equipment, books)?',
        answer:
            'Tap "Non-Monetary Gifts" on the Donation screen to submit details of physical equipment, vehicles, books, or property you wish to consecrate for missionary service. The administrative team will contact you to coordinate delivery.',
        category: 'Giving',
      ),

      // 8. Account & Settings
      FAQItem(
        question: 'How do I reset my password?',
        answer:
            'On the sign-in screen, tap "Forgot Password" and enter your registered email address. You will receive a secure password reset link to create a new password.',
        category: 'Account',
      ),
      FAQItem(
        question: 'How do I change the app language?',
        answer:
            'Tap the language translation icon in the top app bar or visit Settings to toggle between English, Yoruba, Igbo, and Hausa.',
        category: 'Settings',
      ),
      FAQItem(
        question: 'How do I customize my notification preferences?',
        answer:
            'Go to Profile > Notification Settings to toggle push alerts for daily verses, chapter broadcasts, prayer wall updates, meeting reminders, and monthly support reminders.',
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
        title: 'ALIVE Meet: Video Conferencing & Breakout Rooms',
        description:
            'Join, host, and collaborate in secure plenary meetings and breakout sessions.',
        icon: Icons.video_camera_front_rounded,
        color: const Color(0xFF2563EB),
        steps: [
          'Open ALIVE Meet from the Home quick actions, drawer, or tap a shared meeting link.',
          'Enter the meeting title or room code, and configure your camera and microphone in the pre-join lobby.',
          'If the host enabled the Waiting Room, relax while the host or co-host admits you into the session.',
          'Use the docked control bar to toggle audio/video, share your screen, raise your hand, or open in-meeting chat.',
          'Tap "Gallery" to see an interactive video tile grid of all participants, or "List View" for screen presentations.',
          'Participate in assigned Breakout Rooms for focused committee discussions or prayer bands.',
          'Meeting hosts can trigger ALIVE Scribe to automatically transcribe notes, record minutes, and sync files to cloud storage.',
        ],
      ),
      GuideItem(
        title: 'Discipleship Tracker: Mentoring & Milestones',
        description:
            'Track seeker contacts, Bible study progress, interactions, and monthly officer reports.',
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF0D9488),
        steps: [
          'Access the Discipleship Tracker from the Home screen or navigation menu.',
          'Tap "+" to register a new seeker or contact with initial spiritual details and level.',
          'Guide contacts through progressive stages: Prospect -> Contact -> Discipleship -> Baptized -> Discipler.',
          'Tap a contact card to log personal interactions (phone calls, in-person visits, prayer sessions) with notes and duration.',
          'Record Bible study sessions with ratings, lesson topics, and completion status.',
          'Maintain personal prayer requests for each contact, and celebrate God\'s answers in the "Answered" tab.',
          'Officers and coordinators can generate and dispatch monthly discipleship reports directly to regional leadership.',
        ],
      ),
      GuideItem(
        title: 'Prayer Wall, Private Rooms & Testimonies',
        description:
            'Share public or anonymous prayer requests, intercede for others, and celebrate praise reports.',
        icon: Icons.volunteer_activism_rounded,
        color: const Color(0xFFE11D48),
        steps: [
          'Open Prayer from the navigation bar or home screen to access the Prayer Wall.',
          'Tap "New Prayer" to submit a request. Choose between public posting or anonymous submission.',
          'Intercede for brethren by tapping "Pray" on any prayer card to increment the community prayer count.',
          'Access confidential Private Prayer Rooms with your credentials or room token for dedicated pastoral intercession.',
          'When God answers your prayer, tap "Mark Answered" on your card to share your testimony and date of breakthrough.',
          'Switch to the "Answered" tab on the Prayer Wall to rejoice with brethren over all recorded testimonies.',
        ],
      ),
      GuideItem(
        title: 'Health+: Plant-Based Recipes & Natural Remedies',
        description:
            'Explore authentic Nigerian plant-based nutrition, cooking guides, and therapeutic lifestyle remedies.',
        icon: Icons.health_and_safety_rounded,
        color: const Color(0xFF16A34A),
        steps: [
          'Open Health+ from the bottom navigation bar or More menu.',
          'Browse 100% plant-based recipes crafted from accessible Nigerian ingredients with prep times and nutritional highlights.',
          'Tap on any recipe card to view step-by-step cooking instructions, ingredient lists, and bookmark for offline kitchen use.',
          'Explore the Natural Remedies tab for evidence-based lifestyle treatments and herbal therapies for common ailments.',
          'Tap "Submit Recipe" to share your favorite wholesome plant-based creation with the nationwide community.',
        ],
      ),
      GuideItem(
        title: 'Bible Reader & Indigenous Translations',
        description:
            'Read the Scriptures offline with KJV, NIV, ASV, and full Yoruba, Igbo, and Hausa translations.',
        icon: Icons.menu_book_rounded,
        color: const Color(0xFF8B5CF6),
        steps: [
          'Open the Bible Reader from the Study tab or Home quick actions.',
          'Tap the translation selector at the top to toggle between English (KJV, NIV, ASV, NASB, NKJV), Yoruba (Bibeli Mimo), Igbo (Bible Nso), or Hausa (Littafi Mai Tsarki).',
          'Swipe left or right or use the navigation buttons at the bottom to flip between chapters smoothly.',
          'Tap any verse to open options: highlight in custom colors, bookmark, copy, or share.',
          'Tap the Speaker icon on any chapter or verse to listen with built-in Text-To-Speech while on the move.',
        ],
      ),
      GuideItem(
        title: 'Instant Word Memory Game: Voice & Gaps',
        description:
            'Memorize scripture through interactive voice recitation and fill-in-the-gaps challenges.',
        icon: Icons.sports_esports_rounded,
        color: const Color(0xFFD97706),
        steps: [
          'Access the Bible Game under Study Guides or the Home quick action.',
          'Choose between Fill-in-the-Gaps or Voice Recitation mode.',
          'In Fill Gaps mode, type the missing scripture words into the blanks and tap Submit (up to 3 retries).',
          'In Voice mode, recite the verse aloud from memory using your device microphone; speech recognition validates your accuracy.',
          'Earn points, build daily streaks, and unlock achievement badges as you master scriptures.',
        ],
      ),
      GuideItem(
        title: 'Interactive Lessons & Audio Podcasts',
        description:
            'Topic-by-topic doctrinal Bible studies with reflection quizzes and streaming sermon podcasts.',
        icon: Icons.school_rounded,
        color: const Color(0xFF0284C7),
        steps: [
          'Open Interactive Lessons under the Study tab.',
          'Select a study track (Sanctuary, Prophecy, Stewardship, or Personal Evangelism).',
          'Read through each lesson module, answer interactive reflection questions, and review scriptural references.',
          'Track your track completion percentage and earn study completion badges.',
          'Switch to Podcasts to stream or download audio sermons, health lectures, and mission updates with background audio.',
        ],
      ),
      GuideItem(
        title: 'Gospel Tracts: Interactive Reader & Mission Print',
        description:
            'Read evangelistic literature interactively, answer reflection points, and download PDFs for print.',
        icon: Icons.library_books_rounded,
        color: const Color(0xFFEA580C),
        steps: [
          'Open Tracts from the Study menu or More drawer.',
          'Tap on any gospel tract to launch the interactive reader with reflection questions.',
          'Read page by page and type in answers to personal reflection questions.',
          'Tap the PDF icon at the top to view and download the full-color publication layout.',
          'Share softcopy links directly with seekers, or donate towards physical tract printing for campus and rural outreach.',
        ],
      ),
      GuideItem(
        title: 'Giving, Fund Split & Non-Monetary Gifts',
        description:
            'Support specific ministry funds via Paystack or donate physical items like books and vehicles.',
        icon: Icons.favorite_rounded,
        color: const Color(0xFF059669),
        steps: [
          'Open the Donate screen from the Home screen or navigation bar.',
          'Select your preferred fund designation (General Ministry, Tract Production, Missions, etc.) or specify custom split ratios.',
          'If donating physical assets (vehicles, laptops, books, medical tools), tap "Non-Monetary Gifts" to submit the donation form.',
          'Complete monetary donations securely via Paystack using debit card, bank transfer, or USSD.',
          'Review your personal giving history and track fund impact updates directly on the screen.',
        ],
      ),
      GuideItem(
        title: 'Chapter Community, Roles & Organization',
        description:
            'Connect with local chapter members, participate in group chats, and tag leadership.',
        icon: Icons.groups_2_rounded,
        color: const Color(0xFF4F46E5),
        steps: [
          'Navigate to Chapters to locate and join your nearest campus or city chapter.',
          'Participate in chapter group chats, receive official announcements, and pray together.',
          'Use role tags in discussions (@coordinator, @leadership) to direct urgent questions to officers.',
          'Chapter leaders and administrators can access Chapter Reports and leadership archives to manage organizational duties.',
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
    final theme = Theme.of(context);
    final rawDesc = translate('feedback_message_desc');
    final feedbackDesc = (rawDesc.isEmpty ||
            rawDesc.toLowerCase().contains('feedback message desc') ||
            rawDesc == 'feedback_message_desc')
        ? 'Share your thoughts, report a bug, or suggest a feature to help us improve.'
        : rawDesc;

    return LayoutFixUtils.safeColumn(
      padding: ResponsiveUtils.getResponsivePadding(context),
      children: [
        // Compact Horizontal Feedback Header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.feedback_outlined,
                  size: 24,
                  color: theme.colorScheme.tertiary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('we_value_feedback'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      feedbackDesc,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Feedback Type Selection
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            translate('feedback_type'),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFeedbackTypeChip(context, translate('general'), 'General'),
              _buildFeedbackTypeChip(
                  context, translate('bug_report'), 'Bug Report'),
              _buildFeedbackTypeChip(
                  context, translate('feature_request'), 'Feature Request'),
              _buildFeedbackTypeChip(context, translate('other'), 'Other'),
            ],
          ),
        ),
        const SizedBox(height: 16),
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
        return SafeArea(
          top: true,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 640,
                maxHeight: MediaQuery.of(ctx).size.height * 0.88,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 5,
                        margin: const EdgeInsets.only(top: 12, bottom: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  void _launchEmail(String email) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      query: 'subject=ALIVE Nigeria App Support',
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
        content: const Text(
            'Thank you for your feedback! We will review it shortly.'),
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
