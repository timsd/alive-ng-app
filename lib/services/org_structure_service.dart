import 'dart:async';

import '../config/appwrite_backend_config.dart';
import '../config/org_structure.dart';
import '../main.dart';
import '../utils/logger.dart';
import 'appwrite_facade.dart';

/// A single office definition loaded from Appwrite (or seed data).
///
/// This is the *office* (e.g. "Director of Evangelism"), not the person in it.
/// The person is in [holderName] and can change without touching the office.
class DynamicOrgOffice {
  final String id;
  final String title;
  final String iconName;
  final String? reportsTo;
  final String? holderName;
  final String? holderEmail;
  final String? holderUserId;
  final bool namesRestrictedToLeadership;
  final List<String> memberNames;

  const DynamicOrgOffice({
    required this.id,
    required this.title,
    required this.iconName,
    this.reportsTo,
    this.holderName,
    this.holderEmail,
    this.holderUserId,
    this.namesRestrictedToLeadership = false,
    this.memberNames = const [],
  });

  /// Build from Appwrite document (org_offices + org_office_holders merged).
  factory DynamicOrgOffice.fromDocument(Map<String, dynamic> doc) {
    return DynamicOrgOffice(
      id: (doc['office_id'] as String? ?? doc['\$id'] as String? ?? '').trim(),
      title: (doc['title'] as String? ?? doc['office_title'] as String? ?? '').trim(),
      iconName: (doc['icon_name'] as String? ?? 'work').trim(),
      reportsTo: _clean(doc['reports_to']),
      holderName: _clean(doc['holder_name'] ?? doc['full_name']),
      holderEmail: _clean(doc['holder_email'] ?? doc['email']),
      holderUserId: _clean(doc['holder_user_id'] ?? doc['user_id']),
      namesRestrictedToLeadership: doc['restricted_names'] == true,
      memberNames: _parseList(doc['member_names']),
    );
  }

  /// Build from the local seed constant.
  factory DynamicOrgOffice.fromSeed(OrgOffice seed) => DynamicOrgOffice(
        id: seed.id,
        title: seed.title,
        iconName: seed.iconName,
        reportsTo: seed.reportsTo,
        holderName: seed.holderName,
        namesRestrictedToLeadership: seed.namesRestrictedToLeadership,
        memberNames: seed.memberNames,
      );

  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static List<String> _parseList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    if (value is String && value.isNotEmpty) {
      return value.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    }
    return const [];
  }
}

/// Loads the org-chart (offices + current holders) from Appwrite, falling back
/// to [kOrgOffices] when the server is unreachable.
///
/// **The office never changes; only the person holding it can change.**
///
/// Consumers should call e.g. [getDirectors], [getPresidentName],
/// [getOfficeHolder] instead of reading [kOrgOffices] directly.
class OrgStructureService {
  OrgStructureService._();
  static final OrgStructureService instance = OrgStructureService._();

  static final Logger _logger = Logger('OrgStructureService');
  static const Duration _cacheDuration = Duration(minutes: 5);

  static final TablesDB _tables = TablesDB(appwriteClient);

  List<DynamicOrgOffice>? _cache;
  DateTime? _cachedAt;
  bool _loading = false;
  Completer<List<DynamicOrgOffice>>? _inFlight;

  /// All offices, loaded from Appwrite or seed data.
  Future<List<DynamicOrgOffice>> getOffices({bool forceRefresh = false}) {
    return _load(forceRefresh: forceRefresh);
  }

  /// Directors: offices whose [reportsTo] is 'executive_president'.
  Future<List<DynamicOrgOffice>> getDirectors() async {
    final offices = await _load();
    return offices
        .where((o) => o.reportsTo == 'executive_president' && o.id != 'executive_president')
        .toList();
  }

  /// The full list of director *titles* (for dropdowns).
  Future<List<String>> getDirectorTitles() async {
    final dirs = await getDirectors();
    return dirs.map((d) => d.title).toList();
  }

  /// Returns the name of whoever currently holds the given office.
  Future<String?> getOfficeHolderName(String officeId) async {
    final offices = await _load();
    for (final o in offices) {
      if (o.id == officeId) return o.holderName;
    }
    return null;
  }

  /// Current Executive President name.
  Future<String> getPresidentName() async {
    final name = await getOfficeHolderName('executive_president');
    return name ?? 'Executive President';
  }

  /// Check if a user holds the Executive President office (by userId or name).
  Future<bool> isPresident({String? userId, String? name}) async {
    final offices = await _load();
    for (final o in offices) {
      if (o.id != 'executive_president') continue;
      if (userId != null && userId.isNotEmpty && o.holderUserId == userId) {
        return true;
      }
      if (name != null && name.isNotEmpty && o.holderName != null) {
        if (o.holderName!.toLowerCase().contains(name.toLowerCase())) {
          return true;
        }
      }
    }
    return false;
  }

  /// All Board of Directors members.
  Future<List<DynamicOrgOffice>> getBodMembers() async {
    final offices = await _load();
    return offices
        .where((o) =>
            o.id == 'board_of_directors' ||
            o.id == 'bod' ||
            o.reportsTo == 'board_of_directors')
        .toList();
  }

  /// Synchronous check from memory cache if a user is a BOD member.
  bool isBodMemberSync({String? userId, String? name}) {
    final list = _cache;
    if (list == null) return false;
    for (final o in list) {
      if (o.id == 'board_of_directors' ||
          o.id == 'bod' ||
          o.reportsTo == 'board_of_directors') {
        if (userId != null && userId.isNotEmpty && o.holderUserId == userId) {
          return true;
        }
        if (name != null && name.isNotEmpty && o.holderName != null) {
          if (o.holderName!.toLowerCase().contains(name.toLowerCase())) {
            return true;
          }
        }
      }
    }
    return false;
  }

  /// All Trustees.
  Future<List<DynamicOrgOffice>> getTrustees() async {
    final offices = await _load();
    return offices
        .where((o) =>
            o.id == 'board_of_trustees' || o.id == 'trustee')
        .toList();
  }

  /// Lookup a single office by its stable ID.
  Future<DynamicOrgOffice?> getOffice(String officeId) async {
    final offices = await _load();
    for (final o in offices) {
      if (o.id == officeId) return o;
    }
    return null;
  }

  /// Discards the cache; call after an admin changes an assignment.
  void invalidate() {
    _cache = null;
    _cachedAt = null;
  }

  Future<List<DynamicOrgOffice>> _load({bool forceRefresh = false}) {
    final cached = _cache;
    final at = _cachedAt;
    final fresh = cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheDuration;
    if (fresh && !forceRefresh) return Future.value(cached);
    if (_loading && _inFlight != null) return _inFlight!.future;

    final completer = Completer<List<DynamicOrgOffice>>();
    _inFlight = completer;
    _loading = true;

    () async {
      try {
        // 1. Load office definitions from org_offices
        final officesResponse = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.orgOfficesCollectionId,
          queries: [Query.limit(200)],
        );

        // 2. Load current holders from org_office_holders
        final holdersResponse = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
          queries: [Query.limit(200)],
        );

        // Build a map of office_id -> holder data
        final holderMap = <String, Map<String, dynamic>>{};
        for (final row in holdersResponse.rows) {
          final oid = (row.data['office_id'] as String? ?? '').trim();
          if (oid.isNotEmpty) holderMap[oid] = row.data;
        }

        // Merge: office definition + current holder
        final result = <DynamicOrgOffice>[];
        for (final row in officesResponse.rows) {
          final officeData = Map<String, dynamic>.from(row.data);
          final oid = (officeData['office_id'] as String? ?? officeData['\$id'] as String? ?? '').trim();

          // Merge holder info if available
          if (holderMap.containsKey(oid)) {
            final h = holderMap[oid]!;
            officeData['holder_name'] = h['full_name'] ?? h['holder_name'];
            officeData['holder_email'] = h['email'] ?? h['holder_email'];
            officeData['holder_user_id'] = h['user_id'] ?? h['holder_user_id'];
          }

          result.add(DynamicOrgOffice.fromDocument(officeData));
        }

        if (result.isNotEmpty) {
          _cache = result;
          _cachedAt = DateTime.now();
          if (!completer.isCompleted) completer.complete(result);
          return;
        }

        // If Appwrite returned empty, fall back to seed
        _logger.info('org_offices collection empty; using seed data from kOrgOffices');
        _completeSeed(completer, holderMap);
      } catch (e, s) {
        _logger.error('Failed to load org offices from Appwrite; using seed data', e, s);
        _completeSeed(completer, const {});
      } finally {
        _loading = false;
        _inFlight = null;
      }
    }();

    return completer.future;
  }

  void _completeSeed(Completer<List<DynamicOrgOffice>> completer, Map<String, Map<String, dynamic>> holderOverrides) {
    final seedOffices = kOrgOffices.map((seed) {
      final o = DynamicOrgOffice.fromSeed(seed);
      // Override holder with Appwrite data if available
      if (holderOverrides.containsKey(o.id)) {
        final h = holderOverrides[o.id]!;
        return DynamicOrgOffice(
          id: o.id,
          title: o.title,
          iconName: o.iconName,
          reportsTo: o.reportsTo,
          holderName: DynamicOrgOffice._clean(h['full_name'] ?? h['holder_name']) ?? o.holderName,
          holderEmail: DynamicOrgOffice._clean(h['email'] ?? h['holder_email']),
          holderUserId: DynamicOrgOffice._clean(h['user_id'] ?? h['holder_user_id']),
          namesRestrictedToLeadership: o.namesRestrictedToLeadership,
          memberNames: o.memberNames,
        );
      }
      return o;
    }).toList();

    _cache = seedOffices;
    _cachedAt = DateTime.now();
    if (!completer.isCompleted) completer.complete(seedOffices);
  }
}

