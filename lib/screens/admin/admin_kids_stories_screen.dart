import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/kids_content_service.dart';
import '../../models/kids_models.dart';

class AdminKidsStoriesScreen extends StatefulWidget {
  const AdminKidsStoriesScreen({super.key});

  @override
  State<AdminKidsStoriesScreen> createState() => _AdminKidsStoriesScreenState();
}

class _AdminKidsStoriesScreenState extends State<AdminKidsStoriesScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _storageService = AppwriteStorageService.instance;

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _subtitleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _moralLessonController = TextEditingController();
  final TextEditingController _bibleReferenceController =
      TextEditingController();
  final TextEditingController _durationController =
      TextEditingController(text: '10');

  AgeGroup _selectedAgeGroup = AgeGroup.age_3_6;
  StoryCategory _selectedCategory = StoryCategory.oldTestament;

  Uint8List? _coverImageBytes;
  String? _coverImageName;
  Uint8List? _audioBytes;
  String? _audioName;

  bool _isExtracting = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _moralLessonController.dispose();
    _bibleReferenceController.dispose();
    _durationController.dispose();
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
          _contentController.text = text;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: const Text('Document successfully extracted!'),
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

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _audioBytes = result.files.single.bytes;
        _audioName = result.files.single.name;
      });
    }
  }

  Future<void> _saveStory() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? uploadedImageUrl;
      String? uploadedAudioUrl;

      // 1. Upload Media
      if (_coverImageBytes != null && _coverImageName != null) {
        uploadedImageUrl = await _storageService.uploadContentFile(
          bytes: _coverImageBytes!,
          fileName:
              'kids_stories/images/${DateTime.now().millisecondsSinceEpoch}_$_coverImageName',
          contentType: 'image/*',
        );
      }

      if (_audioBytes != null && _audioName != null) {
        uploadedAudioUrl = await _storageService.uploadContentFile(
          bytes: _audioBytes!,
          fileName:
              'kids_stories/audio/${DateTime.now().millisecondsSinceEpoch}_$_audioName',
          contentType: 'audio/*',
        );
      }

      // 2. Build Document Payload
      final durationStr = _durationController.text.trim();
      final durationInt = int.tryParse(durationStr) ?? 10;

      final payload = {
        'title': _titleController.text.trim(),
        'subtitle': _subtitleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'content': _contentController.text.trim(),
        'moral_lesson': _moralLessonController.text.trim(),
        'bible_reference': _bibleReferenceController.text.trim(),
        'duration': durationInt,
        'age_group': _selectedAgeGroup.name.replaceAll('_', '-'),
        'category': _selectedCategory.name.replaceAll('_', '-'),
        'completed': false,
        'favorite': false,
        'tags': [], // Or extract tags from UI
        'image_url': uploadedImageUrl,
        'illustration_url': uploadedImageUrl,
        'audio_url': uploadedAudioUrl,
        'is_active': true,
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      // 3. Save to Appwrite
      await KidsContentService.createKidsStory(payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: const Text('Story published successfully!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
        Navigator.pop(context); // Return to previous screen
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
        title: const Text('Add Kids Story'),
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
                    // Extractor Banner
                    Card(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Document Extractor',
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
                              'Upload a PDF or TXT file of the story. We will extract all text automatically directly on your device without using cloud bandwidth.',
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
                                  : 'Upload & Extract Document'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Media Uploads
                    Text('Media',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickCoverImage,
                            icon: const Icon(Icons.image),
                            label:
                                Text(_coverImageName ?? 'Select Cover Image'),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickAudio,
                            icon: const Icon(Icons.audio_file),
                            label: Text(_audioName ?? 'Select Audio File'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Inputs
                    Text('Story Details',
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
                      controller: _subtitleController,
                      decoration: const InputDecoration(
                          labelText: 'Subtitle', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<StoryCategory>(
                            initialValue: _selectedCategory,
                            decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder()),
                            items: StoryCategory.values.map((c) {
                              return DropdownMenuItem(
                                  value: c, child: Text(c.displayName));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedCategory = v!),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<AgeGroup>(
                            initialValue: _selectedAgeGroup,
                            decoration: const InputDecoration(
                                labelText: 'Age Group',
                                border: OutlineInputBorder()),
                            items: AgeGroup.values.map((a) {
                              return DropdownMenuItem(
                                  value: a, child: Text(a.displayName));
                            }).toList(),
                            onChanged: (v) =>
                                setState(() => _selectedAgeGroup = v!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    TextFormField(
                      controller: _durationController,
                      decoration: const InputDecoration(
                          labelText: 'Duration (Minutes)',
                          border: OutlineInputBorder()),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _bibleReferenceController,
                      decoration: const InputDecoration(
                          labelText: 'Bible Reference',
                          border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _moralLessonController,
                      decoration: const InputDecoration(
                          labelText: 'Moral Lesson',
                          border: OutlineInputBorder()),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                          labelText: 'Short Description',
                          border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),

                    // The extracted content field
                    TextFormField(
                      controller: _contentController,
                      decoration: const InputDecoration(
                        labelText: 'Full Story Content',
                        alignLabelWithHint: true,
                        border: OutlineInputBorder(),
                        hintText:
                            'You can type manually or use the PDF extractor above.',
                      ),
                      maxLines: 15,
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
                        onPressed: _saveStory,
                        child: const Text('Save Story',
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
