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
    this.isTest = false,
  });

  final String reference;
  final String donorName;
  final String donorEmail;
  final String purpose;
  final double amount;
  final String currency;
  final String status;
  final DateTime? createdAt;
  final bool isTest;

  factory DonationReportEntry.fromJson(Map<String, dynamic> json) {
    String firstText(List<String> keys, [String fallback = '']) {
      for (final key in keys) {
        final value = json[key]?.toString().trim();
        if (value != null && value.isNotEmpty) return value;
      }
      return fallback;
    }

    // --- Resolve donor name ---
    bool isPlaceholderName(String? val) {
      if (val == null || val.trim().isEmpty) return true;
      final lower = val.trim().toLowerCase();
      return lower == 'anonymous donor' || lower == 'anonymous';
    }

    var resolvedDonorName =
        firstText(['user_name', 'donor_name', 'name', 'customer_name', 'full_name']);

    final parsedMeta = _parseMetadata(json['metadata']);

    // If empty or placeholder, try embedded metadata (Paystack payload)
    if (isPlaceholderName(resolvedDonorName) && parsedMeta != null) {
      for (final key in ['donor_name', 'customer_name', 'full_name', 'name']) {
        final val = parsedMeta[key]?.toString().trim();
        if (!isPlaceholderName(val)) {
          resolvedDonorName = val!;
          break;
        }
      }
      if (isPlaceholderName(resolvedDonorName) &&
          parsedMeta['custom_fields'] is List) {
        for (final field in parsedMeta['custom_fields'] as List) {
          if (field is Map) {
            final label = (field['display_name'] ?? field['variable_name'] ?? '')
                .toString()
                .toLowerCase();
            final val = field['value']?.toString().trim();
            if (label.contains('name') && !isPlaceholderName(val)) {
              resolvedDonorName = val!;
              break;
            }
          }
        }
      }
    }

    var resolvedEmail = firstText(['user_email', 'donor_email', 'email']);
    if (resolvedEmail.isEmpty && parsedMeta != null) {
      for (final key in ['donor_email', 'user_email', 'customer_email', 'email']) {
        final val = parsedMeta[key]?.toString().trim();
        if (val != null && val.isNotEmpty) {
          resolvedEmail = val;
          break;
        }
      }
    }

    // Last resort: use donor email so the donor is always identifiable
    if (isPlaceholderName(resolvedDonorName)) {
      resolvedDonorName = resolvedEmail;
    }

    // --- Resolve purpose / category ---
    String resolvedPurpose = '';
    final rawSplit = parsedMeta?['fund_designations'];
    if (rawSplit is List) {
      final split = rawSplit
          .map((e) => e?.toString().trim() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
      if (split.length > 1) {
        resolvedPurpose = 'Split donation: ${split.join(', ')}';
      } else if (split.length == 1) {
        resolvedPurpose = split.first;
      }
    }
    if (resolvedPurpose.isEmpty) {
      final designation = parsedMeta?['fund_designation']?.toString().trim();
      if (designation != null &&
          designation.isNotEmpty &&
          !RegExp(r'^split:', caseSensitive: false).hasMatch(designation)) {
        resolvedPurpose = designation;
      }
    }
    if (resolvedPurpose.isEmpty) {
      resolvedPurpose =
          firstText(['material_title', 'mission_purpose', 'purpose']);
    }

    // Check metadata for project_title if no explicit purpose found
    if (resolvedPurpose.isEmpty && parsedMeta != null) {
      final metaTitle = parsedMeta['project_title']?.toString().trim();
      if (metaTitle != null && metaTitle.isNotEmpty) {
        resolvedPurpose = metaTitle;
      }
    }

    // Fall back to top-level project_title
    if (resolvedPurpose.isEmpty) {
      resolvedPurpose = firstText(['project_title']);
    }

    // Fall back to known web/app project_id labels (e.g. youth_discipleship, tract_printing)
    if (resolvedPurpose.isEmpty) {
      const knownProjectTitles = <String, String>{
        'general_mission_fund': 'General Mission Fund',
        'impact_hub_center': 'Impact Hub Center',
        'vehicle_purchase': 'Mission Vehicle Purchase',
        'media_studio_setup': 'Media Studio Setup',
        'youth_discipleship': 'Youth Discipleship & Campus Ministry',
        'tract_printing': 'Bibles, Books & Tract Printing',
      };
      final rawProjectId =
          (parsedMeta?['project_id']?.toString().trim().isNotEmpty == true
                  ? parsedMeta!['project_id'].toString().trim()
                  : firstText(['project_id']))
              .toLowerCase();
      if (knownProjectTitles.containsKey(rawProjectId)) {
        resolvedPurpose = knownProjectTitles[rawProjectId]!;
      }
    }

    if (resolvedPurpose.isEmpty) {
      resolvedPurpose = 'General';
    }

    final isTestTransaction = json['is_test'] == true ||
        json['is_test'] == 'true' ||
        json['mode'] == 'test' ||
        parsedMeta?['is_test'] == true ||
        parsedMeta?['is_test'] == 'true' ||
        parsedMeta?['domain'] == 'test' ||
        firstText(['reference']).toLowerCase().startsWith('test_');

    return DonationReportEntry(
      reference: firstText(['reference', 'transaction_id', r'$id', 'id']),
      donorName: resolvedDonorName,
      donorEmail: resolvedEmail,
      purpose: resolvedPurpose,
      amount: num.tryParse(json['amount']?.toString() ?? json['donation_amount']?.toString() ?? '')?.toDouble() ?? 0,
      currency: firstText(['currency'], 'NGN').toUpperCase(),
      status: firstText(['status'], 'completed').toLowerCase(),
      createdAt: DateTime.tryParse(firstText(['created_at', r'$createdAt', 'downloaded_at'])),
      isTest: isTestTransaction,
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
