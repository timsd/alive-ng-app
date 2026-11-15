import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_models.dart';
import 'notification_service.dart';

class BirthdayGreeting {
  final String title;
  final String message;
  final String scriptureText;
  final String scriptureRef;

  const BirthdayGreeting({
    required this.title,
    required this.message,
    required this.scriptureText,
    required this.scriptureRef,
  });
}

/// Generates dynamic, personalized birthday greetings and Bible promises that
/// rotate year after year for each celebrant.
class BirthdayGreetingService {
  BirthdayGreetingService._();

  static const List<({String theme, String body, String verse, String ref})>
      _blessings = [
    (
      theme: 'Purpose & Hope',
      body:
          'May this new year of your life overflow with divine direction, peace, and breakthroughs in every area of your calling.',
      verse:
          'For I know the plans I have for you, declares the Lord, plans to prosper you and not to harm you, plans to give you hope and a future.',
      ref: 'Jeremiah 29:11',
    ),
    (
      theme: 'Favor & Peace',
      body:
          'As you celebrate another year of God\'s faithfulness, may His face shine upon you and surround you with enduring grace.',
      verse:
          'The Lord bless you and keep you; the Lord make his face shine upon you and be gracious to you.',
      ref: 'Numbers 6:24-25',
    ),
    (
      theme: 'Renewed Strength',
      body:
          'Step into this new chapter with fresh strength and joy. God\'s mercies are brand new for you today and all year long.',
      verse:
          'But those who hope in the Lord will renew their strength. They will soar on wings like eagles.',
      ref: 'Isaiah 40:31',
    ),
    (
      theme: 'Heart\'s Desires',
      body:
          'Happy Birthday! May the Lord honor the prayers of your heart and establish the good work of your hands this year.',
      verse:
          'May he give you the desire of your heart and make all your plans succeed.',
      ref: 'Psalm 20:4',
    ),
    (
      theme: 'Abundant Joy',
      body:
          'Rejoice in the gift of another year! Your life is a testimony of God\'s goodness—may your joy be full today.',
      verse:
          'This is the day the Lord has made; let us rejoice and be glad in it.',
      ref: 'Psalm 118:24',
    ),
    (
      theme: 'Guided Steps',
      body:
          'As you turn a new page, trust the Lord with every dream ahead—He will make your paths straight and fruitful.',
      verse:
          'Trust in the Lord with all your heart and lean not on your own understanding; in all your ways submit to him, and he will make your paths straight.',
      ref: 'Proverbs 3:5-6',
    ),
    (
      theme: 'Health & Prosperity',
      body:
          'Praying that you flourish spiritually, physically, and in every ministry endeavor throughout this new year of life.',
      verse:
          'Dear friend, I pray that you may enjoy good health and that all may go well with you, even as your soul is getting along well.',
      ref: '3 John 1:2',
    ),
    (
      theme: 'Exceeding Grace',
      body:
          'May God surprise you this year with blessings beyond what you could ask or imagine as you walk closely with Him.',
      verse:
          'Now to him who is able to do immeasurably more than all we ask or imagine, according to his power that is at work within us.',
      ref: 'Ephesians 3:20',
    ),
    (
      theme: 'Faithful Mercies',
      body:
          'Thanking God for another year of your life! His unfailing love and compassion will carry you through every season ahead.',
      verse:
          'Because of the Lord\'s great love we are not consumed, for his compassions never fail. They are new every morning; great is your faithfulness.',
      ref: 'Lamentations 3:22-23',
    ),
    (
      theme: 'Divine Protection',
      body:
          'Happy Birthday! Walk boldly into your new year knowing the Almighty watches over your going out and coming in.',
      verse:
          'For he will command his angels concerning you to guard you in all your ways.',
      ref: 'Psalm 91:11',
    ),
  ];

  static bool isBirthdayToday(DateTime? dateOfBirth, [DateTime? now]) {
    if (dateOfBirth == null) return false;
    final today = now ?? DateTime.now();
    return dateOfBirth.month == today.month && dateOfBirth.day == today.day;
  }

  /// Generates a personalized greeting whose message and Bible promise change
  /// automatically each calendar year for the celebrant.
  static BirthdayGreeting generateForUser(
    UserProfile profile, {
    int? year,
  }) {
    final targetYear = year ?? DateTime.now().year;
    final rawName = (profile.fullName ?? '').trim();
    final firstName =
        rawName.isNotEmpty ? rawName.split(RegExp(r'\s+')).first : 'Friend';

    final seed = (targetYear + profile.id.hashCode.abs()) % _blessings.length;
    final blessing = _blessings[seed];

    return BirthdayGreeting(
      title: 'Happy Birthday, $firstName! (${blessing.theme})',
      message: blessing.body,
      scriptureText: '"${blessing.verse}"',
      scriptureRef: blessing.ref,
    );
  }

  /// Triggers a local birthday notification once per year on the user's birthday.
  static Future<void> maybeNotifyBirthdayToday(UserProfile profile) async {
    if (!isBirthdayToday(profile.dateOfBirth)) return;
    final now = DateTime.now();
    final prefsKey = 'birthday_notified_${profile.id}_${now.year}';
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(prefsKey) == true) return;

      final greeting = generateForUser(profile, year: now.year);
      await NotificationService.instance.showNotification(
        id: 77000 + (now.year % 1000),
        title: greeting.title,
        body:
            '${greeting.message} ${greeting.scriptureText} — ${greeting.scriptureRef}',
        payload: jsonEncode({'type': 'birthday', 'route': '/profile'}),
      );
      await prefs.setBool(prefsKey, true);
    } catch (_) {}
  }
}
