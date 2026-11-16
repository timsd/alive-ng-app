import 'dart:typed_data';
import '../../utils/error_handler.dart';
import 'package:flutter/material.dart';
import '../../widgets/modern_dropdown.dart';
import '../../services/file_picker_facade.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/appwrite_study_service.dart';
import '../../models/app_models.dart';
import '../../models/study_guide_models.dart';
import '../../utils/text_formatter.dart';
import '../../widgets/custom_app_bar.dart';

class AdminStudyGuidesScreen extends StatefulWidget {
  const AdminStudyGuidesScreen({super.key});

  @override
  State<AdminStudyGuidesScreen> createState() => _AdminStudyGuidesScreenState();
}

class _AdminStudyGuidesScreenState extends State<AdminStudyGuidesScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _storageService = AppwriteStorageService.instance;
  final _studyService = AppwriteStudyService.instance;
  late final TabController _tabController;

  List<StudyProgram> _existingGuides = [];
  bool _isLoadingList = true;
  String? _editingGuideId;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _durationController =
      TextEditingController(text: '45');
  final TextEditingController _objectivesController = TextEditingController();
  final TextEditingController _lessonContentController =
      TextEditingController();
  final TextEditingController _keyVersesController = TextEditingController();

  StudyGuideType _selectedType = StudyGuideType.discipleship;
  StudyDifficulty _selectedDifficulty = StudyDifficulty.beginner;

  Uint8List? _coverImageBytes;
  String? _coverImageName;

  bool _isExtracting = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExistingGuides();
  }

  Future<void> _loadExistingGuides() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await _studyService.getStudyPrograms();
      if (mounted) {
        setState(() {
          _existingGuides = list;
          _isLoadingList = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void _startEditGuide(StudyProgram guide) {
    setState(() {
      _editingGuideId = guide.id;
      _titleController.text = guide.title;
      _descriptionController.text = guide.description;
      _durationController.text = guide.duration.toString();
    });
    _tabController.animateTo(1);
  }

  void _resetForm() {
    setState(() {
      _editingGuideId = null;
      _titleController.clear();
      _descriptionController.clear();
      _durationController.text = '45';
      _objectivesController.clear();
      _lessonContentController.clear();
      _keyVersesController.clear();
      _coverImageBytes = null;
      _coverImageName = null;
    });
  }

  Future<void> _deleteGuide(StudyProgram guide) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Study Guide'),
        content: Text('Delete "${guide.title}"? This cannot be undone.'),
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
      await _studyService.deleteStudyGuide(guide.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Study guide deleted')),
        );
      }
      await _loadExistingGuides();
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
    _durationController.dispose();
    _objectivesController.dispose();
    _lessonContentController.dispose();
    _keyVersesController.dispose();
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
          _lessonContentController.text = text;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: const Text('Curriculum successfully extracted!'),
                backgroundColor: Theme.of(context).colorScheme.tertiary),
          );
        }
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

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _coverImageBytes = result.files.single.bytes;
        _coverImageName = result.files.single.name;
      });
    }
  }

  Future<void> _saveStudyGuide() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? uploadedImageUrl;

      // 1. Upload Cover Image
      if (_coverImageBytes != null && _coverImageName != null) {
        uploadedImageUrl = await _storageService.uploadContentFile(
          bytes: _coverImageBytes!,
          fileName:
              'study_guides/covers/${DateTime.now().millisecondsSinceEpoch}_$_coverImageName',
          contentType: 'image/*',
        );
      }

      // 2. Build Study Guide Payload
      final durationInt = int.tryParse(_durationController.text.trim()) ?? 45;
      final rawObjectives = _objectivesController.text.trim();
      final objectivesList = rawObjectives.isNotEmpty
          ? rawObjectives.split('\n').where((s) => s.trim().isNotEmpty).toList()
          : <String>[];

      final guideId = DateTime.now().millisecondsSinceEpoch.toString();

      final guide = StudyGuide(
        id: guideId,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        difficulty: _selectedDifficulty,
        estimatedDurationMinutes: durationInt,
        objectives: objectivesList,
        imageUrl: uploadedImageUrl,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (_editingGuideId != null) {
        final updateData = guide.toJson()
          ..remove('id')
          ..remove('created_at')
          ..remove('createdAt');
        if (uploadedImageUrl != null) {
          updateData['cover_image_url'] = uploadedImageUrl;
        }
        updateData['updated_at'] = DateTime.now().toIso8601String();
        await _studyService.updateStudyGuide(_editingGuideId!, updateData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: const Text('Study Guide updated successfully!'),
                backgroundColor: Theme.of(context).colorScheme.tertiary),
          );
          _resetForm();
          await _loadExistingGuides();
          _tabController.animateTo(0);
        }
        return;
      }

      // Save new Guide
      await _studyService.createStudyGuide({
        ...guide.toJson(),
        'cover_image_url': uploadedImageUrl,
        'is_published': true,
        'lesson_count': _lessonContentController.text.isNotEmpty ? 1 : 0,
      });

      // 3. Build & Save Initial Lesson from Extracted Content (snake_case schema)
      final rawVerses = _keyVersesController.text.trim();
      final versesList = rawVerses.isNotEmpty
          ? rawVerses
              .split(',')
              .map((e) => e.trim())
              .where((s) => s.isNotEmpty)
              .toList()
          : <String>[];

      if (_lessonContentController.text.isNotEmpty) {
        final lessonId = '${guideId}_lesson_1';
        final nowIso = DateTime.now().toIso8601String();
        await _studyService.createStudyLesson({
          'id': lessonId,
          'study_guide_id': guideId,
          'title': 'Lesson 1: Introduction',
          'content': _lessonContentController.text.trim(),
          'key_verses': versesList,
          'lesson_number': 1,
          'estimated_duration_minutes': durationInt,
          'created_at': nowIso,
          'updated_at': nowIso,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Study Guide published successfully!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
        _resetForm();
        await _loadExistingGuides();
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
        title: _editingGuideId != null ? 'Edit Study Guide' : 'Study Guides',
        showBackButton: true,
        showDonationButton: false,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Manage Guides'),
            Tab(text: 'Create / Edit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExistingGuidesTab(),
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
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Lesson Extractor',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onTertiaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Upload a curriculum PDF to instantiate the main Study Guide and convert the document into an interactive lesson block automatically.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onTertiaryContainer
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
                                  ? 'Parsing...'
                                  : 'Upload Curriculum PDF'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Course Imagery',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _pickCoverImage,
                        icon: const Icon(Icons.image),
                        label:
                            Text(_coverImageName ?? 'Select Course Cover Art'),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Meta Information',
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
                          child: ModernDropdownFormField<StudyGuideType>(
                            initialValue: _selectedType,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder()),
                            items: StudyGuideType.values.map((c) {
                              return DropdownMenuItem(
                                  value: c, child: Text(TextFormatter.formatText(c.name)));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedType = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ModernDropdownFormField<StudyDifficulty>(
                            initialValue: _selectedDifficulty,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
                            decoration: const InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder()),
                            items: StudyDifficulty.values.map((a) {
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
                    TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                          labelText: 'Estimated Duration (Minutes)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _objectivesController,
                      decoration: const InputDecoration(
                        labelText: 'Learning Objectives (One per line)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _keyVersesController,
                      decoration: const InputDecoration(
                          labelText: 'Key Verses (Comma separated)',
                          border: OutlineInputBorder(),
                          hintText: 'e.g. John 3:16, Romans 8:28'),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _lessonContentController,
                      decoration: const InputDecoration(
                        labelText: 'Extracted Lesson Content',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText:
                            'Content extracted from PDF will appear here for editing.',
                      ),
                      maxLines: 12,
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
                        onPressed: _saveStudyGuide,
                        child: Text(
                            _editingGuideId != null
                                ? 'Update Study Guide'
                                : 'Save Study Guide Curriculum',
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

  Widget _buildExistingGuidesTab() {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_existingGuides.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No study guides found in Appwrite yet.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _resetForm();
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.add),
              label: const Text('Create First Study Guide'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadExistingGuides,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _existingGuides.length,
        itemBuilder: (ctx, i) {
          final g = _existingGuides[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text(g.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                g.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _startEditGuide(g),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _deleteGuide(g),
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
