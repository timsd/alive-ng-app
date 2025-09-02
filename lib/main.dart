import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'providers/theme_provider.dart';
import 'providers/language_provider.dart';
import 'utils/app_router.dart';
import 'utils/app_theme.dart';
import 'constants/app_constants.dart';
import 'config/firebase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: FirebaseConfig.currentPlatform,
  );

  // Initialize Firebase services
  await FirebaseConfig.initializeFirebaseCore();
  await FirebaseConfig.initializeFirebaseMessaging();
  await FirebaseConfig.initializeFirebaseAnalytics();
  await FirebaseConfig.initializeFirebaseCrashlytics();

  // Initialize Supabase
  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(
    const ProviderScope(
      child: AliveApp(),
    ),
  );
}

class AliveApp extends ConsumerWidget {
  const AliveApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ALIVE NG',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Localization
      locale: locale,
      supportedLocales: const [
        Locale('en', 'US'), // English
        Locale('yo', 'NG'), // Yoruba
        Locale('ig', 'NG'), // Igbo
        Locale('ha', 'NG'), // Hausa
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      // Routing
      routerConfig: router,
    );
  }
}
