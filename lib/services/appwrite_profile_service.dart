import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../models/app_models.dart';

final appwriteProfileServiceProvider = Provider<AppwriteProfileService>((ref) {
  return AppwriteProfileService();
});

class AppwriteProfileService {
  late final TablesDB _tables;

  AppwriteProfileService() {
    _tables = TablesDB(appwriteClient);
  }

  Future<models.Row?> getUserProfile(String userId) async {
    try {
      return await _tables.getRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: userId,
      );
    } on AppwriteException catch (e) {
      if (e.code == 404) {
        return null;
      }
      debugPrint('Appwrite profile load error: $e');
      return null;
    } catch (e) {
      debugPrint('General profile load error: $e');
      return null;
    }
  }

  Future<UserProfile?> getUserProfileModel(String userId) async {
    final document = await getUserProfile(userId);
    if (document == null) return null;
    return userProfileFromDocument(
      document,
      fallbackEmail: (document.data['email'] ?? '').toString(),
      fallbackFullName:
          (document.data['fullName'] ?? document.data['full_name'])?.toString(),
    );
  }

  Future<List<UserProfile>> getAllUsers() async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.usersCollectionId,
      queries: [
        Query.limit(500),
      ],
    );

    return response.rows.map((document) {
      return userProfileFromDocument(
        document,
        fallbackEmail: (document.data['email'] ?? '').toString(),
        fallbackFullName:
            (document.data['fullName'] ?? document.data['full_name'])
                ?.toString(),
      );
    }).toList();
  }

  Future<void> updateUserRole(String userId, String newRole) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.usersCollectionId,
      rowId: userId,
      data: {
        'role': newRole,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> archiveUser(String userId) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.usersCollectionId,
      rowId: userId,
      data: {
        'is_archived': true,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> deleteUserProfile(String userId) async {
    try {
      await _tables.deleteRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.usersCollectionId,
        rowId: userId,
      );
    } catch (_) {
      await archiveUser(userId);
    }
  }

  Future<void> archiveLeadershipRole(LeadershipRecord record) async {
    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.leadershipHistoryCollectionId,
      rowId: record.id,
      data: record.toJson()..remove('id'),
    );
  }

  Future<List<LeadershipRecord>> getLeadershipHistory(String userId) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.leadershipHistoryCollectionId,
      queries: [
        Query.equal('user_id', userId),
        Query.limit(100),
      ],
    );

    final records = response.rows.map((document) {
      return LeadershipRecord.fromJson({
        'id': document.$id,
        ...document.data,
      });
    }).toList();
    records.sort((a, b) => b.endDate.compareTo(a.endDate));
    return records;
  }

  Future<models.Row> ensureUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String role = 'member',
    Map<String, dynamic>? profileData,
  }) async {
    final existing = await getUserProfile(userId);
    if (existing != null) return existing;

    final resolvedRole = (profileData != null && profileData['role'] != null)
        ? profileData['role'].toString()
        : role;

    return createUserProfile(
      userId: userId,
      email: email,
      fullName: fullName,
      role: resolvedRole,
      profileData: profileData,
    );
  }

  Future<models.Row> createUserProfile({
    required String userId,
    required String email,
    required String fullName,
    String role = 'member',
    Map<String, dynamic>? profileData,
  }) {
    return _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.usersCollectionId,
      rowId: userId,
      data: _buildProfileData(
        email: email,
        fullName: fullName,
        role: role,
        profileData: profileData,
        includeDefaults: true,
      ),
    );
  }

  Future<models.Row> updateUserProfile({
    required String userId,
    String? email,
    String? fullName,
    String? role,
    Map<String, dynamic>? profileData,
  }) {
    final data = _buildProfileData(
      email: email,
      fullName: fullName,
      role: role,
      profileData: profileData,
      includeDefaults: false,
    );

    return _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.usersCollectionId,
      rowId: userId,
      data: data,
    );
  }

  UserProfile userProfileFromDocument(
    models.Row document, {
    required String fallbackEmail,
    String? fallbackFullName,
    bool? isEmailVerified,
    bool? isAnonymous,
    String? photoUrl,
  }) {
    final data = document.data;

    Map<String, dynamic>? additionalProfile;
    final rawAdditional = data['additional_profile'];
    if (rawAdditional is Map<String, dynamic>) {
      additionalProfile = rawAdditional;
    } else if (rawAdditional is String && rawAdditional.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawAdditional);
        if (decoded is Map<String, dynamic>) {
          additionalProfile = decoded;
        }
      } catch (_) {}
    }

    return UserProfile(
      id: document.$id,
      email: _stringValue(data, 'email') ?? fallbackEmail,
      fullName: _stringValue(data, 'fullName') ??
          _stringValue(data, 'full_name') ??
          fallbackFullName,
      avatarUrl: _stringValue(data, 'avatar_url'),
      photoUrl: _stringValue(data, 'photo_url') ?? photoUrl,
      isEmailVerified: _boolValue(data, 'is_email_verified') ?? isEmailVerified,
      isAnonymous: _boolValue(data, 'is_anonymous') ?? isAnonymous,
      provider: _stringValue(data, 'provider') ?? 'appwrite',
      dateOfBirth: _dateValue(data, 'date_of_birth'),
      phoneNumber: _stringValue(data, 'phone_number'),
      address: _stringValue(data, 'address'),
      bio: _stringValue(data, 'bio'),
      chapterId: _stringValue(data, 'chapter_id'),
      maritalStatus: _stringValue(data, 'marital_status') ?? 'single',
      role: _stringValue(data, 'role') ?? 'member',
      isArchived: _boolValue(data, 'is_archived') ?? false,
      isNewConvert: _boolValue(data, 'is_new_convert') ?? false,
      convertDate: _dateValue(data, 'convert_date'),
      isApproved: _boolValue(data, 'is_approved') ?? true,
      approvedBy: _stringValue(data, 'approved_by'),
      approvedAt: _dateValue(data, 'approved_at'),
      approvalStatus: _stringValue(data, 'approval_status') ?? 'approved',
      rejectionReason: _stringValue(data, 'rejection_reason'),
      requestedRole: _stringValue(data, 'requested_role') ??
          (additionalProfile != null ? _stringValue(additionalProfile, 'requested_role') : null),
      location: _stringValue(data, 'location'),
      localChurch: _stringValue(data, 'local_church'),
      occupation: _stringValue(data, 'occupation'),
      skills: _stringValue(data, 'skills') ??
          (additionalProfile != null ? _stringValue(additionalProfile, 'skills') : null),
      // work_contact / home_contact removed -- see UserProfile.fromJson.
      generalInfo: _stringValue(data, 'general_info'),
      localChapter: _stringValue(data, 'local_chapter') ??
          (additionalProfile != null ? _stringValue(additionalProfile, 'to_join_chapter') : null),
      isChapterVerified: _boolValue(data, 'is_chapter_verified') ?? false,
      isChurchVerified: _boolValue(data, 'is_church_verified') ?? false,
      commitmentType: _stringValue(data, 'commitment_type'),
      financialCommitment: _doubleValue(data, 'financial_commitment'),
      availabilityCommitment: _stringValue(data, 'availability_commitment'),
      commitmentDetails:
          _mapValue(data, 'commitment_details') ?? const <String, dynamic>{},
      totalReadingTime: _intValue(data, 'total_reading_time'),
      chaptersRead: _intValue(data, 'chapters_read'),
      versesRead: _intValue(data, 'verses_read'),
      prayersOffered: _intValue(data, 'prayers_offered'),
      studySessionsCompleted: _intValue(data, 'study_sessions_completed'),
      statsStartDate: _dateValue(data, 'stats_start_date'),
      createdAt:
          _dateValue(data, 'created_at') ?? DateTime.parse(document.$createdAt),
      updatedAt:
          _dateValue(data, 'updated_at') ?? DateTime.parse(document.$updatedAt),
    );
  }

  Map<String, dynamic> userProfileToAppwriteData(UserProfile profile) {
    final profileData = Map<String, dynamic>.from(profile.toJson());
    // Appwrite ignores null values on update, so clear the avatar explicitly
    // when the picture was removed.
    profileData['avatar_url'] = profile.avatarUrl ?? '';
    return _buildProfileData(
      email: profile.email,
      fullName: profile.fullName,
      role: profile.role,
      profileData: profileData,
      includeDefaults: false,
    );
  }

  Map<String, dynamic> _buildProfileData({
    String? email,
    String? fullName,
    String? role,
    Map<String, dynamic>? profileData,
    required bool includeDefaults,
  }) {
    final data = <String, dynamic>{};
    final isSuper =
        email != null && AppwriteBackendConfig.isSuperAdminEmail(email);
    if (includeDefaults) {
      data['role'] = isSuper ? 'admin' : (role ?? 'member');
      data['provider'] = 'appwrite';
      data['is_approved'] = true;
      data['approval_status'] = 'approved';
      data['created_at'] = DateTime.now().toIso8601String();
      data['updated_at'] = DateTime.now().toIso8601String();
    }

    void put(String key, dynamic value) {
      if (value != null) data[key] = value;
    }

    put('email', email);
    put('fullName', fullName);
    put('full_name', fullName);
    put('role', isSuper ? 'admin' : role);
    if (isSuper) {
      put('approval_status', 'approved');
      put('is_approved', true);
    }

    if (profileData != null) {
      for (final entry in profileData.entries) {
        put(entry.key, entry.value);
      }
      if (profileData['fullName'] == null && profileData['full_name'] != null) {
        put('fullName', profileData['full_name']);
      }
      if (profileData['full_name'] == null && profileData['fullName'] != null) {
        put('full_name', profileData['fullName']);
      }
    }

    data['updated_at'] = DateTime.now().toIso8601String();
    return data;
  }

  String? _stringValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String && value.trim().isNotEmpty ? value : null;
  }

  bool? _boolValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is bool ? value : null;
  }

  int? _intValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is int
        ? value
        : value is num
            ? value.toInt()
            : null;
  }

  double? _doubleValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is num ? value.toDouble() : null;
  }

  Map<String, dynamic>? _mapValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is Map<String, dynamic> ? value : null;
  }

  DateTime? _dateValue(Map<String, dynamic> data, String key) {
    final value = data[key];
    return value is String ? DateTime.tryParse(value) : null;
  }
}
