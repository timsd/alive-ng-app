import 'package:appwrite/appwrite.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../services/billboard_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/modern_dropdown.dart';
import '../../widgets/role_guard.dart';

class AdminBillboardScreen extends StatelessWidget {
  const AdminBillboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const RoleProtectedScreen(
      requiredRole: 'admin',
      screenName: 'Program & Project Billboard',
      child: _AdminBillboardBody(),
    );
  }
}

class _AdminBillboardBody extends StatefulWidget {
  const _AdminBillboardBody();

  @override
  State<_AdminBillboardBody> createState() => _AdminBillboardBodyState();
}

class _AdminBillboardBodyState extends State<_AdminBillboardBody>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _mediaUrlCtrl = TextEditingController();
  final _ctaLabelCtrl = TextEditingController();
  final _ctaUrlCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _loadingResponses = false;
  bool _exporting = false;

  bool _isEnabled = true;
  String _contentType = '3d_html';
  String _aspectRatio = 'auto';
  bool _attachInbuiltForm = false;
  bool _showDonateButton = true;
  List<BillboardFormField> _formFields =
      List.of(BillboardConfig.defaultFormFields);
  List<BillboardSubmission> _submissions = [];

  static const _typeItems = [
    DropdownMenuItem(value: 'flyer', child: Text('Flyer / Picture')),
    DropdownMenuItem(value: 'video', child: Text('Video (YouTube / URL)')),
    DropdownMenuItem(value: 'form', child: Text('Registration Form')),
    DropdownMenuItem(value: '3d_html', child: Text('3D / Interactive HTML')),
  ];

  static const _aspectItems = [
    DropdownMenuItem(value: 'auto', child: Text('Auto / Full Screen')),
    DropdownMenuItem(value: '16:9', child: Text('16:9 (Landscape / Widescreen)')),
    DropdownMenuItem(value: '9:16', child: Text('9:16 (Portrait / Reels / Shorts)')),
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _mediaUrlCtrl.dispose();
    _ctaLabelCtrl.dispose();
    _ctaUrlCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final cfg = await BillboardService.instance.fetchConfig(forceRefresh: true);
    if (!mounted) return;
    setState(() {
      _isEnabled = cfg.isEnabled;
      _contentType = cfg.contentType;
      _aspectRatio = cfg.aspectRatio;
      _titleCtrl.text = cfg.title;
      _subtitleCtrl.text = cfg.subtitle;
      _mediaUrlCtrl.text = cfg.mediaUrl;
      _ctaLabelCtrl.text = cfg.ctaLabel;
      _ctaUrlCtrl.text = cfg.ctaUrl;
      _attachInbuiltForm = cfg.attachInbuiltForm;
      _showDonateButton = cfg.showDonateButton;
      _formFields = List.of(cfg.formFields);
      _loading = false;
    });
    await _loadResponses();
  }

  Future<void> _loadResponses() async {
    setState(() => _loadingResponses = true);
    try {
      final rows = await BillboardService.instance.listSubmissions();
      if (!mounted) return;
      setState(() {
        _submissions = rows;
        _loadingResponses = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingResponses = false);
    }
  }

  Future<void> _pickAndUploadFlyer() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        imageQuality: 88,
      );
      if (picked == null) return;
      setState(() => _uploading = true);

      final bytes = await picked.readAsBytes();
      final storage = Storage(appwriteClient);
      final fileId = ID.unique();
      await storage.createFile(
        bucketId: AppwriteBackendConfig.contentMediaBucketId,
        fileId: fileId,
        file: InputFile.fromBytes(
          bytes: bytes,
          filename: picked.name.isNotEmpty ? picked.name : 'billboard.jpg',
        ),
      );
      final fileUrl =
          '${AppwriteBackendConfig.endpoint}/storage/buckets/${AppwriteBackendConfig.contentMediaBucketId}/files/$fileId/view?project=${AppwriteBackendConfig.projectId}';
      if (!mounted) return;
      setState(() {
        _mediaUrlCtrl.text = fileUrl;
        _contentType = 'flyer';
        _uploading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Flyer uploaded! Tap Save to publish.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
      );
    }
  }

  Future<void> _save({bool openPreview = false}) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      final mediaVal = _mediaUrlCtrl.text.trim();
      final config = BillboardConfig(
        isEnabled: _isEnabled,
        contentType: _contentType,
        aspectRatio: _aspectRatio,
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        mediaUrl: (_contentType == 'form' && mediaVal.isEmpty)
            ? 'inbuilt'
            : mediaVal,
        ctaLabel: _ctaLabelCtrl.text.trim(),
        ctaUrl: _ctaUrlCtrl.text.trim(),
        attachInbuiltForm: _attachInbuiltForm,
        showDonateButton: _showDonateButton,
        formFields: _formFields,
      );
      await BillboardService.instance.saveConfig(config);
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Billboard updated successfully')),
      );
      if (openPreview) {
        context.push('/billboard');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
      );
    }
  }

  Future<void> _addOrEditFormFieldDialog({
    BillboardFormField? existing,
    int? editIndex,
  }) async {
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final optionsCtrl = TextEditingController(
      text: existing != null ? existing.options.join(', ') : '',
    );
    String type = existing?.type ?? 'text';
    bool required = existing?.required ?? true;

    final result = await showDialog<BillboardFormField>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  existing == null ? 'Add Form Field' : 'Edit Form Field',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Question / Field Label *',
                    hintText: 'e.g. T-Shirt Size / Department',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                ModernDropdownFormField<String>(
                  value: type,
                  decoration: const InputDecoration(
                    labelText: 'Question Type',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'text', child: Text('Short Answer')),
                    DropdownMenuItem(
                        value: 'multiline', child: Text('Paragraph / Notes')),
                    DropdownMenuItem(value: 'email', child: Text('Email')),
                    DropdownMenuItem(value: 'phone', child: Text('Phone Number')),
                    DropdownMenuItem(value: 'number', child: Text('Number')),
                    DropdownMenuItem(value: 'date', child: Text('Date Picker')),
                    DropdownMenuItem(
                        value: 'radio', child: Text('Multiple Choice (Radio)')),
                    DropdownMenuItem(
                        value: 'checkbox', child: Text('Checkboxes (Multi)')),
                    DropdownMenuItem(
                        value: 'dropdown', child: Text('Dropdown Menu')),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => type = v);
                  },
                ),
                if (type == 'dropdown' ||
                    type == 'radio' ||
                    type == 'checkbox') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: optionsCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Options (comma-separated) *',
                      hintText: 'e.g. Option 1, Option 2, Option 3',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Required Field'),
                  value: required,
                  onChanged: (v) => setDialogState(() => required = v),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
          actions: [
            SizedBox(
              width: double.maxFinite,
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        final lbl = labelCtrl.text.trim();
                        if (lbl.isEmpty) return;
                        final key = existing?.key ??
                            lbl
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
                                .replaceAll(RegExp(r'^_+|_+$'), '');
                        final opts = optionsCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        Navigator.pop(
                          ctx,
                          BillboardFormField(
                            key: key.isEmpty
                                ? 'field_${DateTime.now().millisecondsSinceEpoch}'
                                : key,
                            label: lbl,
                            type: type,
                            required: required,
                            options: opts,
                          ),
                        );
                      },
                      child: Text(existing == null ? 'Add Field' : 'Save Field'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        if (editIndex != null) {
          final updated = List.of(_formFields);
          updated[editIndex] = result;
          _formFields = updated;
        } else {
          _formFields = [..._formFields, result];
        }
      });
    }
  }

  Future<void> _exportResponsesExcel() async {
    if (_submissions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No responses to export yet.')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final result = await BillboardService.instance.exportSubmissionsToExcelCsv(
        _submissions,
        configuredFields: _formFields,
      );
      if (!mounted) return;
      setState(() => _exporting = false);

      final url = result['url']?.toString();
      final bytes = result['bytes'] as Uint8List;
      final fileName = result['fileName']?.toString() ?? 'responses.csv';

      if (kIsWeb && url != null && url.isNotEmpty) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        await SharePlus.instance.share(
          ShareParams(
            files: [
              XFile.fromData(
                bytes,
                mimeType: 'text/csv',
                name: fileName,
              ),
            ],
            subject: 'Billboard Responses ($fileName)',
          ),
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Exported ${result['count']} response(s) to Excel CSV ($fileName) and saved to Documents/Exports.',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
      );
    }
  }

  String get _mediaHint {
    switch (_contentType) {
      case 'flyer':
        return 'https://... or upload an image below';
      case 'video':
        return 'https://youtube.com/watch?v=... or youtube.com/shorts/...';
      case 'form':
        return 'Leave as "inbuilt" for inbuilt form, or paste external form URL';
      default:
        return 'alive_ng_3d_viewer.html';
    }
  }

  bool get _needsInbuiltFormBuilder =>
      _contentType == 'form' || _attachInbuiltForm;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Program & Project Billboard',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            const Tab(icon: Icon(Icons.tune_rounded), text: 'Configure'),
            Tab(
              icon: const Icon(Icons.table_chart_outlined),
              text: 'Responses (${_submissions.length})',
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildConfigureTab(theme),
                _buildResponsesTab(theme),
              ],
            ),
    );
  }

  Widget _buildConfigureTab(ThemeData theme) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('Billboard Active'),
                subtitle: const Text(
                  'Show this showcase on the reusable /billboard & project viewer route',
                ),
                value: _isEnabled,
                onChanged: (v) => setState(() => _isEnabled = v),
              ),
            ),
            const SizedBox(height: 14),
            ModernDropdownFormField<String>(
              value: _contentType,
              decoration: const InputDecoration(
                labelText: 'Content Type',
                hintText: 'Select content type',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: _typeItems,
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _contentType = val;
                    if (val == 'form' &&
                        (_mediaUrlCtrl.text.trim().isEmpty ||
                            _mediaUrlCtrl.text.trim() ==
                                'alive_ng_3d_viewer.html')) {
                      _mediaUrlCtrl.text = 'inbuilt';
                    }
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            ModernDropdownFormField<String>(
              value: _aspectRatio,
              decoration: const InputDecoration(
                labelText: 'Aspect Ratio (Video & Flyer)',
                prefixIcon: Icon(Icons.aspect_ratio_rounded),
                border: OutlineInputBorder(),
              ),
              items: _aspectItems,
              onChanged: (val) {
                if (val != null) setState(() => _aspectRatio = val);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(
                labelText: 'Title *',
                hintText: 'e.g. Annual Youth Summit 2026',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _subtitleCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description / Details (optional)',
                hintText: 'Short summary for members and visitors',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _mediaUrlCtrl,
              decoration: InputDecoration(
                labelText: _contentType == 'form'
                    ? 'Form Mode ("inbuilt" or external URL)'
                    : 'Media / HTML URL *',
                hintText: _mediaHint,
                border: const OutlineInputBorder(),
              ),
              validator: (v) {
                if (_contentType == 'form') return null;
                return (v == null || v.trim().isEmpty)
                    ? 'URL is required'
                    : null;
              },
            ),
            if (_contentType == 'flyer') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _uploading ? null : _pickAndUploadFlyer,
                icon: _uploading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.upload_file_rounded),
                label: Text(
                    _uploading ? 'Uploading Flyer...' : 'Upload Flyer Image'),
              ),
            ],
            if (_contentType == '3d_html') ...[
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text('Show Donate Button'),
                  subtitle: const Text(
                    'Display a Donate to Project button inside the 3D billboard',
                  ),
                  value: _showDonateButton,
                  onChanged: (v) => setState(() => _showDonateButton = v),
                ),
              ),
            ],
            if (_contentType == 'flyer' || _contentType == 'video') ...[
              const SizedBox(height: 12),
              Card(
                child: SwitchListTile(
                  title: const Text('Attach Inbuilt Registration Form'),
                  subtitle: Text(
                    _contentType == 'flyer'
                        ? 'Tapping the flyer or button opens the inbuilt form on the same page'
                        : 'Tapping the button below the video opens the inbuilt form on the same page',
                  ),
                  value: _attachInbuiltForm,
                  onChanged: (v) => setState(() => _attachInbuiltForm = v),
                ),
              ),
            ],
            const SizedBox(height: 14),
            TextFormField(
              controller: _ctaLabelCtrl,
              decoration: const InputDecoration(
                labelText: 'Action Button Label (optional)',
                hintText: 'e.g. Register Now / Fill Form',
                border: OutlineInputBorder(),
              ),
            ),
            if (!_attachInbuiltForm) ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _ctaUrlCtrl,
                decoration: const InputDecoration(
                  labelText: 'External Action Link (optional)',
                  hintText: 'https://... (only used if inbuilt form is off)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (_needsInbuiltFormBuilder) ...[
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Inbuilt Form Fields (${_formFields.length})',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () => _addOrEditFormFieldDialog(),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Field'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ..._formFields.asMap().entries.map((entry) {
                final idx = entry.key;
                final f = entry.value;
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    onTap: () => _addOrEditFormFieldDialog(
                      existing: f,
                      editIndex: idx,
                    ),
                    title: Text('${f.label}${f.required ? ' *' : ''}'),
                    subtitle: Text(
                      f.options.isNotEmpty
                          ? '${f.type}: ${f.options.join(', ')}'
                          : 'Type: ${f.type}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (idx > 0)
                          IconButton(
                            tooltip: 'Move up',
                            icon: const Icon(Icons.arrow_upward, size: 18),
                            onPressed: () {
                              setState(() {
                                final item = _formFields.removeAt(idx);
                                _formFields.insert(idx - 1, item);
                              });
                            },
                          ),
                        if (idx < _formFields.length - 1)
                          IconButton(
                            tooltip: 'Move down',
                            icon: const Icon(Icons.arrow_downward, size: 18),
                            onPressed: () {
                              setState(() {
                                final item = _formFields.removeAt(idx);
                                _formFields.insert(idx + 1, item);
                              });
                            },
                          ),
                        IconButton(
                          tooltip: 'Edit field',
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          onPressed: () => _addOrEditFormFieldDialog(
                            existing: f,
                            editIndex: idx,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete field',
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.red, size: 18),
                          onPressed: () {
                            setState(() => _formFields.removeAt(idx));
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _saving ? null : () => _save(openPreview: true),
                    icon: const Icon(Icons.visibility_outlined),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Save & Preview', maxLines: 1),
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : () => _save(),
                    icon: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: theme.colorScheme.onPrimary,
                            ),
                          )
                        : const Icon(Icons.save_rounded),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('Save Billboard', maxLines: 1),
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 46),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsesTab(ThemeData theme) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _exporting ? null : _exportResponsesExcel,
                  icon: _exporting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.onPrimary,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      _exporting ? 'Exporting...' : 'Export to Excel (.csv)',
                      maxLines: 1,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 44),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: 'Refresh responses',
                onPressed: _loadingResponses ? null : _loadResponses,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loadingResponses
              ? const Center(child: CircularProgressIndicator())
              : _submissions.isEmpty
                  ? const Center(
                      child: Text('No form responses submitted yet.'),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: _submissions.length,
                      itemBuilder: (context, index) {
                        final s = _submissions[index];
                        final dt = DateTime.tryParse(s.submittedAt);
                        final dateStr = dt != null
                            ? DateFormat('MMM d, yyyy · HH:mm')
                                .format(dt.toLocal())
                            : s.submittedAt;
                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: ExpansionTile(
                            title: Text(
                              s.fullName.isNotEmpty
                                  ? s.fullName
                                  : (s.email.isNotEmpty ? s.email : 'Submission'),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${s.programTitle} · $dateStr',
                              style: theme.textTheme.bodySmall,
                            ),
                            childrenPadding:
                                const EdgeInsets.fromLTRB(16, 0, 16, 14),
                            children: [
                              if (s.email.isNotEmpty)
                                _detailRow('Email', s.email),
                              if (s.phone.isNotEmpty)
                                _detailRow('Phone', s.phone),
                              ...s.answers.entries.map(
                                (e) => _detailRow(
                                    e.key, e.value?.toString() ?? ''),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
