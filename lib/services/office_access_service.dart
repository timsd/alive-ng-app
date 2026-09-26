import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../config/appwrite_backend_config.dart';
import '../config/org_structure.dart';
import '../main.dart';
import '../utils/logger.dart';
import 'appwrite_facade.dart';

/// One office held by one person, as stored in `org_office_holders`.
class OfficeHolder {
  final String officeId;
  final String? userId;
  final String fullName;
  final String? email;

  const OfficeHolder({
    required this.officeId,
    this.userId,
    required this.fullName,
    this.email,
  });

  factory OfficeHolder.fromDocument(Map<String, dynamic> doc) => OfficeHolder(
        officeId: (doc['office_id'] as String? ?? '').trim(),
        userId: _clean(doc['user_id'] ?? doc['holder_user_id']),
        fullName: (doc['full_name'] as String? ??
                doc['holder_name'] as String? ??
                '')
            .trim(),
        email: _clean(doc['email'] ??
            doc['holder_email'] ??
            doc['officer_email']),
      );

  static String? _clean(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

/// Answers "which offices does this person hold?" from the server.
///
/// This is the single source of truth for office-based access control. It
/// replaces the older per-device map in SharedPreferences
/// (`alive_officer_office_assignments`), which could be edited on one handset
/// and so could not be trusted to gate anything financial.
///
/// Offices are matched to an account by `user_id` first, then by email.
/// A display name is deliberately NOT a match key: anyone can set their
/// profile name, so matching on it would let a member claim the Treasurer's
/// office by renaming themselves.
class OfficeAccessService {
  OfficeAccessService._();
  static final OfficeAccessService instance = OfficeAccessService._();

  static final Logger _logger = Logger('OfficeAccessService');
  static const Duration _cacheDuration = Duration(minutes: 5);

  // The org tables are reached through TablesDB, matching
  // LeadershipService and PrayerRequestsService.
  static final TablesDB _tables = TablesDB(appwriteClient);

  List<OfficeHolder>? _cache;
  DateTime? _cachedAt;
  bool _loading = false;
  Completer<List<OfficeHolder>>? _inFlight;

  /// The financial offices: Treasurer and Executive President.
  ///
  /// Finance is gated on the office rather than on the role ladder, because
  /// `treasurer`/`president` are offices in `org_structure.dart` -- the role
  /// hierarchy has no such entries.
  static const Set<String> financeOfficeIds = {
    'treasurer',
    'executive_president',
  };

  /// Offices held by [userId] (and optionally [email]).
  Future<List<OfficeHolder>> officesFor({
    String? userId,
    String? email,
    bool forceRefresh = false,
  }) async {
    final holders = await _load(forceRefresh: forceRefresh);
    if (holders.isEmpty) return const [];

    final normalizedEmail = email?.trim().toLowerCase() ?? '';
    return holders.where((h) {
      if (userId != null && userId.isNotEmpty && h.userId == userId) return true;
      if (normalizedEmail.isNotEmpty &&
          h.email != null &&
          h.email!.toLowerCase() == normalizedEmail) {
        return true;
      }
      return false;
    }).toList();
  }

  /// Whether the person holds any of [officeIds].
  Future<bool> holdsAnyOffice(
    Iterable<String> officeIds, {
    String? userId,
    String? email,
  }) async {
    final wanted = officeIds.toSet();
    if (wanted.isEmpty) return false;
    final mine = await officesFor(userId: userId, email: email);
    return mine.any((h) => wanted.contains(h.officeId));
  }

  /// Whether this person may see donations and finance.
  Future<bool> canAccessFinance({String? userId, String? email}) async {
    return holdsAnyOffice(financeOfficeIds, userId: userId, email: email);
  }

  /// Discards the cache; call after an admin changes an assignment.
  void invalidate() {
    _cache = null;
    _cachedAt = null;
  }

  Future<List<OfficeHolder>> _load({bool forceRefresh = false}) {
    final cached = _cache;
    final at = _cachedAt;
    final fresh = cached != null &&
        at != null &&
        DateTime.now().difference(at) < _cacheDuration;
    if (fresh && !forceRefresh) return Future.value(cached);
    if (_loading && _inFlight != null) return _inFlight!.future;

    final completer = Completer<List<OfficeHolder>>();
    _inFlight = completer;
    _loading = true;

    () async {
      try {
        final response = await _tables.listRows(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
          queries: [Query.limit(200)],
        );
        final holders = response.rows
            .map((r) => OfficeHolder.fromDocument(r.data))
            .where((h) => h.officeId.isNotEmpty)
            .toList();
        _cache = holders;
        _cachedAt = DateTime.now();
        completer.complete(holders);
      } catch (e, s) {
        // A failed read must not crash the caller, and must not grant access:
        // completing empty means "holds no office", so the caller denies.
        _logger.error('Failed to load office holders', e, s);
        completer.complete(const <OfficeHolder>[]);
      } finally {
        _loading = false;
        _inFlight = null;
      }
    }();

    return completer.future;
  }

  // ── Legacy migration ───────────────────────────────────────────────────

  /// Copies the old per-device officer assignments into `org_office_holders`.
  ///
  /// Runs once per device. Returns how many were written. If any holder row
  /// is already bound to a real account the legacy rows are discarded rather
  /// than written, so a stale handset cannot overwrite good data.
  static Future<int> migrateLegacyAssignments({
    required String ownerUserId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList('alive_officer_office_assignments');
      if (raw == null || raw.isEmpty) return 0;

      final existing = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
        queries: [Query.limit(200)],
      );
      final alreadyBound = existing.rows
          .where((d) => (d.data['user_id'] as String? ?? '').isNotEmpty)
          .length;
      if (alreadyBound > 0) {
        await prefs.remove('alive_officer_office_assignments');
        return 0;
      }

      var written = 0;
      for (final line in raw) {
        final map = _decodeAssignment(line);
        if (map == null) continue;
        final title = (map['office_title'] as String? ?? '').trim();
        await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.orgOfficeHoldersCollectionId,
          rowId: ID.unique(),
          data: {
            // The legacy row stored a free-text title, so it is resolved to
            // the registry's office_id where it matches one.
            'office_id': officeIdForTitle(title) ?? title,
            'user_id': map['officer_id'] ?? '',
            'full_name': map['officer_name'] ?? '',
            'email': map['officer_email'] ?? '',
            'migrated_from': 'shared_preferences',
            'migrated_at': DateTime.now().toUtc().toIso8601String(),
            'migrated_by': ownerUserId,
          },
        );
        written++;
      }
      if (written > 0) await prefs.remove('alive_officer_office_assignments');
      return written;
    } catch (e, s) {
      _logger.error('Legacy officer migration failed', e, s);
      return 0;
    }
  }

  static Map<String, dynamic>? _decodeAssignment(String line) {
    try {
      final decoded = jsonDecode(line);
      return decoded is Map<String, dynamic> ? decoded : null;
    } catch (_) {
      return null;
    }
  }

  /// Resolves a legacy free-text office title to a registry `office_id`.
  static String? officeIdForTitle(String title) {
    final wanted = title.trim().toLowerCase();
    for (final office in kOrgOffices) {
      if (office.title.toLowerCase() == wanted) return office.id;
    }
    return null;
  }
}
