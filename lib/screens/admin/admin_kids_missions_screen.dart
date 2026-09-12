import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/kids_content_service.dart';
import '../../models/kids_missions.dart';

class AdminKidsMissionsScreen extends StatefulWidget {
  const AdminKidsMissionsScreen({super.key});

  @override
  State<AdminKidsMissionsScreen> createState() =>
      _AdminKidsMissionsScreenState();
}

class _AdminKidsMissionsScreenState extends State<AdminKidsMissionsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _storageService = AppwriteStorageService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController =
      TextEditingController(text: 'Home');
  final TextEditingController _durationController =
      TextEditingController(text: '30 minutes');
  final TextEditingController _pointsController =
      TextEditingController(text: '100');
  final TextEditingController _instructionsController = TextEditingController();

  MissionDifficulty _selectedDifficulty = MissionDifficulty.easy;
  MissionCategory _selectedCategory = MissionCategory.learning;
  VerificationMethod _selectedVerification = VerificationMethod.photo;

  Uint8List? _mediaBytes;
  String? _mediaName;

  bool _isExtracting = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _pointsController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _extractFromDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isExtracting = true);

        final text = await _pdfExtractor.extractTextFromBytes(
          result.files.single.bytes!,
          result.files.single.name,
        );

        setState(() {
          _instructionsController.text = text;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Document successfully extracted!'),
                backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to extract: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExtracting = false);
      }
    }
  }

  Future<void> _pickMedia() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.media);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _mediaBytes = result.files.single.bytes;
        _mediaName = result.files.single.name;
      });
    }
  }

  Future<void> _saveMission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? uploadedMediaUrl;

      // 1. Upload Media
      if (_mediaBytes != null && _mediaName != null) {
        uploadedMediaUrl = await _storageService.uploadContentFile(
          bytes: _mediaBytes!,
          fileName:
              'kids_missions/${DateTime.now().millisecondsSinceEpoch}_$_mediaName',
          contentType: 'application/octet-stream',
        );
      }

      // 2. Build Payload
      final pointsInt = int.tryParse(_pointsController.text.trim()) ?? 50;
      final rawInstructions = _instructionsController.text.trim();
      final instructionsList = rawInstructions.isNotEmpty
          ? rawInstructions
              .split('\n')
              .where((s) => s.trim().isNotEmpty)
              .toList()
          : <String>['Follow the mission steps provided.'];

      final payload = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'location': _locationController.text.trim(),
        'difficulty': _selectedDifficulty.name,
        'duration': _durationController.text.trim(),
        'points': pointsInt,
        'category': _selectedCategory.name,
        'completed': false,
        'instructions': jsonEncode(instructionsList),
        'verification_method': _selectedVerification.name,
        'prerequisite_mission_ids': const <String>[],
        'is_locked': false,
        'media_url': uploadedMediaUrl,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // 3. Save to Appwrite
      await KidsContentService.createKidsMission(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Mission published successfully!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: $e'),
              backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Kids Mission'),
      ),
      body: _isSaving
          ? Center(
              child: CircularProgressIndicator(
                  color: Theme.of(context).colorScheme.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Zero-Code Mission Extractor',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a PDF of mission instructions to instantly populate the step-by-step checklist.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withValues(alpha: 200 / 255.0)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              onPressed:
                                  _isExtracting ? null : _extractFromDocument,
                              icon: _isExtracting
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.picture_as_pdf),
                              label: Text(_isExtracting
                                  ? 'Extracting...'
                                  : 'Upload Instruction Doc'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Visuals',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickMedia,
                        icon: const Icon(Icons.perm_media),
                        label: Text(
                            _mediaName ?? 'Select Example Media (Image/Video)'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Mission Core',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _titleController,
                      decoration: const InputDecoration(
                          labelText: 'Title', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Short Description',
                          border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<MissionCategory>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder()),
                            items: MissionCategory.values.map((c) {
                              return DropdownMenuItem(
                                  value: c, child: Text(c.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<MissionDifficulty>(
                            initialValue: _selectedDifficulty,
                            decoration: const InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder()),
                            items: MissionDifficulty.values.map((a) {
                              return DropdownMenuItem(
                                  value: a, child: Text(a.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedDifficulty = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pointsController,
                            decoration: const InputDecoration(
                                labelText: 'Points Awarded',
                                border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _durationController,
                            decoration: const InputDecoration(
                                labelText: 'Estimated Duration',
                                border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _locationController,
                            decoration: const InputDecoration(
                                labelText: 'Location',
                                border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<VerificationMethod>(
                            initialValue: _selectedVerification,
                            decoration: const InputDecoration(
                                labelText: 'Verification',
                                border: OutlineInputBorder()),
                            items: VerificationMethod.values.map((v) {
                              return DropdownMenuItem(
                                  value: v, child: Text(v.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedVerification = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: const InputDecoration(
                        labelText: 'Instructions (One per line)',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText:
                            'Extract via PDF or type them out separated by returns.',
                      ),
                      maxLines: 8,
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Theme.of(context).colorScheme.primary,
                          foregroundColor:
                              Theme.of(context).colorScheme.onPrimary,
                        ),
                        onPressed: _saveMission,
                        child: const Text('Create Mission',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                     const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor:
                              Theme.of(context).colorScheme.secondary,
                        ),
                        onPressed: _isSeeding ? null : _seedSampleMissions,
                        icon: _isSeeding
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.auto_awesome),
                        label: Text(
                          _isSeeding
                              ? 'Loading samples...'
                              : 'Load 10 Sample Missions',
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'One-tap seed of the 10 built-in sample missions (Share a '
                      'Bible Story, Help Someone in Need, etc.). Safe to run more '
                      'than once — duplicates are skipped.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
    );
  }

  bool _isSeeding = false;

  Future<void> _seedSampleMissions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Load Sample Missions?'),
        content: const Text(
            'This will create the 10 built-in sample missions (Share a Bible '
            'Story, Help Someone in Need, Memorize the Beatitudes, etc.).\n\n'
            'Duplicates are skipped, so it is safe to run more than once.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Load Samples'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isSeeding = true);
    try {
      final created =
          await KidsContentService.seedSampleKidsMission();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Loaded $created sample mission${created == 1 ? '' : 's'}!'),
          backgroundColor: Theme.of(context).colorScheme.tertiary,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Seed failed: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }
}

enum _Kids
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
