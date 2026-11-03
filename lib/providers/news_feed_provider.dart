import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/appwrite_events_service.dart';

/// Tracks how many News Feed items (events + announcements, including
/// "Live now" meeting posts) were published since the user last opened
/// the News Feed. Drives the badge on the Home top navigation icon.
class NewsFeedUnreadNotifier extends StateNotifier<int> {
  NewsFeedUnreadNotifier() : super(0) {
    refresh();
    // Light polling so new drops show up without a manual refresh.
    _timer = Timer.periodic(const Duration(minutes: 2), (_) => refresh());
  }

  static const String _lastSeenKey = 'news_feed_last_seen_at';
  Timer? _timer;

  Future<void> refresh() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenMs = prefs.getInt(_lastSeenKey);
      // First launch: only count what was dropped in the last 7 days.
      final since = lastSeenMs != null
          ? DateTime.fromMillisecondsSinceEpoch(lastSeenMs)
          : DateTime.now().subtract(const Duration(days: 7));

      final service = AppwriteEventsService.instance;
      final dates = <DateTime?>[];
      try {
        dates.addAll((await service.listEvents()).map((e) => e.createdAt));
      } catch (_) {}
      try {
        dates.addAll(
            (await service.listAnnouncements()).map((a) => a.createdAt));
      } catch (_) {}

      final count =
          dates.where((d) => d != null && d.isAfter(since)).length;
      if (mounted) state = count;
    } catch (_) {
      // Network/permission issues should never break the home header.
    }
  }

  /// Called when the user opens the News Feed.
  Future<void> markAllSeen() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastSeenKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
    if (mounted) state = 0;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

final newsFeedUnreadProvider =
    StateNotifierProvider<NewsFeedUnreadNotifier, int>(
  (ref) => NewsFeedUnreadNotifier(),
);
