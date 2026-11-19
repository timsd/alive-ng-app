import 'app_constants.dart';

/// Metadata for a navigable in-app route exposed to admins in route pickers
/// (e.g. Push Notification target routes and Announcement action buttons).
class AppRouteOption {
  final String path;
  final String label;
  final String category;
  final List<String> keywords;

  const AppRouteOption({
    required this.path,
    required this.label,
    required this.category,
    this.keywords = const [],
  });

  bool matches(String rawQuery) {
    final q = rawQuery.trim().toLowerCase();
    if (q.isEmpty || q == '/') return true;
    final cleanQ = q.startsWith('/') ? q.substring(1) : q;

    if (path.toLowerCase().contains(q) || path.toLowerCase().contains(cleanQ)) {
      return true;
    }
    if (label.toLowerCase().contains(cleanQ)) return true;
    if (category.toLowerCase().contains(cleanQ)) return true;
    for (final kw in keywords) {
      if (kw.toLowerCase().contains(cleanQ)) return true;
    }
    return false;
  }
}

/// Authoritative catalog of user-navigable and admin-navigable GoRouter paths.
/// Keep in sync with `lib/utils/app_router.dart`.
class AppRoutesCatalog {
  AppRoutesCatalog._();

  static const List<AppRouteOption> allRoutes = [
    // Core & News Feed
    AppRouteOption(
      path: AppConstants.homeRoute,
      label: 'Home Dashboard',
      category: 'Core',
      keywords: ['dashboard', 'main', 'start'],
    ),
    AppRouteOption(
      path: AppConstants.announcementsRoute,
      label: 'Announcements (News Feed)',
      category: 'News & Events',
      keywords: ['announcement', 'broadcast', 'news', 'feed', 'updates', 'notice'],
    ),
    AppRouteOption(
      path: AppConstants.eventsRoute,
      label: 'Events & Calendar',
      category: 'News & Events',
      keywords: ['calendar', 'retreat', 'program', 'news', 'feed'],
    ),
    AppRouteOption(
      path: AppConstants.dailyRoute,
      label: 'Daily Verse & Devotion',
      category: 'Study & Bible',
      keywords: ['devotional', 'verse', 'quiet time', 'morning'],
    ),

    // Study, Bible & Resources
    AppRouteOption(
      path: AppConstants.studyRoute,
      label: 'Bible Study',
      category: 'Study & Bible',
      keywords: ['lessons', 'scripture', 'learn'],
    ),
    AppRouteOption(
      path: AppConstants.studyGuideRoute,
      label: 'Study Guides',
      category: 'Study & Bible',
      keywords: ['guide', 'sabbath school', 'lessons'],
    ),
    AppRouteOption(
      path: AppConstants.bibleRoute,
      label: 'Bible Reader',
      category: 'Study & Bible',
      keywords: ['scripture', 'read', 'kjv', 'nkjv', 'chapters'],
    ),
    AppRouteOption(
      path: AppConstants.bibleGameRoute,
      label: 'Bible Memory Game',
      category: 'Study & Bible',
      keywords: ['quiz', 'memorize', 'game', 'verse'],
    ),
    AppRouteOption(
      path: AppConstants.interactiveLessonsRoute,
      label: 'Interactive Lessons',
      category: 'Study & Bible',
      keywords: ['lessons', 'discipleship', 'course', 'study'],
    ),
    AppRouteOption(
      path: AppConstants.tractsRoute,
      label: 'Books & Gospel Tracts',
      category: 'Study & Bible',
      keywords: ['books', 'tracts', 'evangelism', 'reading', 'pdf'],
    ),
    AppRouteOption(
      path: AppConstants.podcastsRoute,
      label: 'Podcasts & Audio',
      category: 'Study & Bible',
      keywords: ['audio', 'sermons', 'episodes', 'listen'],
    ),
    AppRouteOption(
      path: AppConstants.libraryRoute,
      label: 'Resource Library',
      category: 'Study & Bible',
      keywords: ['books', 'media', 'resources', 'documents'],
    ),

    // Prayer & Community
    AppRouteOption(
      path: AppConstants.prayerRoute,
      label: 'Prayer Hub',
      category: 'Prayer & Community',
      keywords: ['intercession', 'pray'],
    ),
    AppRouteOption(
      path: AppConstants.prayerWallRoute,
      label: 'Prayer Wall & Requests',
      category: 'Prayer & Community',
      keywords: ['prayer-requests', 'requests', 'intercede', 'wall'],
    ),
    AppRouteOption(
      path: AppConstants.privatePrayerRoomRoute,
      label: 'Private Prayer Room',
      category: 'Prayer & Community',
      keywords: ['closet', 'personal prayer', 'journal'],
    ),
    AppRouteOption(
      path: AppConstants.missionsRoute,
      label: 'Missions & Outreach',
      category: 'Prayer & Community',
      keywords: ['evangelism', 'outreach', 'field', 'mission'],
    ),
    AppRouteOption(
      path: AppConstants.discipleshipTrackerRoute,
      label: 'Discipleship Tracker',
      category: 'Prayer & Community',
      keywords: ['discipleship', 'mentorship', 'follow up', 'contacts'],
    ),
    AppRouteOption(
      path: AppConstants.chaptersRoute,
      label: 'ALIVE Chapters',
      category: 'Prayer & Community',
      keywords: ['campus', 'chapters', 'fellowship', 'branches'],
    ),
    AppRouteOption(
      path: AppConstants.chatRoute,
      label: 'Community Chat',
      category: 'Prayer & Community',
      keywords: ['messages', 'channels', 'forum', 'discuss'],
    ),
    AppRouteOption(
      path: AppConstants.conferenceRoute,
      label: 'ALIVE Meet & Conference',
      category: 'Prayer & Community',
      keywords: ['meeting', 'video', 'live', 'zoom', 'call'],
    ),
    AppRouteOption(
      path: AppConstants.meetRoute,
      label: 'Join Live Meeting Room',
      category: 'Prayer & Community',
      keywords: ['meeting', 'call', 'livekit', 'room'],
    ),
    AppRouteOption(
      path: AppConstants.testimoniesRoute,
      label: 'Testimonies',
      category: 'Prayer & Community',
      keywords: ['stories', 'praise', 'witness'],
    ),

    // Health & Kids
    AppRouteOption(
      path: AppConstants.healthRoute,
      label: 'Health & Wellness',
      category: 'Health & Kids',
      keywords: ['wellness', 'newstart', 'medical', 'lifestyle'],
    ),
    AppRouteOption(
      path: AppConstants.enhancedHealthRoute,
      label: 'Health+ & Healthy Recipes',
      category: 'Health & Kids',
      keywords: ['recipes', 'plant-based', 'nutrition', 'health+'],
    ),
    AppRouteOption(
      path: AppConstants.recipeSubmissionRoute,
      label: 'Submit a Recipe',
      category: 'Health & Kids',
      keywords: ['recipe', 'food', 'submit', 'health'],
    ),
    AppRouteOption(
      path: AppConstants.kidsMissionRoute,
      label: 'Kids Mission',
      category: 'Health & Kids',
      keywords: ['children', 'kids', 'mission'],
    ),
    AppRouteOption(
      path: AppConstants.kidsStoriesRoute,
      label: 'Kids Stories',
      category: 'Health & Kids',
      keywords: ['children', 'kids', 'stories'],
    ),

    // Giving, Showcase & Info
    AppRouteOption(
      path: '/billboard',
      label: 'Impact Hub & 3D Billboard Showcase',
      category: 'Giving & Info',
      keywords: ['showcase', '3d', 'project', 'impact hub', 'building'],
    ),
    AppRouteOption(
      path: '/donate',
      label: 'Donate & Support Ministry',
      category: 'Giving & Info',
      keywords: ['donation', 'give', 'offering', 'paystack', 'support'],
    ),
    AppRouteOption(
      path: AppConstants.giftInKindRoute,
      label: 'Gift In Kind Form',
      category: 'Giving & Info',
      keywords: ['donate', 'items', 'gift', 'material'],
    ),
    AppRouteOption(
      path: AppConstants.nonMonetaryGiftRoute,
      label: 'Non-Monetary Gift Form',
      category: 'Giving & Info',
      keywords: ['volunteer', 'skills', 'gift', 'service'],
    ),
    AppRouteOption(
      path: '/achievements',
      label: 'Achievements & Badges',
      category: 'Account & Info',
      keywords: ['badges', 'streaks', 'milestones', 'rewards'],
    ),
    AppRouteOption(
      path: AppConstants.profileRoute,
      label: 'My Profile',
      category: 'Account & Info',
      keywords: ['account', 'user', 'settings'],
    ),
    AppRouteOption(
      path: AppConstants.notificationSettingsRoute,
      label: 'Notification Settings',
      category: 'Account & Info',
      keywords: ['alerts', 'push', 'reminders', 'preferences'],
    ),
    AppRouteOption(
      path: AppConstants.aboutAliveRoute,
      label: 'About ALIVE Nigeria',
      category: 'Account & Info',
      keywords: ['about', 'ministry', 'vision', 'mission'],
    ),
    AppRouteOption(
      path: AppConstants.aboutAppRoute,
      label: 'About This App',
      category: 'Account & Info',
      keywords: ['version', 'info', 'app'],
    ),
    AppRouteOption(
      path: AppConstants.helpSupportRoute,
      label: 'Help & Support',
      category: 'Account & Info',
      keywords: ['faq', 'contact', 'support', 'help'],
    ),

    // Leadership & Admin
    AppRouteOption(
      path: AppConstants.adminRoute,
      label: 'Admin Dashboard',
      category: 'Leadership & Admin',
      keywords: ['admin', 'panel', 'manage'],
    ),
    AppRouteOption(
      path: AppConstants.adminApprovalRoute,
      label: 'Admin Approvals',
      category: 'Leadership & Admin',
      keywords: ['approve', 'coordinators', 'pending', 'requests'],
    ),
    AppRouteOption(
      path: AppConstants.contentManagementRoute,
      label: 'Content Management',
      category: 'Leadership & Admin',
      keywords: ['cms', 'broadcast', 'announcements', 'content'],
    ),
    AppRouteOption(
      path: AppConstants.leadershipReportsRoute,
      label: 'Leadership Reports',
      category: 'Leadership & Admin',
      keywords: ['reports', 'chapters', 'hierarchical'],
    ),
    AppRouteOption(
      path: AppConstants.leadershipDirectoryRoute,
      label: 'Leadership Directory',
      category: 'Leadership & Admin',
      keywords: ['leaders', 'executives', 'directory', 'archive'],
    ),
    AppRouteOption(
      path: AppConstants.bodRoute,
      label: 'Board of Directors & Trustees',
      category: 'Leadership & Admin',
      keywords: ['bod', 'board', 'trustees', 'decisions'],
    ),
    AppRouteOption(
      path: AppConstants.meetingFileSharingRoute,
      label: 'Meeting Files & Minutes',
      category: 'Leadership & Admin',
      keywords: ['files', 'minutes', 'documents', 'board'],
    ),
    AppRouteOption(
      path: AppConstants.scribeRoute,
      label: 'ALIVE Scribe (Meeting Notes)',
      category: 'Leadership & Admin',
      keywords: ['scribe', 'transcription', 'minutes', 'notes'],
    ),
    AppRouteOption(
      path: AppConstants.tractPodcastAdminRoute,
      label: 'Tract & Podcast Admin',
      category: 'Leadership & Admin',
      keywords: ['tracts', 'podcasts', 'manage'],
    ),
    AppRouteOption(
      path: AppConstants.videoContentAdminRoute,
      label: 'Video Content Admin',
      category: 'Leadership & Admin',
      keywords: ['videos', 'media', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.adminDonationsReportRoute,
      label: 'Donations Report (Admin)',
      category: 'Leadership & Admin',
      keywords: ['finance', 'donations', 'report'],
    ),
    AppRouteOption(
      path: AppConstants.adminHealthContentRoute,
      label: 'Health+ Content Admin',
      category: 'Leadership & Admin',
      keywords: ['health', 'recipes', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.adminKidsStoriesRoute,
      label: 'Kids Stories Admin',
      category: 'Leadership & Admin',
      keywords: ['kids', 'stories', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.adminKidsMissionsRoute,
      label: 'Kids Missions Admin',
      category: 'Leadership & Admin',
      keywords: ['kids', 'missions', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.adminStudyGuidesRoute,
      label: 'Study Guides Admin',
      category: 'Leadership & Admin',
      keywords: ['study', 'guides', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.adminChatTagManagementRoute,
      label: 'Chat Tag Management',
      category: 'Leadership & Admin',
      keywords: ['chat', 'tags', 'roles', 'admin'],
    ),
    AppRouteOption(
      path: '/admin-billboard',
      label: 'Billboard Admin',
      category: 'Leadership & Admin',
      keywords: ['billboard', '3d', 'showcase', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.userArchiveRoute,
      label: 'User Archive',
      category: 'Leadership & Admin',
      keywords: ['users', 'members', 'archive', 'admin'],
    ),
    AppRouteOption(
      path: AppConstants.roleManagementRoute,
      label: 'Role Management',
      category: 'Leadership & Admin',
      keywords: ['roles', 'permissions', 'admin'],
    ),
  ];

  /// Additional registered aliases in `app_router.dart` so validation accepts
  /// them even if not listed as duplicate entries in the picker.
  static const Set<String> _routeAliases = {
    '/announcement',
    '/prayer-requests',
    '/books-tracts',
    '/discipleship',
    '/donation',
    '/showcase',
    '/project-3d-viewer',
    '/alive_ng_3d_viewer.html',
    '/hierarchical-reports',
    '/content',
    '/tract-management',
    '/podcast-management',
    '/meeting-files',
    '/board',
    '/admin/board-decisions',
    '/admin-sample-content',
    '/more',
  };

  static final Set<String> validRoutePaths = {
    ...allRoutes.map((r) => r.path),
    ..._routeAliases,
  };

  /// Checks whether [rawRoute] resolves to a real registered route in `GoRouter`.
  /// Query parameters (e.g. `/bible?tab=study`, `/meet?room=prayer`) are allowed.
  static bool isValidAppRoute(String rawRoute) {
    final trimmed = rawRoute.trim();
    if (trimmed.isEmpty || !trimmed.startsWith('/')) return false;

    final uri = Uri.tryParse(trimmed);
    var basePath = (uri?.path ?? trimmed).trim();
    if (basePath.length > 1 && basePath.endsWith('/')) {
      basePath = basePath.substring(0, basePath.length - 1);
    }
    return validRoutePaths.contains(basePath);
  }

  /// Returns routes matching [query], ranked with path prefix matches first.
  static List<AppRouteOption> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty || q == '/') {
      return allRoutes;
    }

    final cleanQ = q.startsWith('/') ? q.substring(1) : q;
    final matches = allRoutes.where((r) => r.matches(q)).toList();

    int score(AppRouteOption r) {
      final p = r.path.toLowerCase();
      final l = r.label.toLowerCase();
      if (p == q || p == '/$cleanQ') return 0;
      if (p.startsWith('/$cleanQ')) return 1;
      if (l.startsWith(cleanQ)) return 2;
      if (p.contains(cleanQ)) return 3;
      if (l.contains(cleanQ)) return 4;
      return 5;
    }

    matches.sort((a, b) => score(a).compareTo(score(b)));
    return matches;
  }
}
