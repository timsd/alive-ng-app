import 'package:flutter/material.dart';
import '../../services/appwrite_facade.dart';
import 'package:intl/intl.dart';
import '../../config/appwrite_backend_config.dart';
import '../../main.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';
import '../../utils/layout_fix_utils.dart';
import 'tract_podcast_admin_screen.dart';

class ContentManagementScreen extends StatefulWidget {
  final String? contentType;

  const ContentManagementScreen({
    super.key,
    this.contentType,
  });

  @override
  State<ContentManagementScreen> createState() =>
      _ContentManagementScreenState();
}

class _ContentManagementScreenState extends State<ContentManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TablesDB _tables = TablesDB(appwriteClient);

  bool _isLoading = false;
  List<Map<String, dynamic>> _contentPages = [];
  List<Map<String, dynamic>> _featuredContent = [];
  List<Map<String, dynamic>> _projects = [];

  Widget _buildSectionHeader(
      BuildContext context, String title, Widget action) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          LayoutFixUtils.safeText(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
          ),
          action,
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllContent();

    // Set initial tab based on content type
    if (widget.contentType != null) {
      switch (widget.contentType) {
        case 'featured':
          _tabController.index = 1;
          break;
        case 'projects':
          _tabController.index = 2;
          break;
        default:
          _tabController.index = 0;
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllContent() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadContentPages(),
        _loadFeaturedContent(),
        _loadProjects(),
      ]);
    } catch (e) {
      ToastUtils.showError('Error loading content: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadContentPages() async {
    try {
      setState(() {
        _contentPages = [];
      });
      final pages = await _listAdminDocuments(
        AppwriteBackendConfig.contentPagesCollectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(100)],
      );
      if (!mounted) return;
      setState(() => _contentPages = pages);
    } catch (e) {
      debugPrint('Error loading content pages: $e');
    }
  }

  Future<void> _loadFeaturedContent() async {
    try {
      final featured = await _listAdminDocuments(
        AppwriteBackendConfig.featuredContentCollectionId,
        queries: [Query.orderDesc('created_at'), Query.limit(100)],
      );
      if (!mounted) return;
      setState(() => _featuredContent = featured);
    } catch (e) {
      debugPrint('Error loading featured content: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _listAdminDocuments(
        AppwriteBackendConfig.projectsCollectionId,
        queries: [Query.orderAsc('priority'), Query.limit(100)],
      );
      if (projects.isEmpty) {
        // Automatically seed sample data if the collection is empty
        await _seedSampleProjects(showDialog: false);
        return;
      }
      setState(() {
        _projects = projects;
      });
    } catch (e) {
      debugPrint('Error loading projects: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _listAdminDocuments(
    String collectionId, {
    List<String> queries = const [],
  }) async {
    final response = await _tables.listRows(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      queries: queries,
    );
    return response.rows
        .map((row) => {...Map<String, dynamic>.from(row.data), 'id': row.$id})
        .toList();
  }

  Future<void> _createAdminDocument(
    String collectionId,
    Map<String, dynamic> data, {
    String? documentId,
  }) async {
    await _tables.createRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: documentId ?? ID.unique(),
      data: data,
    );
  }

  Future<void> _upsertAdminDocument(
    String collectionId,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _tables.updateRow(
        databaseId: AppwriteBackendConfig.databaseId,
        tableId: collectionId,
        rowId: documentId,
        data: data,
      );
    } on AppwriteException catch (e) {
      if (e.code != 404) rethrow;
      await _createAdminDocument(collectionId, data, documentId: documentId);
    }
  }

  Future<void> _updateAdminDocument(
    String collectionId,
    String documentId,
    Map<String, dynamic> data,
  ) async {
    await _tables.updateRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: documentId,
      data: data,
    );
  }

  Future<void> _deleteAdminDocument(
    String collectionId,
    String documentId,
  ) async {
    await _tables.deleteRow(
      databaseId: AppwriteBackendConfig.databaseId,
      tableId: collectionId,
      rowId: documentId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const [
        'admin',
        'super_admin',
        'content_manager',
        'director',
        'president',
      ],
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Content Management',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
          elevation: 0,
          shadowColor: Theme.of(context).colorScheme.shadow,
          centerTitle: true,
          bottom: TabBar(
            controller: _tabController,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
            indicatorColor: Theme.of(context).colorScheme.onPrimary,
            labelColor: Theme.of(context).colorScheme.onPrimary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.76),
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            tabs: const [
              Tab(text: 'Pages', icon: Icon(Icons.article_outlined, size: 20)),
              Tab(text: 'Featured', icon: Icon(Icons.star_outline, size: 20)),
              Tab(
                  text: 'Projects',
                  icon: Icon(Icons.account_tree_outlined, size: 20)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingWidget()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildContentPagesTab(),
                  _buildFeaturedContentTab(),
                  _buildProjectsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildContentPagesTab() {
    return LayoutFixUtils.safeColumn(
      children: [
        _buildSectionHeader(
          context,
          'Content Pages (${_contentPages.length})',
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _showContentPageDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Page'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _editOnboardingPage,
                icon: const Icon(Icons.flag),
                label: const Text('Edit Onboarding'),
              ),
            ],
          ),
        ),
        Expanded(
          child: _contentPages.isEmpty
              ? const Center(
                  child: Text(
                    'No content pages found.\nCreate your first page!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _contentPages.length,
                  itemBuilder: (context, index) {
                    final page = _contentPages[index];
                    return _buildContentPageCard(page);
                  },
                ),
        ),
      ],
    );
  }

  void _editOnboardingPage() {
    try {
      final page = _contentPages.firstWhere(
        (p) => (p['slug'] as String?) == 'onboarding',
        orElse: () => {},
      );
      if (page.isNotEmpty) {
        _showContentPageDialog(page: page);
      } else {
        _showContentPageDialog();
      }
    } catch (_) {
      _showContentPageDialog();
    }
  }

  Widget _buildContentPageCard(Map<String, dynamic> page) {
    final isPublished = page['is_published'] ?? false;
    final publishDate = page['publish_date'] != null
        ? DateTime.parse(page['publish_date'])
        : null;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isPublished
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.secondary,
          child: Icon(
            isPublished ? Icons.public : Icons.drafts,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
        title: Text(
          page['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: LayoutFixUtils.safeColumn(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutFixUtils.safeText(page['slug'] ?? ''),
            const SizedBox(height: 4),
            LayoutFixUtils.safeText(
              isPublished
                  ? 'Published${publishDate != null ? ' on ${publishDate.day}/${publishDate.month}/${publishDate.year}' : ''}'
                  : 'Draft',
              style: TextStyle(
                color: isPublished
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.secondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isPublished ? 'unpublish' : 'publish',
              child: ListTile(
                leading:
                    Icon(isPublished ? Icons.visibility_off : Icons.visibility),
                title: Text(isPublished ? 'Unpublish' : 'Publish'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('Delete',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onError)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleContentPageAction(value, page),
        ),
      ),
    );
  }

  Widget _buildFeaturedContentTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Featured Content (${_featuredContent.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showFeaturedContentDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Featured'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _featuredContent.isEmpty
              ? const Center(
                  child: Text(
                    'No featured content found.\nCreate your first featured item!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _featuredContent.length,
                  itemBuilder: (context, index) {
                    final content = _featuredContent[index];
                    return _buildFeaturedContentCard(content);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFeaturedContentCard(Map<String, dynamic> content) {
    final isActive = content['is_active'] ?? false;
    final contentType = content['content_type'] ?? 'general';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isActive ? Colors.green : Colors.grey,
          child: const Icon(
            Icons.star,
            color: Colors.white,
          ),
        ),
        title: Text(
          content['title'] ?? 'Untitled',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content['description'] ?? ''),
            const SizedBox(height: 4),
            Text(
              'Type: ${TextFormatter.formatCategory(contentType).toUpperCase()}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isActive ? 'deactivate' : 'activate',
              child: ListTile(
                leading: Icon(isActive ? Icons.pause : Icons.play_arrow),
                title: Text(isActive ? 'Deactivate' : 'Activate'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text('Delete',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onError)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleFeaturedContentAction(value, content),
        ),
      ),
    );
  }

  // Action handlers
  void _handleContentPageAction(String action, Map<String, dynamic> page) {
    switch (action) {
      case 'edit':
        _showContentPageDialog(page: page);
        break;
      case 'publish':
        _toggleContentPagePublish(page, true);
        break;
      case 'unpublish':
        _toggleContentPagePublish(page, false);
        break;
      case 'delete':
        _deleteContentPage(page);
        break;
    }
  }



  void _handleFeaturedContentAction(
      String action, Map<String, dynamic> content) {
    switch (action) {
      case 'edit':
        _showFeaturedContentDialog(content: content);
        break;
      case 'activate':
        _toggleFeaturedContentActive(content, true);
        break;
      case 'deactivate':
        _toggleFeaturedContentActive(content, false);
        break;
      case 'delete':
        _deleteFeaturedContent(content);
        break;
    }
  }

  // Dialog methods (placeholder implementations)
  void _showContentPageDialog({Map<String, dynamic>? page}) {
    final isEditing = page != null && page.isNotEmpty;
    final titleController =
        TextEditingController(text: page?['title'] ?? 'Onboarding');
    final slugController =
        TextEditingController(text: page?['slug'] ?? 'onboarding');
    final contentController =
        TextEditingController(text: page?['content'] ?? '');
    String selectedLanguage =
        (page?['language'] ?? page?['language_code'] ?? 'en').toString();
    if (!['en', 'yo', 'ha', 'ig'].contains(selectedLanguage)) {
      selectedLanguage = 'en';
    }
    bool isPublished = page?['is_published'] ?? false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: Text(
                isEditing ? 'Edit Content Page' : 'Create Content Page',
              ),
              content: SizedBox(
                width: 480,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: titleController,
                        onChanged: (val) {
                          if (!isEditing) {
                            slugController.text = val
                                .toLowerCase()
                                .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
                                .replaceAll(RegExp(r'\s+'), '-')
                                .replaceAll(RegExp(r'-+'), '-')
                                .trim();
                          }
                        },
                        decoration: const InputDecoration(
                          labelText: 'Title',
                          prefixIcon: Icon(Icons.title),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: slugController,
                        decoration: const InputDecoration(
                          labelText: 'Slug',
                          hintText: 'onboarding',
                          prefixIcon: Icon(Icons.link),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedLanguage,
                        decoration: const InputDecoration(
                          labelText: 'Language',
                          prefixIcon: Icon(Icons.language),
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'en', child: Text('English (en)')),
                          DropdownMenuItem(value: 'yo', child: Text('Yorùbá (yo)')),
                          DropdownMenuItem(value: 'ha', child: Text('Hausa (ha)')),
                          DropdownMenuItem(value: 'ig', child: Text('Igbo (ig)')),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedLanguage = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: contentController,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'Content',
                          alignLabelWithHint: true,
                          prefixIcon: Icon(Icons.description),
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile(
                        value: isPublished,
                        onChanged: (v) => setDialogState(() => isPublished = v),
                        title: const Text('Published'),
                        subtitle: Text(
                          isPublished
                              ? 'Visible to app users'
                              : 'Saved as draft (hidden)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text('Save'),
                  onPressed: () async {
                    final payload = {
                      'title': titleController.text.trim(),
                      'slug': slugController.text.trim(),
                      'language': selectedLanguage,
                      'language_code': selectedLanguage,
                      'content': contentController.text.trim(),
                      'is_published': isPublished,
                      'updated_at': DateTime.now().toIso8601String(),
                    };

                    try {
                      if (isEditing) {
                        await _updateAdminDocument(
                          AppwriteBackendConfig.contentPagesCollectionId,
                          page['id'],
                          payload,
                        );
                        ToastUtils.showSuccess('Content page updated');
                      } else {
                        await _createAdminDocument(
                          AppwriteBackendConfig.contentPagesCollectionId,
                          {
                            ...payload,
                            'created_at': DateTime.now().toIso8601String(),
                          },
                        );
                        ToastUtils.showSuccess('Content page created');
                      }
                      if (!mounted) return;
                      Navigator.of(this.context).pop();
                      _loadContentPages();
                    } catch (e) {
                      ToastUtils.showError('Error saving content: $e');
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showFeaturedContentDialog({Map<String, dynamic>? content}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const TractPodcastAdminScreen(),
      ),
    ).then((_) => _loadFeaturedContent());
  }

  // Database operations
  Future<void> _toggleContentPagePublish(
      Map<String, dynamic> page, bool publish) async {
    try {
      await _updateAdminDocument(
        AppwriteBackendConfig.contentPagesCollectionId,
        page['id'],
        {
          'is_published': publish,
          'publish_date': publish ? DateTime.now().toIso8601String() : null,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      ToastUtils.showSuccess(
          'Page ${publish ? 'published' : 'unpublished'} successfully');
      _loadContentPages();
    } catch (e) {
      ToastUtils.showError('Error updating page: $e');
    }
  }

  Future<void> _toggleFeaturedContentActive(
      Map<String, dynamic> content, bool active) async {
    try {
      await _updateAdminDocument(
        AppwriteBackendConfig.featuredContentCollectionId,
        content['id'],
        {
          'is_active': active,
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      ToastUtils.showSuccess(
          'Featured content ${active ? 'activated' : 'deactivated'} successfully');
      _loadFeaturedContent();
    } catch (e) {
      ToastUtils.showError('Error updating featured content: $e');
    }
  }

  Future<void> _deleteContentPage(Map<String, dynamic> page) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Content Page'),
        content: Text('Are you sure you want to delete "${page['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.contentPagesCollectionId,
          page['id'],
        );

        ToastUtils.showSuccess('Content page deleted successfully');
        _loadContentPages();
      } catch (e) {
        ToastUtils.showError('Error deleting page: $e');
      }
    }
  }

  Future<void> _deleteFeaturedContent(Map<String, dynamic> content) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Featured Content'),
        content: Text('Are you sure you want to delete "${content['title']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.featuredContentCollectionId,
          content['id'],
        );

        ToastUtils.showSuccess('Featured content deleted successfully');
        _loadFeaturedContent();
      } catch (e) {
        ToastUtils.showError('Error deleting featured content: $e');
      }
    }
  }

  Widget _buildProjectsTab() {
    return LayoutFixUtils.safeColumn(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              LayoutFixUtils.safeText(
                'Projects (${_projects.length})',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showProjectDialog(),
                icon: const Icon(Icons.add),
                label: const Text('New Project'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _projects.isEmpty
              ? const Center(
                  child: Text(
                    'No projects found.\nCreate your first project!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: _projects.length,
                  itemBuilder: (context, index) {
                    final project = _projects[index];
                    return _buildProjectCard(project);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final goal = (project['goal'] ?? 0).toDouble();
    final raised = (project['raised'] ?? 0).toDouble();
    final percent = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    final status = project['status'] ?? 'active';

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: status == 'active' ? Colors.green : Colors.orange,
          child: const Icon(Icons.account_tree, color: Colors.white),
        ),
        title: Text(
          project['title'] ?? 'Untitled Project',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(project['summary'] ?? '',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: percent,
                backgroundColor: Colors.grey.shade200,
                valueColor:
                    AlwaysStoppedAnimation<Color>(Colors.green.shade600),
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Raised: ${NumberFormat.simpleCurrency(name: 'NGN').format(raised)}',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Goal: ${NumberFormat.simpleCurrency(name: 'NGN').format(goal)}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'edit') {
              _showProjectDialog(project: project);
            } else if (value == 'delete') {
              _deleteProject(project);
            }
          },
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Description:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                Text(project['description'] ?? 'No description provided.'),
                const SizedBox(height: 12),
                if (project['image_url'] != null) ...[
                  const Text('Image URL:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(project['image_url'],
                      style: const TextStyle(fontSize: 12, color: Colors.blue)),
                ],
                if ((project['fund_update_title'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty ||
                    (project['fund_update_text'] ?? '')
                        .toString()
                        .trim()
                        .isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text('Fund update:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  if ((project['fund_update_title'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    Text(project['fund_update_title'].toString()),
                  if ((project['fund_update_text'] ?? '')
                      .toString()
                      .trim()
                      .isNotEmpty)
                    Text(project['fund_update_text'].toString()),
                ],
                if (_projectImageList(project['fund_update_images'])
                    .isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${_projectImageList(project['fund_update_images']).length} fund update image(s)',
                    style: const TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Status: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    _buildStatusBadge(status),
                    const Spacer(),
                    const Text('Priority: ',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('${project['priority'] ?? 100}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'active':
        color = Colors.green;
        break;
      case 'planning':
        color = Colors.blue;
        break;
      case 'completed':
        color = Colors.purple;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _showProjectDialog({Map<String, dynamic>? project}) async {
    final isEditing = project != null;
    final titleController =
        TextEditingController(text: project?['title'] ?? '');
    final summaryController =
        TextEditingController(text: project?['summary'] ?? '');
    final descriptionController =
        TextEditingController(text: project?['description'] ?? '');
    final goalController =
        TextEditingController(text: (project?['goal'] ?? 0).toString());
    final raisedController =
        TextEditingController(text: (project?['raised'] ?? 0).toString());
    final imageUrlController =
        TextEditingController(text: project?['image_url'] ?? '');
    final fundUpdateTitleController =
        TextEditingController(text: project?['fund_update_title'] ?? '');
    final fundUpdateTextController =
        TextEditingController(text: project?['fund_update_text'] ?? '');
    final fundUpdateImagesController = TextEditingController(
      text: _projectImageList(project?['fund_update_images']).join('\n'),
    );
    final priorityController =
        TextEditingController(text: (project?['priority'] ?? 100).toString());
    String status = project?['status'] ?? 'active';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Project' : 'New Project'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration:
                      const InputDecoration(labelText: 'Project Title *'),
                ),
                TextField(
                  controller: summaryController,
                  decoration: const InputDecoration(labelText: 'Short Summary'),
                ),
                TextField(
                  controller: descriptionController,
                  decoration:
                      const InputDecoration(labelText: 'Full Description'),
                  maxLines: 3,
                ),
                TextField(
                  controller: goalController,
                  decoration:
                      const InputDecoration(labelText: 'Goal Amount (NGN)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: raisedController,
                  decoration:
                      const InputDecoration(labelText: 'Amount Raised (NGN)'),
                  keyboardType: TextInputType.number,
                ),
                TextField(
                  controller: imageUrlController,
                  decoration: const InputDecoration(labelText: 'Image URL'),
                ),
                TextField(
                  controller: fundUpdateTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Fund update title',
                    hintText: 'What has been done so far?',
                  ),
                ),
                TextField(
                  controller: fundUpdateTextController,
                  decoration: const InputDecoration(
                    labelText: 'Fund update text',
                    hintText:
                        'Explain what the received funds have helped accomplish.',
                  ),
                  maxLines: 4,
                ),
                TextField(
                  controller: fundUpdateImagesController,
                  decoration: const InputDecoration(
                    labelText: 'Fund update image URLs',
                    hintText: 'One image URL per line, maximum 10 images',
                  ),
                  maxLines: 5,
                ),
                TextField(
                  controller: priorityController,
                  decoration:
                      const InputDecoration(labelText: 'Priority (ascending)'),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: ['active', 'planning', 'completed']
                      .map((s) => DropdownMenuItem(
                          value: s, child: Text(s.toUpperCase())))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setDialogState(() => status = val);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (titleController.text.isEmpty) {
                  ToastUtils.showError('Title is required');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: Text(isEditing ? 'Update' : 'Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true) {
      final fundUpdateImages =
          _projectImageList(fundUpdateImagesController.text).take(10).toList();
      final projectData = {
        'title': titleController.text,
        'summary': summaryController.text,
        'description': descriptionController.text,
        'goal': double.tryParse(goalController.text) ?? 0,
        'raised': double.tryParse(raisedController.text) ?? 0,
        'image_url': imageUrlController.text,
        'fund_update_title': fundUpdateTitleController.text,
        'fund_update_text': fundUpdateTextController.text,
        'fund_update_images': fundUpdateImages,
        if (fundUpdateTitleController.text.trim().isNotEmpty ||
            fundUpdateTextController.text.trim().isNotEmpty ||
            fundUpdateImages.isNotEmpty)
          'fund_update_updated_at': DateTime.now().toIso8601String(),
        'priority': int.tryParse(priorityController.text) ?? 100,
        'status': status,
      };

      try {
        if (isEditing) {
          await _updateAdminDocument(
            AppwriteBackendConfig.projectsCollectionId,
            project['id'],
            {
              ...projectData,
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          ToastUtils.showSuccess('Project updated successfully');
        } else {
          await _createAdminDocument(
            AppwriteBackendConfig.projectsCollectionId,
            {
              ...projectData,
              'currency': 'NGN',
              'is_active': status == 'active',
              'created_at': DateTime.now().toIso8601String(),
              'updated_at': DateTime.now().toIso8601String(),
            },
          );
          ToastUtils.showSuccess('Project created successfully');
        }
        _loadProjects();
      } catch (e) {
        ToastUtils.showError('Error saving project: $e');
      }
    }
  }

  List<String> _projectImageList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(10)
          .toList();
    }
    return value
        .toString()
        .split(RegExp(r'[\r\n,]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(10)
        .toList();
  }

  Future<void> _deleteProject(Map<String, dynamic> project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project'),
        content: Text(
            'Are you sure you want to delete "${project['title']}"? This will also affect the donation page.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.projectsCollectionId,
          project['id'],
        );
        ToastUtils.showSuccess('Project deleted successfully');
        _loadProjects();
      } catch (e) {
        ToastUtils.showError('Error deleting project: $e');
      }
    }
  }

  // Seed template content into Appwrite so the live admin experience owns
  // project content, while the app can still fall back safely when offline.
  Future<void> _seedSampleProjects({bool showDialog = false}) async {
    setState(() => _isLoading = true);
    try {
      final samples = [
        {
          'id': 'impact_hub_center',
          'title': 'Impact Hub Center',
          'summary': 'Community discipleship and outreach facility',
          'description':
              'A central hub for training, discipleship, and community engagement.',
          'goal': 35000000.0,
          'raised': 8384400.0,
          'currency': 'NGN',
          'status': 'active',
          'priority': 1,
          'cta_label': 'Donate for this item',
          'image_url':
              'https://images.unsplash.com/photo-1593914370442-49d414beca24?q=80&w=1031&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
          'fund_update_title': 'Progress so far',
          'fund_update_text':
              'Seed funding has helped prepare the project scope, early planning, and ministry coordination for the hub.',
          'fund_update_images': <String>[],
        },
        {
          'id': 'vehicle_purchase',
          'title': 'Vehicle Purchase',
          'summary': 'Mission vehicle for outreach logistics',
          'description':
              'Reliable transportation for mission trips and logistics across Nigeria.',
          'goal': 18000000.0,
          'raised': 0.0,
          'currency': 'NGN',
          'status': 'active',
          'priority': 2,
          'cta_label': 'Donate for this item',
          'image_url':
              'https://images.unsplash.com/photo-1597685204565-110abf469a1e?q=80&w=870&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
          'fund_update_title': '',
          'fund_update_text': '',
          'fund_update_images': <String>[],
        },
        {
          'id': 'media_studio_setup',
          'title': 'Media Studio Setup',
          'summary': 'Podcast and content production equipment',
          'description':
              'Equipping the ministry with high-quality media production capabilities.',
          'goal': 9000000.0,
          'raised': 0.0,
          'currency': 'NGN',
          'status': 'planning',
          'priority': 3,
          'cta_label': 'Donate for this item',
          'image_url':
              'https://images.unsplash.com/photo-1769699167906-a44d5ae50abb?q=80&w=387&auto=format&fit=crop&ixlib=rb-4.1.0&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
          'fund_update_title': '',
          'fund_update_text': '',
          'fund_update_images': <String>[],
        },
      ];

      for (var project in samples) {
        final documentId = project['id']?.toString();
        await _upsertAdminDocument(
          AppwriteBackendConfig.projectsCollectionId,
          documentId ?? ID.unique(),
          {
            ...project,
            'is_active': project['status'] == 'active',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          },
        );
      }

      _loadProjects();
    } catch (e) {
      debugPrint('Error seeding projects: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}
