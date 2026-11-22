import 'dart:typed_data';
import '../../utils/error_handler.dart';
import 'package:flutter/material.dart';
import '../../widgets/modern_dropdown.dart';
import '../../services/file_picker_facade.dart';
import '../../services/pdf_extractor_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/kids_content_service.dart';
import '../../models/kids_models.dart';
import '../../widgets/custom_app_bar.dart';

class AdminKidsStoriesScreen extends StatefulWidget {
  const AdminKidsStoriesScreen({super.key});

  @override
  State<AdminKidsStoriesScreen> createState() => _AdminKidsStoriesScreenState();
}

class _AdminKidsStoriesScreenState extends State<AdminKidsStoriesScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _pdfExtractor = PdfExtractorService();
  final _storageService = AppwriteStorageService.instance;
  late final TabController _tabController;

  List<Map<String, dynamic>> _existingStories = [];
  bool _isLoadingList = true;
  String? _editingStoryId;
  String? _existingImageUrl;
  String? _existingAudioUrl;

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
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadExistingStories();
  }

  Future<void> _loadExistingStories() async {
    setState(() => _isLoadingList = true);
    try {
      final list = await KidsContentService.getKidsStories();
      if (mounted) {
        setState(() {
          _existingStories = list;
          _isLoadingList = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingList = false);
    }
  }

  void _startEditStory(Map<String, dynamic> story) {
    setState(() {
      _editingStoryId = story['id']?.toString();
      _titleController.text = (story['title'] ?? '').toString();
      _subtitleController.text = (story['subtitle'] ?? '').toString();
      _descriptionController.text = (story['description'] ?? '').toString();
      _contentController.text = (story['content'] ?? '').toString();
      _moralLessonController.text = (story['moral_lesson'] ?? '').toString();
      _bibleReferenceController.text = (story['bible_reference'] ?? '').toString();
      _durationController.text = (story['duration_minutes'] ?? 10).toString();
      _existingImageUrl = story['image_url']?.toString();
      _existingAudioUrl = story['audio_url']?.toString();
      _coverImageBytes = null;
      _coverImageName = null;
      _audioBytes = null;
      _audioName = null;
    });
    _tabController.animateTo(1);
  }

  void _resetForm() {
    setState(() {
      _editingStoryId = null;
      _existingImageUrl = null;
      _existingAudioUrl = null;
      _titleController.clear();
      _subtitleController.clear();
      _descriptionController.clear();
      _contentController.clear();
      _moralLessonController.clear();
      _bibleReferenceController.clear();
      _durationController.text = '10';
      _coverImageBytes = null;
      _coverImageName = null;
      _audioBytes = null;
      _audioName = null;
    });
  }

  Future<void> _deleteStory(Map<String, dynamic> story) async {
    final id = story['id']?.toString() ?? '';
    if (id.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Kids Story'),
        content: Text('Delete "${story['title']}"? This cannot be undone.'),
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
      await KidsContentService.deleteKidsStory(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Story deleted')),
        );
      }
      await _loadExistingStories();
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
        withData: true,
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
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _coverImageBytes = result.files.single.bytes;
        _coverImageName = result.files.single.name;
      });
    }
  }

  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      withData: true,
    );
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
      String? uploadedImageUrl = _existingImageUrl;
      String? uploadedAudioUrl = _existingAudioUrl;

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
      if (_editingStoryId != null && _editingStoryId!.isNotEmpty) {
        payload.remove('created_at');
        await KidsContentService.updateKidsStory(_editingStoryId!, payload);
      } else {
        await KidsContentService.createKidsStory(payload);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(_editingStoryId != null
                  ? 'Story updated successfully!'
                  : 'Story published successfully!'),
              backgroundColor: Theme.of(context).colorScheme.tertiary),
        );
        _resetForm();
        await _loadExistingStories();
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
            Icon(Icons.auto_stories_rounded, size: 22, color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 8),
            Text(
              _editingStoryId != null ? 'Edit Kids Story' : 'Kids Stories',
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
            Tab(text: 'Manage Stories'),
            Tab(text: 'Add / Edit'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildExistingStoriesTab(),
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
                          child: ModernDropdownFormField<StoryCategory>(
                            isExpanded: true,
                            initialValue: _selectedCategory,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
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
                          child: ModernDropdownFormField<AgeGroup>(
                            isExpanded: true,
                            initialValue: _selectedAgeGroup,
                            borderRadius: BorderRadius.circular(12),
                            dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            icon: const Icon(Icons.arrow_drop_down_rounded),
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
                        child: Text(
                            _editingStoryId != null ? 'Update Story' : 'Save Story',
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

  Widget _buildExistingStoriesTab() {
    if (_isLoadingList) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_existingStories.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No kids stories found yet.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                _resetForm();
                _tabController.animateTo(1);
              },
              icon: const Icon(Icons.add),
              label: const Text('Add First Story'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadExistingStories,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _existingStories.length,
        itemBuilder: (ctx, i) {
          final s = _existingStories[i];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              title: Text((s['title'] ?? 'Untitled').toString(),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(
                '${s['age_group'] ?? ''} • ${s['category'] ?? ''} • ${s['bible_reference'] ?? ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _startEditStory(s),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    tooltip: 'Delete',
                    onPressed: () => _deleteStory(s),
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
