class AppConstants {
  // App Information
  static const String appName = 'ALIVE Nigeria';
  static const String appVersion = '2.0.2+8';

  // Navigation Routes
  static const String splashRoute = '/';
  static const String onboardingRoute = '/onboarding';
  static const String homeRoute = '/home';
  static const String studyRoute = '/study';
  static const String dailyRoute = '/daily';
  static const String prayerRoute = '/prayer';
  static const String profileRoute = '/profile';
  static const String healthRoute = '/health';
  static const String missionsRoute = '/missions';
  static const String authRoute = '/auth';
  static const String resetPasswordRoute = '/reset-password';
  static const String bibleRoute = '/bible';
  static const String notificationSettingsRoute = '/notification-settings';

  // Admin and Management Routes
  static const String aboutAppRoute = '/about-app';
  static const String aboutAliveRoute = '/about-alive';
  static const String adminRoute = '/admin';
  static const String adminDonationsReportRoute = '/admin-donations-report';
  static const String contentManagementRoute = '/content-management';
  static const String bodTrusteesRoute = '/bod-trustees';
  static const String userArchiveRoute = '/user-archive';
  static const String roleManagementRoute = '/role-management';
  static const String adminApprovalRoute = '/admin-approval';
  static const String adminApprovalLinkRoute = '/admin-approve';
  static const String leadershipArchiveRoute = '/leadership-archive';
  static const String sampleContentAdminRoute = '/admin-sample-content';
  static const String studyGuideRoute = '/study-guide';
  static const String tractPodcastAdminRoute = '/tract-podcast-admin';
  static const String meetingFileSharingRoute = '/meeting-file-sharing';
  static const String adminKidsStoriesRoute = '/admin-kids-stories';
  static const String adminKidsMissionsRoute = '/admin-kids-missions';
  static const String adminStudyGuidesRoute = '/admin-study-guides';
  static const String adminHealthContentRoute = '/admin-health-content';
  static const String conferenceRoute = '/conference';
  static const String bibleGameRoute = '/bible-game';
  static const String chatRoute = '/chat';
  static const String chaptersRoute = '/chapters';
  // Recipes are now part of Health+. Keep the constant pointing at the
  // enhanced health screen so any older deep-link still resolves.
  static const String recipesRoute = '/enhanced-health';
  static const String recipeSubmissionRoute = '/recipe-submission';
  static const String enhancedHealthRoute = '/enhanced-health';
  static const String kidsMissionRoute = '/kids-mission';
  static const String discipleshipTrackerRoute = '/discipleship-tracker';
  static const String podcastsRoute = '/podcasts';
  static const String interactiveLessonsRoute = '/interactive-lessons';
  static const String libraryRoute = '/library';
  static const String booksTractsRoute = '/books-tracts';
  static const String kidsStoriesRoute = '/kids-stories';
  static const String prayerWallRoute = '/prayer-wall';
  static const String privatePrayerRoomRoute = '/private-prayer-room';
  static const String eventsRoute = '/events';
  static const String testimoniesRoute = '/testimonies';
  static const String resourcesRoute = '/resources';
  

  // Support Routes
  static const String helpSupportRoute = '/help-support';
  static const String donationRoute = '/donation';
  static const String giftInKindRoute = '/gift-in-kind';
  static const String nonMonetaryGiftRoute = '/non-monetary-gift';

  // Bible Versions
  static const List<String> bibleVersions = ['KJV', 'NKJV', 'NIV', 'NLT'];

  // Supported Languages
  static const Map<String, String> supportedLanguages = {
    'en': 'English',
    'yo': 'Yoruba',
    'ig': 'Igbo',
    'ha': 'Hausa',
  };

  // Health Categories
  static const List<String> healthCategories = [
    'Nutrition',
    'Exercise',
    'Water',
    'Sunlight',
    'Temperance',
    'Fresh Air',
  ];

  // Prayer Categories
  static const List<String> prayerCategories = [
    'Personal',
    'Family',
    'Health',
    'Work',
    'Ministry',
    'Others',
  ];

  // Study Difficulty Levels
  static const List<String> studyDifficulties = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  // Mission Categories
  static const List<String> missionCategories = [
    'Evangelism',
    'Community Service',
    'Education',
    'Health',
    'Youth',
  ];

  // Notification Types
  static const String dailyVerseNotification = 'daily_verse';
  static const String prayerReminderNotification = 'prayer_reminder';
  static const String studyReminderNotification = 'study_reminder';
  static const String healthTrackingNotification = 'health_tracking';
  static const String missionReminderNotification = 'mission_reminder';

  // Storage Keys
  static const String themeKey = 'theme_mode';
  static const String languageKey = 'language';
  static const String bibleVersionKey = 'bible_version';
  static const String onboardingKey = 'onboarding_completed';
  static const String notificationTokenKey = 'notification_token';
  static const String showAchievementBadgeKey = 'show_achievement_badge';
}




