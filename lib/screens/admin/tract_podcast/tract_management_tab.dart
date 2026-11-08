import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../../services/file_picker_facade.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../../../models/tract_models.dart';
import '../../../utils/error_handler.dart';
import '../../../utils/responsive_utils.dart';
import '../../../services/appwrite_admin_content_service.dart';
import '../../../services/appwrite_storage_compat_service.dart';
import '../../../services/pdf_extractor_service.dart';
import '../../../services/interactive_lessons_service.dart';
import '../../../widgets/custom_image.dart';
import 'tract_podcast_shared.dart';

class TractManagementTab extends StatefulWidget {
  @override
  State<TractManagementTab> createState() => _TractManagementTabState();
}

class _TractManagementTabState extends State<TractManagementTab> {
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
        // Add new tract and interactive study buttons
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showAddTractDialog(),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('Add Tract (PDF)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _showAddStandaloneLessonDialog(),
                  icon: const Icon(Icons.school),
                  label: const Text('Add Interactive Study'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green, width: 1.5),
                  ),
                ),
              ),
            ],
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

  void _showAddStandaloneLessonDialog() {
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => const _StandaloneLessonFormDialog(),
    ).then((result) {
      if (result == true) {
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Interactive Bible study lesson added successfully!'),
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
                      content: Text('Error deleting tract: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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

  // Dynamic tract categories from Appwrite with robust defaults
  List<String> _tractCategories = List<String>.from(defaultTractCategoryNames);
  String? _selectedCategoryName;
  bool _loadingTractCategories = true;
  String _selectedCategory = 'What the Bible Says'; // fallback for local UI
  bool _isFeatured = false;
  Uint8List? _selectedPdfBytes;
  String? _selectedPdfName;
  Uint8List? _selectedCoverImageBytes;
  String? _selectedCoverImageName;
  // Additional lesson cover images (multiple)
  final List<Uint8List> _selectedCoverImages = [];
  List<String> _selectedCoverNames = [];
  bool _isUploading = false;
  bool _createInteractiveLesson = true;

  @override
  void initState() {
    super.initState();
    if (widget.tract != null) {
      _titleController.text = widget.tract!.title;
      _authorController.text = widget.tract!.author ?? '';
      _descriptionController.text = widget.tract!.description;
      _pagesController.text = widget.tract!.pages?.toString() ?? '6';
      _tagsController.text = widget.tract!.tags.join(', ');
      _selectedCategory = widget.tract!.category;
      _selectedCategoryName = widget.tract!.category.tractDisplayName;
      _isFeatured = widget.tract!.featured;
      // Prefill existing cover image name (display only)
      _selectedCoverImageName = widget.tract!.coverImage;
      // Prefill existing additional cover images list (names only; bytes not available)
      _selectedCoverNames = List<String>.from(widget.tract!.coverImages);
    } else {
      _pagesController.text = '6'; // Default bulletin format
      _selectedCategoryName = defaultTractCategoryNames.first;
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
      final categoryNames = docs
          .where(activeFlag)
          .map((d) => (d['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        final merged = <String>{
          ...defaultTractCategoryNames,
          ...categoryNames,
          if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty)
            _selectedCategoryName!,
        };
        _tractCategories = merged.toList();
        _selectedCategoryName ??= _tractCategories.first;
        _loadingTractCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final merged = <String>{
          ...defaultTractCategoryNames,
          if (_selectedCategoryName != null && _selectedCategoryName!.isNotEmpty)
            _selectedCategoryName!,
        };
        _tractCategories = merged.toList();
        _selectedCategoryName ??= _tractCategories.first;
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
                      DropdownButtonFormField<String>(
                        value: _selectedCategoryName,
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.category),
                          suffixIcon: _loadingTractCategories
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        items: <String>{
                          if (_selectedCategoryName != null &&
                              _selectedCategoryName!.isNotEmpty)
                            _selectedCategoryName!,
                          ..._tractCategories,
                          ...defaultTractCategoryNames,
                        }.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryName = value;
                            _selectedCategory = value ?? 'biblesays';
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
                      const SizedBox(height: 8),

                      // Also create Interactive Bible Study switch
                      SwitchListTile(
                        title: const Text('Also Create Interactive Bible Study Lesson'),
                        subtitle: const Text(
                            'Extracts PDF text into an interactive lesson so users can study interactively'),
                        value: _createInteractiveLesson,
                        activeThumbColor: Colors.green,
                        onChanged: (value) {
                          setState(() {
                            _createInteractiveLesson = value;
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

        String? extractedBody;
        if (_selectedPdfBytes != null && _selectedPdfName != null) {
          try {
            final article = await PdfExtractorService().extractAndFormatArticle(
              _selectedPdfBytes!,
              _selectedPdfName!,
              fallbackTitle: tract.title,
            );
            extractedBody = article.fullFormattedBody.trim();
            if (extractedBody.isNotEmpty) {
              final extractedQuestions = article.interactiveSections
                  .map((s) => {
                        'id': 'q_${s.number}',
                        'question': s.title,
                        'scriptureReferences': s.scriptureReferences,
                        'paletteId': s.paletteId,
                      })
                  .toList();
              await contentService.upsertDocument(
                'tract_contents',
                tract.id,
                {
                  'tract_id': tract.id,
                  'content': extractedBody,
                  'questions': jsonEncode(extractedQuestions),
                  'metadata': jsonEncode({
                    'source_file': _selectedPdfName,
                    'source_pdf_url': tract.downloadUrl,
                    'extracted_at': DateTime.now().toUtc().toIso8601String(),
                    'pages': article.sections,
                    'headings': article.headings,
                    'word_count': article.totalWordCount,
                    'primary_palette_id': article.primaryPaletteId,
                    'interactive_sections': article.interactiveSections
                        .map((s) => s.toJson())
                        .toList(),
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

        // If admin opted to also create/update an interactive lesson
        if (_createInteractiveLesson) {
          try {
            final lessonContent = (extractedBody != null && extractedBody.isNotEmpty)
                ? extractedBody
                : tract.description;

            final interactiveLesson = InteractiveLessonItem(
              id: 'lesson_${tract.id}',
              title: tract.title,
              description: tract.description,
              category: _selectedCategoryName ?? 'What the Bible Says',
              level: 'Beginner',
              duration: '${((tract.pages ?? 6) * 3).clamp(15, 45)} min',
              content: lessonContent,
              tractId: tract.id,
              coverImage: tract.coverImage,
              isActive: true,
            );
            await InteractiveLessonsService.instance.saveLesson(interactiveLesson);
          } catch (e) {
            debugPrint('Warning: Could not save interactive lesson: $e');
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
            content: Text('Error uploading tract: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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

class _StandaloneLessonFormDialog extends StatefulWidget {
  const _StandaloneLessonFormDialog();

  @override
  State<_StandaloneLessonFormDialog> createState() =>
      _StandaloneLessonFormDialogState();
}

class _StandaloneLessonFormDialogState
    extends State<_StandaloneLessonFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contentController = TextEditingController();
  final _durationController = TextEditingController(text: '20 min');

  String _selectedCategory = 'What the Bible Says';
  String _selectedLevel = 'Beginner';
  bool _isSaving = false;

  final List<String> _categories = [
    'What the Bible Says',
    'Bible Study',
    'Prophecy',
    'Doctrine',
    'Christian Living',
    'Health',
    'Youth',
    'Evangelism',
  ];

  final List<String> _levels = [
    'Beginner',
    'Intermediate',
    'Advanced',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _contentController.dispose();
    _durationController.dispose();
    super.dispose();
  }

  Future<void> _saveLesson() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final id =
          'lesson_${DateTime.now().millisecondsSinceEpoch}_${_titleController.text.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';

      final lesson = InteractiveLessonItem(
        id: id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        level: _selectedLevel,
        duration: _durationController.text.trim(),
        content: _contentController.text.trim(),
        isActive: true,
      );

      await InteractiveLessonsService.instance.saveLesson(lesson);

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save interactive lesson: ${ErrorHandler.getUserFriendlyMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
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
          maxHeight: MediaQuery.of(context).size.height * 0.85,
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
                  const Icon(Icons.school, color: Colors.white),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Add Interactive Bible Study',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
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

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Lesson Title *',
                          hintText: 'e.g., Lesson 2: Keys to Answered Prayer',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter a title'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: const InputDecoration(
                                labelText: 'Category *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c, overflow: TextOverflow.ellipsis),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedCategory = val);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedLevel,
                              decoration: const InputDecoration(
                                labelText: 'Level *',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.signal_cellular_alt),
                              ),
                              items: _levels.map((l) {
                                return DropdownMenuItem(value: l, child: Text(l));
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedLevel = val);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Estimated Duration *',
                          hintText: 'e.g. 20 min',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.access_time),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please specify duration'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Description / Summary *',
                          hintText: 'A brief summary of what this study covers...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter a summary'
                                : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _contentController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Study Content / Lesson Body *',
                          hintText:
                              'Paste study content, scripture questions, reflections, or markdown...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Please enter lesson content'
                                : null,
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
                    onPressed: _isSaving ? null : _saveLesson,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    child: _isSaving
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
                              Text('Saving...'),
                            ],
                          )
                        : const Text('Save Study Lesson'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
