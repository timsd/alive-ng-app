// Chapter Constants for ALIVE Nigeria App
//
// The seed lists below are used as fallback when Appwrite is unreachable.
// At runtime, call [ChapterConstants.loadDynamicChapters()] to refresh
// from the server; the cached list is then returned by [availableChapters].

import '../services/chapter_service.dart';
import '../utils/logger.dart';

class ChapterConstants {
  static final Logger _logger = Logger('ChapterConstants');

  /// Seed / fallback chapter names — used until the first Appwrite fetch.
  static const List<String> _seedChapters = [
    'Ibadan',
    'Ife',
    'Abuja',
    'Lagos',
    'Benin',
    'Diaspora',
    'Kaduna',
    'Port Harcourt',
    'Lagos 1',
    'Lagos 2',
    'Lagos 3',
    'Babcock',
    'Abia',
    'Jos',
    'Calabar',
  ];

  /// In-memory dynamic cache, initially populated from seed.
  static List<String> _dynamicChapters = List.of(_seedChapters);

  /// Whether we have successfully loaded from Appwrite at least once.
  static bool _loaded = false;

  /// The chapter list to use everywhere in the app.
  ///
  /// Returns the Appwrite-loaded list when available, otherwise the seed list.
  static List<String> get availableChapters => _dynamicChapters;

  /// Refreshes [availableChapters] from Appwrite's chapters collection.
  ///
  /// Safe to call multiple times; first successful load sets [_loaded].
  /// On failure the previous (or seed) list remains in place.
  static Future<void> loadDynamicChapters() async {
    try {
      final chapters = await ChapterService().getChapters(isActive: true);
      if (chapters.isNotEmpty) {
        final names = chapters.map((c) => c.name).toList()..sort();
        _dynamicChapters = names;
        _loaded = true;
        _logger.info('Loaded ${names.length} chapters from Appwrite');
      } else {
        _logger.info('Chapters collection empty; keeping seed data (${_seedChapters.length} chapters)');
      }
    } catch (e) {
      _logger.error('Failed to load chapters from Appwrite; keeping ${_loaded ? "cached" : "seed"} data', e);
    }
  }

  /// Whether the dynamic list has been loaded from Appwrite.
  static bool get isLoaded => _loaded;

  static const Map<String, String> _seedDescriptions = {
    'Ibadan': 'ALIVE Nigeria Ibadan Chapter',
    'Ife': 'ALIVE Nigeria Ife Chapter',
    'Abuja': 'ALIVE Nigeria Abuja Chapter',
    'Lagos': 'ALIVE Nigeria Lagos Chapter',
    'Benin': 'ALIVE Nigeria Benin Chapter',
    'Diaspora': 'ALIVE Nigeria Diaspora Chapter',
    'Kaduna': 'ALIVE Nigeria Kaduna Chapter',
    'Port Harcourt': 'ALIVE Nigeria Port Harcourt Chapter',
    'Lagos 1': 'ALIVE Nigeria Lagos 1 Chapter',
    'Lagos 2': 'ALIVE Nigeria Lagos 2 Chapter',
    'Lagos 3': 'ALIVE Nigeria Lagos 3 Chapter',
    'Babcock': 'ALIVE Nigeria Babcock Chapter',
    'Abia': 'ALIVE Nigeria Abia Chapter',
    'Jos': 'ALIVE Nigeria Jos Chapter',
    'Calabar': 'ALIVE Nigeria Calabar Chapter',
  };

  /// Chapter descriptions. Returns dynamic map when loaded, otherwise seed.
  static Map<String, String> get chapterDescriptions {
    // Build from dynamic list: any chapter not in seed gets a generic desc.
    final result = <String, String>{};
    for (final ch in _dynamicChapters) {
      result[ch] = _seedDescriptions[ch] ?? 'ALIVE Nigeria $ch Chapter';
    }
    return result;
  }

  /// Roles an admin can assign from Role Management.
  ///
  /// `field_worker`, `campus_missionary`, `amtc_team`, and `dietist` are
  /// specialized functional roles sitting at the member privilege tier.
  /// They grant zero administrative permissions, but automatically enroll
  /// holders into their dedicated mission chat channels, team badges,
  /// and specialized broadcasts.
  static const List<String> userRoles = [
    'member',
    'field_worker',
    'campus_missionary',
    'amtc_team',
    'dietist',
    'coordinator',
    'leader',
    'director',
    'bod',
    'trustee',
    'admin',
    'super_admin',
  ];

  /// Roles that grant the Health+ content editor (recipes + remedies) but no
  /// other admin surface. Kept here so Role Management and the Health+ screen
  /// agree on exactly who qualifies.
  static const Set<String> healthContentRoles = {
    'dietist',
    'coordinator',
    'leader',
    'director',
    'bod',
    'trustee',
    'admin',
    'super_admin',
  };

  static const List<String> teamTypes = [
    'Field Workers',
    'Campus Missionary Team',
    'AMTC Team',
  ];

  static const Map<String, Map<String, dynamic>> rolePermissions = {
    'member': {
      'permissions': ['view_activities', 'join_activities', 'submit_reports'],
      'canCreateActivities': false,
      'canManageMembers': false,
    },
    'field_worker': {
      'permissions': ['view_activities', 'join_activities', 'submit_reports'],
      'canCreateActivities': false,
      'canManageMembers': false,
    },
    'campus_missionary': {
      'permissions': ['view_activities', 'join_activities', 'submit_reports'],
      'canCreateActivities': false,
      'canManageMembers': false,
    },
    'amtc_team': {
      'permissions': ['view_activities', 'join_activities', 'submit_reports'],
      'canCreateActivities': false,
      'canManageMembers': false,
    },
    'coordinator': {
      'permissions': [
        'view_activities',
        'join_activities',
        'submit_reports',
        'create_activities',
        'manage_activities'
      ],
      'canCreateActivities': true,
      'canManageMembers': true,
    },
    'director': {
      'permissions': [
        'view_activities',
        'join_activities',
        'submit_reports',
        'create_activities',
        'manage_activities',
        'manage_members',
        'approve_reports'
      ],
      'canCreateActivities': true,
      'canManageMembers': true,
    },
    'bod': {
      'permissions': [
        'view_activities',
        'join_activities',
        'submit_reports',
        'create_activities',
        'manage_activities',
        'manage_members',
        'approve_reports',
        'manage_chapter'
      ],
      'canCreateActivities': true,
      'canManageMembers': true,
    },
    'trustee': {
      'permissions': [
        'view_activities',
        'join_activities',
        'submit_reports',
        'create_activities',
        'manage_activities',
        'manage_members',
        'approve_reports',
        'manage_chapter'
      ],
      'canCreateActivities': true,
      'canManageMembers': true,
    },
  };

  static bool isValidChapter(String chapter) {
    return availableChapters.contains(chapter);
  }

  static bool isValidRole(String role) {
    return userRoles.contains(role);
  }

  static bool isValidTeamType(String teamType) {
    return teamTypes.contains(teamType);
  }
}
