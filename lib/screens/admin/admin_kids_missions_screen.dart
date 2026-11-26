import 'dart:convert';
import '../../utils/error_handler.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../widgets/modern_dropdown.dart';
import '../../services/file_picker_facade.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/kids_content_service.dart';
import '../../models/kids_missions.dart';
import '../../utils/text_formatter.dart';
import '../../widgets/custom_app_bar.dart';

class AdminKidsMissionsScreen extends StatefulWidget {
  const AdminKidsMissionsScreen({super.key});

  @override
  State<AdminKidsMissionsScreen> createState() =>
      _AdminKidsMissionsScreenState();
}

class _AdminKidsMissionsScreenState extends State<AdminKidsMissionsScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _storageService = AppwriteStorageService.instance;
  late final TabController _tabController;

  List<Map<String, dynamic>> _existingMissions = [];
  bool _isLoadingList = true;
  String? _editingMissionId;
  String? _existingMediaUrl;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _locationController =
      TextEditingController(text: 'Home');
  final TextEditingController _durationController =
      TextEditingController(text: '30 minutes');
  final TextEditingController _pointsController =
      TextEditingController(text: '100');
  final TextEditingController _instructionsController = TextEditingController();
  // The passage a child's answer is scored against. Kept separate from
  // `description`, which is the task label shown on screen and is not
  // something the child can say.
  final TextEditingController _expectedResponseController =
      TextEditingController();
  final TextEditingController _expectedResponseModeController =
      TextEditingController(text: 'recite');

  MissionDifficulty _selectedDifficulty = MissionDifficulty.easy;
  MissionCategory _selectedCategory = MissionCategory.learning;
  VerificationMethod _selectedVerification = VerificationMethod.photo;

  Uint8List? _mediaBytes;
  String? _mediaName;

  bool _isExtracting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExistingMissions();
  }

  Future<void> _loadExistingMissions() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await KidsContentService.getKidsMissions(forceRefresh: true);
      if (mounted) {
        setState(() {
          _existingMissions = list;
          _isLoadingList = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void _startEditMission(Map<String, dynamic> mission) {
    setState(() {
      _editingMissionId = mission['id']?.toString();
      _titleController.text = (mission['title'] ?? '').toString();
      _descriptionController.text = (mission['description'] ?? '').toString();
      _locationController.text = (mission['location'] ?? 'Home').toString();
      _durationController.text = (mission['duration'] ?? '30 minutes').toString();
      _pointsController.text = (mission['points'] ?? 100).toString();
      final instr = mission['instructions'];
      if (instr is List) {
        _instructionsController.text = instr.join('\n');
      } else {
        _instructionsController.text = (instr ?? '').toString();
      }
      _expectedResponseController.text = (mission['expected_response'] ?? '').toString();
      _expectedResponseModeController.text = (mission['expected_response_mode'] ?? 'recite').toString();
      _existingMediaUrl = mission['media_url']?.toString();
      _mediaBytes = null;
      _mediaName = null;
    });
    _tabController.animateTo(1);
  }

  void _resetForm() {
    setState(() {
      _editingMissionId = null;
      _existingMediaUrl = null;
      _titleController.clear();
      _descriptionController.clear();
      _locationController.text = 'Home';
      _durationController.text = '30 minutes';
      _pointsController.text = '100';
      _instructionsController.clear();
      _expectedResponseController.clear();
      _expectedResponseModeController.text = 'recite';
      _mediaBytes = null;
      _mediaName = null;
    });
  }

  Future<void> _deleteMission(Map<String, dynamic> mission) async {
    final id = mission['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Kids Mission'),
        content: Text('Delete "${mission['title']}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await KidsContentService.deleteKidsMission(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mission deleted')),
        );
      }
      await _loadExistingMissions();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _durationController.dispose();
    _pointsController.dispose();
    _instructionsController.dispose();
    _expectedResponseController.dispose();
    _expectedResponseModeController.dispose();
    super.dispose();
  }

  Future<void> _extractFromDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'txt'],
        withData: true,
      );

      if (result != null && result.files.single.bytes != null) {
        setState(() => _isExtracting = true);

        final text = await _pdfExtractor.extractTextFromBytes(
          result.files.single.bytes!,
          result.files.single.name,
        );

        if (!mounted) return;
        if (text.trim().isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'No selectable text found in this document. If it is a scanned PDF, please run OCR or enter instructions manually.',
              ),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
          return;
        }

        setState(() {
          _instructionsController.text = text;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Document successfully extracted!'),
              backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to extract: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.media,
      withData: true,
    );
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
      String? uploadedMediaUrl = _existingMediaUrl;

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
        // Only a scored activity has a passage. A photo or witness mission
        // is confirmed by a person, so storing text for it would invite the
        // app to grade the child's own words against something they never
        // said.
        'expected_response': _expectedResponseController.text.trim().isEmpty
            ? null
            : _expectedResponseController.text.trim(),
        'expected_response_mode': _expectedResponseController.text.trim().isEmpty
            ? null
            : _expectedResponseModeController.text.trim(),
        'prerequisite_mission_ids': const <String>[],
        'is_locked': false,
        'media_url': uploadedMediaUrl,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // 3. Save to Appwrite
      if (_editingMissionId != null && _editingMissionId!.isNotEmpty) {
        payload.remove('created_at');
        await KidsContentService.updateKidsMission(_editingMissionId!, payload);
      } else {
        await KidsContentService.createKidsMission(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_editingMissionId != null
                  ? 'Mission updated successfully!'
                  : 'Mission published successfully!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
        _resetForm();
        await _loadExistingMissions();
        _tabController.animateTo(0);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Save failed: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
      appBar: CustomAppBar(
        titleWidget: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.child_care_rounded, size: 22, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              _editingMissionId != null ? 'Edit Kids Mission' : 'Kids Missions',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        showBackButton: true,
        showDonationButton: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Manage Missions'),
            Tab(text: 'Add / Edit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExistingMissionsTab(),
          _isSaving
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
                              'Mission Extractor',
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
                          child: ModernDropdownFormField<MissionCategory>(
                            isExpanded: true,
                            initialValue: _selectedCategory,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder()),
                            items: MissionCategory.values.map((c) {
                              return DropdownMenuItem(
                                  value: c, child: Text(TextFormatter.formatText(c.name)));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ModernDropdownFormField<MissionDifficulty>(
                            isExpanded: true,
                            initialValue: _selectedDifficulty,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            decoration: const InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder()),
                            items: MissionDifficulty.values.map((a) {
                              return DropdownMenuItem(
                                  value: a, child: Text(TextFormatter.formatText(a.name)));
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
                          child: ModernDropdownFormField<VerificationMethod>(
                            isExpanded: true,
                            initialValue: _selectedVerification,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            decoration: const InputDecoration(
                                labelText: 'Verification',
                                border: OutlineInputBorder()),
                            items: VerificationMethod.values.map((v) {
                              return DropdownMenuItem(
                                  value: v, child: Text(TextFormatter.formatText(v.name)));
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _expectedResponseController,
                      decoration: InputDecoration(
                        labelText: 'Expected Response (passage to recite)',
                        alignLabelWithHint: true,
                        border: const OutlineInputBorder(),
                        helperText:
                            'The exact words a child should say, e.g. the '
                            'Beatitudes. Leave empty for photo or witness '
                            'activities, which a person confirms.',
                        helperMaxLines: 3,
                        hintText:
                            'Leave empty unless this activity is scored by '
                            'speech or by a typed answer.',
                      ),
                      maxLines: 6,
                    ),
                    const SizedBox(height: 12),
                    ModernDropdownFormField<String>(
                      initialValue: _expectedResponseModeController.text,
                      decoration: const InputDecoration(
                        labelText: 'Scoring Mode',
                        border: OutlineInputBorder(),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'recite', child: Text('Recite (spoken)')),
                        DropdownMenuItem(value: 'quiz', child: Text('Quiz (typed answer)')),
                      ],
                      onChanged: (v) {
                        if (v != null) _expectedResponseModeController.text = v;
                      },
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
                        child: Text(
                            _editingMissionId != null ? 'Update Mission' : 'Create Mission',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildExistingMissionsTab() {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_existingMissions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No kids missions found yet.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _resetForm();
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Mission'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadExistingMissions,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _existingMissions.length,
        itemBuilder: (ctx, i) {
          final m = _existingMissions[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text((m['title'] ?? 'Untitled').toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${m['category'] ?? ''} • ${m['difficulty'] ?? ''} • ${m['points'] ?? 0} pts',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _startEditMission(m),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _deleteMission(m),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
