import 'dart:convert';

// Domain model for donation projects
class Project {
  final String id;
  final String title;
  final String description;
  final double targetAmount;
  final double raisedAmount;
  final String currency;
  final String category;
  final String status;
  final int priority;
  final bool isActive;
  final String? imageUrl;
  final String fundUpdateTitle;
  final String fundUpdateText;
  final List<String> fundUpdateImages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAmount,
    required this.raisedAmount,
    required this.currency,
    required this.category,
    this.status = '',
    required this.priority,
    required this.isActive,
    this.imageUrl,
    this.fundUpdateTitle = '',
    this.fundUpdateText = '',
    this.fundUpdateImages = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromJson(Map<String, dynamic> json) {
    final goal = (json['goal'] as num?) ?? (json['target_amount'] as num?);
    final raised =
        (json['raised'] as num?) ?? (json['raised_amount'] as num?);
    // Status may be an explicit bool flag or a string status
    // ('active', 'planning', 'completed', ...).
    final bool active;
    if (json['is_active'] is bool) {
      active = json['is_active'] as bool;
    } else {
      active =
          (json['status'] as String? ?? 'active').toLowerCase() != 'inactive';
    }
    return Project(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      targetAmount: goal?.toDouble() ?? 0.0,
      raisedAmount: raised?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'NGN',
      category: json['category'] as String? ?? 'general',
      status: json['status'] as String? ?? '',
      priority: json['priority'] as int? ?? 0,
      isActive: active,
      imageUrl: json['image_url'] as String?,
      fundUpdateTitle: json['fund_update_title'] as String? ?? '',
      fundUpdateText: json['fund_update_text'] as String? ?? '',
      fundUpdateImages: _parseImageList(json['fund_update_images']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  /// Parses a fund-update image list that may arrive as a JSON array string,
  /// a raw List, or a comma/newline-separated string.
  static List<String> _parseImageList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .take(10)
          .toList();
    }
    final str = value.toString().trim();
    if (str.isEmpty) return const [];
    if (str.startsWith('[')) {
      try {
        final decoded = jsonDecode(str);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .take(10)
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }
    // Comma/newline-separated string format
    return str
        .split(RegExp(r'[\r\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'target_amount': targetAmount,
      'raised_amount': raisedAmount,
      'currency': currency,
      'category': category,
      'priority': priority,
      'is_active': isActive,
      'image_url': imageUrl,
      'fund_update_title': fundUpdateTitle,
      'fund_update_text': fundUpdateText,
      'fund_update_images': fundUpdateImages,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  double get progressPercentage {
    if (targetAmount <= 0) return 0;
    return (raisedAmount / targetAmount) * 100;
  }

  bool get isFullyFunded => raisedAmount >= targetAmount;
}