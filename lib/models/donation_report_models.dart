import 'dart:convert';

class DonationReportEntry {
  const DonationReportEntry({
    required this.reference,
    required this.donorName,
    required this.donorEmail,
    required this.purpose,
    required this.amount,
    required this.currency,
    required this.status,
    required this.createdAt,
  });

  final String reference;
  final String donorName;
  final String donorEmail;
  final String purpose;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;

  factory DonationReportEntry.fromJson(Map<String, dynamic> json) {
    String firstText(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return fallback;
    }

    // --- Resolve donor name ---
    // Check explicit top-level fields first
    var resolvedDonorName =
        firstText(['user_name', 'donor_name', 'name']);

    // If empty or still 'Anonymous', try embedded metadata (Paystack payload)
    if (resolvedDonorName.isEmpty || resolvedDonorName == 'Anonymous Donor') {
      final meta = _parseMetadata(json['metadata']);
      if (meta != null) {
        for (final key in ['donor_name', 'customer_name', 'name']) {
          final val = meta[key]?.toString().trim();
          if (val != null && val.isNotEmpty && val != 'Anonymous Donor') {
            resolvedDonorName = val;
            break;
          }
        }
      }
    }

    // Last resort: derive from email
    if (resolvedDonorName.isEmpty || resolvedDonorName == 'Anonymous Donor') {
      final email = firstText(['user_email', 'donor_email', 'email']);
      if (email.isNotEmpty && email.contains('@')) {
        resolvedDonorName = email.split('@').first;
      }
    }

    if (resolvedDonorName.isEmpty) {
      resolvedDonorName = 'Anonymous Donor';
    }

    // --- Resolve purpose / category ---
    var resolvedPurpose = firstText(
        ['material_title', 'mission_purpose', 'purpose']);

    // Check metadata for project_title if no explicit purpose found
    if (resolvedPurpose.isEmpty) {
      final meta = _parseMetadata(json['metadata']);
      if (meta != null) {
        final metaTitle = meta['project_title']?.toString().trim();
        if (metaTitle != null && metaTitle.isNotEmpty) {
          resolvedPurpose = metaTitle;
        }
      }
    }

    // Fall back to top-level project_title
    if (resolvedPurpose.isEmpty) {
      resolvedPurpose = firstText(['project_title']);
    }

    if (resolvedPurpose.isEmpty) {
      resolvedPurpose = 'General';
    }

    return DonationReportEntry(
      reference: firstText(['reference', 'transaction_id', 'id', '\$id']),
      donorName: resolvedDonorName,
      donorEmail: firstText(['user_email', 'donor_email', 'email']),
      purpose: resolvedPurpose,
      amount: num.tryParse(json['amount']?.toString() ?? '')?.toDouble() ?? 0,
      currency: firstText(['currency'], 'NGN').toUpperCase(),
      status: firstText(['status'], 'pending').toLowerCase(),
      createdAt: DateTime.tryParse(firstText(['created_at', '\$createdAt'])),
    );
  }

  /// Parse metadata that could be a JSON string or a Map.
  static Map<String, dynamic>? _parseMetadata(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return null;
      }
    }
    return null;
  }
}
