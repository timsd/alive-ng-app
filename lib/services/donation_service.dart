import 'dart:convert';

import 'package:appwrite/appwrite.dart';
import 'package:appwrite/enums.dart' as appwrite_enums;
import 'package:appwrite/models.dart' as models;
import 'package:flutter/material.dart';

import '../config/appwrite_backend_config.dart';
import '../main.dart';
import 'payment_service.dart';
import 'ports/payment_gateway.dart';
import '../models/donation_models.dart';
import '../models/project_model.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';
import 'auth_service.dart';

class DonationService {
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal() : _paymentService = PaymentService();

  DonationService.withPaymentGateway(PaymentGateway gateway)
      : _paymentService = PaymentService(gateway);

  final PaymentService _paymentService;

  late final TablesDB _tables = TablesDB(appwriteClient);
  final Uuid _uuid = const Uuid();
  final Map<String, DonationRecord> _checkoutDrafts = {};
  final Logger _logger = Logger('DonationService');

  String get _databaseId => AppwriteBackendConfig.databaseId;
  String get _donationsCollectionId =>
      AppwriteBackendConfig.donationRecordsCollectionId;
  String get _materialsCollectionId =>
      AppwriteBackendConfig.downloadableMaterialsCollectionId;
  String get _downloadsCollectionId =>
      AppwriteBackendConfig.materialDownloadsCollectionId;
  String get _projectsCollectionId =>
      AppwriteBackendConfig.projectsCollectionId;
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

  List<String> _queriesWithOffset(
      List<String> queries, int? limit, int? offset) {
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

  Future<Project?> getProject(String projectId) async {
    try {
      final row = await _tables.getRow(
        databaseId: _databaseId,
        tableId: _projectsCollectionId,
        rowId: projectId,
      );
      return Project.fromJson(_rowData(row));
    } catch (_) {
      return null;
    }
  }

  Future<List<Project>> getDonationProjects() async {
    try {
      final snapshot = await _tables.listRows(
        databaseId: _databaseId,
        tableId: _projectsCollectionId,
        queries: [
          Query.orderAsc('priority'),
          Query.limit(100),
        ],
      );
      return snapshot.rows
          .map((row) => Project.fromJson(_rowData(row)))
          .toList();
    } catch (e) {
      _logger.error('Failed to fetch donation projects', e);
      return [];
    }
  }

  Future<AppUser?> _currentUser() async {
    final cached = AuthService.instance.currentUser;
    if (cached != null) return cached;
    try {
      final appUser = await AuthService.instance.getCurrentUser();
      if (appUser != null) return appUser;
    } catch (_) {}

    try {
      final raw = await appwriteAccount.get();
      return AppUser(
        uid: raw.$id,
        email: raw.email,
        displayName: raw.name.isEmpty ? null : raw.name,
        isEmailVerified: raw.emailVerification,
        isAnonymous: false,
      );
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
        userName = user.displayName ?? (user.email.isNotEmpty ? user.email.split('@').first : 'Donor');
        userEmail = user.email.isNotEmpty ? user.email : (guestEmail ?? '');
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

      if (paymentMethod == PaymentMethod.paystack) {
        // Persist a pending row immediately so the admin finance report can
        // see the attempt even before the Paystack webhook confirms it.
        // The server webhook later flips status -> completed.
        try {
          final data = _appwriteData(donation.toJson());
          data['reference'] = donation.id;
          data['amount_kobo'] = (donation.amount * 100).round();
          await _tables.createRow(
            databaseId: _databaseId,
            tableId: _donationsCollectionId,
            rowId: donation.id,
            data: data,
          );
        } catch (e) {
          _logger.error('Failed to persist pending paystack donation', e);
        }
        _checkoutDrafts[donation.id] = donation;
        return donation;
      }

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
      if (userId == null) return [];

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
          .where((d) => d.type == DonationType.tractProduction)
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
      case DonationType.tractProduction:
        // Tract download / share donations use the configured
        // regional tract production minimum.
        return DonationConstants.tractDonationByRegion[regionCode] ??
            DonationConstants.minimumTractDonation;
      case DonationType.generalSupport:
      case DonationType.appMaintenance:
        switch (currency.toUpperCase()) {
          case 'NGN':
            // TEMPORARY TESTING VALUE: lowered to ₦100 so the Paystack
            // checkout flow can be verified end-to-end. Restore to 7500.0
            // once payment is confirmed working in production.
            return 100.0;
          case 'USD':
          default:
            return 5.0;
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
    double? exchangeRateUsdNgn,
  }) async {
    try {
      // Get the donation record
      var donation = _checkoutDrafts[donationId];
      if (donation == null) {
        try {
          final row = await _tables.getRow(
            databaseId: _databaseId,
            tableId: _donationsCollectionId,
            rowId: donationId,
          );
          donation = DonationRecord.fromJson(_rowData(row));
        } catch (e) {
          // APK guest checkouts may use an in-memory draft when the earlier
          // TablesDB write was denied; never block Paystack on this lookup.
          _logger.error('Donation draft lookup failed; using fallback', e);
          donation = null;
        }
      }

      // Ensure context is still valid before using it across async boundary
      if (!context.mounted) {
        return {
          'success': false,
          'message': 'Context not mounted',
          'donation_id': donationId,
        };
      }
      // Use PaymentService to process the payment
      final donorName = donation?.metadata?['donor_name'] as String? ??
          ((donation?.userName.isNotEmpty ?? false)
              ? donation!.userName
              : null) ??
          donation?.userEmail ??
          email;
      final baseMetadata = {
        'donation_id': donationId,
        'appwrite_user_id': donation?.userId ?? 'guest',
        'donation_type': donation?.type.name ?? 'generalSupport',
        'material_title': donation?.materialTitle,
        'donor_name': donorName,
        'donor_email': donation?.userEmail ?? email,
        'amount': amount,
        'amount_minor': (amount * 100).round(),
        if (currency.toUpperCase() == 'NGN') 'amount_ngn': amount,
        if (donation?.metadata?['project_title'] != null)
          'project_title': donation!.metadata!['project_title'],
        if (donation?.metadata?['project_id'] != null)
          'project_id': donation!.metadata!['project_id'],
        'currency': currency,
        'recurring': isRecurringMonthly,
        if (donation?.materialId != null) 'material_id': donation!.materialId,
        // Fresh display rate so the server bills the donor-visible USD->NGN
        // conversion instead of a stale hardcoded value.
        if (exchangeRateUsdNgn != null)
          'exchange_rate_usd_ngn': exchangeRateUsdNgn,
      };
      final paymentResult = isRecurringMonthly
          ? await _paymentService.processMonthlyDonation(
              amount: amount,
              email: email,
              currency: currency,
              reference: donationId,
              metadata: baseMetadata,
            )
          : await _paymentService.processDonation(
              amount: amount,
              email: email,
              currency: currency,
              reference: donationId,
              metadata: baseMetadata,
            );

      _checkoutDrafts.remove(donationId);

      // When the payment gateway confirms success inline (e.g. native SDK
      // checkout completed or dev-mode simulation), mark the donation as
      // completed immediately and trigger server-side receipt dispatch.
      if (paymentResult.success) {
        try {
          await updateDonationStatus(
            donationId,
            DonationStatus.completed,
            transactionId: paymentResult.reference,
          );
        } catch (e) {
          _logger.error('Failed to mark donation completed', e);
        }

        // Trigger server-side verification which also sends the Resend receipt
        try {
          final functions = Functions(appwriteClient);
          await functions.createExecution(
            functionId: AppwriteBackendConfig.paystackPaymentsFunctionId,
            body: jsonEncode({
              'action': 'verify_transaction',
              // Paystack verifies by ITS reference, not our local donation id.
              'reference': paymentResult.reference ?? donationId,
            }),
            xasync: true,
            method: appwrite_enums.ExecutionMethod.pOST,
          );
        } catch (e) {
          _logger.error('Failed to trigger server-side verification', e);
        }

        return {
          'success': true,
          'initialized': true,
          'message': paymentResult.message,
          'donation_id': donationId,
          'transaction_id': paymentResult.reference,
        };
      }

      // Payment was only initialized (redirect opened, not yet confirmed).
      // Update the local row to `initialized` so admins can see that checkout
      // was opened (webhook later flips it to completed/success).
      try {
        await _tables.updateRow(
          databaseId: _databaseId,
          tableId: _donationsCollectionId,
          rowId: donationId,
          data: {
            'status': 'initialized',
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      } catch (e) {
        _logger.error('Failed to mark donation initialized', e);
      }
      return {
        'success': false,
        'initialized': paymentResult.initialized,
        'message': paymentResult.message,
        'donation_id': donationId,
      };

    } catch (e) {
      _logger.error('Error processing Paystack payment', e);
      return {
        'success': false,
        // Surface the real reason (e.g. Paystack init error) so APK failures
        // are diagnosable instead of a generic "could not open checkout".
        'message': '$e'.replaceFirst('Exception: ', ''),
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
          if (deliveryPreference != null &&
              deliveryPreference.trim().isNotEmpty)
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
