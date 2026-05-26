import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'payment_service.dart';
import '../models/donation_models.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';
import 'auth_service.dart';

class DonationService {
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal();

  late final TablesDB _tables = TablesDB(appwriteClient);
  final Uuid _uuid = const Uuid();
  final Logger _logger = Logger('DonationService');

  String get _databaseId => AppwriteBackendConfig.databaseId;
  String get _donationsCollectionId =>
      AppwriteBackendConfig.donationRecordsCollectionId;
  String get _materialsCollectionId =>
      AppwriteBackendConfig.downloadableMaterialsCollectionId;
  String get _downloadsCollectionId =>
      AppwriteBackendConfig.materialDownloadsCollectionId;
  String get _projectsCollectionId => AppwriteBackendConfig.projectsCollectionId;
  String get _settingsCollectionId =>
      AppwriteBackendConfig.appSettingsCollectionId;

  Map<String, dynamic> _rowData(models.Row row) {
    return {
      ...Map<String, dynamic>.from(row.data),
      'id': row.$id,
    };
  }

  List<String> _queriesWithLimit(List<String> queries, int? limit) {
    if (limit == null) return queries;
    return [...queries, Query.limit(limit)];
  }

  List<String> _queriesWithOffset(List<String> queries, int? limit, int? offset) {
    final built = _queriesWithLimit(queries, limit);
    if (offset == null) return built;
    return [...built, Query.offset(offset)];
  }

  Map<String, dynamic> _appwriteData(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data)..remove('id');
    copy.removeWhere((_, value) => value == null);
    if (copy['metadata'] is Map) {
      copy['metadata'] = jsonEncode(copy['metadata']);
    }
    return copy;
  }

  Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      final decoded = jsonDecode(value);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    }
    return null;
  }

  Future<String?> getAppSettingValue(String key) async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _settingsCollectionId,
        queries: [
          Query.equal('key', key),
          Query.limit(1),
        ],
      );
      if (snapshot.rows.isEmpty) {
        final fallback = await _tables.listRows(
          databaseId: _databaseId,
          tableId: _settingsCollectionId,
          queries: [
            Query.equal('setting_key', key),
            Query.limit(1),
          ],
        );
        if (fallback.rows.isEmpty) return null;
        return (fallback.rows.first.data['value'] ??
                fallback.rows.first.data['setting_value'])
            ?.toString();
      }

      return (snapshot.rows.first.data['value'] ??
              snapshot.rows.first.data['setting_value'])
          ?.toString();
    } catch (e) {
      _logger.error('Failed to fetch app setting $key', e);
      return null;
    }
  }

  Future<Map<String, dynamic>?> getProject(String projectId) async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: _projectsCollectionId,
        rowId: projectId,
      );
      return _rowData(row);
    } catch (_) {
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getDonationProjects() async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _projectsCollectionId,
        queries: [
          Query.orderAsc('priority'),
          Query.limit(100),
        ],
      );
      return snapshot.rows.map(_rowData).toList();
    } catch (e) {
      _logger.error('Failed to fetch donation projects', e);
      return [];
    }
  }

  Future<dynamic> _currentUser() async {
    final cached = AuthService.instance.currentUser;
    if (cached != null) return cached;
    try {
      return await appwriteAccount.get();
    } catch (_) {
      return null;
    }
  }

  String _resolveMaterialUrl(String path) {
    final trimmed = path.trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    var bucketId = AppwriteBackendConfig.tractFilesBucketId;
    var fileId = trimmed;
    if (trimmed.contains(':')) {
      final parts = trimmed.split(':');
      bucketId = parts.first;
      fileId = parts.sublist(1).join(':');
    } else if (trimmed.contains('/')) {
      final parts = trimmed.split('/');
      bucketId = parts.first;
      fileId = parts.sublist(1).join('/');
    }

    return '${AppwriteBackendConfig.endpoint}/storage/buckets/'
        '${Uri.encodeComponent(bucketId)}/files/${Uri.encodeComponent(fileId)}'
        '/view?project=${Uri.encodeComponent(AppwriteBackendConfig.projectId)}';
  }

  // Get all downloadable materials
  Future<List<DownloadableMaterial>> getMaterials({
    String? category,
    bool? requiresDonation,
    int? limit,
    int? offset,
  }) async {
    try {
      final queries = <String>[Query.equal('is_active', true)];
      if (category != null) {
        queries.add(Query.equal('category', category));
      }

      if (requiresDonation != null) {
        queries.add(Query.equal('requires_donation', requiresDonation));
      }
      queries.add(Query.orderDesc('created_at'));

      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _materialsCollectionId,
        queries: _queriesWithOffset(queries, limit, offset),
      );
      return snapshot.rows
          .map((row) => DownloadableMaterial.fromJson(_rowData(row)))
          .toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch materials', originalError: e);
    }
  }

  // Get material by ID
  Future<DownloadableMaterial> getMaterialById(String materialId) async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: _materialsCollectionId,
        rowId: materialId,
      );
      final data = _rowData(row);
      if (data['is_active'] != true) {
        throw NotFoundException('Material not found or inactive');
      }
      return DownloadableMaterial.fromJson(data);
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to fetch material', originalError: e);
    }
  }

  // Search materials
  Future<List<DownloadableMaterial>> searchMaterials({
    required String query,
    String? category,
    int? limit,
  }) async {
    try {
      final queries = <String>[Query.equal('is_active', true)];

      if (category != null) {
        queries.add(Query.equal('category', category));
      }

      queries.add(Query.orderDesc('download_count'));
      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _materialsCollectionId,
        queries: _queriesWithLimit(queries, limit),
      );
      final lower = query.toLowerCase();
      return snapshot.rows
          .map((row) => DownloadableMaterial.fromJson(_rowData(row)))
          .where((m) =>
              (m.title.toLowerCase().contains(lower)) ||
              (m.description.toLowerCase().contains(lower)))
          .toList();
    } catch (e) {
      throw DatabaseException('Failed to search materials', originalError: e);
    }
  }

  // Get material categories
  Future<List<String>> getMaterialCategories() async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _materialsCollectionId,
        queries: [Query.equal('is_active', true), Query.limit(5000)],
      );
      final categories = snapshot.rows
          .map((row) => row.data['category'] as String?)
          .whereType<String>()
          .toSet()
          .toList();

      categories.sort();
      return categories;
    } catch (e) {
      throw DatabaseException('Failed to fetch categories', originalError: e);
    }
  }

  // Check if user can download material (has made required donation)
  Future<bool> canUserDownloadMaterial(String materialId) async {
    try {
      final user = await _currentUser();
      final userId = user?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final material = await getMaterialById(materialId);

      // If material doesn't require donation, user can download
      if (!material.requiresDonation) return true;

      // Check if user has made a successful donation for this material
      final donationSnap = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('material_id', materialId),
          Query.equal('status', DonationStatus.completed.name),
          Query.greaterThanEqual('amount', material.minimumDonation),
          Query.limit(1),
        ],
      );
      return donationSnap.rows.isNotEmpty;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to check download permission',
          originalError: e);
    }
  }

  // Create donation record
  Future<DonationRecord> createDonation({
    required DonationType type,
    required double amount,
    required String currency,
    required PaymentMethod paymentMethod,
    String? materialId,
    String? materialTitle,
    String? notes,
    Map<String, dynamic>? metadata,
    String? guestName,
    String? guestEmail,
  }) async {
    try {
      final user = await _currentUser();
      final isGuest = user == null;

      String userId;
      String userName;
      String userEmail;

      if (!isGuest) {
        userId = user.uid;
        userName = user.displayName ?? user.name ?? 'Unknown User';
        userEmail = user.email ?? '';
      } else {
        userId = 'guest-${_uuid.v4()}';
        userName = (guestName ?? 'Guest Donor');
        userEmail = (guestEmail ?? '');
        if (userEmail.isEmpty) {
          throw ValidationException('Email is required for guest donations');
        }
      }

      final donation = DonationRecord(
        id: _uuid.v4(),
        userId: userId,
        userName: userName,
        userEmail: userEmail,
        type: type,
        amount: amount,
        currency: currency,
        status: DonationStatus.pending,
        paymentMethod: paymentMethod,
        materialId: materialId,
        materialTitle: materialTitle,
        notes: notes,
        metadata: metadata,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final data = _appwriteData(donation.toJson());
      data['reference'] = donation.id;
      data['amount_kobo'] = (donation.amount * 100).round();

      await _tables.createRow(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        rowId: donation.id,
        data: data,
      );

      return donation;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to create donation', originalError: e);
    }
  }

  // Update donation status
  Future<DonationRecord> updateDonationStatus(
    String donationId,
    DonationStatus status, {
    String? paymentIntentId,
    String? transactionId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final Map<String, dynamic> updates = {
        'status': status.name,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (paymentIntentId != null) {
        updates['payment_intent_id'] = paymentIntentId;
      }

      if (transactionId != null) {
        updates['transaction_id'] = transactionId;
      }

      if (metadata != null) {
        final existing = await _tables.getRow(
          databaseId: _databaseId,
          tableId: _donationsCollectionId,
          rowId: donationId,
        );
        updates['metadata'] = jsonEncode({
          ...?_parseMetadata(existing.data['metadata']),
          ...metadata,
        });
      }

      if (status == DonationStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await _tables.updateRow(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        rowId: donationId,
        data: updates,
      );
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        rowId: donationId,
      );
      return DonationRecord.fromJson(_rowData(row));
    } catch (e) {
      throw DatabaseException('Failed to update donation status',
          originalError: e);
    }
  }

  // Generate download URL for material
  Future<String> generateDownloadUrl(String materialId) async {
    try {
      final user = await _currentUser();
      final userId = user?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      // Check if user can download
      final canDownload = await canUserDownloadMaterial(materialId);
      if (!canDownload) {
        throw ValidationException(
            'Donation required to download this material');
      }

      final material = await getMaterialById(materialId);

      final path = material.fileUrl;
      final downloadUrl = _resolveMaterialUrl(path);
      await recordDownload(materialId, material.title);

      await _tables.updateRow(
        databaseId: _databaseId,
        tableId: _materialsCollectionId,
        rowId: materialId,
        data: {
          'download_count': material.downloadCount + 1,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      return downloadUrl;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to generate download URL',
          originalError: e);
    }
  }

  // Record user download
  Future<void> recordDownload(String materialId,
      [String materialTitle = '']) async {
    try {
      final user = await _currentUser();
      final userId = user?.uid;
      if (userId == null) return;

      // Find associated donation if any
      final donationsSnap = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.equal('material_id', materialId),
          Query.equal('status', DonationStatus.completed.name),
          Query.limit(100),
        ],
      );
      final donationDataList = donationsSnap.rows.map(_rowData).toList();
      donationDataList.sort((a, b) {
        final ad = a['completed_at'] as String?;
        final bd = b['completed_at'] as String?;
        final at = ad != null
            ? DateTime.parse(ad)
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bt = bd != null
            ? DateTime.parse(bd)
            : DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });
      final donation =
          donationDataList.isNotEmpty ? donationDataList.first : null;

      final download = UserDownload(
        id: _uuid.v4(),
        userId: userId,
        materialId: materialId,
        materialTitle: materialTitle,
        donationId: donation != null ? donation['id'] as String? : null,
        donationAmount:
            donation != null ? (donation['amount'] as num?)?.toDouble() : null,
        downloadedAt: DateTime.now(),
      );

      await _tables.createRow(
        databaseId: _databaseId,
        tableId: _downloadsCollectionId,
        rowId: download.id,
        data: _appwriteData(download.toJson()),
      );
    } catch (e) {
      // Log error but don't throw - download should still work
      _logger.error('Failed to record download', e);
    }
  }

  // Get user's donation history
  Future<List<DonationRecord>> getUserDonations() async {
    try {
      final user = await _currentUser();
      final userId = user?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('created_at'),
          Query.limit(500),
        ],
      );
      return snapshot.rows
          .map((row) => DonationRecord.fromJson(_rowData(row)))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to fetch user donations',
          originalError: e);
    }
  }

  // Get user's download history
  Future<List<UserDownload>> getUserDownloads() async {
    try {
      final user = await _currentUser();
      final userId = user?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _downloadsCollectionId,
        queries: [
          Query.equal('user_id', userId),
          Query.orderDesc('downloaded_at'),
          Query.limit(500),
        ],
      );
      return snapshot.rows
          .map((row) => UserDownload.fromJson(_rowData(row)))
          .toList();
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to fetch user downloads',
          originalError: e);
    }
  }

  // Get donation summary for user
  Future<DonationSummary> getUserDonationSummary() async {
    try {
      final user = await _currentUser();
      final userId = user?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final donations = await getUserDonations();
      final downloads = await getUserDownloads();

      final completedDonations = donations.where((d) => d.isCompleted).toList();

      final totalDonated = completedDonations
          .map((d) => d.amount)
          .fold(0.0, (acc, amount) => acc + amount);

      final materialsDownloaded =
          downloads.where((d) => d.donationAmount != null).length;

      final tractsReprinted = completedDonations
          .where((d) => d.type == DonationType.tractReprint)
          .length;

      final lastDonation = completedDonations.isNotEmpty
          ? completedDonations.first.completedAt
          : null;

      return DonationSummary(
        userId: userId,
        totalDonated: totalDonated,
        totalDonations: completedDonations.length,
        materialsDownloaded: materialsDownloaded,
        tractsReprinted: tractsReprinted,
        lastDonationDate: lastDonation,
        recentDonations: completedDonations.take(5).toList(),
      );
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to fetch donation summary',
          originalError: e);
    }
  }

  // Get donation statistics (admin)
  Future<Map<String, dynamic>> getDonationStatistics() async {
    try {
      // Completed donations snapshot
      final completedSnap = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        queries: [Query.equal('status', DonationStatus.completed.name)],
      );

      final totalAmount = completedSnap.rows
          .map((row) => (row.data['amount'] as num?)?.toDouble() ?? 0)
          .fold(0.0, (acc, amount) => acc + amount);

      // Donations by type
      final donationsByType = <String, int>{};
      for (final type in DonationType.values) {
        final typeSnap = await _tables.listRows(
          databaseId: _databaseId,
          tableId: _donationsCollectionId,
          queries: [
            Query.equal('type', type.name),
            Query.equal('status', DonationStatus.completed.name),
          ],
        );
        donationsByType[type.name] = typeSnap.total;
      }

      // Recent donations
      final recentSnap = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        queries: [
          Query.equal('status', DonationStatus.completed.name),
          Query.orderDesc('completed_at'),
          Query.limit(10),
        ],
      );
      final recentDonations =
          recentSnap.rows.map((row) => _rowData(row)).toList();

      return {
        'total_amount': totalAmount,
        'total_donations': completedSnap.total,
        'donations_by_type': donationsByType,
        'recent_donations': recentDonations,
      };
    } catch (e) {
      throw DatabaseException('Failed to fetch donation statistics',
          originalError: e);
    }
  }

  // Validate minimum donation amount with currency awareness
  bool validateDonationAmount(DonationType type, double amount,
      {String currency = DonationConstants.defaultCurrency}) {
    final minimumAmount = getMinimumDonationAmount(type, currency: currency);
    return amount >= minimumAmount;
  }

  // Get minimum donation amount for type with currency awareness
  double getMinimumDonationAmount(DonationType type,
      {String currency = DonationConstants.defaultCurrency}) {
    // Get region code from currency
    String? regionCode;
    DonationConstants.currencyByRegion.forEach((region, curr) {
      if (curr == currency) {
        regionCode = region;
      }
    });

    // Default to US if region not found
    regionCode ??= 'US';

    switch (type) {
      case DonationType.tractReprint:
        // Use region-specific tract donation amount if available
        return DonationConstants.tractDonationByRegion[regionCode] ??
            DonationConstants.minimumTractDonation;
      case DonationType.materialDownload:
        // For material downloads, we could add a similar map in the future
        // For now, use the default with a currency conversion factor for non-USD
        if (currency != 'USD') {
          // Apply a simple conversion factor based on region
          switch (currency) {
            case 'NGN':
              return DonationConstants.minimumMaterialDonation *
                  1500; // Approx conversion
            case 'GBP':
              return DonationConstants.minimumMaterialDonation *
                  0.8; // Approx conversion
            case 'CAD':
              return DonationConstants.minimumMaterialDonation *
                  1.3; // Approx conversion
            default:
              return DonationConstants.minimumMaterialDonation;
          }
        }
        return DonationConstants.minimumMaterialDonation;
      case DonationType.generalSupport:
      case DonationType.ministrySupport:
      case DonationType.appMaintenance:
        // Apply currency-specific minimum for general support
        switch (currency) {
          case 'NGN':
            return 7500.0; // Approx $5 equivalent
          case 'GBP':
            return 4.0; // Approx $5 equivalent
          case 'CAD':
            return 7.0; // Approx $5 equivalent
          default:
            return 5.0; // Default $5 for USD
        }
    }
  }

  // Process payment with Paystack
  Future<Map<String, dynamic>> processPaystackPayment({
    required BuildContext context,
    required String donationId,
    required double amount,
    required String currency,
    required String email,
    bool isRecurringMonthly = false,
  }) async {
    try {
      // Get the donation record
      final donationRow = await _tables.getRow(
        databaseId: _databaseId,
        tableId: _donationsCollectionId,
        rowId: donationId,
      );
      final donation = DonationRecord.fromJson(_rowData(donationRow));

      // Ensure context is still valid before using it across async boundary
      if (!context.mounted) {
        return {
          'success': false,
          'message': 'Context not mounted',
          'donation_id': donationId,
        };
      }
      // Use PaymentService to process the payment
      final baseMetadata = {
        'donation_id': donationId,
        'appwrite_user_id': donation.userId,
        'donation_type': donation.type.name,
        'material_title': donation.materialTitle,
        if (donation.metadata?['project_title'] != null)
          'project_title': donation.metadata!['project_title'],
        if (donation.metadata?['project_id'] != null)
          'project_id': donation.metadata!['project_id'],
        'currency': currency,
        'recurring': isRecurringMonthly,
        if (donation.materialId != null) 'material_id': donation.materialId,
      };
      final paymentResult = isRecurringMonthly
          ? await PaymentService().processMonthlyDonation(
              email: email,
              currency: currency,
              reference: donationId,
              metadata: baseMetadata,
            )
          : await PaymentService().processDonation(
              amount: amount,
              email: email,
              reference: donationId,
              metadata: baseMetadata,
            );

      if (paymentResult.initialized && !paymentResult.success) {
        await updateDonationStatus(
          donationId,
          DonationStatus.processing,
          metadata: {
            'processor': 'paystack',
            'message': paymentResult.message,
          },
        );
        return {
          'success': false,
          'message':
              'Payment initialized. Complete checkout to finalize donation.',
          'donation_id': donationId,
          'initialized': true,
        };
      } else if (paymentResult.success) {
        // Update donation status to completed
        await updateDonationStatus(
          donationId,
          DonationStatus.completed,
          transactionId: paymentResult.reference,
          metadata: {
            'processor': 'paystack',
            'message': paymentResult.message,
          },
        );

        return {
          'success': true,
          'message': 'Payment processed successfully',
          'donation_id': donationId,
          'transaction_id': paymentResult.reference,
          'initialized': false,
        };
      } else {
        // Update donation status to failed
        await updateDonationStatus(
          donationId,
          DonationStatus.failed,
          metadata: {
            'processor': 'paystack',
            'message': paymentResult.message,
          },
        );

        return {
          'success': false,
          'message': paymentResult.message,
          'donation_id': donationId,
          'initialized': false,
        };
      }
    } catch (e) {
      _logger.error('Error processing Paystack payment', e);
      // Attempt to mark as failed if donation exists
      try {
        await updateDonationStatus(
          donationId,
          DonationStatus.failed,
          metadata: {'error': '$e'},
        );
      } catch (_) {}

      if (e is AppException) rethrow;

      return {
        'success': false,
        'message': 'Payment processing error: $e',
        'donation_id': donationId,
        'initialized': false,
      };
    }
  }

  Future<void> submitGiftContribution({
    required String giftType,
    required String fullName,
    required String email,
    required String phone,
    String? itemType,
    String? quantity,
    String? estimatedValue,
    String? deliveryPreference,
    String? location,
    String? skillsOrService,
    String? availability,
    String? description,
  }) async {
    try {
      final user = await _currentUser();
      await _tables.createRow(
        databaseId: _databaseId,
        tableId: AppwriteBackendConfig.giftSubmissionsCollectionId,
        rowId: ID.unique(),
        data: _appwriteData({
          'gift_type': giftType,
          'user_id': user?.uid,
          'full_name': fullName,
          'email': email,
          'phone': phone,
          if (itemType != null && itemType.trim().isNotEmpty)
            'item_type': itemType,
          if (quantity != null && quantity.trim().isNotEmpty)
            'quantity': quantity,
          if (estimatedValue != null && estimatedValue.trim().isNotEmpty)
            'estimated_value': estimatedValue,
          if (deliveryPreference != null && deliveryPreference.trim().isNotEmpty)
            'delivery_preference': deliveryPreference,
          if (location != null && location.trim().isNotEmpty)
            'location': location,
          if (skillsOrService != null && skillsOrService.trim().isNotEmpty)
            'skills_or_service': skillsOrService,
          if (availability != null && availability.trim().isNotEmpty)
            'availability': availability,
          if (description != null && description.trim().isNotEmpty)
            'description': description,
          'status': 'submitted',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        }),
      );
    } catch (e) {
      throw DatabaseException('Failed to submit gift contribution',
          originalError: e);
    }
  }
}
