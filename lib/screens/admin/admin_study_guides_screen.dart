import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/firebase_database_service.dart';
import '../../models/study_guide_models.dart';

class AdminStudyGuidesScreen extends StatefulWidget {
  const AdminStudyGuidesScreen({super.key});

  @override
  State<AdminStudyGuidesScreen> createState() => _AdminStudyGuidesScreenState();
}

class _AdminStudyGuidesScreenState extends State<AdminStudyGuidesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _dbService = FirebaseDatabaseService.instance;

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
  void dispose() {
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
                content: Text('Curriculum successfully extracted!'),
                backgroundColor: Theme.of(context).colorScheme.tertiary),
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
        final path =
            'study_guides/covers/${DateTime.now().millisecondsSinceEpoch}_$_coverImageName';
        uploadedImageUrl = await _dbService.uploadFile(path, _coverImageBytes!);
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

      // Save Guide
      await _dbService.firestore
          .collection('study_guides')
          .doc(guideId)
          .set(guide.toJson());

      // 3. Build & Save Initial Lesson from Extracted Content
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
        final lesson = StudyLesson(
          id: lessonId,
          studyGuideId: guideId,
          title: 'Lesson 1: Introduction', // Default first lesson generated
          content: _lessonContentController.text.trim(),
          keyVerses: versesList,
          lessonNumber: 1,
          estimatedDurationMinutes: durationInt,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _dbService.firestore
            .collection('study_guides')
            .doc(guideId)
            .collection('lessons')
            .doc(lessonId)
            .set(lesson.toJson());
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Study Guide published successfully!'),
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
        title: const Text('Study Guide Builder'),
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
                      color: Theme.of(context).colorScheme.tertiaryContainer,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Zero-Code Lesson Extractor',
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
                          child: DropdownButtonFormField<StudyGuideType>(
                            initialValue: _selectedType,
                            decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder()),
                            items: StudyGuideType.values.map((c) {
                              return DropdownMenuItem(
                                  value: c, child: Text(c.name.toUpperCase()));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedType = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<StudyDifficulty>(
                            initialValue: _selectedDifficulty,
                            decoration: const InputDecoration(
                                labelText: 'Difficulty',
                                border: OutlineInputBorder()),
                            items: StudyDifficulty.values.map((a) {
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
                        child: const Text('Save Study Guide Curriculum',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
    );
  }
}
