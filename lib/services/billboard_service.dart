import 'dart:convert';
import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import '../main.dart';
import '../utils/appwrite_upsert_helper.dart';

class BillboardConfig {
  final bool isEnabled;
  final String contentType; // '3d_html', 'flyer', 'video', 'form'
  final String title;
  final String subtitle;
  final String mediaUrl;
  final String ctaLabel;
  final String ctaUrl;

  const BillboardConfig({
    this.isEnabled = true,
    this.contentType = '3d_html',
    this.title = 'Impact Hub Center 3D',
    this.subtitle = '',
    this.mediaUrl = 'alive_ng_3d_viewer.html',
    this.ctaLabel = 'Explore the project in 3D',
    this.ctaUrl = '',
  });

  factory BillboardConfig.fromJson(Map<String, dynamic> json) {
    return BillboardConfig(
      isEnabled: json['is_enabled'] != false,
      contentType: (json['content_type']?.toString().trim().isNotEmpty ?? false)
          ? json['content_type'].toString().trim()
          : '3d_html',
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim()
          : 'Featured Program & Project',
      subtitle: json['subtitle']?.toString() ?? '',
      mediaUrl: (json['media_url']?.toString().trim().isNotEmpty ?? false)
          ? json['media_url'].toString().trim()
          : 'alive_ng_3d_viewer.html',
      ctaLabel: (json['cta_label']?.toString().trim().isNotEmpty ?? false)
          ? json['cta_label'].toString().trim()
          : 'View Details',
      ctaUrl: json['cta_url']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'content_type': contentType,
        'title': title,
        'subtitle': subtitle,
        'media_url': mediaUrl,
        'cta_label': ctaLabel,
        'cta_url': ctaUrl,
      };
}

class BillboardService {
  BillboardService._();
  static final BillboardService instance = BillboardService._();

  static const String settingKey = 'program_billboard_config';

  final TablesDB _tables = TablesDB(appwriteClient);
  BillboardConfig? _cached;
  String? _rowId;

  void invalidateCache() {
    _cached = null;
  }

  Future<BillboardConfig> fetchConfig({bool forceRefresh = false}) async {
    if (!forceRefresh && _cached != null) return _cached!;
    try {
      final res = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [Query.equal('key', settingKey), Query.limit(1)],
      );
      if (res.rows.isNotEmpty) {
        final row = res.rows.first;
        _rowId = row.$id;
        final raw = row.data['value'] ?? row.data['setting_value'];
        if (raw is String && raw.trim().isNotEmpty) {
          final decoded = jsonDecode(raw);
          if (decoded is Map<String, dynamic>) {
            _cached = BillboardConfig.fromJson(decoded);
            return _cached!;
          }
        }
      }
    } catch (_) {
      // Fall back to default Impact Hub 3D config if not yet configured.
    }
    _cached = const BillboardConfig();
    return _cached!;
  }

  Future<void> saveConfig(BillboardConfig config) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final encoded = jsonEncode(config.toJson());
    final payload = <String, dynamic>{
      'key': settingKey,
      'setting_key': settingKey,
      'display_name': 'Program & Project Billboard',
      'value': encoded,
      'setting_value': encoded,
      'type': 'json',
      'data_type': 'json',
      'category': 'content',
      'description':
          'Reusable showcase billboard for upcoming programs, flyers, videos, registration forms, or 3D HTML previews.',
      'is_public': true,
      'is_active': config.isEnabled,
      'updated_at': now,
    };

    if (_rowId != null && _rowId!.isNotEmpty) {
      await AppwriteUpsertHelper.updateOrCreateRow(
        _tables,
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        rowId: _rowId!,
        data: payload,
        createData: {...payload, 'created_at': now},
      );
    } else {
      final existing = await _tables.listRows(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: AppwriteBackendConfig.appSettingsCollectionId,
        queries: [Query.equal('key', settingKey), Query.limit(1)],
      );
      if (existing.rows.isNotEmpty) {
        _rowId = existing.rows.first.$id;
        await _tables.updateRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          rowId: _rowId!,
          data: payload,
        );
      } else {
        final created = await _tables.createRow(
          databaseId: AppwriteBackendConfig.databaseId,
          tableId: AppwriteBackendConfig.appSettingsCollectionId,
          rowId: ID.unique(),
          data: {...payload, 'created_at': now},
        );
        _rowId = created.$id;
      }
    }
    _cached = config;
  }
}
