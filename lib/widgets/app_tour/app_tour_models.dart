import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Defines an individual step within the interactive App Tour.
class AppTourStep {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color accentColor;
  final String? route;
  final String targetArea;
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

/// Comprehensive multi-step tour covering bottom navigation, header navigation,
/// and specialized features grounded in ALIVE Nigeria's actual architecture.
class AppTourSteps {
  static const List<AppTourStep> standardTour = [
    // 1. Home (Bottom Nav Item 1)
    AppTourStep(
      id: 'step_home',
      title: 'Home & Daily Inspiration',
      subtitle: 'Daily Scripture, Audio & Ministry Pulse',
      description:
          'Your daily spiritual home base. Access today\'s Bible verse in your chosen language with Text-To-Speech audio, memorize scripture with interactive games, and track spiritual milestones.',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF2563EB), // Vibrant Blue
      route: '/home',
      targetArea: 'home',
      highlights: [
        'Daily Bible verse with multilingual audio TTS playback',
        'Quick shortcuts to Bible Study, Tracts, Podcasts, and Kids Missions',
        'Personalized greeting, profile hub, and ministry updates',
      ],
    ),

    // 2. Study (Bottom Nav Item 2)
    AppTourStep(
      id: 'step_study',
      title: 'Interactive Bible Study',
      subtitle: 'Offline Bibles, Memory Games & Discipleship',
      description:
          'Engage deeply with God\'s Word. Read offline across multiple translations (KJV, NIV, Yoruba BM, Hausa HAU, Igbo IGBOB), memorize verses with voice recitation, and follow discipleship tracks.',
      icon: Icons.book_rounded,
      accentColor: Color(0xFF10B981), // Emerald Green
      route: '/study',
      targetArea: 'study',
      highlights: [
        'Multi-translation Bible with verse highlighting and audio TTS',
        'Scripture Memory Game with Fill-in-the-Gaps and Voice Recitation',
        'Structured discipleship studies',
      ],
    ),

    // 3. Prayer (Bottom Nav Item 3) - EXACT MATCH with FontAwesome personPraying icon
    AppTourStep(
      id: 'step_prayer',
      title: '24/7 Prayer Community',
      subtitle: 'Prayer Requests, Intercession & Testimonies',
      description:
          'Experience the power of united prayer across Nigeria. Submit prayer requests publicly or anonymously, tap "I Prayed for This" to lift up brethren, and celebrate answered prayers on the testimony wall.',
      icon: FontAwesomeIcons.personPraying,
      accentColor: Color(0xFF8B5CF6), // Royal Violet
      route: '/prayer',
      targetArea: 'prayer',
      highlights: [
        'Submit public or anonymous prayer requests with instant community alerts',
        'Intercede for fellow believers with a single tap in real time',
        'Testimony wall celebrating God\'s miraculous answers to prayer',
      ],
    ),

    // 4. Health (Bottom Nav Item 4)
    AppTourStep(
      id: 'step_health',
      title: 'Health & Total Wellness',
      subtitle: 'NEWSTART Principles & Lifestyle Medicine',
      description:
          'Embrace God\'s design for abundant physical and spiritual vitality through the NEWSTART principles — nutrition, exercise, water, sunshine, temperance, air, rest, and trust in God.',
      icon: Icons.health_and_safety_rounded,
      accentColor: Color(0xFF059669), // Forest Green
      route: '/health',
      targetArea: 'health',
      highlights: [
        'NEWSTART lifestyle assessments and daily health nuggets',
        'Health+ comes with Delicious, nutritious plant-based recipes with local Nigerian ingredients',
        'and Natural health remedies',
      ],
    ),

    // 5. More (Bottom Nav Item 5)
    AppTourStep(
      id: 'step_more',
      title: 'More Ministry Resources',
      subtitle: 'Tracts, Podcasts, Kids & Chapters',
      description:
          'Explore the complete ALIVE toolbox. Access digital tracts for evangelism, inspiring audio podcasts, interactive kids stories, and locate local campus mission and regional chapters across Nigeria.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFF59E0B), // Radiant Amber
      route: '/more',
      targetArea: 'more',
      highlights: [
        'Books & Tracts with interactive questions and in-app PDF view',
        'Podcasts featuring uplifting sermons, health talks, and music',
        'Kids Mission with illustrated Bible stories and achievement badges',
        'Chapters directory connecting you to campus & regional units',
      ],
    ),

    // 6. Live Meetings (Accessible via More)
    AppTourStep(
      id: 'step_conference',
      title: 'Live Meetings & Scribe',
      subtitle: 'Meeting Rooms & On-Device Minutes Scribe',
      description:
          'Found under the More menu, ALIVE Live Meetings connect members, leaders, and chapters in real-time video conferences with automated meeting minutes and resolution tracking.',
      icon: Icons.video_camera_front_rounded,
      accentColor: Color(0xFFD946EF), // Fuchsia / Magenta
      route: '/conference',
      targetArea: 'conference',
      highlights: [
        'Low-latency LiveKit audio/video conference rooms',
        'Automated meeting minutes capturing resolutions and action items',
        'File sharing and secure leader meeting collaboration',
      ],
    ),

    // 7. Donations (Top Header Action)
    AppTourStep(
      id: 'step_donations',
      title: 'Giving & Ministry Partnership',
      subtitle: 'Secure Giving via Paystack & Gift Pledges',
      description:
          'Accessible anytime from the top bar. Partner in literature evangelism, campus missions, and ministry projects with secure Paystack payments or non-monetary gift pledges.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFE11D48), // Rose Red
      route: '/donations',
      targetArea: 'donations',
      highlights: [
        'Direct fund designations: General Ministry, Tract Production, Campus Outreaches',
        'Instant receipt generation and transaction history',
        'Non-monetary donation registry for equipment and ministry supplies',
      ],
    ),

    // 8. Language Selector (Top Header Action)
    AppTourStep(
      id: 'step_language',
      title: 'Indigenous Language Support',
      subtitle: 'English, Yoruba, Hausa & Igbo',
      description:
          'Tap the language selector at the top of the screen to switch the app, daily devotionals, Bible reader, and literature into your preferred indigenous Nigerian language.',
      icon: Icons.translate_rounded,
      accentColor: Color(0xFF0284C7), // Sky Blue
      route: '/settings/language',
      targetArea: 'language',
      highlights: [
        'One-tap toggle between English, Yorùbá, Hausa, and Asụsụ Igbo',
        'Localized scripture verses, reflections, and menu navigation',
        'Saves your preference automatically across sessions',
      ],
    ),
  ];
}
