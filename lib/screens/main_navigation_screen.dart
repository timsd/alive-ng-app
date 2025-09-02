import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/theme_provider.dart';

class MainNavigationScreen extends ConsumerWidget {
  final Widget child;

  const MainNavigationScreen({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocation =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _getCurrentIndex(currentLocation),
        onTap: (index) => _onItemTapped(context, index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.book_outlined),
            activeIcon: Icon(Icons.book),
            label: 'Study',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today_outlined),
            activeIcon: Icon(Icons.calendar_today),
            label: 'Daily',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_outline),
            activeIcon: Icon(Icons.favorite),
            label: 'Prayer',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
      floatingActionButton: _buildThemeToggle(context, ref),
      floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
    );
  }

  int _getCurrentIndex(String location) {
    switch (location) {
      case AppConstants.homeRoute:
        return 0;
      case AppConstants.studyRoute:
        return 1;
      case AppConstants.dailyRoute:
        return 2;
      case AppConstants.prayerRoute:
        return 3;
      case AppConstants.profileRoute:
        return 4;
      default:
        return 0;
    }
  }

  void _onItemTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go(AppConstants.homeRoute);
        break;
      case 1:
        context.go(AppConstants.studyRoute);
        break;
      case 2:
        context.go(AppConstants.dailyRoute);
        break;
      case 3:
        context.go(AppConstants.prayerRoute);
        break;
      case 4:
        context.go(AppConstants.profileRoute);
        break;
    }
  }

  Widget _buildThemeToggle(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: FloatingActionButton(
        mini: true,
        onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        child: Icon(
          isDark ? Icons.light_mode : Icons.dark_mode,
        ),
      ),
    );
  }
}
