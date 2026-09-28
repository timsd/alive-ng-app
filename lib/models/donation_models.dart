import 'dart:convert';

import 'package:equatable/equatable.dart';

enum DonationType {
  tractProduction,
  generalSupport,
  appMaintenance,
}

enum DonationStatus {
  pending,
  processing,
  completed,
  failed,
  refunded,
}

enum PaymentMethod {
  paystack, // Paystack handles card, bank, USSD, QR, and transfer flows.
}

class DonationRecord extends Equatable {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final DonationType type;
  final double amount;
  final String currency;
  final DonationStatus status;
  final PaymentMethod paymentMethod;
  final String? paymentIntentId;
  final String? transactionId;
  final Map<String, dynamic>? metadata;
  final String? materialId;
  final String? materialTitle;
  final String? notes;
  /// The donation purpose, e.g. 'Ministry & Administration'. Present on the
  /// table but was missing here, so a DonationRecord could not say what a gift
  /// was for even though the server knew.
  final String? purpose;
  /// The project the gift was aimed at, when it was aimed at one.
  final String? projectTitle;
  /// The Paystack reference shown on the receipt.
  final String? reference;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  const DonationRecord({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    required this.paymentMethod,
    this.paymentIntentId,
    this.transactionId,
    this.metadata,
    this.materialId,
    this.materialTitle,
    this.notes,
    this.purpose,
    this.projectTitle,
    this.reference,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory DonationRecord.fromJson(Map<String, dynamic> json) {
    return DonationRecord(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String,
      userEmail: json['user_email'] as String,
      type: DonationType.values.firstWhere(
        (e) => e.name == json['type'],
        // Legacy types are mapped onto the surviving ones:
        //   'tractReprint' / 'materialDownload' -> 'tractProduction'
        //   'ministrySupport'                    -> 'generalSupport'
        // 'ministrySupport' was retired because it only ever meant "a gift
        // aimed at a specific project", which is now carried by
        // `project_id`/`project_title` (and the receipt's Purpose) instead of
        // by a separate donation type.
        orElse: () => switch (json['type']) {
          'tractReprint' || 'materialDownload' => DonationType.tractProduction,
          _ => DonationType.generalSupport,
        },
      ),
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String,
      status: DonationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => DonationStatus.pending,
      ),
      paymentMethod: PaymentMethod.values.firstWhere(
        (e) => e.name == json['payment_method'],
        orElse: () => PaymentMethod.paystack,
      ),
      paymentIntentId: json['payment_intent_id'] as String?,
      transactionId: json['transaction_id'] as String?,
      metadata: _metadataFromJson(json['metadata']),
      materialId: json['material_id'] as String?,
      materialTitle: json['material_title'] as String?,
      notes: json['notes'] as String?,
      purpose: json['purpose'] as String?,
      projectTitle: json['project_title'] as String?,
      reference: json['reference'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'user_name': userName,
      'user_email': userEmail,
      'type': type.name,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'payment_method': paymentMethod.name,
      'payment_intent_id': paymentIntentId,
      'transaction_id': transactionId,
      'metadata': metadata,
      'material_id': materialId,
      'material_title': materialTitle,
      'notes': notes,
      'purpose': purpose,
      'project_title': projectTitle,
      'reference': reference,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  DonationRecord copyWith({
    String? id,
    String? userId,
    String? userName,
    String? userEmail,
    DonationType? type,
    double? amount,
    String? currency,
    DonationStatus? status,
    PaymentMethod? paymentMethod,
    String? paymentIntentId,
    String? transactionId,
    Map<String, dynamic>? metadata,
    String? materialId,
    String? materialTitle,
    String? notes,
    String? purpose,
    String? projectTitle,
    String? reference,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? completedAt,
  }) {
    return DonationRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentIntentId: paymentIntentId ?? this.paymentIntentId,
      transactionId: transactionId ?? this.transactionId,
      metadata: metadata ?? this.metadata,
      materialId: materialId ?? this.materialId,
      materialTitle: materialTitle ?? this.materialTitle,
      notes: notes ?? this.notes,
      purpose: purpose ?? this.purpose,
      projectTitle: projectTitle ?? this.projectTitle,
      reference: reference ?? this.reference,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  String get typeDisplayName {
    switch (type) {
      case DonationType.tractProduction:
        return 'Tract Production';
      case DonationType.generalSupport:
        return 'General Support';
      case DonationType.appMaintenance:
        return 'App Maintenance';
    }
  }

  String get statusDisplayName {
    switch (status) {
      case DonationStatus.pending:
        return 'Pending';
      case DonationStatus.processing:
        return 'Processing';
      case DonationStatus.completed:
        return 'Completed';
      case DonationStatus.failed:
        return 'Failed';
      case DonationStatus.refunded:
        return 'Refunded';
    }
  }

  String get paymentMethodDisplayName {
    // All new donations go through Paystack
    return 'Paystack';
  }

  bool get isCompleted => status == DonationStatus.completed;
  bool get isPending => status == DonationStatus.pending;
  bool get isProcessing => status == DonationStatus.processing;
  bool get isFailed => status == DonationStatus.failed;
  bool get isRefunded => status == DonationStatus.refunded;

  String get formattedAmount => '\$${amount.toStringAsFixed(2)}';

  @override
  List<Object?> get props => [
        id,
        userId,
        userName,
        userEmail,
        type,
        amount,
        currency,
        status,
        paymentMethod,
        paymentIntentId,
        transactionId,
        metadata,
        materialId,
        materialTitle,
        notes,
    purpose,
    projectTitle,
    reference,
        createdAt,
        updatedAt,
        completedAt,
      ];
}

class DownloadableMaterial extends Equatable {
  final String id;
  final String title;
  final String description;
  final String category;
  final String fileUrl;
  final String? thumbnailUrl;
  final int fileSizeBytes;
  final String fileType;
  final double minimumDonation;
  final bool requiresDonation;
  final bool isActive;
  final int downloadCount;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? createdBy;

  const DownloadableMaterial({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.fileSizeBytes,
    required this.fileType,
    required this.minimumDonation,
    required this.requiresDonation,
    required this.isActive,
    required this.downloadCount,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
    this.createdBy,
  });

  factory DownloadableMaterial.fromJson(Map<String, dynamic> json) {
    return DownloadableMaterial(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      category: json['category'] as String,
      fileUrl: json['file_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      fileSizeBytes: json['file_size_bytes'] as int,
      fileType: json['file_type'] as String,
      minimumDonation: (json['minimum_donation'] as num).toDouble(),
      requiresDonation: json['requires_donation'] as bool,
      isActive: json['is_active'] as bool,
      downloadCount: json['download_count'] as int,
      metadata: _metadataFromJson(json['metadata']),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      createdBy: json['created_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'category': category,
      'file_url': fileUrl,
      'thumbnail_url': thumbnailUrl,
      'file_size_bytes': fileSizeBytes,
      'file_type': fileType,
      'minimum_donation': minimumDonation,
      'requires_donation': requiresDonation,
      'is_active': isActive,
      'download_count': downloadCount,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'created_by': createdBy,
    };
  }

  DownloadableMaterial copyWith({
    String? id,
    String? title,
    String? description,
    String? category,
    String? fileUrl,
    String? thumbnailUrl,
    int? fileSizeBytes,
    String? fileType,
    double? minimumDonation,
    bool? requiresDonation,
    bool? isActive,
    int? downloadCount,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
  }) {
    return DownloadableMaterial(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      fileType: fileType ?? this.fileType,
      minimumDonation: minimumDonation ?? this.minimumDonation,
      requiresDonation: requiresDonation ?? this.requiresDonation,
      isActive: isActive ?? this.isActive,
      downloadCount: downloadCount ?? this.downloadCount,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '${fileSizeBytes}B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }

  String get formattedMinimumDonation =>
      '\$${minimumDonation.toStringAsFixed(2)}';

  bool get isFree => !requiresDonation || minimumDonation == 0;

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        category,
        fileUrl,
        thumbnailUrl,
        fileSizeBytes,
        fileType,
        minimumDonation,
        requiresDonation,
        isActive,
        downloadCount,
        metadata,
        createdAt,
        updatedAt,
        createdBy,
      ];
}

Map<String, dynamic>? _metadataFromJson(dynamic value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String && value.trim().isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  return null;
}

class UserDownload extends Equatable {
  final String id;
  final String userId;
  final String materialId;
  final String materialTitle;
  final String? donationId;
  final double? donationAmount;
  final DateTime downloadedAt;
  final String? downloadUrl;
  final DateTime? urlExpiresAt;

  const UserDownload({
    required this.id,
    required this.userId,
    required this.materialId,
    required this.materialTitle,
    this.donationId,
    this.donationAmount,
    required this.downloadedAt,
    this.downloadUrl,
    this.urlExpiresAt,
  });

  factory UserDownload.fromJson(Map<String, dynamic> json) {
    return UserDownload(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      materialId: json['material_id'] as String,
      materialTitle: json['material_title'] as String,
      donationId: json['donation_id'] as String?,
      donationAmount: json['donation_amount'] != null
          ? (json['donation_amount'] as num).toDouble()
          : null,
      downloadedAt: DateTime.parse(json['downloaded_at'] as String),
      downloadUrl: json['download_url'] as String?,
      urlExpiresAt: json['url_expires_at'] != null
          ? DateTime.parse(json['url_expires_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'material_id': materialId,
      'material_title': materialTitle,
      'donation_id': donationId,
      'donation_amount': donationAmount,
      'downloaded_at': downloadedAt.toIso8601String(),
      'download_url': downloadUrl,
      'url_expires_at': urlExpiresAt?.toIso8601String(),
    };
  }

  bool get hasValidUrl {
    return downloadUrl != null &&
        (urlExpiresAt == null || urlExpiresAt!.isAfter(DateTime.now()));
  }

  bool get wasDonationMade => donationId != null;

  String? get formattedDonationAmount {
    return donationAmount != null
        ? '\$${donationAmount!.toStringAsFixed(2)}'
        : null;
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        materialId,
        materialTitle,
        donationId,
        donationAmount,
        downloadedAt,
        downloadUrl,
        urlExpiresAt,
      ];
}

// Constants for donation requirements
class DonationConstants {
  static const double minimumTractDonation = 12.0;
  static const double minimumMaterialDonation = 5.0;
  static const String defaultCurrency = 'USD';

  static const Map<String, double> tractDonationByRegion = {
    'US': 12.0,
    'NG': 7500.0, // Nigerian Naira
  };

  static const Map<String, String> currencyByRegion = {
    'US': 'USD',
    'NG': 'NGN',
  };
}
