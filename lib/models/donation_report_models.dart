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

    return DonationReportEntry(
      reference: firstText(['reference', 'transaction_id', 'id', '\$id']),
      donorName: firstText(['user_name', 'donor_name', 'name'], 'Anonymous Donor'),
      donorEmail: firstText(['user_email', 'donor_email', 'email']),
      purpose: firstText(['material_title', 'mission_purpose', 'purpose', 'project_title'], 'General'),
      amount: num.tryParse(json['amount']?.toString() ?? '')?.toDouble() ?? 0,
      currency: firstText(['currency'], 'NGN').toUpperCase(),
      status: firstText(['status'], 'pending').toLowerCase(),
      createdAt: DateTime.tryParse(firstText(['created_at', '\$createdAt'])),
    );
  }
}

