import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Defines an individual step within the interactive App Tour.
class AppTourStep {
  final String id;
  final String title;
  final String subtitle;
  final String description;
  final IconData? icon;
  final IconData? faIcon;
  final Color accentColor;
  final String? route;
  final String targetArea;
  final List<String> highlights;

  const AppTourStep({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    this.icon,
    this.faIcon,
    required this.accentColor,
    this.route,
    required this.targetArea,
    this.highlights = const [],
  });

  Widget buildIcon({double size = 32, Color color = Colors.white}) {
    if (faIcon != null) {
      return FaIcon(faIcon, size: size, color: color);
    }
    return Icon(icon ?? Icons.help_outline, size: size, color: color);
  }
}

/// Comprehensive multi-step tour covering bottom navigation, header navigation,
/// and specialized features with full multilingual localization.
class AppTourSteps {
  static List<AppTourStep> getTourStepsForLanguage(String langCode) {
    switch (langCode) {
      case 'yo':
        return _yorubaSteps;
      case 'ha':
        return _hausaSteps;
      case 'ig':
        return _igboSteps;
      case 'en':
      default:
        return _englishSteps;
    }
  }

  static const List<AppTourStep> standardTour = _englishSteps;

  // -------------------------------------------------------------
  // ENGLISH TOUR STEPS
  // -------------------------------------------------------------
  static const List<AppTourStep> _englishSteps = [
    // 1. Home
    AppTourStep(
      id: 'step_home',
      title: 'Home & Daily Inspiration',
      subtitle: 'Daily Scripture, Audio & Ministry Pulse',
      description:
          'Your spiritual home base. Access today\'s Bible verse in your chosen language with Text-To-Speech audio, explore daily spiritual reflections, and track your faith journey.',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF2563EB), // Vibrant Blue
      route: '/home',
      targetArea: 'home',
      highlights: [
        'Daily Bible verse with multilingual audio TTS playback',
        'Quick shortcuts to Bible Study, Tracts, Podcasts, and Kids Missions',
        'Personalized profile hub and church community updates',
      ],
    ),

    // 2. Study (Bible Study - Ẹkọ)
    AppTourStep(
      id: 'step_study',
      title: 'Interactive Bible Study',
      subtitle: 'Offline Bibles, Memory Games & Discipleship',
      description:
          'Engage deeply with God\'s Word. Read offline across multiple translations (KJV, Yoruba BM, Hausa HAU, Igbo IGBOB), memorize verses with voice recitation, and follow structured discipleship courses.',
      icon: Icons.book_rounded,
      accentColor: Color(0xFF10B981), // Emerald Green
      route: '/study',
      targetArea: 'study',
      highlights: [
        'Multi-translation Bible with verse highlighting and audio TTS',
        'Scripture Memory Game with Fill-in-the-Gaps and Voice Recitation',
        'Interactive discipleship guides and spiritual growth tracks',
      ],
    ),

    // 3. Prayer (FontAwesomeIcons.personPraying - Adura)
    AppTourStep(
      id: 'step_prayer',
      title: '24/7 Prayer Community',
      subtitle: 'Prayer Requests, Intercession & Testimonies',
      description:
          'Experience the power of united prayer across Nigeria. Submit prayer requests publicly or anonymously, tap "I Prayed for This" to lift up brethren, and celebrate answered prayers on the testimony wall.',
      faIcon: FontAwesomeIcons.personPraying,
      accentColor: Color(0xFF8B5CF6), // Royal Violet
      route: '/prayer',
      targetArea: 'prayer',
      highlights: [
        'Submit public or anonymous prayer requests with instant alerts',
        'Intercede for fellow believers with a single tap in real time',
        'Testimony wall celebrating God\'s miraculous answers to prayer',
      ],
    ),

    // 4. Health
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
        'Delicious plant-based recipes made with local Nigerian ingredients',
        'Natural home remedies and preventative health guides',
      ],
    ),

    // 5. More
    AppTourStep(
      id: 'step_more',
      title: 'More Ministry Resources',
      subtitle: 'Tracts, Podcasts, Kids & Chapters',
      description:
          'Explore the complete ALIVE ministry toolbox. Access digital tracts for evangelism, uplifting audio podcasts, interactive kids Bible stories, and directory of campus and regional chapters.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFF59E0B), // Radiant Amber
      route: '/more',
      targetArea: 'more',
      highlights: [
        'Digital tracts with in-app PDF view and sharing',
        'Audio podcasts with uplifting sermons and Christian music',
        'Kids missions with illustrated stories and achievement badges',
        'Directory connecting you to campus and regional chapter units',
      ],
    ),

    // 6. Live Meetings
    AppTourStep(
      id: 'step_conference',
      title: 'Live Meetings & Scribe',
      subtitle: 'Virtual Rooms & Automated Minutes',
      description:
          'Accessible under More, ALIVE Live Meetings connect members and leaders in real-time video conferences with automated meeting minutes and resolution tracking.',
      icon: Icons.video_camera_front_rounded,
      accentColor: Color(0xFFD946EF), // Fuchsia / Magenta
      route: '/conference',
      targetArea: 'conference',
      highlights: [
        'Low-latency LiveKit audio/video conference rooms',
        'Automated minutes capturing resolutions and action items',
        'Encrypted leader collaboration and meeting file sharing',
      ],
    ),

    // 7. Donations
    AppTourStep(
      id: 'step_donations',
      title: 'Giving & Ministry Partnership',
      subtitle: 'Secure Giving via Paystack & Gift Pledges',
      description:
          'Accessible anytime from the top bar. Partner in literature evangelism, campus missions, and community outreach with secure Paystack payments or non-monetary gift pledges.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFE11D48), // Rose Red
      route: '/donations',
      targetArea: 'donations',
      highlights: [
        'Direct fund designations: General Ministry, Tract Production, Campus Outreaches',
        'Instant receipt generation and personal giving history',
        'Registry for non-monetary equipment and mission supplies',
      ],
    ),

    // 8. Language Selector
    AppTourStep(
      id: 'step_language',
      title: 'Indigenous Language Support',
      subtitle: 'English, Yorùbá, Hausa & Asụsụ Igbo',
      description:
          'Tap the language selector at the top of the screen to switch the app, daily devotionals, Bible reader, and literature into your preferred indigenous Nigerian language.',
      icon: Icons.translate_rounded,
      accentColor: Color(0xFF0284C7), // Sky Blue
      route: '/settings/language',
      targetArea: 'language',
      highlights: [
        'One-tap toggle between English, Yorùbá, Hausa, and Igbo',
        'Localized scripture verses, reflections, and navigation',
        'Saves your preference automatically across sessions',
      ],
    ),
  ];

  // -------------------------------------------------------------
  // YORUBA TOUR STEPS (ÈDÈ YORÙBÁ)
  // -------------------------------------------------------------
  static const List<AppTourStep> _yorubaSteps = [
    // 1. Ilé (Home)
    AppTourStep(
      id: 'step_home',
      title: 'Ilé & Ìmísí Ojoojúmọ́',
      subtitle: 'Ẹsẹ Bíbélì, Ohùn Kíkà & Ìbùkún Ọjọ́',
      description:
          'Ibùdó tẹ̀mí rẹ fún ojoojúmọ́. Ka ẹsẹ Bíbélì lónìí ní èdè Yorùbá pẹ̀lú ohùn kíkà (TTS), ṣe àṣàrò lórí Ọ̀rọ̀ Ọlọ́run, kí o sì rí àwọn ìbùkún tuntun.',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF2563EB),
      route: '/home',
      targetArea: 'home',
      highlights: [
        'Ẹsẹ Bíbélì ojoojúmọ́ pẹ̀lú ohùn kíkà ní èdè Yorùbá',
        'Àwọn ọ̀nà ìkékúrú sí Ẹkọ Bíbélì, Ìwé Àṣàrò, àti Àdúrà',
        'Àwọn ìròyìn àti àbójútó iṣẹ́ ìránṣẹ́ ALIVE Nigeria',
      ],
    ),

    // 2. Ẹkọ (Study - Bible Study)
    AppTourStep(
      id: 'step_study',
      title: 'Ẹkọ Bíbélì & Ìdàgbàsókè Ẹ̀mí',
      subtitle: 'Bíbélì Àìlórí-Íńtánẹ́ẹ̀tì, Eré Àkọ́sórí & Ẹ̀kọ́ Ọmọ-ẹ̀yìn',
      description:
          'Wọ inú Ọ̀rọ̀ Ọlọ́run jinlẹ̀. Ka Bíbélì láìsí íńtánẹ́ẹ̀tì ní Bíbélì Mímọ́ Yorùbá (BM), KJV, HAU, àti IGBOB, kọ́ ẹsẹ sórí pẹ̀lú eré àkọ́sórí, kí o sì kọ́ ẹ̀kọ́ ọmọ-ẹ̀yìn.',
      icon: Icons.book_rounded,
      accentColor: Color(0xFF10B981),
      route: '/study',
      targetArea: 'study',
      highlights: [
        'Bíbélì Mímọ́ ní èdè Yorùbá pẹ̀lú àmì ẹsẹ àti ohùn kíkà',
        'Eré Àkọ́sórí Bíbélì pẹ̀lú pípe ọ̀rọ̀ àti fífún ní àyè',
        'Àwọn ẹ̀kọ́ ìtọ́sọ́nà fún ìdàgbàsókè àti ìrìn-àjò ìgbàgbọ́ rẹ',
      ],
    ),

    // 3. Àdúrà (Prayer - FontAwesomeIcons.personPraying)
    AppTourStep(
      id: 'step_prayer',
      title: 'Àdúrà 24/7 & Àwùjọ Ìbẹ̀bẹ̀',
      subtitle: 'Àwọn Ìbéèrè Àdúrà, Ìbẹ̀bẹ̀ & Ẹ̀rí Ìyìn',
      description:
          'Ní ìrírí agbára àdúrà àpapọ̀ káàkiri Nàìjíríà. Fi ìbéèrè àdúrà ránṣẹ́ ní gbangba tàbí ní ìkọ̀kọ̀, tẹ "Mo Gbàdúrà fún Èyí" láti gbé àwọn ará ga, kí o sì kọ ẹ̀rí ìdáhùn àdúrà.',
      faIcon: FontAwesomeIcons.personPraying,
      accentColor: Color(0xFF8B5CF6),
      route: '/prayer',
      targetArea: 'prayer',
      highlights: [
        'Fi ìbéèrè àdúrà ránṣẹ́ lẹ́sẹ̀kẹsẹ̀ fún àwùjọ onígbàgbọ́',
        'Gbàdúrà fún àwọn arákùnrin àti arábìnrin pẹ̀lú fífọwọ́tẹ́ lẹ́ẹ̀kan',
        'Ògiri ẹ̀rí tí ń yin Ọlọ́run fún àwọn iṣẹ́ ìyanu àti ìdáhùn',
      ],
    ),

    // 4. Ìlera (Health)
    AppTourStep(
      id: 'step_health',
      title: 'Ìlera & Àlàáfíà Pípé',
      subtitle: 'Àwọn Ìlànà NEWSTART & Oúnjẹ Aṣaralóore',
      description:
          'Ṣe àbójútó ara rẹ gẹ́gẹ́ bí tẹ́ńpìlì Ẹ̀mí Mímọ́. Rí àwọn ìmọ̀ràn ìlera tó péye, àwọn oúnjẹ aṣaralóore ilẹ̀ wa Nàìjíríà, àti àwọn ìlànà ìlera tó dá lórí Bíbélì.',
      icon: Icons.health_and_safety_rounded,
      accentColor: Color(0xFF059669),
      route: '/health',
      targetArea: 'health',
      highlights: [
        'Àyẹ̀wò ìgbésí ayé NEWSTART àti ìmọ̀ràn ìlera ojoojúmọ́',
        'Àwọn ohun èlò oúnjẹ àdánidá tí kò ní ẹran fún ìlera tó dára',
        'Àwọn àbájáde ìtọ́jú àdánidá fún ìdènà àwọn àrùn',
      ],
    ),

    // 5. Púpọ̀ sí i (More)
    AppTourStep(
      id: 'step_more',
      title: 'Púpọ̀ sí i nínú Iṣẹ́ Ìránṣẹ́',
      subtitle: 'Ìwé Àṣàrò, Pọ́díkáàsì & Àwọn Ọmọdé',
      description:
          'Ṣàwárí gbogbo àwọn orísun iṣẹ́ ìránṣẹ́ ALIVE: Ìwé àti Ìwé Àṣàrò fún ìwàásù, Pọ́díkáàsì ohùn tí ń gbé ẹ̀mí ró, àti Ẹ̀ka Àwọn Ọmọdé pẹ̀lú àwọn ìtàn alárinrin.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFF59E0B),
      route: '/more',
      targetArea: 'more',
      highlights: [
        'Ìwé Àṣàrò ìhìnrere pẹ̀lú kíkà PDF ní tààràtà nínú àpù',
        'Pọ́díkáàsì orin àti ìwàásù tí a lè tẹ́tí sí nígbàkúgbà',
        'Ìtàn Bíbélì fún àwọn ọmọdé pẹ̀lú àmì ẹ̀yẹ àṣeyọrí',
        'Àkójọ àwọn ẹ̀ka iṣẹ́ ìránṣẹ́ ní àwọn ilé-ẹ̀kọ́ gíga',
      ],
    ),

    // 6. Ìpàdé Orí-afẹ́fẹ́ (Live Meetings)
    AppTourStep(
      id: 'step_conference',
      title: 'Àkójọ Ìpàdé & Akọsílẹ̀',
      subtitle: 'Fídíò LiveKit & Àwọn Ìpinnu Ìpàdé',
      description:
          'Wà lábẹ́ àkójọ Púpọ̀ sí i, Ìpàdé Orí-afẹ́fẹ́ ALIVE ń so àwọn ọmọ ìjọ àti àwọn aṣáájú pọ̀ ní fídíò lójú ẹsẹ̀ pẹ̀lú akọsílẹ̀ àti àwọn ìpinnu ìpàdé.',
      icon: Icons.video_camera_front_rounded,
      accentColor: Color(0xFFD946EF),
      route: '/conference',
      targetArea: 'conference',
      highlights: [
        'Yàrá fídíò àti ohùn tó yára pẹ̀lú ìmọ̀-ẹ̀rọ LiveKit',
        'Akọsílẹ̀ àwọn ìpinnu ìpàdé ní àkókò gidi láìsí àṣìṣe',
        'Pípín àwọn fáìlì àti ìfọwọ́sowọ́pọ̀ láàárín àwọn aṣáájú',
      ],
    ),

    // 7. Ìtọrẹ Àánú (Donations)
    AppTourStep(
      id: 'step_donations',
      title: 'Ìtọrẹ Àánú & Ìfọwọ́sowọ́pọ̀',
      subtitle: 'Ìtọrẹ Lójú-ẹsẹ̀ nípasẹ̀ Paystack & Ẹ̀bùn Ohun-ìní',
      description:
          'Wà lórí pẹpẹ lókè nígbàkúgbà. Ṣe àtìlẹ́yìn fún títẹ ìwé àṣàrò jáde, iṣẹ́ ìránṣẹ́ ní àwọn ilé-ẹ̀kọ́, àti ìrànwọ́ àwùjọ nípasẹ̀ Paystack.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFE11D48),
      route: '/donations',
      targetArea: 'donations',
      highlights: [
        'Yíyàn ibi tí ìtọrẹ ń lọ: Iṣẹ́ Ìránṣẹ́ Gbogbogbò, Ìwé Àṣàrò, Ìwàásù',
        'Rísíìtì lójú ẹsẹ̀ àti àkọsílẹ̀ gbogbo ìtọrẹ rẹ',
        'Àyè fún ìtọrẹ àwọn ohun-èlò bíi kọ̀mpútà, ẹ̀rọ orin, àti àwọn ohun èlò iṣẹ́',
      ],
    ),

    // 8. Èdè Rẹ (Language Selector)
    AppTourStep(
      id: 'step_language',
      title: 'Àṣàyàn Èdè Nàìjíríà',
      subtitle: 'Èdè Gẹ̀ẹ́sì, Yorùbá, Hausa & Igbo',
      description:
          'Tẹ àami bọ́ọ̀lù àgbáyé lókè láti yí gbogbo àpù, ẹsẹ Bíbélì ojoojúmọ́, àti àwọn ìwé àṣàrò padà sí èdè abínibí rẹ nígbàkúgbà.',
      icon: Icons.translate_rounded,
      accentColor: Color(0xFF0284C7),
      route: '/settings/language',
      targetArea: 'language',
      highlights: [
        'Fífọwọ́tẹ́ lẹ́ẹ̀kan láti yí padà láàárín English, Yorùbá, Hausa, àti Igbo',
        'Àwọn ẹsẹ Ọ̀rọ̀ Ọlọ́run àti àṣàrò ní èdè tí ó yé ọ dáradára',
        'Àpù ń rántí èdè tí o yàn fún ìgbà mìíràn tí o bá wọlé',
      ],
    ),
  ];

  // -------------------------------------------------------------
  // HAUSA TOUR STEPS (HARSHEN HAUSA)
  // -------------------------------------------------------------
  static const List<AppTourStep> _hausaSteps = [
    AppTourStep(
      id: 'step_home',
      title: 'Gida & Wahayi na Kullum',
      subtitle: 'Ayar Littafi Mai Tsarki & Albarka',
      description:
          'Gidan ruhaniyarku na yau da kullum. Karanta ayar yau a cikin harshen Hausa tare da sautin karatu (TTS) da bimbini.',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF2563EB),
      route: '/home',
      targetArea: 'home',
      highlights: [
        'Ayar kullum tare da sautin karatu a Hausa',
        'Hanyoyi masu sauri zuwa Nazarin Littafi Mai Tsarki da Addu\'a',
        'Labaran ma\'aikatar ALIVE Nigeria',
      ],
    ),
    AppTourStep(
      id: 'step_study',
      title: 'Nazarin Littafi Mai Tsarki',
      subtitle: 'Littafi Mai Tsarki Ba Tare Da Intanet Ba & Horarwa',
      description:
          'Shiga cikin Kalmar Allah. Karanta Littafi Mai Tsarki a Hausa (HAU), KJV, da sauran fassarori ba tare da intanet ba.',
      icon: Icons.book_rounded,
      accentColor: Color(0xFF10B981),
      route: '/study',
      targetArea: 'study',
      highlights: [
        'Littafi Mai Tsarki a Hausa tare da sautin karatu',
        'Wasan haddace ayoyi don iyali',
        'Kwasakwasan koyarwa don ci gaban ruhaniya',
      ],
    ),
    AppTourStep(
      id: 'step_prayer',
      title: 'Addu\'a ta Awanni 24/7',
      subtitle: 'Rokon Addu\'a, Ceto & Shaidu',
      description:
          'Gane ikon addu\'a ta haɗin gwiwa a fadin Najeriya. Aika buƙatun addu\'a a fili ko a asirce kuma yi addu\'a ga \'yan\'uwa.',
      faIcon: FontAwesomeIcons.personPraying,
      accentColor: Color(0xFF8B5CF6),
      route: '/prayer',
      targetArea: 'prayer',
      highlights: [
        'Aika buƙatun addu\'a cikin sauƙi',
        'Yi addu\'a ga wasu da taɓawa ɗaya',
        'Bangon shaida don yabon Allah',
      ],
    ),
    AppTourStep(
      id: 'step_health',
      title: 'Lafiya & Cikakkiyar Rayuwa',
      subtitle: 'Ka\'idodin NEWSTART & Abinci Mai Gina Jiki',
      description:
          'Kula da jikinka a matsayin haikalin Ruhu Mai Tsarki tare da ingantattun shawarwarin lafiya na Littafi Mai Tsarki.',
      icon: Icons.health_and_safety_rounded,
      accentColor: Color(0xFF059669),
      route: '/health',
      targetArea: 'health',
      highlights: [
        'Ka\'idodin NEWSTART na yau da kullum',
        'Girke-girke masu gina jiki na gida',
        'Maganin gargajiya masu inganci',
      ],
    ),
    AppTourStep(
      id: 'step_more',
      title: 'Karin Albarkatun Ma\'aikata',
      subtitle: 'Littattafai, Podcasts & Yara',
      description:
          'Bincika cikakkun albarkatun ALIVE: warƙoƙin bishara, sautin podcasts, da labaran Littafi Mai Tsarki na yara.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFF59E0B),
      route: '/more',
      targetArea: 'more',
      highlights: [
        'Warƙoƙin bishara a cikin PDF',
        'Podcasts na wa\'azi da waƙoƙi',
        'Sashen yara mai kayatarwa',
      ],
    ),
    AppTourStep(
      id: 'step_conference',
      title: 'Taron Kai Tsaye & Rubuce-rubuce',
      subtitle: 'Bidiyo na LiveKit & Shawarwari',
      description:
          'Haɗu da shugabanni da membobi a cikin tarurrukan bidiyo na kai tsaye tare da rubuta shawarwari.',
      icon: Icons.video_camera_front_rounded,
      accentColor: Color(0xFFD946EF),
      route: '/conference',
      targetArea: 'conference',
      highlights: [
        'Dakin taro mai sauri ta LiveKit',
        'Rubuta shawarwarin taro nan take',
        'Raba fayiloli tsakanin shugabanni',
      ],
    ),
    AppTourStep(
      id: 'step_donations',
      title: 'Gudunmawa & Haɗin Gwiwa',
      subtitle: 'Ba da Gudunmawa ta Paystack',
      description:
          'Taimaka wa buga warƙoƙi da aikin bishara a Najeriya ta hanyar Paystack cikin kwanciyar hankali.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFE11D48),
      route: '/donations',
      targetArea: 'donations',
      highlights: [
        'Zaɓi inda gudunmawar ke zuwa',
        'Samun rasit nan take',
        'Ba da gudunmawar kayan aiki',
      ],
    ),
    AppTourStep(
      id: 'step_language',
      title: 'Harsunan Najeriya',
      subtitle: 'Turanci, Yorùbá, Hausa & Igbo',
      description:
          'Taɓa tambarin duniya da ke sama don sauya manhajar zuwa yaren da kuka fi so a kowane lokaci.',
      icon: Icons.translate_rounded,
      accentColor: Color(0xFF0284C7),
      route: '/settings/language',
      targetArea: 'language',
      highlights: [
        'Sauyawa tsakanin Turanci, Yorùbá, Hausa da Igbo',
        'Ayoyin Littafi Mai Tsarki a yarenku',
        'Adana zaɓinku ta atomatik',
      ],
    ),
  ];

  // -------------------------------------------------------------
  // IGBO TOUR STEPS (ASỤSỤ IGBO)
  // -------------------------------------------------------------
  static const List<AppTourStep> _igboSteps = [
    AppTourStep(
      id: 'step_home',
      title: 'Ụlọ & Nkpali Kwa Ụbọchị',
      subtitle: 'Amaokwu Baịbụl, Ọdịyo & Ngọzi',
      description:
          'Ụlọ ime mmụọ gị kwa ụbọchị. Gụọ amaokwu taa n\'asụsụ Igbo yana ọdịyo ọgụgụ (TTS) na ntụgharị uche.',
      icon: Icons.home_rounded,
      accentColor: Color(0xFF2563EB),
      route: '/home',
      targetArea: 'home',
      highlights: [
        'Amaokwu Baịbụl kwa ụbọchị n\'asụsụ Igbo',
        'Ụzọ ngwa ngwa gaa Ọmụmụ Baịbụl na Ekpere',
        'Akụkọ na ọrụ ALIVE Nigeria',
      ],
    ),
    AppTourStep(
      id: 'step_study',
      title: 'Ọmụmụ Baịbụl & Ọzụzụ Ime Mmụọ',
      subtitle: 'Baịbụl Na-anọghị n\'Ịntanet & Egwuregwu Amaokwu',
      description:
          'Banye n\'ime Okwu Chineke. Gụọ Baịbụl n\'Igbo (IGBOB), KJV na fassarori ndị ọzọ na-enweghị ịntanetị.',
      icon: Icons.book_rounded,
      accentColor: Color(0xFF10B981),
      route: '/study',
      targetArea: 'study',
      highlights: [
        'Baịbụl n\'asụsụ Igbo yana ọgụgụ ọdịyo',
        'Egwuregwu iburu amaokwu n\'isi maka ezinụlọ',
        'Ihe ọmụmụ maka ito eto n\'okwukwe',
      ],
    ),
    AppTourStep(
      id: 'step_prayer',
      title: 'Ekpere 24/7 & Ndị Arịrịọ',
      subtitle: 'Arịrịọ Ekpere, Mkpebi & Àmà',
      description:
          'Nweta ike ekpere ọnụ n\'ofe Nigeria. Zipu arịrịọ ekpere n\'ihu ọha ma ọ bụ na nzuzo ma kpee ekpere maka ụmụnna.',
      faIcon: FontAwesomeIcons.personPraying,
      accentColor: Color(0xFF8B5CF6),
      route: '/prayer',
      targetArea: 'prayer',
      highlights: [
        'Zipu arịrịọ ekpere ngwa ngwa',
        'Kpeere ndị ọzọ ekpere site n\'otu mmetụ',
        'Mgbidi àmà iji too Chineke',
      ],
    ),
    AppTourStep(
      id: 'step_health',
      title: 'Ahụike & Ọdịmma zuru oke',
      subtitle: 'Ụkpụrụ NEWSTART & Nri Dị Mma',
      description:
          'Lekọta ahụ gị dịka ụlọ nsọ nke Mụọ Nsọ site na ndụmọdụ ahụike sitere na Baịbụl.',
      icon: Icons.health_and_safety_rounded,
      accentColor: Color(0xFF059669),
      route: '/health',
      targetArea: 'health',
      highlights: [
        'Ụkpụrụ ndụ NEWSTART kwa ụbọchị',
        'Nri ndị na-edozi ahụ sitere n\'ala anyị',
        'Ọgwụgwọ eke bara uru maka mgbochi',
      ],
    ),
    AppTourStep(
      id: 'step_more',
      title: 'Ihe Ndị Ọzọ Maka Ozi Ọma',
      subtitle: 'Akwụkwọ, Podcasts & Ụmụaka',
      description:
          'Nyochaa ngwa ọrụ ALIVE niile: traktị maka ozi ọma, ọdịyo podcasts, na akụkọ Baịbụl ụmụaka.',
      icon: Icons.grid_view_rounded,
      accentColor: Color(0xFFF59E0B),
      route: '/more',
      targetArea: 'more',
      highlights: [
        'Traktị ozi ọma n\'ụdị PDF na ngwa',
        'Podcasts nke nkuzi na egwu',
        'Akụkọ Baịbụl maka ụmụaka nwere ihe nrite',
      ],
    ),
    AppTourStep(
      id: 'step_conference',
      title: 'Nzukọ Ndụ & Ndekọ',
      subtitle: 'Vidio LiveKit & Mkpebi Nzukọ',
      description:
          'Jikọọ na ndị isi na ndị otu na nzukọ vidio ozugbo yana idekọ mkpebi nzukọ.',
      icon: Icons.video_camera_front_rounded,
      accentColor: Color(0xFFD946EF),
      route: '/conference',
      targetArea: 'conference',
      highlights: [
        'Ọnụ ụlọ nzukọ vidio ngwa ngwa LiveKit',
        'Ndekọ mkpebi nzukọ ozugbo',
        'Ịkekọrịta faịlụ n\'etiti ndị isi',
      ],
    ),
    AppTourStep(
      id: 'step_donations',
      title: 'Inye Onyinye & Mmekọrịta Ozi',
      subtitle: 'Inye Onyinye site na Paystack',
      description:
          'Kwado ibipụta traktị na ozi ọma na Mahadum na Nigeria site na Paystack na nchekwa.',
      icon: Icons.volunteer_activism_rounded,
      accentColor: Color(0xFFE11D48),
      route: '/donations',
      targetArea: 'donations',
      highlights: [
        'Họrọ ebe onyinye gị ga-aga',
        'Nweta akwụkwọ ọnụahịa ozugbo',
        'Inye onyinye nke ngwa ọrụ na akụrụngwa',
      ],
    ),
    AppTourStep(
      id: 'step_language',
      title: 'Asụsụ Ndị Dị na Nigeria',
      subtitle: 'Bekee, Yorùbá, Hausa & Igbo',
      description:
          'Kpatụ akara ụwa dị n\'elu ka ị gbanwee ngwa ahụ gaa n\'asụsụ masịrị gị n\'oge ọ bụla.',
      icon: Icons.translate_rounded,
      accentColor: Color(0xFF0284C7),
      route: '/settings/language',
      targetArea: 'language',
      highlights: [
        'Gbanwee n\'etiti Bekee, Yorùbá, Hausa na Igbo',
        'Amaokwu Baịbụl n\'asụsụ gị',
        'Chekwaa nhọrọ gị ozugbo',
      ],
    ),
  ];
}
