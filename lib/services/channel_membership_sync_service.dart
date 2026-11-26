import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import 'appwrite_client.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';
import 'tag_parser.dart';

/// Service responsible for automatically synchronizing user memberships across
/// system chat channels (General, Singles, Married, Chapter Coordinators).
class ChannelMembershipSyncService {
  static final ChannelMembershipSyncService _instance =
      ChannelMembershipSyncService._internal();
  factory ChannelMembershipSyncService() => _instance;
  ChannelMembershipSyncService._internal();

  static ChannelMembershipSyncService get instance => _instance;

  final Logger _logger = Logger('ChannelMembershipSyncService');
  static const String databaseId = AppwriteBackendConfig.databaseId;
  static const String channelsCollectionId =
      AppwriteBackendConfig.chatChannelsCollectionId;

  static const String channelGeneralId = 'channel_general';
  static const String channelSinglesId = 'channel_singles';
  static const String channelMarriedId = 'channel_married';
  static const String channelCoordinatorsId = 'channel_coordinators';
  static const String channelDonorsId = 'channel_donors';
  static const String channelBodId = 'channel_bod';
  static const String channelFieldWorkersId = 'channel_field_workers';
  static const String channelCampusMissionariesId = 'channel_campus_missionaries';
  static const String channelAmtcId = 'channel_amtc';
  static const String tagConfigKey = 'chat_tag_configuration';

  List<Map<String, dynamic>>? _cachedRoleBridges;
  DateTime? _tagConfigFetchedAt;

  void invalidateTagConfigCache() {
    _cachedRoleBridges = null;
    _tagConfigFetchedAt = null;
  }

  /// Fetches `chat_tag_configuration` from `app_settings` (cached 5 minutes)
  /// and applies it to [TagParser] as well.
  Future<List<Map<String, dynamic>>> loadTagConfiguration({
    bool forceRefresh = false,
  }) async {
    final now = DateTime.now();
    if (!forceRefresh &&
        _cachedRoleBridges != null &&
        _tagConfigFetchedAt != null &&
        now.difference(_tagConfigFetchedAt!) < const Duration(minutes: 5)) {
      return _cachedRoleBridges!;
    }
    try {
      final tables = TablesDB(appwriteClient);
      final res = await tables.listRows(
        databaseId: databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [Query.equal('key', tagConfigKey), Query.limit(1)],
      );
      if (res.rows.isNotEmpty) {
        final raw = (res.rows.first.data['value'] ?? '').toString().trim();
        if (raw.isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map) {
            final bridges = (decoded['role_bridges'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const <Map<String, dynamic>>[];
            final specialTags = (decoded['special_tags'] as List?)
                    ?.whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList() ??
                const <Map<String, dynamic>>[];
            TagParser.applyRemoteConfig(
              roleBridges: bridges,
              specialTags: specialTags,
            );
            _cachedRoleBridges = bridges;
            _tagConfigFetchedAt = now;
            return bridges;
          }
        }
      }
    } catch (e) {
      _logger.warning('Could not load chat_tag_configuration: $e');
    }
    return _cachedRoleBridges ?? const <Map<String, dynamic>>[];
  }

  bool _isBridgeEnabled(
    List<Map<String, dynamic>> bridges,
    String defaultChannelId,
  ) {
    if (bridges.isEmpty) return true;
    final match = bridges.where(
      (b) => (b['channelId'] ?? '').toString() == defaultChannelId,
    );
    if (match.isEmpty) return true;
    return match.first['enabled'] != false;
  }

  String _resolvedChannelId(
    List<Map<String, dynamic>> bridges,
    String roleKeyword,
    String fallbackChannelId,
  ) {
    for (final b in bridges) {
      final r = (b['role'] ?? '').toString().toLowerCase();
      final cid = (b['channelId'] ?? '').toString().trim();
      if (r.contains(roleKeyword) && cid.isNotEmpty) {
        return cid;
      }
    }
    return fallbackChannelId;
  }

  /// Synchronize a user's channel memberships based on their current profile.
  /// Automatically handles:
  /// - Auto-enrollment in General
  /// - Singles vs Married migration (when status changes)
  /// - Coordinator assignment or removal
  Future<void> syncUserChannels(UserProfile profile) async {
    final userId = profile.id;
    if (userId.isEmpty) return;

    try {
      final tables = TablesDB(appwriteClient);
      final bridges = await loadTagConfiguration();
      final role = profile.role.toLowerCase();
      final isMarried =
          (profile.maritalStatus ?? '').trim().toLowerCase() == 'married';
      final isSingle = !isMarried && !profile.isArchived;
      final isCoordinator = role == 'coordinator' && !profile.isArchived;
      final commitType = (profile.commitmentType ?? '').trim().toLowerCase();
      final isDonor = !profile.isArchived &&
          (role.contains('donor') ||
              commitType == 'financial' ||
              commitType == 'both');
      final isBod = !profile.isArchived &&
          (role == 'bod' ||
              role == 'admin' ||
              role == 'super_admin' ||
              role == 'trustee' ||
              role == 'director' ||
              role.contains('bod') ||
              role.contains('trustee') ||
              role.contains('director'));

      final isLeadership = !profile.isArchived &&
          (role == 'admin' ||
              role == 'super_admin' ||
              role == 'bod' ||
              role == 'board' ||
              role.contains('director') ||
              role.contains('trustee') ||
              role.contains('president') ||
              AppwriteBackendConfig.isSuperAdminEmail(profile.email));

      // 1. General Channel: All active members
      final generalId =
          _resolvedChannelId(bridges, 'all active', channelGeneralId);
      if (_isBridgeEnabled(bridges, generalId)) {
        await _ensureMembership(
          tables: tables,
          channelId: generalId,
          userId: userId,
          shouldBeMember: !profile.isArchived,
        );
      }

      // 2. Singles vs Married Channels
      final singlesId = _resolvedChannelId(bridges, 'single', channelSinglesId);
      if (_isBridgeEnabled(bridges, singlesId)) {
        await _ensureMembership(
          tables: tables,
          channelId: singlesId,
          userId: userId,
          shouldBeMember: isSingle,
        );
      }

      final marriedId =
          _resolvedChannelId(bridges, 'married', channelMarriedId);
      if (_isBridgeEnabled(bridges, marriedId)) {
        await _ensureMembership(
          tables: tables,
          channelId: marriedId,
          userId: userId,
          shouldBeMember: isMarried && !profile.isArchived,
        );
      }

      // 3. Chapter Coordinators Channel
      final coordinatorsId =
          _resolvedChannelId(bridges, 'coordinator', channelCoordinatorsId);
      if (_isBridgeEnabled(bridges, coordinatorsId)) {
        await _ensureMembership(
          tables: tables,
          channelId: coordinatorsId,
          userId: userId,
          shouldBeMember: isCoordinator,
        );
      }

      // 4. Donors Channel: Users with donor role or financial commitment
      final donorsId = _resolvedChannelId(bridges, 'donor', channelDonorsId);
      if (_isBridgeEnabled(bridges, donorsId)) {
        await _ensureMembership(
          tables: tables,
          channelId: donorsId,
          userId: userId,
          shouldBeMember: isDonor,
        );
      }

      // 5. Board of Directors (BOD) Channel
      final bodId = _resolvedChannelId(bridges, 'bod', channelBodId);
      if (_isBridgeEnabled(bridges, bodId)) {
        await _ensureMembership(
          tables: tables,
          channelId: bodId,
          userId: userId,
          shouldBeMember: isBod,
        );
      }

      // 6. Field Workers Channel (Field Workers + Full Leadership/Admin Oversight)
      final isFieldWorker = !profile.isArchived &&
          (role == 'field_worker' ||
              role.contains('field_worker') ||
              isLeadership);
      final fieldWorkersId =
          _resolvedChannelId(bridges, 'field_worker', channelFieldWorkersId);
      if (_isBridgeEnabled(bridges, fieldWorkersId)) {
        await _ensureMembership(
          tables: tables,
          channelId: fieldWorkersId,
          userId: userId,
          shouldBeMember: isFieldWorker,
        );
      }

      // 7. Campus Missionary Team Channel (Campus Missionaries + Full Leadership/Admin Oversight)
      final isCampusMissionary = !profile.isArchived &&
          (role == 'campus_missionary' ||
              role.contains('campus_missionary') ||
              isLeadership);
      final campusId = _resolvedChannelId(
          bridges, 'campus_missionary', channelCampusMissionariesId);
      if (_isBridgeEnabled(bridges, campusId)) {
        await _ensureMembership(
          tables: tables,
          channelId: campusId,
          userId: userId,
          shouldBeMember: isCampusMissionary,
        );
      }

      // 8. AMTC Team Channel (AMTC Team + Full Leadership/Admin Oversight)
      final isAmtc = !profile.isArchived &&
          (role == 'amtc_team' || role.contains('amtc_team') || isLeadership);
      final amtcId = _resolvedChannelId(bridges, 'amtc_team', channelAmtcId);
      if (_isBridgeEnabled(bridges, amtcId)) {
        await _ensureMembership(
          tables: tables,
          channelId: amtcId,
          userId: userId,
          shouldBeMember: isAmtc,
        );
      }

      // 9. Custom admin-defined role bridges from chat_tag_configuration
      final builtInChannelIds = {
        generalId,
        singlesId,
        marriedId,
        coordinatorsId,
        donorsId,
        bodId,
        fieldWorkersId,
        campusId,
        amtcId,
      };
      for (final bridge in bridges) {
        if (bridge['enabled'] == false) continue;
        final cid = (bridge['channelId'] ?? '').toString().trim();
        final rawRole = (bridge['role'] ?? '').toString().trim().toLowerCase();
        if (cid.isEmpty ||
            rawRole.isEmpty ||
            builtInChannelIds.contains(cid)) {
          continue;
        }
        final tokens = rawRole
            .split(RegExp(r'[/,]'))
            .map((e) => e.replaceAll(RegExp(r'\([^)]*\)'), '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
        final matchesCustom = !profile.isArchived &&
            tokens.any((t) => role == t || role.contains(t));
        await _ensureMembership(
          tables: tables,
          channelId: cid,
          userId: userId,
          shouldBeMember: matchesCustom,
        );
      }

      // 10. Organization Leadership Auto-Access across active channels and chapters

      if (isLeadership) {
        try {
          final allChannels = await tables.listRows(
            databaseId: databaseId,
            tableId: channelsCollectionId,
            queries: [
              Query.equal('is_archived', false),
              Query.limit(100),
            ],
          );
          for (final doc in allChannels.rows) {
            final channelType = (doc.data['type'] ?? '').toString().toLowerCase().trim();
            if (channelType == 'direct') {
              continue; // Never auto-add leadership into private 1-on-1 DMs
            }
            final desc = (doc.data['description'] ?? '').toString().toLowerCase();
            bool settingsSecluded = false;
            final rawSettings = doc.data['settings'];
            if (rawSettings is Map) {
              settingsSecluded = rawSettings['exclude_leadership'] == true ||
                  rawSettings['is_secluded'] == true;
            } else if (rawSettings is String && rawSettings.trim().startsWith('{')) {
              try {
                final decoded = jsonDecode(rawSettings);
                if (decoded is Map) {
                  settingsSecluded = decoded['exclude_leadership'] == true ||
                      decoded['is_secluded'] == true;
                }
              } catch (_) {}
            }
            final isSecluded = settingsSecluded ||
                doc.data['exclude_leadership'] == true ||
                doc.data['is_secluded'] == true ||
                desc.contains('[secluded]');
            if (!isSecluded) {
              await _ensureMembership(
                tables: tables,
                channelId: doc.$id,
                userId: userId,
                shouldBeMember: true,
              );
            }
          }
        } catch (e) {
          _logger.warning('Auto-membership across channels for leader note: $e');
        }
      }

      _logger.info('Synced channel memberships for user: $userId (married=$isMarried, bod=$isBod, leader=$isLeadership, coordinator=$isCoordinator, donor=$isDonor)');
    } catch (e) {
      _logger.warning('Channel sync note: $e');
    }
  }

  /// Explicitly add a user to the donors channel (called after successful donation).
  Future<void> addDonorToChannel(String userId) async {
    if (userId.isEmpty) return;
    try {
      final tables = TablesDB(appwriteClient);
      await _ensureMembership(
        tables: tables,
        channelId: channelDonorsId,
        userId: userId,
        shouldBeMember: true,
      );
      _logger.info('Added user $userId to donors channel after donation.');
    } catch (e) {
      _logger.warning('Failed to add donor to channel: $e');
    }
  }

  Future<void> _ensureMembership({
    required TablesDB tables,
    required String channelId,
    required String userId,
    required bool shouldBeMember,
  }) async {
    try {
      final doc = await tables.getRow(
        databaseId: databaseId,
        tableId: channelsCollectionId,
        rowId: channelId,
      );

      final currentMembers = List<String>.from(doc.data['members'] ?? []);
      final containsUser = currentMembers.contains(userId);

      if (shouldBeMember && !containsUser) {
        currentMembers.add(userId);
        await tables.updateRow(
          databaseId: databaseId,
          tableId: channelsCollectionId,
          rowId: channelId,
          data: {
            'members': currentMembers,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      } else if (!shouldBeMember && containsUser) {
        currentMembers.remove(userId);
        await tables.updateRow(
          databaseId: databaseId,
          tableId: channelsCollectionId,
          rowId: channelId,
          data: {
            'members': currentMembers,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugPrint('Sync membership for $channelId failed: $e');
    }
  }
}
