import 'package:flutter/material.dart';
import '../../services/appwrite_content_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';

class ContentPageEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? page;

  const ContentPageEditorScreen({
    super.key,
    this.page,
  });

  @override
  State<ContentPageEditorScreen> createState() =>
      _ContentPageEditorScreenState();
}

class _ContentPageEditorScreenState extends State<ContentPageEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final AppwriteContentService _contentService =
      AppwriteContentService.instance;
  final AuthService _authService = AuthService.instance;

  late TextEditingController _titleController;
  late TextEditingController _slugController;
  late TextEditingController _contentController;
  late TextEditingController _metaDescriptionController;
  late TextEditingController _metaKeywordsController;

  bool _isLoading = false;
  bool _isPublished = false;
  DateTime? _publishDate;
  String _pageType = 'article';
  int _sortOrder = 0;

  final List<String> _pageTypes = [
    'article',
    'page',
    'announcement',
    'event',
    'resource',
    'testimony',
    'devotional',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadPageData();
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _slugController = TextEditingController();
    _contentController = TextEditingController();
    _metaDescriptionController = TextEditingController();
    _metaKeywordsController = TextEditingController();

    // Auto-generate slug from title
    _titleController.addListener(_generateSlug);
  }

  void _generateSlug() {
    if (_slugController.text.isEmpty || widget.page == null) {
      final title = _titleController.text.toLowerCase();
      final slug = title
          .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
          .replaceAll(RegExp(r'\s+'), '-')
          .replaceAll(RegExp(r'-+'), '-')
          .trim();
      _slugController.text = slug;
    }
  }

  void _loadPageData() {
    if (widget.page != null) {
      final page = widget.page!;
      _titleController.text = page['title'] ?? '';
      _slugController.text = page['slug'] ?? '';
      _contentController.text = page['content'] ?? '';
      _metaDescriptionController.text = page['meta_description'] ?? '';
      _metaKeywordsController.text = page['meta_keywords'] ?? '';
      _isPublished = page['is_published'] ?? false;
      _pageType = page['page_type'] ?? 'article';
      _sortOrder = page['sort_order'] ?? 0;

      if (page['publish_date'] != null) {
        _publishDate = DateTime.parse(page['publish_date']);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _contentController.dispose();
    _metaDescriptionController.dispose();
    _metaKeywordsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin', 'content_manager'],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.page == null ? 'Create Page' : 'Edit Page'),
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          actions: [
            if (widget.page != null)
              IconButton(
                icon: const Icon(Icons.preview),
                onPressed: _previewPage,
                tooltip: 'Preview',
              ),
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _savePage,
              tooltip: 'Save',
            ),
          ],
        ),
        body: _isLoading
            ? const LoadingWidget()
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Page Status Card
                      Card(
                        color: _isPublished
                            ? Colors.green.shade50
                            : Colors.orange.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                _isPublished ? Icons.public : Icons.drafts,
                                color:
                                    _isPublished ? Colors.green : Colors.orange,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isPublished ? 'Published' : 'Draft',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isPublished
                                            ? Colors.green
                                            : Colors.orange,
                                      ),
                                    ),
                                    if (_publishDate != null)
                                      Text(
                                        'Published on ${_publishDate!.day}/${_publishDate!.month}/${_publishDate!.year}',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isPublished,
                                onChanged: (value) {
                                  setState(() {
                                    _isPublished = value;
                                    if (value && _publishDate == null) {
                                      _publishDate = DateTime.now();
                                    }
                                  });
                                },
                                activeThumbColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Basic Information
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Page Title *',
                          hintText: 'Enter a descriptive title',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _slugController,
                        decoration: const InputDecoration(
                          labelText: 'URL Slug *',
                          hintText: 'url-friendly-slug',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                          helperText: 'This will be used in the page URL',
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'URL slug is required';
                          }
                          if (!RegExp(r'^[a-z0-9-]+$').hasMatch(value)) {
                            return 'Slug can only contain lowercase letters, numbers, and hyphens';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _pageType,
                              decoration: const InputDecoration(
                                labelText: 'Page Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _pageTypes.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(TextFormatter.formatCategory(type)
                                      .toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _pageType = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              initialValue: _sortOrder.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Sort Order',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.sort),
                                helperText: 'Lower numbers appear first',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) {
                                _sortOrder = int.tryParse(value) ?? 0;
                              },
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),

                      // Content Section
                      const Text(
                        'Content',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _contentController,
                        decoration: const InputDecoration(
                          labelText: 'Page Content *',
                          hintText: 'Write your content here...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 15,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Content is required';
                          }
                          return null;
                        },
                      ),

                      const SizedBox(height: 24),

                      // SEO Section
                      const Text(
                        'SEO & Metadata',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _metaDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Meta Description',
                          hintText: 'Brief description for search engines',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                          helperText: 'Recommended: 150-160 characters',
                        ),
                        maxLines: 3,
                        maxLength: 160,
                      ),

                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _metaKeywordsController,
                        decoration: const InputDecoration(
                          labelText: 'Meta Keywords',
                          hintText: 'keyword1, keyword2, keyword3',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                          helperText: 'Separate keywords with commas',
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _savePage,
                              icon: const Icon(Icons.save),
                              label: Text(widget.page == null
                                  ? 'Create Page'
                                  : 'Update Page'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _savePage() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final pageData = {
        'title': _titleController.text.trim(),
        'slug': _slugController.text.trim(),
        'content': _contentController.text.trim(),
        'page_type': _pageType,
        'is_published': _isPublished,
        'publish_date': _isPublished && _publishDate != null
            ? _publishDate!.toIso8601String()
            : null,
        'meta_description': _metaDescriptionController.text.trim(),
        'meta_keywords': _metaKeywordsController.text.trim(),
        'sort_order': _sortOrder,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.page == null) {
        // Create new page
        pageData['created_at'] = DateTime.now().toIso8601String();
        pageData['author_id'] = _authService.currentUser?.uid;

        await _contentService.createContentPage(pageData);

        ToastUtils.showSuccess('Page created successfully');
      } else {
        // Update existing page
        await _contentService.updateContentPage(widget.page!['id'], pageData);

        ToastUtils.showSuccess('Page updated successfully');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ToastUtils.showError('Error saving page: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _previewPage() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(_titleController.text.isNotEmpty
            ? _titleController.text
            : 'Page Preview'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_slugController.text.isNotEmpty) ...[
                Text(
                  'URL: /${_slugController.text}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _contentController.text.isNotEmpty
                      ? _contentController.text
                      : 'No content yet...',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
