import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/donation_models.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

class DonationService {
  static final DonationService _instance = DonationService._internal();
  factory DonationService() => _instance;
  DonationService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
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
      dynamic query = _supabase
          .from('downloadable_materials')
          .select()
          .eq('is_active', true);

      if (category != null) {
        query = query.eq('category', category);
      }

      if (requiresDonation != null) {
        query = query.eq('requires_donation', requiresDonation);
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      if (offset != null) {
        query = query.range(offset, offset + (limit ?? 50) - 1);
      }

      query = query.order('created_at', ascending: false);

      final response = await query;

      return (response as List)
          .map((json) => DownloadableMaterial.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch materials: $e');
    }
  }

  // Get material by ID
  Future<DownloadableMaterial> getMaterialById(String materialId) async {
    try {
      final response = await _supabase
          .from('downloadable_materials')
          .select()
          .eq('id', materialId)
          .eq('is_active', true)
          .single();

      return DownloadableMaterial.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch material: $e');
    }
  }

  // Search materials
  Future<List<DownloadableMaterial>> searchMaterials({
    required String query,
    String? category,
    int? limit,
  }) async {
    try {
      dynamic supabaseQuery = _supabase
          .from('downloadable_materials')
          .select()
          .eq('is_active', true)
          .or('title.ilike.%$query%,description.ilike.%$query%');

      if (category != null) {
        supabaseQuery = supabaseQuery.eq('category', category);
      }

      if (limit != null) {
        supabaseQuery = supabaseQuery.limit(limit);
      }

      supabaseQuery = supabaseQuery.order('download_count', ascending: false);

      final response = await supabaseQuery;

      return (response as List)
          .map((json) => DownloadableMaterial.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to search materials: $e');
    }
  }

  // Get material categories
  Future<List<String>> getMaterialCategories() async {
    try {
      final response = await _supabase
          .from('downloadable_materials')
          .select('category')
          .eq('is_active', true);

      final categories = (response as List)
          .map((item) => item['category'] as String)
          .toSet()
          .toList();

      categories.sort();
      return categories;
    } catch (e) {
      throw Exception('Failed to fetch categories: $e');
    }
  }

  // Check if user can download material (has made required donation)
  Future<bool> canUserDownloadMaterial(String materialId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final material = await getMaterialById(materialId);

      // If material doesn't require donation, user can download
      if (!material.requiresDonation) return true;

      // Check if user has made a successful donation for this material
      final donations = await _supabase
          .from('donation_records')
          .select()
          .eq('user_id', userId)
          .eq('material_id', materialId)
          .eq('status', DonationStatus.completed.name)
          .gte('amount', material.minimumDonation);

      return donations.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check download permission: $e');
    }
  }

  // Create donation record
  Future<DonationRecord> createDonation({
    required DonationType type,
    required double amount,
    required PaymentMethod paymentMethod,
    String? materialId,
    String? materialTitle,
    String? notes,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      // Get user profile for name and email
      final profile = await _supabase
          .from('profiles')
          .select('full_name')
          .eq('id', user.id)
          .single();

      final donation = DonationRecord(
        id: _uuid.v4(),
        userId: user.id,
        userName: (profile['full_name'] as String?) ?? 'Unknown User',
        userEmail: user.email ?? '',
        type: type,
        amount: amount,
        currency: DonationConstants.defaultCurrency,
        status: DonationStatus.pending,
        paymentMethod: paymentMethod,
        materialId: materialId,
        materialTitle: materialTitle,
        notes: notes,
        metadata: metadata,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _supabase.from('donation_records').insert(donation.toJson());

      return donation;
    } catch (e) {
      throw Exception('Failed to create donation: $e');
    }
  }

  // Process payment with Stripe
  Future<Map<String, dynamic>> processStripePayment({
    required String donationId,
    required double amount,
    required String currency,
  }) async {
    try {
      // This would integrate with Stripe API
      // For now, we'll simulate the payment process

      // In a real implementation, you would:
      // 1. Create a payment intent with Stripe
      // 2. Return the client secret for frontend processing
      // 3. Handle webhooks for payment confirmation

      final response = {
        'client_secret': 'pi_test_${_uuid.v4()}_secret_test',
        'payment_intent_id': 'pi_test_${_uuid.v4()}',
        'status': 'requires_payment_method',
      };

      // Update donation with payment intent ID
      await updateDonationStatus(
        donationId,
        DonationStatus.processing,
        paymentIntentId: response['payment_intent_id'],
      );

      return response;
    } catch (e) {
      throw Exception('Failed to process Stripe payment: $e');
    }
  }

  // Process payment with Paystack (for Nigerian users)
  Future<Map<String, dynamic>> processPaystackPayment({
    required String donationId,
    required double amount,
    required String currency,
    required String email,
  }) async {
    try {
      // This would integrate with Paystack API
      // For now, we'll simulate the payment process

      final response = {
        'authorization_url': 'https://checkout.paystack.com/test_${_uuid.v4()}',
        'access_code': 'test_access_${_uuid.v4()}',
        'reference': 'ref_${_uuid.v4()}',
      };

      // Update donation with transaction reference
      await updateDonationStatus(
        donationId,
        DonationStatus.processing,
        transactionId: response['reference'],
      );

      return response;
    } catch (e) {
      throw Exception('Failed to process Paystack payment: $e');
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
        updates['metadata'] = metadata;
      }

      if (status == DonationStatus.completed) {
        updates['completed_at'] = DateTime.now().toIso8601String();
      }

      final response = await _supabase
          .from('donation_records')
          .update(updates)
          .eq('id', donationId)
          .select()
          .single();

      return DonationRecord.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update donation status: $e');
    }
  }

  // Generate download URL for material
  Future<String> generateDownloadUrl(String materialId) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      // Check if user can download
      final canDownload = await canUserDownloadMaterial(materialId);
      if (!canDownload) {
        throw Exception('Donation required to download this material');
      }

      final material = await getMaterialById(materialId);

      // Generate signed URL for file download (expires in 1 hour)
      final String signedUrl = await _supabase.storage
          .from('materials')
          .createSignedUrl(material.fileUrl, 3600);

      // Record the download
      await _recordDownload(materialId, material.title);

      // Update download count
      await _supabase.from('downloadable_materials').update({
        'download_count': material.downloadCount + 1,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', materialId);

      return signedUrl;
    } catch (e) {
      throw Exception('Failed to generate download URL: $e');
    }
  }

  // Record user download
  Future<void> _recordDownload(String materialId, String materialTitle) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // Find associated donation if any
      final donations = await _supabase
          .from('donation_records')
          .select()
          .eq('user_id', userId)
          .eq('material_id', materialId)
          .eq('status', DonationStatus.completed.name)
          .order('completed_at', ascending: false)
          .limit(1);

      final donation = donations.isNotEmpty ? donations.first : null;

      final download = UserDownload(
        id: _uuid.v4(),
        userId: userId,
        materialId: materialId,
        materialTitle: materialTitle,
        donationId: donation?['id'] as String?,
        donationAmount: donation?['amount']?.toDouble(),
        downloadedAt: DateTime.now(),
      );

      await _supabase.from('user_downloads').insert(download.toJson());
    } catch (e) {
      // Log error but don't throw - download should still work
      _logger.error('Failed to record download: $e');
    }
  }

  // Get user's donation history
  Future<List<DonationRecord>> getUserDonations() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('donation_records')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => DonationRecord.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user donations: $e');
    }
  }

  // Get user's download history
  Future<List<UserDownload>> getUserDownloads() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final response = await _supabase
          .from('user_downloads')
          .select()
          .eq('user_id', userId)
          .order('downloaded_at', ascending: false);

      return (response as List)
          .map((json) => UserDownload.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch user downloads: $e');
    }
  }

  // Get donation summary for user
  Future<DonationSummary> getUserDonationSummary() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) throw Exception('User not authenticated');

      final donations = await getUserDonations();
      final downloads = await getUserDownloads();

      final completedDonations = donations.where((d) => d.isCompleted).toList();

      final totalDonated = completedDonations
          .map((d) => d.amount)
          .fold(0.0, (sum, amount) => sum + amount);

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
      throw Exception('Failed to fetch donation summary: $e');
    }
  }

  // Get donation statistics (admin)
  Future<Map<String, dynamic>> getDonationStatistics() async {
    try {
      // Total donations
      final totalDonationsResponse = await _supabase
          .from('donation_records')
          .select('amount')
          .eq('status', DonationStatus.completed.name);

      final totalAmount = (totalDonationsResponse as List)
          .map((item) => (item['amount'] as num).toDouble())
          .fold(0.0, (sum, amount) => sum + amount);

      // Donations by type
      final donationsByType = <String, int>{};
      for (final type in DonationType.values) {
        final count = await _supabase
            .from('donation_records')
            .select('*')
            .eq('type', type.name)
            .eq('status', DonationStatus.completed.name)
            .count();
        donationsByType[type.name] = count.count;
      }

      // Recent donations
      final recentDonations = await _supabase
          .from('donation_records')
          .select()
          .eq('status', DonationStatus.completed.name)
          .order('completed_at', ascending: false)
          .limit(10);

      return {
        'total_amount': totalAmount,
        'total_donations': totalDonationsResponse.length,
        'donations_by_type': donationsByType,
        'recent_donations': recentDonations,
      };
    } catch (e) {
      throw Exception('Failed to fetch donation statistics: $e');
    }
  }

  // Validate minimum donation amount
  bool validateDonationAmount(DonationType type, double amount) {
    switch (type) {
      case DonationType.tractReprint:
        return amount >= DonationConstants.minimumTractDonation;
      case DonationType.materialDownload:
        return amount >= DonationConstants.minimumMaterialDonation;
      case DonationType.generalSupport:
      case DonationType.ministrySupport:
        return amount > 0;
    }
  }

  // Get minimum donation amount for type
  double getMinimumDonationAmount(DonationType type) {
    switch (type) {
      case DonationType.tractReprint:
        return DonationConstants.minimumTractDonation;
      case DonationType.materialDownload:
        return DonationConstants.minimumMaterialDonation;
      case DonationType.generalSupport:
      case DonationType.ministrySupport:
        return 1.0; // Minimum $1 for general support
    }
  }
}
