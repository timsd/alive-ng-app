import 'package:flutter/material.dart';

/// Defines an individual step within the interactive App Tour.
class AppTourStep {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String? route;
  final String targetArea; // 'header', 'verse', 'actions', 'study', 'prayer', 'health', 'conference'
  final List<String> highlights;

  const AppTourStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    this.route,
    required this.targetArea,
    this.highlights = const [],
  });
}

/// Standard 6-step tour covering every major ecosystem feature of ALIVE Nigeria.
class AppTourSteps {
  static const List<AppTourStep> standardTour = [
    AppTourStep(
      id: 'step_home',
      title: 'Home & Spiritual Pulse',
      subtitle: 'Daily Devotionals & Quick Actions',
      description:
          'Welcome to ALIVE Nigeria! Your home feed provides your personalized daily verse, spiritual milestones, active announcements, and one-tap access to discipleship tools.',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF2563EB), // Vibrant Blue
      route: '/home',
      targetArea: 'header',
      highlights: [
        'Personalized daily Bible verse and memory challenge',
        'One-tap shortcuts to Kids missions, Tracts, and Podcasts',
        'Real-time ministry announcements and updates',
      ],
    ),
    AppTourStep(
      id: 'step_study',
      title: 'Interactive Bible Study',
      subtitle: 'Scripture, Guides & Offline Library',
      description:
          'Immerse yourself in God\'s Word with offline multi-version Bibles, structured study guides, Sabbath School lessons, tracts, and biblical interactive quizzes.',
      icon: Icons.menu_book_rounded,
      accentColor: Color(0xFF10B981), // Emerald Green
      route: '/study',
      targetArea: 'study',
      highlights: [
        'Multi-translation Bible with instant verse bookmarking',
        'Comprehensive Discipleship trackers and study questions',
        'Downloadable tracts and literature evangelism resources',
      ],
    ),
    AppTourStep(
      id: 'step_prayer',
      title: '24/7 Prayer Community',
      subtitle: 'Intercession, Private Rooms & Testimonies',
      description:
          'Experience the power of united prayer. Share your requests with believers across Nigeria, intercede for others, create private prayer rooms, and post answered prayer testimonies.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFF8B5CF6), // Royal Violet
      route: '/prayer',
      targetArea: 'prayer',
      highlights: [
        'Submit public or anonymous prayer requests',
        'Tap to pray for brothers & sisters in real time',
        'Testimony wall celebrating God\'s faithfulness',
      ],
    ),
    AppTourStep(
      id: 'step_health',
      title: 'Health & Total Wellness',
      subtitle: 'NEWSTART Principles & Wholesome Living',
      description:
          'Discover biblical health message principles for physical and spiritual vigor — evidence-based plant-based recipes, health trackers, natural remedies, and lifestyle assessments.',
      icon: Icons.health_and_safety_rounded,
      accentColor: Color(0xFF059669), // Forest Green
      route: '/health',
      targetArea: 'health',
      highlights: [
        'NEWSTART lifestyle assessments and daily health tips',
        'Delicious, wholesome plant-based meal recipes',
        'Natural health remedies and wellness calculators',
      ],
    ),
    AppTourStep(
      id: 'step_conference',
      title: 'Live Meetings & Hybrid Scribe',
      subtitle: 'LiveKit Rooms & 100% On-Device AI Minutes',
      description:
          'Connect with council members and chapters in crisp live video conference rooms. Our built-in On-Device Scribe automatically transcribes speakers and formats council resolutions and action items.',
      icon: Icons.video_camera_front_rounded,
      accentColor: Color(0xFFD946EF), // Fuchsia / Magenta
      route: '/conference',
      targetArea: 'conference',
      highlights: [
        'Low-latency LiveKit multi-speaker conference rooms',
        '100% On-Device rule synthesizer (no cloud AI latency)',
        'Automatic minutes: Executive Summary, Decisions & Tasks',
      ],
    ),
    AppTourStep(
      id: 'step_more',
      title: 'Chapters, Missions & Community',
      subtitle: 'Regional Chapters, Events & Volunteer Registry',
      description:
          'Find and connect with your nearest ALIVE chapter, join campus evangelism outreaches, submit donations securely via Paystack, and customize your language preferences.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFF59E0B), // Radiant Amber
      route: '/chapters',
      targetArea: 'actions',
      highlights: [
        'Connect with local and campus ALIVE chapters across Nigeria',
        'Seamless giving via Paystack with instant receipt delivery',
        'Multilingual support in English, Hausa, Igbo, and Yoruba',
      ],
    ),
  ];
}
