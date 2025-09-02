class AppConstants {
  // Supabase Configuration
  static const String supabaseUrl = 'https://alavvcknoleddumqdxhv.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFsYXZ2Y2tub2xlZGR1bXFkeGh2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTU5MDM2NDIsImV4cCI6MjA3MTQ3OTY0Mn0.5zV86kAD7rRYiso6oXYZNmN1C5c-1aaV3qqdF48bLu8';

  // App Information
  static const String appName = 'ALIVE NG';
  static const String appVersion = '1.0.0';

  // Navigation Routes
  static const String splashRoute = '/';
  static const String homeRoute = '/home';
  static const String studyRoute = '/study';
  static const String dailyRoute = '/daily';
  static const String prayerRoute = '/prayer';
  static const String profileRoute = '/profile';
  static const String healthRoute = '/health';
  static const String missionsRoute = '/missions';
  static const String authRoute = '/auth';

  // Admin and Management Routes
  static const String aboutAppRoute = '/about-app';
  static const String aboutAliveRoute = '/about-alive';
  static const String adminRoute = '/admin';
  static const String bodTrusteesRoute = '/bod-trustees';
  static const String userArchiveRoute = '/user-archive';
  static const String roleManagementRoute = '/role-management';
  static const String conferenceRoute = '/conference';
  static const String bibleGameRoute = '/bible-game';
  static const String chatRoute = '/chat';
  static const String chaptersRoute = '/chapters';
  static const String recipesRoute = '/recipes';
  static const String recipeSubmissionRoute = '/recipe-submission';
  static const String enhancedHealthRoute = '/enhanced-health';

  // Bible Versions
  static const List<String> bibleVersions = ['KJV', 'NKJV', 'NIV'];

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
}
