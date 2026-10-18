import 'package:flutter/foundation.dart';
import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';
import '../utils/logger.dart';

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

      // 1. General Channel: All active members
      await _ensureMembership(
        tables: tables,
        channelId: channelGeneralId,
        userId: userId,
        shouldBeMember: !profile.isArchived,
      );

      // 2. Singles vs Married Channels
      final isMarried = (profile.maritalStatus ?? '').trim().toLowerCase() == 'married';
      final isSingle = !isMarried && !profile.isArchived;

      await _ensureMembership(
        tables: tables,
        channelId: channelSinglesId,
        userId: userId,
        shouldBeMember: isSingle,
      );

      await _ensureMembership(
        tables: tables,
        channelId: channelMarriedId,
        userId: userId,
        shouldBeMember: isMarried && !profile.isArchived,
      );

      // 3. Chapter Coordinators Channel
      final isCoordinator =
          profile.role.toLowerCase() == 'coordinator' && !profile.isArchived;

      await _ensureMembership(
        tables: tables,
        channelId: channelCoordinatorsId,
        userId: userId,
        shouldBeMember: isCoordinator,
      );

      // 4. Donors Channel: Users with donor role or financial commitment
      final commitType = (profile.commitmentType ?? '').trim().toLowerCase();
      final isDonor = !profile.isArchived &&
          (profile.role.toLowerCase().contains('donor') ||
              commitType == 'financial' ||
              commitType == 'both');

      await _ensureMembership(
        tables: tables,
        channelId: channelDonorsId,
        userId: userId,
        shouldBeMember: isDonor,
      );

      _logger.info('Synced channel memberships for user: $userId (married=$isMarried, coordinator=$isCoordinator, donor=$isDonor)');
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
