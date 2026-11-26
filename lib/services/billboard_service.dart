import 'dart:convert';
import 'dart:typed_data';
import 'package:appwrite/appwrite.dart';
import '../config/appwrite_backend_config.dart';
import 'appwrite_client.dart';
import '../utils/appwrite_upsert_helper.dart';

class BillboardFormField {
  final String key;
  final String label;
  final String type; // 'text', 'email', 'phone', 'multiline', 'dropdown'
  final bool required;
  final List<String> options;

  const BillboardFormField({
    required this.key,
    required this.label,
    this.type = 'text',
    this.required = true,
    this.options = const [],
  });

  factory BillboardFormField.fromJson(Map<String, dynamic> json) {
    final rawOpts = json['options'];
    final opts = rawOpts is List
        ? rawOpts.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];
    return BillboardFormField(
      key: json['key']?.toString() ?? 'field',
      label: json['label']?.toString() ?? 'Field',
      type: json['type']?.toString() ?? 'text',
      required: json['required'] != false,
      options: opts,
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'type': type,
        'required': required,
        'options': options,
      };
}

class BillboardConfig {
  final bool isEnabled;
  final String contentType; // '3d_html', 'flyer', 'video', 'form'
  final String aspectRatio; // 'auto', '16:9', '9:16'
  final String title;
  final String subtitle;
  final String mediaUrl;
  final String ctaLabel;
  final String ctaUrl;
  final bool attachInbuiltForm;
  final bool showDonateButton;
  final List<BillboardFormField> formFields;

  const BillboardConfig({
    this.isEnabled = true,
    this.contentType = '3d_html',
    this.aspectRatio = 'auto',
    this.title = 'Impact Hub Center 3D',
    this.subtitle = '',
    this.mediaUrl = 'alive_ng_3d_viewer.html',
    this.ctaLabel = 'Register / Fill Form',
    this.ctaUrl = '',
    this.attachInbuiltForm = false,
    this.showDonateButton = true,
    this.formFields = defaultFormFields,
  });

  static const List<BillboardFormField> defaultFormFields = [
    BillboardFormField(
      key: 'full_name',
      label: 'Full Name',
      type: 'text',
      required: true,
    ),
    BillboardFormField(
      key: 'email',
      label: 'Email Address',
      type: 'email',
      required: true,
    ),
    BillboardFormField(
      key: 'phone',
      label: 'Phone Number',
      type: 'phone',
      required: true,
    ),
    BillboardFormField(
      key: 'chapter',
      label: 'Chapter / Location',
      type: 'text',
      required: false,
    ),
    BillboardFormField(
      key: 'notes',
      label: 'Additional Notes',
      type: 'multiline',
      required: false,
    ),
  ];

  factory BillboardConfig.fromJson(Map<String, dynamic> json) {
    final rawFields = json['form_fields'];
    final parsedFields = rawFields is List && rawFields.isNotEmpty
        ? rawFields
            .whereType<Map>()
            .map((m) => BillboardFormField.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : defaultFormFields;
    return BillboardConfig(
      isEnabled: json['is_enabled'] != false,
      contentType: (json['content_type']?.toString().trim().isNotEmpty ?? false)
          ? json['content_type'].toString().trim()
          : '3d_html',
      aspectRatio: (json['aspect_ratio']?.toString().trim().isNotEmpty ?? false)
          ? json['aspect_ratio'].toString().trim()
          : 'auto',
      title: (json['title']?.toString().trim().isNotEmpty ?? false)
          ? json['title'].toString().trim()
          : 'Featured Program & Project',
      subtitle: json['subtitle']?.toString() ?? '',
      mediaUrl: (json['media_url']?.toString().trim().isNotEmpty ?? false)
          ? json['media_url'].toString().trim()
          : 'alive_ng_3d_viewer.html',
      ctaLabel: (json['cta_label']?.toString().trim().isNotEmpty ?? false)
          ? json['cta_label'].toString().trim()
          : 'Register / Fill Form',
      ctaUrl: json['cta_url']?.toString() ?? '',
      attachInbuiltForm: json['attach_inbuilt_form'] == true,
      showDonateButton: json['show_donate_button'] != false,
      formFields: parsedFields,
    );
  }

  Map<String, dynamic> toJson() => {
        'is_enabled': isEnabled,
        'content_type': contentType,
        'aspect_ratio': aspectRatio,
        'title': title,
        'subtitle': subtitle,
        'media_url': mediaUrl,
        'cta_label': ctaLabel,
        'cta_url': ctaUrl,
        'attach_inbuilt_form': attachInbuiltForm,
        'show_donate_button': showDonateButton,
        'form_fields': formFields.map((f) => f.toJson()).toList(),
      };
}

class BillboardSubmission {
  final String id;
  final String billboardKey;
  final String programTitle;
  final String userId;
  final String fullName;
  final String email;
  final String phone;
  final Map<String, dynamic> answers;
  final String submittedAt;

  const BillboardSubmission({
    required this.id,
    required this.billboardKey,
    required this.programTitle,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.answers,
    required this.submittedAt,
  });

  factory BillboardSubmission.fromRow(String id, Map<String, dynamic> data) {
    Map<String, dynamic> parsedAnswers = {};
    final raw = data['answers_json'];
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          parsedAnswers = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {}
    }
    return BillboardSubmission(
      id: id,
      billboardKey: data['billboard_key']?.toString() ?? '',
      programTitle: data['program_title']?.toString() ?? '',
      userId: data['user_id']?.toString() ?? '',
      fullName: data['full_name']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      phone: data['phone']?.toString() ?? '',
      answers: parsedAnswers,
      submittedAt: data['submitted_at']?.toString() ??
          data['created_at']?.toString() ??
          '',
    );
  }
}

class BillboardService {
  BillboardService._();
  static final BillboardService instance = BillboardService._();

  static const String settingKey = 'program_billboard_config';

  final TablesDB _tables = TablesDB(appwriteClient);
  final Storage _storage = Storage(appwriteClient);
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

  Future<void> submitFormResponse({
    required String programTitle,
    required String userId,
    required String fullName,
    required String email,
    required String phone,
    required Map<String, dynamic> answers,
  }) async {
    final now = DateTime.now().toUtc().toIso8601String();
    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.billboardSubmissionsCollectionId,
      rowId: ID.unique(),
      data: {
        'billboard_key': settingKey,
        'program_title': programTitle,
        'user_id': userId,
        'full_name': fullName,
        'email': email,
        'phone': phone,
        'answers_json': jsonEncode(answers),
        'submitted_at': now,
        'created_at': now,
      },
    );
  }

  Future<List<BillboardSubmission>> listSubmissions({int limit = 200}) async {
    final res = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.billboardSubmissionsCollectionId,
      queries: [
        Query.equal('billboard_key', settingKey),
        Query.orderDesc('submitted_at'),
        Query.limit(limit),
      ],
    );
    return res.rows
        .map((r) => BillboardSubmission.fromRow(r.$id, r.data))
        .toList();
  }

  Future<void> deleteSubmission(String id) async {
    await _tables.deleteRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: AppwriteBackendConfig.billboardSubmissionsCollectionId,
      rowId: id,
    );
  }

  String _csvCell(Object? value) {
    final str = (value ?? '').toString().replaceAll('"', '""');
    return '"$str"';
  }

  /// Generates a UTF-8 BOM CSV file (opens cleanly in Microsoft Excel with all
  /// columns and full response details) and saves it to the Appwrite
  /// `system_exports` Documents folder bucket so it can be downloaded/shared.
  Future<Map<String, dynamic>> exportSubmissionsToExcelCsv(
    List<BillboardSubmission> submissions, {
    List<BillboardFormField> configuredFields = const [],
  }) async {
    final dynamicKeys = <String>{};
    for (final f in configuredFields) {
      dynamicKeys.add(f.label);
    }
    for (final s in submissions) {
      dynamicKeys.addAll(s.answers.keys);
    }
    final extraCols = dynamicKeys.toList();

    final headers = [
      'Submitted At',
      'Program / Project',
      'Full Name',
      'Email',
      'Phone',
      'User ID',
      ...extraCols,
    ];

    final buf = StringBuffer()
      // UTF-8 BOM so Microsoft Excel auto-detects UTF-8 encoding properly.
      ..write('\uFEFF')
      ..writeln(headers.map(_csvCell).join(','));

    for (final s in submissions) {
      final row = [
        s.submittedAt,
        s.programTitle,
        s.fullName,
        s.email,
        s.phone,
        s.userId,
        ...extraCols.map((k) => s.answers[k] ?? ''),
      ];
      buf.writeln(row.map(_csvCell).join(','));
    }

    final csvString = buf.toString();
    final bytes = Uint8List.fromList(utf8.encode(csvString));
    final ts = DateTime.now().toUtc().toIso8601String().replaceAll(':', '-');
    final fileName = 'billboard-responses-$ts.csv';

    String? downloadUrl;
    String? fileId;
    try {
      final uploaded = await _storage.createFile(
        bucketId: AppwriteBackendConfig.systemExportsBucketId,
        fileId: ID.unique(),
        file: InputFile.fromBytes(bytes: bytes, filename: fileName),
      );
      fileId = uploaded.$id;
      downloadUrl =
          '${AppwriteBackendConfig.endpoint}/storage/buckets/${AppwriteBackendConfig.systemExportsBucketId}/files/$fileId/download?project=${AppwriteBackendConfig.projectId}';
    } catch (_) {
      // Even if storage upload fails, still return the CSV bytes/content for direct share.
    }

    return {
      'fileName': fileName,
      'fileId': fileId,
      'url': downloadUrl,
      'bytes': bytes,
      'csv': csvString,
      'count': submissions.length,
    };
  }
}
