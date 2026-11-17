import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

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

class _AdminBillboardBodyState extends State<_AdminBillboardBody> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _mediaUrlCtrl = TextEditingController();
  final _ctaLabelCtrl = TextEditingController();
  final _ctaUrlCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _uploading = false;
  bool _isEnabled = true;
  String _contentType = '3d_html';

  static const _typeItems = [
    DropdownMenuItem(value: 'flyer', child: Text('Flyer / Picture')),
    DropdownMenuItem(value: 'video', child: Text('Video (YouTube / URL)')),
    DropdownMenuItem(value: 'form', child: Text('Registration Form')),
    DropdownMenuItem(value: '3d_html', child: Text('3D / Interactive HTML')),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
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
      _titleCtrl.text = cfg.title;
      _subtitleCtrl.text = cfg.subtitle;
      _mediaUrlCtrl.text = cfg.mediaUrl;
      _ctaLabelCtrl.text = cfg.ctaLabel;
      _ctaUrlCtrl.text = cfg.ctaUrl;
      _loading = false;
    });
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
      final config = BillboardConfig(
        isEnabled: _isEnabled,
        contentType: _contentType,
        title: _titleCtrl.text.trim(),
        subtitle: _subtitleCtrl.text.trim(),
        mediaUrl: _mediaUrlCtrl.text.trim(),
        ctaLabel: _ctaLabelCtrl.text.trim(),
        ctaUrl: _ctaUrlCtrl.text.trim(),
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

  String get _mediaHint {
    switch (_contentType) {
      case 'flyer':
        return 'https://... or upload an image below';
      case 'video':
        return 'https://youtube.com/watch?v=... or youtu.be/...';
      case 'form':
        return 'https://forms.gle/... or registration form URL';
      default:
        return 'alive_ng_3d_viewer.html';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const CustomAppBar(
        title: 'Program & Project Billboard',
        showBackButton: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                    const SizedBox(height: 16),
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
                          setState(() => _contentType = val);
                        }
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
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Title is required'
                          : null,
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
                        labelText: 'Media / Form / HTML URL *',
                        hintText: _mediaHint,
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'URL is required'
                          : null,
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
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _ctaLabelCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Action Button Label (optional)',
                        hintText: 'e.g. Register Now / Open Link',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _ctaUrlCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Action / Registration Link (optional)',
                        hintText: 'https://... (shown as a button below flyer/video)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => _save(openPreview: true),
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
            ),
    );
  }
}
