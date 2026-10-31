import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../models/tract_models.dart';
import '../../models/podcast_models.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/role_guard.dart';
import '../../services/appwrite_admin_content_service.dart';
import '../../services/appwrite_storage_compat_service.dart';
import '../../services/pdf_extractor_service.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/custom_app_bar.dart';
import 'podcast_episode_form_dialog.dart';

Map<String, dynamic> _podcastPayload(Podcast podcast, {String? category}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    'title': podcast.title,
    'description': podcast.description,
    'category': category ?? podcast.category.displayName,
    'host': podcast.host,
    'episodes': podcast.episodes,
    'rating': podcast.rating,
    'is_subscribed': podcast.isSubscribed,
    'tags': podcast.tags,
    'cover_image': podcast.coverImage,
    'audio_url': podcast.audioUrl,
    'created_at': now,
    'updated_at': now,
  };
}

Map<String, dynamic> _categoryPayload({
  required String name,
  required int order,
  String? imageUrl,
}) {
  return {
    'name': name,
    'description': '',
    'image_url': imageUrl,
    'order': order,
    'is_active': true,
  };
}

bool _activeFlag(Map<String, dynamic> data) =>
    (data['is_active'] as bool?) ?? (data['isActive'] as bool?) ?? true;

class TractPodcastAdminScreen extends StatefulWidget {
  const TractPodcastAdminScreen({super.key});

  @override
  State<TractPodcastAdminScreen> createState() =>
      _TractPodcastAdminScreenState();
}

class _TractPodcastAdminScreenState extends State<TractPodcastAdminScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin', 'content_manager'],
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Tract & Podcast Management',
          showBackButton: true,
          showDonationButton: false,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          bottom: TabBar(
            controller: _tabController,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: const [
              Tab(
                icon: Icon(Icons.article),
                text: 'Tracts',
              ),
              Tab(
                icon: Icon(Icons.mic),
                text: 'Podcasts',
              ),
              Tab(
                icon: Icon(Icons.category),
                text: 'Categories',
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: [
            _TractManagementTab(),
            _PodcastManagementTab(),
            _CategoryManagementTab(),
          ],
        ),
      ),
    );
  }
}

class _TractManagementTab extends StatefulWidget {
  @override
  State<_TractManagementTab> createState() => _TractManagementTabState();
}

class _TractManagementTabState extends State<_TractManagementTab> {
  Future<List<Tract>> _loadTracts() async {
    final docs = await AppwriteAdminContentService.instance.listCollection(
      'tracts',
      orderBy: 'order',
    );
    return docs.map((doc) {
      final id = doc['id'] as String? ?? '';
      return Tract.fromDocument(doc, id);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add new tract button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddTractDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Tract'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),

        // Tracts list
        Expanded(
          child: FutureBuilder<List<Tract>>(
            future: _loadTracts(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return const Center(child: Text('Error loading tracts'));
              }
              final tracts = snapshot.data ?? [];

              if (tracts.isEmpty) {
                return const Center(child: Text('No tracts available.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: tracts.length,
                itemBuilder: (context, index) {
                  final tract = tracts[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.article,
                          color: Colors.orange,
                        ),
                      ),
                      title: Text(
                        tract.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${tract.author} — ${tract.pages} pages'),
                          Text(
                            tract.category.tractDisplayName,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditTractDialog(tract);
                              break;
                            case 'delete':
                              _showDeleteTractDialog(tract);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddTractDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => const _TractFormDialog(),
    ).then((result) {
      if (result is Tract) {
        if (!mounted) return;
        setState(() {});
        messenger.showSnackBar(
          SnackBar(
            content: Text('Tract "${result.title}" added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showEditTractDialog(Tract tract) {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => _TractFormDialog(tract: tract),
    ).then((result) {
      if (result is Tract) {
        if (!mounted) return;
        setState(() {});
        messenger.showSnackBar(
          SnackBar(
            content: Text('Tract "${result.title}" updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    });
  }

  void _showDeleteTractDialog(Tract tract) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Tract'),
        content: Text(
            'Are you sure you want to delete "${tract.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final contentService = AppwriteAdminContentService.instance;
                final storageService = AppwriteStorageCompatService();

                final List<String> filesToDelete = [];

                // Add PDF file if exists
                if (tract.downloadUrl?.isNotEmpty == true) {
                  filesToDelete.add(tract.downloadUrl!);
                }

                // Add cover image if exists
                if (tract.coverImage != null && tract.coverImage!.isNotEmpty) {
                  filesToDelete.add(tract.coverImage!);
                }

                // Add additional cover images if exist
                for (final coverImage in tract.coverImages) {
                  if (coverImage.isNotEmpty) {
                    filesToDelete.add(coverImage);
                  }
                }

                // Delete files from Storage
                for (final fileUrl in filesToDelete) {
                  try {
                    await storageService.deleteFileByUrl(fileUrl);
                  } catch (e) {
                    debugPrint('Warning: Could not delete file $fileUrl: $e');
                    // Continue with other deletions even if one fails
                  }
                }

                await contentService.deleteDocument('tracts', tract.id);

                if (!mounted) return;
                setState(() {});

                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Tract "${tract.title}" and associated files deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting tract: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _TractFormDialog extends StatefulWidget {
  final Tract? tract;

  const _TractFormDialog({this.tract});

  @override
  State<_TractFormDialog> createState() => _TractFormDialogState();
}

class _TractFormDialogState extends State<_TractFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _authorController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pagesController = TextEditingController();
  final _tagsController = TextEditingController();

  // Dynamic tract categories from Appwrite
  List<String> _tractCategories = [];
  String? _selectedCategoryName;
  bool _loadingTractCategories = true;
  String _selectedCategory = 'biblesays'; // fallback for local UI
  bool _isFeatured = false;
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfName;
  Uint8List? _selectedCoverImageBytes;
  String? _selectedCoverImageName;
  // Additional lesson cover images (multiple)
  final List<Uint8List> _selectedCoverImages = [];
  List<String> _selectedCoverNames = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.tract != null) {
      _titleController.text = widget.tract!.title;
      _authorController.text = widget.tract!.author ?? '';
      _descriptionController.text = widget.tract!.description;
      _pagesController.text = widget.tract!.pages.toString();
      _tagsController.text = widget.tract!.tags.join(', ');
      _selectedCategory = widget.tract!.category;
      _selectedCategoryName = widget.tract!.category;
      _isFeatured = widget.tract!.featured;
      // Prefill existing cover image name (display only)
      _selectedCoverImageName = widget.tract!.coverImage;
      // Prefill existing additional cover images list (names only; bytes not available)
      _selectedCoverNames = List<String>.from(widget.tract!.coverImages);
    } else {
      _pagesController.text = '6'; // Default bulletin format
    }

    // Load tract categories from Appwrite
    _loadTractCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _authorController.dispose();
    _descriptionController.dispose();
    _pagesController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _loadTractCategories() async {
    try {
      final docs = await AppwriteAdminContentService.instance
          .listCollection('tract_categories', orderBy: 'order');
      final categoryNames =
          docs.where(_activeFlag).map((d) => d['name'] as String).toList();
      if (!mounted) return;
      setState(() {
        _tractCategories = categoryNames;
        if (_selectedCategoryName == null && categoryNames.isNotEmpty) {
          _selectedCategoryName = categoryNames.first;
        }
        _loadingTractCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tractCategories = [];
        _selectedCategoryName ??= null;
        _loadingTractCategories = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: MediaQuery.of(context).size.width * 0.9,
          tablet: 600,
          desktop: 700,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.tract == null ? Icons.add : Icons.edit,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.tract == null ? 'Add New Tract' : 'Edit Tract',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Tract Title *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Author
                      TextFormField(
                        controller: _authorController,
                        decoration: const InputDecoration(
                          labelText: 'Author *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter an author';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category (dynamic from Appwrite)
                      _loadingTractCategories
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading categories...'),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: _selectedCategoryName,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _tractCategories.map((name) {
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedCategoryName = value;
                                  _selectedCategory = value
                                          ?.toLowerCase()
                                          .replaceAll(' ', '') ??
                                      'biblesays';
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                            ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Pages
                      TextFormField(
                        controller: _pagesController,
                        decoration: const InputDecoration(
                          labelText: 'Number of Pages *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.pages),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter number of pages';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                          helperText: 'e.g., salvation, bible study, faith',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Featured toggle
                      SwitchListTile(
                        title: const Text('Featured Tract'),
                        subtitle: const Text('Show this tract prominently'),
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // PDF Upload
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'PDF File',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedPdfName ?? 'No PDF selected',
                                      style: TextStyle(
                                        color: _selectedPdfName != null
                                            ? Colors.green
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isUploading ? null : _selectPdfFile,
                                    icon: const Icon(Icons.upload_file),
                                    label: const Text('Select PDF'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Cover Image Upload
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Default Cover Image',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCoverImageName ??
                                          'No cover image selected',
                                      style: TextStyle(
                                        color: _selectedCoverImageName != null
                                            ? Colors.green
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isUploading ? null : _selectCoverImage,
                                    icon: const Icon(Icons.image),
                                    label: const Text('Select Image'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Additional Lesson Cover Images (Multiple)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Lesson Cover Images (Multiple)',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCoverNames.isNotEmpty
                                          ? '${_selectedCoverNames.length} image(s) selected'
                                          : 'No lesson images selected',
                                      style: TextStyle(
                                        color: _selectedCoverNames.isNotEmpty
                                            ? Colors.green
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: _isUploading
                                        ? null
                                        : _selectAdditionalCoverImages,
                                    icon: const Icon(Icons.collections),
                                    label: const Text('Add Images'),
                                  ),
                                ],
                              ),
                              if (_selectedCoverNames.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _selectedCoverNames
                                      .map((name) => Chip(label: Text(name)))
                                      .toList(),
                                ),
                              ]
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _saveTract,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Uploading...'),
                            ],
                          )
                        : Text(widget.tract == null
                            ? 'Add Tract'
                            : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPdfFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      int detectedPages = 6;
      try {
        final pdfDoc = PdfDocument(inputBytes: bytes);
        detectedPages = pdfDoc.pages.count;
        pdfDoc.dispose();
      } catch (e) {
        debugPrint('Could not auto-detect PDF page count: $e');
      }

      setState(() {
        _selectedPdfBytes = bytes;
        _selectedPdfName = result.files.single.name;
        _pagesController.text = detectedPages.toString();
      });
    }
  }

  void _selectCoverImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedCoverImageBytes = result.files.single.bytes;
        _selectedCoverImageName = result.files.single.name;
      });
    }
  }

  void _selectAdditionalCoverImages() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: true,
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final names = <String>[];
      final bytesList = <Uint8List>[];
      for (final file in result.files) {
        if (file.bytes != null) {
          names.add(file.name);
          bytesList.add(file.bytes!);
        }
      }
      setState(() {
        _selectedCoverNames.addAll(names);
        _selectedCoverImages.addAll(bytesList);
      });
    }
  }

  void _saveTract() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final contentService = AppwriteAdminContentService.instance;
        final storageService = AppwriteStorageCompatService();

        // For editing: collect old files to delete after successful upload
        final List<String> oldFilesToDelete = [];

        String? pdfUrl;

        // Upload PDF file
        if (_selectedPdfBytes != null && _selectedPdfName != null) {
          // If editing and replacing PDF, mark old one for deletion
          if (widget.tract?.downloadUrl?.isNotEmpty == true) {
            oldFilesToDelete.add(widget.tract!.downloadUrl!);
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_${_selectedPdfName!}';
          pdfUrl = await storageService.uploadFile(
            'pdf-files/$fileName',
            _selectedPdfBytes!,
            contentType: 'application/pdf',
          );
        }

        // Upload cover image
        String? coverImageUrl;
        if (_selectedCoverImageBytes != null &&
            _selectedCoverImageName != null) {
          // If editing and replacing cover image, mark old one for deletion
          if (widget.tract?.coverImage?.isNotEmpty == true) {
            oldFilesToDelete.add(widget.tract!.coverImage!);
          }

          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_${_selectedCoverImageName!}';
          coverImageUrl = await storageService.uploadFile(
            'tract-avatars/$fileName',
            _selectedCoverImageBytes!,
            contentType: 'image/jpeg',
          );
        }

        // Upload additional lesson cover images
        final List<String> additionalCoverUrls = [];
        for (int i = 0;
            i < _selectedCoverImages.length && i < _selectedCoverNames.length;
            i++) {
          final name = _selectedCoverNames[i];
          final bytes = _selectedCoverImages[i];
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_$name';
          final url = await storageService.uploadFile(
            'tract-avatars/$fileName',
            bytes,
            contentType: 'image/jpeg',
          );
          additionalCoverUrls.add(url);
        }

        // Create tract object with uploaded URLs
        final tract = Tract(
          id: widget.tract?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          author: _authorController.text,
          description: _descriptionController.text,
          // Local enum used only for UI visuals; Appwrite payload uses a name string
          category: _selectedCategory,
          pages: int.parse(_pagesController.text),
          tags: _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(),
          pdfUrl: pdfUrl ?? widget.tract?.downloadUrl,
          coverImage: coverImageUrl ?? widget.tract?.coverImage,
          coverImages: _mergeCoverImages(
            existing: widget.tract?.coverImages ?? const [],
            uploaded: additionalCoverUrls,
          ),
          featured: _isFeatured,
        );

        final payload = {
          'title': tract.title,
          'description': tract.description,
          'category': _selectedCategoryName ?? tract.category,
          'pdf_url': tract.downloadUrl,
          'image_url': tract.coverImage,
          'cover_image': tract.coverImage,
          'cover_images': tract.coverImages,
          'author': tract.author,
          'pages': tract.pages,
          'order': widget.tract?.order ?? 0,
          'language': 'en',
          'featured': tract.featured,
          'tags': tract.tags,
          'created_at': widget.tract?.createdAt?.toUtc().toIso8601String() ??
              DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };

        await contentService.upsertDocument(
          'tracts',
          tract.id,
          payload,
        );

        if (_selectedPdfBytes != null && _selectedPdfName != null) {
          try {
            final article = await PdfExtractorService().extractAndFormatArticle(
              _selectedPdfBytes!,
              _selectedPdfName!,
              fallbackTitle: tract.title,
            );
            if (article.fullFormattedBody.trim().isNotEmpty) {
              await contentService.upsertDocument(
                'tract_contents',
                tract.id,
                {
                  'tract_id': tract.id,
                  'content': article.fullFormattedBody.trim(),
                  'questions': jsonEncode(const []),
                  'metadata': jsonEncode({
                    'source_file': _selectedPdfName,
                    'source_pdf_url': tract.downloadUrl,
                    'extracted_at': DateTime.now().toUtc().toIso8601String(),
                    'pages': article.sections,
                    'headings': article.headings,
                    'word_count': article.totalWordCount,
                  }),
                },
              );
            }

            // Auto-register tract in downloadable_materials to enforce donation gate
            try {
              await contentService.upsertDocument(
                'downloadable_materials',
                tract.id,
                {
                  'title': tract.title,
                  'description': tract.description,
                  'category': 'Tracts',
                  'file_type': 'pdf',
                  'file_url': tract.downloadUrl ?? '',
                  'thumbnail_url': tract.coverImage,
                  'requires_donation': true,
                  'minimum_donation': 7500.0,
                  'is_active': true,
                  'created_at': DateTime.now().toUtc().toIso8601String(),
                  'updated_at': DateTime.now().toUtc().toIso8601String(),
                },
              );
            } catch (_) {}
          } catch (e) {
            debugPrint('Warning: Could not extract tract PDF text: $e');
          }
        }

        // Clean up old files after successful save
        for (final fileUrl in oldFilesToDelete) {
          try {
            await storageService.deleteFileByUrl(fileUrl);
          } catch (e) {
            debugPrint('Warning: Could not delete old file $fileUrl: $e');
            // Continue even if cleanup fails - the main operation succeeded
          }
        }

        if (!mounted) return;
        navigator.pop(tract);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.tract == null
                  ? 'Tract added successfully!'
                  : 'Tract updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error uploading tract: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUploading = false;
          });
        }
      }
    }
  }

  List<String> _mergeCoverImages(
      {required List<String> existing, required List<String> uploaded}) {
    final set = <String>{...existing, ...uploaded};
    return set.toList();
  }
}

class _PodcastManagementTab extends StatefulWidget {
  @override
  State<_PodcastManagementTab> createState() => _PodcastManagementTabState();
}

class _PodcastManagementTabState extends State<_PodcastManagementTab> {
  Future<List<Podcast>> _loadPodcasts() async {
    final docs = await AppwriteAdminContentService.instance.listCollection(
      'podcasts',
    );
    final podcasts = docs.map((doc) => Podcast.fromJson(doc)).toList();
    podcasts.sort((a, b) => a.title.compareTo(b.title));
    return podcasts;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add new podcast button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddPodcastDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Podcast'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),

        // Podcasts list
        Expanded(
          child: FutureBuilder<List<Podcast>>(
            future: _loadPodcasts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Unable to load podcasts right now.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final podcasts = snapshot.data ?? [];
              if (podcasts.isEmpty) {
                return const Center(
                    child: Text('No podcasts yet. Tap + to add one.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: podcasts.length,
                itemBuilder: (context, index) {
                  final podcast = podcasts[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: podcast.coverImage != null
                            ? CustomImage(
                                imageUrl: podcast.coverImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(8),
                                placeholder: const Icon(
                                  Icons.mic,
                                  color: Colors.blue,
                                ),
                              )
                            : const Icon(
                                Icons.mic,
                                color: Colors.blue,
                              ),
                      ),
                      title: Text(
                        podcast.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${podcast.host} — ${podcast.episodes} episodes'),
                          Text(
                            podcast.category.displayName,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditPodcastDialog(podcast);
                              break;
                            case 'episodes':
                              _showEpisodesDialog(podcast);
                              break;
                            case 'delete':
                              _showDeletePodcastDialog(podcast);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'episodes',
                            child: Row(
                              children: [
                                Icon(Icons.queue_music),
                                SizedBox(width: 8),
                                Text('Manage Episodes'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete',
                                    style: TextStyle(color: Colors.red)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddPodcastDialog() {
    showDialog(
      context: context,
      builder: (context) => const _PodcastFormDialog(),
    ).then((result) {
      if (result is Podcast && mounted) {
        setState(() {});
      }
    });
  }

  void _showEditPodcastDialog(Podcast podcast) {
    showDialog(
      context: context,
      builder: (context) => _PodcastFormDialog(podcast: podcast),
    ).then((result) {
      if (result is Podcast && mounted) {
        setState(() {});
      }
    });
  }

  void _showEpisodesDialog(Podcast podcast) {
    showDialog(
      context: context,
      builder: (context) => _EpisodeManagementDialog(podcast: podcast),
    );
  }

  void _showDeletePodcastDialog(Podcast podcast) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Podcast'),
        content: Text(
            'Are you sure you want to delete "${podcast.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final contentService = AppwriteAdminContentService.instance;
                final storageService = AppwriteStorageCompatService();

                // Delete associated cover image if present
                if (podcast.coverImage != null &&
                    podcast.coverImage!.isNotEmpty) {
                  try {
                    await storageService.deleteFileByUrl(podcast.coverImage!);
                  } catch (e) {
                    debugPrint(
                        'Warning: Could not delete podcast cover image: $e');
                  }
                }

                // Find and delete all episodes and their audio files
                final episodes = await contentService.listWhere(
                  'podcast_episodes',
                  'podcast_id',
                  podcast.id,
                );

                for (final ep in episodes) {
                  final audioUrl = (ep['audio_url'] as String?) ??
                      (ep['audioUrl'] as String?) ??
                      '';
                  final episodeId = ep['id'] as String?;

                  if (audioUrl.isNotEmpty) {
                    try {
                      await storageService.deleteFileByUrl(audioUrl);
                    } catch (e) {
                      debugPrint(
                          'Warning: Could not delete episode audio $audioUrl: $e');
                    }
                  }

                  if (episodeId != null && episodeId.isNotEmpty) {
                    try {
                      await contentService.deleteDocument(
                          'podcast_episodes', episodeId);
                    } catch (e) {
                      debugPrint(
                          'Warning: Could not delete episode doc $episodeId: $e');
                    }
                  }
                }

                // Delete podcast document
                await contentService.deleteDocument('podcasts', podcast.id);

                if (mounted) {
                  setState(() {});
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Podcast "${podcast.title}" and associated episodes deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting podcast: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _CategoryManagementTab extends StatefulWidget {
  @override
  State<_CategoryManagementTab> createState() => _CategoryManagementTabState();
}

class _CategoryManagementTabState extends State<_CategoryManagementTab> {
  // Appwrite-backed categories
  List<Map<String, dynamic>> _tractCategoryDocs = [];
  List<Map<String, dynamic>> _podcastCategoryDocs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refreshCategories();
  }

  Future<void> _refreshCategories() async {
    setState(() {
      _loading = true;
    });
    try {
      final contentService = AppwriteAdminContentService.instance;
      final tractDocs = await contentService.listCollection('tract_categories',
          orderBy: 'order');
      final podcastDocs = await contentService
          .listCollection('podcast_categories', orderBy: 'order');
      setState(() {
        _tractCategoryDocs = tractDocs
            .map((d) => {
                  'id': d['id'] ?? d['docId'] ?? d['uid'],
                  'name': d['name'],
                  'order': d['order'] ?? 0,
                  'isActive': _activeFlag(d),
                })
            .toList();
        _podcastCategoryDocs = podcastDocs
            .map((d) => {
                  'id': d['id'] ?? d['docId'] ?? d['uid'],
                  'name': d['name'],
                  'order': d['order'] ?? 0,
                  'isActive': _activeFlag(d),
                })
            .toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  SizedBox(width: 8),
                  Text('Loading categories...'),
                ],
              ),
            ),
          // Tract Categories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.article, color: Colors.orange),
                      const SizedBox(width: 8),
                      const Text(
                        'Tract Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showAddCategoryDialog('tract'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._tractCategoryDocs.map((doc) {
                    final name = doc['name'] as String? ?? '';
                    final id = doc['id'] as String?;
                    return ListTile(
                      leading: const Icon(Icons.label, color: Colors.orange),
                      title: Text(name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showEditCategoryDialog('tract', name),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: id == null
                                ? null
                                : () =>
                                    _attemptDeleteCategory('tract', name, id),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Podcast Categories
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.podcasts, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text(
                        'Podcast Categories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: () => _showAddCategoryDialog('podcast'),
                        icon: const Icon(Icons.add),
                        label: const Text('Add Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ..._podcastCategoryDocs.map((doc) {
                    final name = doc['name'] as String? ?? '';
                    final id = doc['id'] as String?;
                    return ListTile(
                      leading: const Icon(Icons.label, color: Colors.blue),
                      title: Text(name),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () =>
                                _showEditCategoryDialog('podcast', name),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: id == null
                                ? null
                                : () =>
                                    _attemptDeleteCategory('podcast', name, id),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddCategoryDialog(String type) {
    final rootCtx = context;
    final controller = TextEditingController();

    showDialog(
      context: rootCtx,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Add ${type.capitalize()} Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                try {
                  final navigator = Navigator.of(rootCtx);
                  final messenger = ScaffoldMessenger.of(rootCtx);
                  final name = controller.text.trim();
                  final contentService = AppwriteAdminContentService.instance;
                  final collection = type == 'tract'
                      ? 'tract_categories'
                      : 'podcast_categories';
                  final order = type == 'tract'
                      ? (_tractCategoryDocs.length + 1)
                      : (_podcastCategoryDocs.length + 1);
                  final id = DateTime.now().millisecondsSinceEpoch.toString();
                  await contentService.upsertDocument(
                    collection,
                    id,
                    _categoryPayload(name: name, order: order),
                  );
                  if (!rootCtx.mounted) return;
                  navigator.pop();
                  await _refreshCategories();
                  if (!rootCtx.mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content:
                          Text('${type.capitalize()} category "$name" added'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!rootCtx.mounted) return;
                  final messenger = ScaffoldMessenger.of(rootCtx);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error adding category: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditCategoryDialog(String type, String currentName) {
    final controller = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${type.capitalize()} Category'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Category Name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final navigator = Navigator.of(context);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  final newName = controller.text.trim();
                  final collection = type == 'tract'
                      ? 'tract_categories'
                      : 'podcast_categories';
                  final docs = type == 'tract'
                      ? _tractCategoryDocs
                      : _podcastCategoryDocs;
                  final doc = docs.firstWhere(
                      (d) => (d['name'] as String?) == currentName,
                      orElse: () => {});
                  final id = doc['id'] as String?;
                  if (id == null) {
                    throw Exception('Category not found');
                  }
                  await AppwriteAdminContentService.instance
                      .updateDocument(collection, id, {
                    'name': newName,
                  });
                  await _refreshCategories();
                  if (!mounted) return;
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('${type.capitalize()} category updated'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error updating category: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _attemptDeleteCategory(
      String type, String name, String id) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final contentService = AppwriteAdminContentService.instance;
      // Check usage in related collections
      int usageCount = 0;
      if (type == 'tract') {
        final tractsUsing =
            await contentService.listWhere('tracts', 'category', name);
        usageCount = tractsUsing.length;
      } else {
        // Podcast category may be stored as enum name or display name
        final byDisplay =
            await contentService.listWhere('podcasts', 'category', name);
        final byEnum = await contentService.listWhere(
            'podcasts', 'category', name.toLowerCase());
        usageCount = byDisplay.length + byEnum.length;
      }

      if (usageCount > 0) {
        // Show usage warning and block deletion
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cannot Delete Category'),
            content: Text(
              'The $type category "$name" is currently used by $usageCount item(s).\n\n'
              'Please reassign or remove those items before deleting this category.',
            ),
            actions: [
              TextButton(
                onPressed: () => navigator.pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      // Confirm deletion
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Category'),
          content: Text(
              'Are you sure you want to delete "$name"? This action cannot be undone.'),
          actions: [
            TextButton(
              onPressed: () => navigator.pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => navigator.pop(true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!mounted) return;

      final collection =
          type == 'tract' ? 'tract_categories' : 'podcast_categories';
      await contentService.deleteDocument(collection, id);
      if (!mounted) return;
      await _refreshCategories();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('${type.capitalize()} category "$name" deleted'),
            backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
            content: Text('Error deleting category: $e'),
            backgroundColor: Colors.red),
      );
    }
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}

class _PodcastFormDialog extends StatefulWidget {
  final Podcast? podcast;

  const _PodcastFormDialog({this.podcast});

  @override
  State<_PodcastFormDialog> createState() => _PodcastFormDialogState();
}

class _PodcastFormDialogState extends State<_PodcastFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hostController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();

  // Dynamic podcast categories from Appwrite
  List<String> _podcastCategories = [];
  String? _selectedPodcastCategoryName;
  bool _loadingPodcastCategories = true;
  PodcastCategory _selectedCategory =
      PodcastCategory.mec; // fallback for local visuals
  bool _isFeatured = false;
  Uint8List? _selectedCoverImageBytes;
  String? _selectedCoverImageName;
  Uint8List? _selectedAudioBytes;
  String? _selectedAudioName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.podcast != null) {
      _titleController.text = widget.podcast!.title;
      _hostController.text = widget.podcast!.host;
      _descriptionController.text = widget.podcast!.description;
      _tagsController.text = widget.podcast!.tags.join(', ');
      _selectedCategory = widget.podcast!.category;
      _selectedPodcastCategoryName = widget.podcast!.category.displayName;
    }
    _loadPodcastCategories();
  }

  Future<void> _loadPodcastCategories() async {
    setState(() {
      _loadingPodcastCategories = true;
    });
    try {
      final docs = await AppwriteAdminContentService.instance
          .listCollection('podcast_categories', orderBy: 'order');
      final names = docs
          .map((d) => (d['name'] as String?) ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      setState(() {
        _podcastCategories = names;
        _selectedPodcastCategoryName ??= names.isNotEmpty ? names.first : null;
        _loadingPodcastCategories = false;
      });
    } catch (e) {
      setState(() {
        _podcastCategories = [];
        _loadingPodcastCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hostController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: MediaQuery.of(context).size.width * 0.9,
          tablet: 600,
          desktop: 700,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.podcast == null ? Icons.add : Icons.edit,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.podcast == null ? 'Add New Podcast' : 'Edit Podcast',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Podcast Title *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Host
                      TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Host *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a host';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category (dynamic from Appwrite)
                      _loadingPodcastCategories
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12.0),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Loading categories...'),
                                ],
                              ),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: _selectedPodcastCategoryName,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _podcastCategories.map((name) {
                                return DropdownMenuItem(
                                  value: name,
                                  child: Text(name),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _selectedPodcastCategoryName = value;
                                  final match =
                                      PodcastCategory.values.firstWhere(
                                    (c) => c.displayName == value,
                                    orElse: () => _selectedCategory,
                                  );
                                  _selectedCategory = match;
                                });
                              },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please select a category';
                                }
                                return null;
                              },
                            ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                          helperText: 'e.g., sermon, teaching, worship',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Featured toggle
                      SwitchListTile(
                        title: const Text('Featured Podcast'),
                        subtitle: const Text('Show this podcast prominently'),
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cover Image Upload
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cover Image',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCoverImageName ??
                                          widget.podcast?.coverImage ??
                                          'No cover image selected',
                                      style: TextStyle(
                                        color: _selectedCoverImageName != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isUploading
                                        ? null
                                        : _selectPodcastCoverImage,
                                    icon: const Icon(Icons.image),
                                    label: const Text('Select Image'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Trailer / intro audio upload (was cover-image only)
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trailer / Intro Audio',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Optional show-level audio. Full episodes live under Manage Episodes.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedAudioName ??
                                          widget.podcast?.audioUrl ??
                                          'No audio selected',
                                      style: TextStyle(
                                        color: _selectedAudioName != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isUploading ? null : _selectAudioFile,
                                    icon: const Icon(Icons.audio_file),
                                    label: const Text('Select Audio'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _savePodcast,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Uploading...'),
                            ],
                          )
                        : Text(widget.podcast == null
                            ? 'Add Podcast'
                            : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPodcastCoverImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedCoverImageBytes = result.files.single.bytes;
        _selectedCoverImageName = result.files.single.name;
      });
    }
  }

  Future<void> _selectAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      if (bytes.lengthInBytes > 200000000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file is too large (max 200 MB).')),
        );
        return;
      }
      setState(() {
        _selectedAudioBytes = bytes;
        _selectedAudioName = result.files.single.name;
      });
    }
  }

  String _audioContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  void _savePodcast() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final contentService = AppwriteAdminContentService.instance;
        final storageService = AppwriteStorageCompatService();

        // Upload cover image
        String? coverImageUrl;
        if (_selectedCoverImageBytes != null &&
            _selectedCoverImageName != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_${_selectedCoverImageName!}';
          coverImageUrl = await storageService.uploadFile(
            'podcast-covers/$fileName',
            _selectedCoverImageBytes!,
            contentType: 'image/jpeg',
          );
        }

        // Upload trailer / intro audio (show-level audio)
        String? audioUrl;
        if (_selectedAudioBytes != null && _selectedAudioName != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_${_selectedAudioName!}';
          audioUrl = await storageService.uploadFile(
            'audio-files/podcasts/$fileName',
            _selectedAudioBytes!,
            contentType: _audioContentType(_selectedAudioName!),
          );
        }

        // Create podcast object with uploaded URL
        final podcast = Podcast(
          id: widget.podcast?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          host: _hostController.text,
          episodes: widget.podcast?.episodes ?? 0,
          rating: widget.podcast?.rating ?? 0.0,
          isSubscribed: widget.podcast?.isSubscribed ?? false,
          tags: _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(),
          coverImage: coverImageUrl ?? widget.podcast?.coverImage,
          audioUrl: audioUrl ?? widget.podcast?.audioUrl,
        );

        final payload = _podcastPayload(
          podcast,
          category:
              _selectedPodcastCategoryName ?? podcast.category.displayName,
        );
        await contentService.upsertDocument(
          'podcasts',
          podcast.id,
          payload,
        );

        try {
          if (_isFeatured) {
            await contentService.upsertDocument(
              'featured_content',
              'podcast_${podcast.id}',
              {
                'title': podcast.title,
                'description': podcast.description,
                'content_id': podcast.id,
                'content_type': 'podcast',
                'priority': 1,
                'is_active': true,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
            );
          } else {
            await contentService.deleteDocument(
              'featured_content',
              'podcast_${podcast.id}',
            );
          }
        } catch (_) {}

        if (!mounted) return;
        navigator.pop(podcast);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.podcast == null
                  ? 'Podcast created successfully!'
                  : 'Podcast updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Second notification removed to avoid duplication
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error uploading podcast: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}

class _EpisodeManagementDialog extends StatefulWidget {
  final Podcast podcast;

  const _EpisodeManagementDialog({required this.podcast});

  @override
  State<_EpisodeManagementDialog> createState() =>
      _EpisodeManagementDialogState();
}

class _EpisodeManagementDialogState extends State<_EpisodeManagementDialog> {
  Future<List<PodcastEpisode>>? _episodesFuture;

  @override
  void initState() {
    super.initState();
    _episodesFuture = _loadEpisodes();
  }

  Future<List<PodcastEpisode>> _loadEpisodes() async {
    final docs = await AppwriteAdminContentService.instance.listWhere(
      'podcast_episodes',
      'podcast_id',
      widget.podcast.id,
    );
    final episodes =
        docs.map((doc) => PodcastEpisode.fromJson(doc)).toList();
    episodes.sort((a, b) => b.publishDate.compareTo(a.publishDate));
    return episodes;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _episodesFuture = _loadEpisodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: MediaQuery.of(context).size.width * 0.95,
          tablet: 800,
          desktop: 900,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue_music, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage Episodes - ${widget.podcast.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Add episode button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddEpisodeDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Episode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            // Episodes list
            Expanded(
              child: FutureBuilder<List<PodcastEpisode>>(
                future: _episodesFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load episodes right now. Pull to retry.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final episodes = snapshot.data ?? const <PodcastEpisode>[];
                  if (episodes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No episodes yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first episode to get started',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.audiotrack,
                                  color: Colors.blue),
                            ),
                            title: Text(
                              episode.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (episode.duration.isNotEmpty)
                                  episode.duration,
                                '${episode.publishDate.day}/${episode.publishDate.month}/${episode.publishDate.year}',
                              ].join(' • '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showEditEpisodeDialog(episode),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _showDeleteEpisodeDialog(episode),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEpisodeDialog() {
    showDialog(
      context: context,
      builder: (context) => PodcastEpisodeFormDialog(
        podcast: widget.podcast,
        onEpisodeSaved: _refresh,
      ),
    );
  }

  void _showEditEpisodeDialog(PodcastEpisode episode) {
    showDialog(
      context: context,
      builder: (context) => PodcastEpisodeFormDialog(
        podcast: widget.podcast,
        episode: episode,
        onEpisodeSaved: _refresh,
      ),
    );
  }

  void _showDeleteEpisodeDialog(PodcastEpisode episode) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Episode'),
        content: Text(
            'Are you sure you want to delete "${episode.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final contentService = AppwriteAdminContentService.instance;
                final storageService = AppwriteStorageCompatService();

                await contentService.deleteDocument(
                    'podcast_episodes', episode.id);

                // Delete audio file from storage if it exists
                if (episode.audioUrl.isNotEmpty) {
                  await storageService.deleteFileByUrl(episode.audioUrl);
                }

                // Update podcast episode count
                final updatedPodcast = widget.podcast.copyWith(
                  episodes: widget.podcast.episodes - 1,
                );

                await contentService.upsertDocument(
                  'podcasts',
                  updatedPodcast.id,
                  _podcastPayload(updatedPodcast),
                );

                if (!mounted) return;
                navigator.pop();
                _refresh();
                messenger.showSnackBar(
                  SnackBar(
                    content:
                        Text('Episode "${episode.title}" deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting episode: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
