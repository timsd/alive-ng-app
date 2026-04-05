// Using Firebase for donations and downloadable materials
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'firebase_database_service.dart';
import 'payment_service.dart';
import '../models/donation_models.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';
import '../utils/app_exception.dart';

class DonationService {
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Uuid _uuid = const Uuid();
  final Logger _logger = Logger('DonationService');

  // Get all downloadable materials
  Future<List<DownloadableMaterial>> getMaterials({
    String? category,
    bool? requiresDonation,
    int? limit,
    int? offset,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('downloadable_materials')
          .where('is_active', isEqualTo: true);

      if (category != null) {
        query = query.where('category', isEqualTo: category);
      }

      if (requiresDonation != null) {
        query = query.where('requires_donation', isEqualTo: requiresDonation);
      }

      final ordered = query.orderBy('created_at', descending: true);

      if (offset != null && limit != null) {
        final snapshot = await ordered.limit(limit + offset).get();
        final docs = snapshot.docs.skip(offset).toList();
        return docs
            .map(
                (d) => DownloadableMaterial.fromJson({...d.data(), 'id': d.id}))
            .toList();
      }

      final snapshot = limit != null
          ? await ordered.limit(limit).get()
          : await ordered.get();
      return snapshot.docs
          .map((d) => DownloadableMaterial.fromJson({...d.data(), 'id': d.id}))
          .toList();
    } catch (e) {
      throw DatabaseException('Failed to fetch materials', originalError: e);
    }
  }

  // Get material by ID
  Future<DownloadableMaterial> getMaterialById(String materialId) async {
    try {
      final doc =
          await _db.collection('downloadable_materials').doc(materialId).get();
      final data = doc.data();
      if (data == null || data['is_active'] != true) {
        throw NotFoundException('Material not found or inactive');
      }
      return DownloadableMaterial.fromJson({...data, 'id': doc.id});
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
      Query<Map<String, dynamic>> q = _db
          .collection('downloadable_materials')
          .where('is_active', isEqualTo: true);

      if (category != null) {
        q = q.where('category', isEqualTo: category);
      }

      final ordered = q.orderBy('download_count', descending: true);
      final snapshot = limit != null
          ? await ordered.limit(limit).get()
          : await ordered.get();
      final lower = query.toLowerCase();
      return snapshot.docs
          .map((d) => DownloadableMaterial.fromJson({...d.data(), 'id': d.id}))
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
      final snapshot = await _db
          .collection('downloadable_materials')
          .where('is_active', isEqualTo: true)
          .get();
      final categories = snapshot.docs
          .map((d) => d.data()['category'] as String?)
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
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final material = await getMaterialById(materialId);

      // If material doesn't require donation, user can download
      if (!material.requiresDonation) return true;

      // Check if user has made a successful donation for this material
      final donationSnap = await _db
          .collection('donation_records')
          .where('user_id', isEqualTo: userId)
          .where('material_id', isEqualTo: materialId)
          .where('status', isEqualTo: DonationStatus.completed.name)
          .where('amount', isGreaterThanOrEqualTo: material.minimumDonation)
          .get();
      return donationSnap.docs.isNotEmpty;
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
      final user = _auth.currentUser;
      final isGuest = user == null;

      String userId;
      String userName;
      String userEmail;

      if (!isGuest) {
        final userProfile =
            await FirebaseDatabaseService.instance.getUserProfile(user.uid);
        userId = user.uid;
        userName = (userProfile?.fullName ?? 'Unknown User');
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

      await _db
          .collection('donation_records')
          .doc(donation.id)
          .set(donation.toJson());

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
        final existing =
            (await _db.collection('donation_records').doc(donationId).get())
                .data();
        updates['metadata'] = {
          ...?((existing?['metadata'] as Map<String, dynamic>?)),
          ...metadata,
        };
      }

      if (status == DonationStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      await _db.collection('donation_records').doc(donationId).update(updates);
      final doc =
          await _db.collection('donation_records').doc(donationId).get();
      return DonationRecord.fromJson({...doc.data()!, 'id': doc.id});
    } catch (e) {
      throw DatabaseException('Failed to update donation status',
          originalError: e);
    }
  }

  // Generate download URL for material
  Future<String> generateDownloadUrl(String materialId) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      // Check if user can download
      final canDownload = await canUserDownloadMaterial(materialId);
      if (!canDownload) {
        throw ValidationException(
            'Donation required to download this material');
      }

      final material = await getMaterialById(materialId);

      final path = material.fileUrl;

      // If this is an external non-Firebase HTTP URL, return it directly
      if (path.startsWith('http') &&
          !path.contains('firebasestorage.googleapis.com')) {
        await recordDownload(materialId, material.title);
        await _db.collection('downloadable_materials').doc(materialId).update({
          'download_count': FieldValue.increment(1),
          'updated_at': DateTime.now().toIso8601String(),
        });
        return path;
      }

      // Generate download URL from Firebase Storage
      Reference ref;
      if (path.startsWith('gs://') ||
          path.contains('firebasestorage.googleapis.com')) {
        ref = _storage.refFromURL(path);
      } else {
        ref = _storage.ref(path);
      }

      final String signedUrl = await ref.getDownloadURL();

      // Record the download
      await recordDownload(materialId, material.title);

      // Update download count
      await _db.collection('downloadable_materials').doc(materialId).update({
        'download_count': FieldValue.increment(1),
        'updated_at': DateTime.now().toIso8601String(),
      });

      return signedUrl;
    } catch (e) {
      if (e is AppException) rethrow;
      throw DatabaseException('Failed to generate download URL',
          originalError: e);
    }
  }

  // Record user download
  Future<void> recordDownload(String materialId, [String materialTitle = '']) async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      // Find associated donation if any
      final donationsSnap = await _db
          .collection('donation_records')
          .where('user_id', isEqualTo: userId)
          .where('material_id', isEqualTo: materialId)
          .where('status', isEqualTo: DonationStatus.completed.name)
          .get();
      final donationDataList = donationsSnap.docs.map((d) => d.data()).toList();
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

      await _db
          .collection('user_downloads')
          .doc(download.id)
          .set(download.toJson());
    } catch (e) {
      // Log error but don't throw - download should still work
      _logger.error('Failed to record download', e);
    }
  }

  // Get user's donation history
  Future<List<DonationRecord>> getUserDonations() async {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final snapshot = await _db
          .collection('donation_records')
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();
      return snapshot.docs
          .map((d) => DonationRecord.fromJson({...d.data(), 'id': d.id}))
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
      final userId = _auth.currentUser?.uid;
      if (userId == null) throw AuthException('User not authenticated');

      final snapshot = await _db
          .collection('user_downloads')
          .where('user_id', isEqualTo: userId)
          .orderBy('downloaded_at', descending: true)
          .get();
      return snapshot.docs
          .map((d) => UserDownload.fromJson({...d.data(), 'id': d.id}))
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
      final userId = _auth.currentUser?.uid;
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
      final completedSnap = await _db
          .collection('donation_records')
          .where('status', isEqualTo: DonationStatus.completed.name)
          .get();

      final totalAmount = completedSnap.docs
          .map((d) => (d.data()['amount'] as num).toDouble())
          .fold(0.0, (acc, amount) => acc + amount);

      // Donations by type
      final donationsByType = <String, int>{};
      for (final type in DonationType.values) {
        final typeSnap = await _db
            .collection('donation_records')
            .where('type', isEqualTo: type.name)
            .where('status', isEqualTo: DonationStatus.completed.name)
            .get();
        donationsByType[type.name] = typeSnap.docs.length;
      }

      // Recent donations
      final recentSnap = await _db
          .collection('donation_records')
          .where('status', isEqualTo: DonationStatus.completed.name)
          .orderBy('completed_at', descending: true)
          .limit(10)
          .get();
      final recentDonations = recentSnap.docs.map((d) => d.data()).toList();

      return {
        'total_amount': totalAmount,
        'total_donations': completedSnap.docs.length,
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
      final donationDoc =
          await _db.collection('donation_records').doc(donationId).get();
      if (!donationDoc.exists) {
        throw NotFoundException('Donation record not found');
      }
      final donation = DonationRecord.fromJson(
          {...donationDoc.data()!, 'id': donationDoc.id});

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
          'message': 'Payment initialized. Complete checkout to finalize donation.',
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
      final user = _auth.currentUser;
      await _db.collection('gift_submissions').add({
        'gift_type': giftType,
        'user_id': user?.uid,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        if (itemType != null && itemType.trim().isNotEmpty) 'item_type': itemType,
        if (quantity != null && quantity.trim().isNotEmpty) 'quantity': quantity,
        if (estimatedValue != null && estimatedValue.trim().isNotEmpty)
          'estimated_value': estimatedValue,
        if (deliveryPreference != null && deliveryPreference.trim().isNotEmpty)
          'delivery_preference': deliveryPreference,
        if (location != null && location.trim().isNotEmpty) 'location': location,
        if (skillsOrService != null && skillsOrService.trim().isNotEmpty)
          'skills_or_service': skillsOrService,
        if (availability != null && availability.trim().isNotEmpty)
          'availability': availability,
        if (description != null && description.trim().isNotEmpty)
          'description': description,
        'status': 'submitted',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw DatabaseException('Failed to submit gift contribution',
          originalError: e);
    }
  }
}
