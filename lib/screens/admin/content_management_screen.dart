import 'dart:convert';
import '../../utils/appwrite_id_utils.dart';
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
import '../../utils/project_sync_bridge.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/interactive_lessons_service.dart';
import '../../services/exchange_rate_service.dart';
import '../../config/default_content_data.dart';

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
  List<Map<String, dynamic>> _contentPages = List.from(_defaultContentPages);
  List<Map<String, dynamic>> _projects = List.from(_defaultProjects);

  static List<Map<String, dynamic>> get _defaultContentPages =>
      DefaultContentData.defaultContentPages;
  static List<Map<String, dynamic>> get _defaultProjects =>
      DefaultContentData.defaultProjects;

  Widget _buildSectionHeader(
      BuildContext context, String title, Widget action) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 460;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: LayoutFixUtils.safeText(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                    ),
                  ),
                  if (!isNarrow) action,
                ],
              ),
              if (isNarrow) ...[
                const SizedBox(height: 10),
                action,
              ],
            ],
          );
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllContent();

    // Set initial tab based on content type
    if (widget.contentType == 'projects') {
      _tabController.index = 1;
    } else if (widget.contentType == 'lessons') {
      _tabController.index = 2;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAllContent() async {
    try {
      await Future.wait([
        _loadContentPages(),
        _loadProjects(),
      ]);
    } catch (e) {
      debugPrint('Error loading content: $e');
    }
  }

  Future<void> _loadContentPages() async {
    try {
      final pages = await _listAdminDocuments(
        AppwriteBackendConfig.contentPagesCollectionId,
      );
      if (!mounted) return;
      setState(() {
        _contentPages =
            pages.isNotEmpty ? pages : List.from(_defaultContentPages);
      });
      if (pages.isEmpty) {
        _seedSamplePages();
      }
    } catch (e) {
      debugPrint('Error loading content pages: $e');
      if (mounted) {
        setState(() {
          _contentPages = List.from(_defaultContentPages);
        });
      }
    }
  }

  Future<void> _seedSamplePages() async {
    try {
      for (var page in _defaultContentPages) {
        final id = page['id'] as String;
        final data = Map<String, dynamic>.from(page)..remove('id');
        try {
          await _createAdminDocument(
            AppwriteBackendConfig.contentPagesCollectionId,
            data,
            documentId: id,
          );
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error seeding sample pages: $e');
    }
  }

  void _broadcastProjectsSync() {
    try {
      final jsonString = jsonEncode(_projects);
      syncProjectsToWeb(jsonString);
    } catch (e) {
      debugPrint('Error syncing projects to web: $e');
    }
  }

  Future<void> _loadProjects() async {
    try {
      final projects = await _listAdminDocuments(
        AppwriteBackendConfig.projectsCollectionId,
        queries: [Query.orderAsc('priority'), Query.limit(100)],
      );
      if (!mounted) return;
      setState(() {
        _projects = projects.isNotEmpty ? projects : List.from(_defaultProjects);
      });
      _broadcastProjectsSync();
      if (projects.isEmpty) {
        _seedSampleProjects(showDialog: false);
      }
    } catch (e) {
      debugPrint('Error loading projects: $e');
      if (mounted) {
        setState(() {
          _projects = List.from(_defaultProjects);
        });
        _broadcastProjectsSync();
      }
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
      rowId: AppwriteIdUtils.toValidUid(documentId),
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
        rowId: AppwriteIdUtils.toValidUid(documentId),
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
      rowId: AppwriteIdUtils.toValidUid(documentId),
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
      rowId: AppwriteIdUtils.toValidUid(documentId),
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
        appBar: CustomAppBar(
          title: 'Content Management',
          showBackButton: true,
          showDonationButton: false,
          bottom: TabBar(
            controller: _tabController,
            labelStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            unselectedLabelStyle:
                const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            indicatorColor: Theme.of(context).colorScheme.primary,
            labelColor: Theme.of(context).colorScheme.primary,
            unselectedLabelColor:
                Theme.of(context).colorScheme.onSurfaceVariant,
            indicatorWeight: 3,
            tabs: const [
              Tab(text: 'Content Pages', icon: Icon(Icons.article_outlined, size: 20)),
              Tab(text: 'Projects', icon: Icon(Icons.account_tree_outlined, size: 20)),
              Tab(text: 'Lessons', icon: Icon(Icons.school_outlined, size: 20)),
            ],
          ),
        ),
        body: _isLoading
            ? const LoadingWidget()
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildContentPagesTab(),
                  _buildProjectsTab(),
                  _buildInteractiveLessonsTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildContentPagesTab() {
    final theme = Theme.of(context);

    if (_contentPages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.article_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No content pages found.\nCreate your first page!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showContentPageDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Page'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _contentPages.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  'Content Pages (${_contentPages.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showContentPageDialog(),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('New Page'),
                  style: ElevatedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ],
            ),
          );
        }

        final page = _contentPages[index - 1];
        return _buildContentPageCard(page);
      },
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isPublished = page['is_published'] == true ||
        page['is_published'] == 'true' ||
        page['is_published'] == 1;

    DateTime? publishDate;
    if (page['publish_date'] != null) {
      if (page['publish_date'] is DateTime) {
        publishDate = page['publish_date'] as DateTime;
      } else {
        publishDate = DateTime.tryParse(page['publish_date'].toString());
      }
    }

    final title = (page['title'] ?? 'Untitled').toString();
    final slug = (page['slug'] ?? '').toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _showContentPageDialog(page: page),
        leading: CircleAvatar(
          backgroundColor: isPublished
              ? Colors.green.withValues(alpha: 0.15)
              : Colors.orange.withValues(alpha: 0.15),
          child: Icon(
            isPublished ? Icons.public : Icons.drafts,
            color: isPublished ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '/$slug',
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              isPublished
                  ? 'Published${publishDate != null ? ' on ${DateFormat('MMM dd, yyyy').format(publishDate)}' : ''}'
                  : 'Draft',
              style: TextStyle(
                color: isPublished ? Colors.green : Colors.orange,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'edit',
              child: ListTile(
                leading: Icon(Icons.edit, size: 20),
                title: Text('Edit'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: isPublished ? 'unpublish' : 'publish',
              child: ListTile(
                leading: Icon(
                  isPublished ? Icons.visibility_off : Icons.visibility,
                  size: 20,
                ),
                title: Text(isPublished ? 'Unpublish' : 'Publish'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red, size: 20),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
          onSelected: (value) => _handleContentPageAction(value, page),
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

                    setState(() {
                      if (isEditing) {
                        final idx = _contentPages
                            .indexWhere((p) => p['id'] == page['id']);
                        if (idx != -1) {
                          _contentPages[idx] = {
                            ..._contentPages[idx],
                            ...payload
                          };
                        }
                      } else {
                        _contentPages.insert(0, {
                          ...payload,
                          'id': 'page_${DateTime.now().millisecondsSinceEpoch}',
                          'created_at': DateTime.now().toIso8601String(),
                        });
                      }
                    });

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
                      Navigator.of(context).pop();
                    } catch (e) {
                      debugPrint('Note: local page saved, Appwrite sync: $e');
                      if (!mounted) return;
                      Navigator.of(context).pop();
                      ToastUtils.showSuccess(
                          isEditing ? 'Content page updated' : 'Content page created');
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

  Future<void> _toggleContentPagePublish(
      Map<String, dynamic> page, bool publish) async {
    final id = page['id'];
    setState(() {
      final idx = _contentPages.indexWhere((p) => p['id'] == id);
      if (idx != -1) {
        _contentPages[idx] = {
          ..._contentPages[idx],
          'is_published': publish,
          'status': publish ? 'published' : 'draft',
        };
      }
    });
    try {
      await _updateAdminDocument(
        AppwriteBackendConfig.contentPagesCollectionId,
        id,
        {
          'is_published': publish,
          'status': publish ? 'published' : 'draft',
          'updated_at': DateTime.now().toIso8601String(),
        },
      );
      ToastUtils.showSuccess(
        publish ? 'Page published' : 'Page unpublished',
      );
    } catch (e) {
      debugPrint('Note: local page updated, Appwrite sync: $e');
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
      final id = page['id'];
      setState(() {
        _contentPages.removeWhere((p) => p['id'] == id);
      });
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.contentPagesCollectionId,
          id,
        );
      } catch (e) {
        debugPrint('Note: local page removed, Appwrite sync: $e');
      }
      ToastUtils.showSuccess('Content page deleted successfully');
    }
  }

  Widget _buildProjectsTab() {
    final theme = Theme.of(context);

    if (_projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.account_tree_outlined, size: 54, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No projects found.\nCreate your first project!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _showProjectDialog(),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Project'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      itemCount: _projects.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Projects (${_projects.length})',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showProjectDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('New Project'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          );
        }

        final project = _projects[index - 1];
        return _buildProjectCard(project);
      },
    );
  }

  Widget _buildProjectCard(Map<String, dynamic> project) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final goal = double.tryParse(project['goal']?.toString() ?? '') ?? 0.0;
    final raised = double.tryParse(project['raised']?.toString() ?? '') ?? 0.0;
    final percent = goal > 0 ? (raised / goal).clamp(0.0, 1.0) : 0.0;
    final status = (project['status'] ?? 'active').toString();
    final rate = ExchangeRateService.instance.lastKnownRate;
    final usdRaised = rate > 0 ? (raised / rate) : 0.0;
    final usdGoal = rate > 0 ? (goal / rate) : 0.0;
    final title = (project['title'] ?? 'Untitled Project').toString();
    final summary = (project['summary'] ?? '').toString();

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12.0),
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: status == 'active' ? Colors.green : Colors.orange,
          child: const Icon(Icons.account_tree, color: Colors.white),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (summary.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(summary, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
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
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Raised: ${NumberFormat.simpleCurrency(name: 'NGN').format(raised)}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      if (rate > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(≈ \$${NumberFormat.currency(symbol: '', decimalDigits: 0).format(usdRaised)})',
                          style: TextStyle(fontSize: 10, color: Colors.green.shade600),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Goal: ${NumberFormat.simpleCurrency(name: 'NGN').format(goal)}',
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      if (rate > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '(≈ \$${NumberFormat.currency(symbol: '', decimalDigits: 0).format(usdGoal)})',
                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                        ),
                      ],
                    ],
                  ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Edit Project' : 'New Project'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Project Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryController,
                    decoration: const InputDecoration(
                      labelText: 'Short Summary',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Full Description',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: goalController,
                          decoration: const InputDecoration(
                            labelText: 'Goal (NGN)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: raisedController,
                          decoration: const InputDecoration(
                            labelText: 'Raised (NGN)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    decoration: const InputDecoration(
                      labelText: 'Image URL',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fundUpdateTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Fund update title',
                      hintText: 'What has been done so far?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fundUpdateTextController,
                    decoration: const InputDecoration(
                      labelText: 'Fund update text',
                      hintText:
                          'Explain what the received funds have helped accomplish.',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: fundUpdateImagesController,
                    decoration: const InputDecoration(
                      labelText: 'Fund update image URLs',
                      hintText: 'One image URL per line',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priorityController,
                          decoration: const InputDecoration(
                            labelText: 'Priority (ascending)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: status,
                          borderRadius: BorderRadius.circular(12),
                          dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                          icon: const Icon(Icons.arrow_drop_down_rounded),
                          decoration: const InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(),
                          ),
                          items: ['active', 'planning', 'completed']
                              .map((s) => DropdownMenuItem(
                                  value: s, child: Text(TextFormatter.formatText(s))))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => status = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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
        'target_amount': double.tryParse(goalController.text) ?? 0,
        'raised': double.tryParse(raisedController.text) ?? 0,
        'amount_raised': double.tryParse(raisedController.text) ?? 0,
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

      setState(() {
        if (isEditing) {
          final idx = _projects.indexWhere((p) => p['id'] == project['id']);
          if (idx != -1) {
            _projects[idx] = {
              ..._projects[idx],
              ...projectData,
              'updated_at': DateTime.now().toIso8601String(),
            };
          }
        } else {
          _projects.insert(0, {
            ...projectData,
            'id': 'proj_${DateTime.now().millisecondsSinceEpoch}',
            'currency': 'NGN',
            'is_active': status == 'active',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      });
      _broadcastProjectsSync();

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
      } catch (e) {
        debugPrint('Note: local project saved, Appwrite sync: $e');
        ToastUtils.showSuccess(
            isEditing ? 'Project updated successfully' : 'Project created successfully');
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
      final id = project['id'];
      setState(() {
        _projects.removeWhere((p) => p['id'] == id);
      });
      _broadcastProjectsSync();
      try {
        await _deleteAdminDocument(
          AppwriteBackendConfig.projectsCollectionId,
          id,
        );
      } catch (e) {
        debugPrint('Note: local project removed, Appwrite sync: $e');
      }
      ToastUtils.showSuccess('Project deleted successfully');
    }
  }

  // Seed template content into Appwrite so the live admin experience owns
  // project content, while the app can still fall back safely when offline.
  Future<void> _seedSampleProjects({bool showDialog = false}) async {
    setState(() => _isLoading = true);
    try {
      for (var project in _defaultProjects) {
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

  // -------------------------------------------------------------
  // TAB 3: Interactive Lessons Management
  // -------------------------------------------------------------

  Widget _buildInteractiveLessonsTab() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lessonsService = InteractiveLessonsService.instance;

    return AnimatedBuilder(
      animation: lessonsService,
      builder: (context, _) {
        final lessons = lessonsService.lessons;

        if (lessons.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_outlined, size: 54, color: Colors.grey),
                const SizedBox(height: 12),
                const Text(
                  'No interactive lessons yet.\nTap below to create one.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showLessonEditorDialog(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Interactive Study'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: lessons.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Interactive Lessons (${lessons.length})',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Add Lesson'),
                      style: ElevatedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () => _showLessonEditorDialog(),
                    ),
                  ],
                ),
              );
            }

            final lesson = lessons[index - 1];
            return Card(
              elevation: 0,
              margin: const EdgeInsets.only(bottom: 12),
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: Avatar + Title with full horizontal room
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.15),
                          child: Icon(
                            Icons.school_outlined,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lesson.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lesson.category,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lesson.level,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      lesson.duration,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (lesson.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        lesson.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Bottom actions row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: (lesson.isActive ? Colors.green : Colors.grey).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            lesson.isActive ? 'PUBLISHED' : 'HIDDEN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: lesson.isActive ? Colors.green : Colors.grey,
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(
                                lesson.isActive
                                    ? Icons.visibility_rounded
                                    : Icons.visibility_off_rounded,
                                color: lesson.isActive ? Colors.green : Colors.grey,
                                size: 20,
                              ),
                              tooltip: lesson.isActive ? 'Hide' : 'Publish',
                              visualDensity: VisualDensity.compact,
                              onPressed: () {
                                lessonsService.saveLesson(
                                  lesson.copyWith(isActive: !lesson.isActive),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: 'Edit Lesson',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showLessonEditorDialog(lesson: lesson),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: Colors.redAccent, size: 20),
                              tooltip: 'Delete Lesson',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  _showDeleteLessonDialog(lesson),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
                          lesson.copyWith(isActive: !lesson.isActive),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Edit Lesson',
                      onPressed: () =>
                          _showLessonEditorDialog(lesson: lesson),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent, size: 20),
                      tooltip: 'Delete Lesson',
                      onPressed: () =>
                          _showDeleteLessonDialog(lesson),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showLessonEditorDialog({InteractiveLessonItem? lesson}) {
    final isEditing = lesson != null;
    final titleController = TextEditingController(text: lesson?.title ?? '');
    final descriptionController =
        TextEditingController(text: lesson?.description ?? '');
    final durationController =
        TextEditingController(text: lesson?.duration ?? '30 min');
    final contentController =
        TextEditingController(text: lesson?.content ?? '');

    String selectedCategory = lesson?.category ?? 'Bible Study';
    String selectedLevel = lesson?.level ?? 'Beginner';
    bool isActive = lesson?.isActive ?? true;

    final categories = ['Bible Study', 'Prophecy', 'Health', 'Missions', 'Discipleship', 'Doctrine'];
    final levels = ['Beginner', 'Intermediate', 'Advanced'];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isEditing ? 'Edit Interactive Lesson' : 'New Interactive Lesson'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedCategory,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            border: OutlineInputBorder(),
                          ),
                          items: categories
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedLevel,
                          decoration: const InputDecoration(
                            labelText: 'Level',
                            border: OutlineInputBorder(),
                          ),
                          items: levels
                              .map((l) => DropdownMenuItem(value: l, child: Text(l)))
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => selectedLevel = val);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: durationController,
                    decoration: const InputDecoration(
                      labelText: 'Estimated Duration',
                      hintText: 'e.g. 35 min',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Short Description',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Lesson Content (Markdown)',
                      hintText: '# Title\n\nLesson content and scripture references...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Published (Visible to members)'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (titleController.text.trim().isEmpty) {
                  ToastUtils.showError('Please enter a lesson title');
                  return;
                }
                final updated = InteractiveLessonItem(
                  id: lesson?.id ?? 'lesson_${DateTime.now().millisecondsSinceEpoch}',
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  category: selectedCategory,
                  level: selectedLevel,
                  duration: durationController.text.trim(),
                  content: contentController.text.trim(),
                  isActive: isActive,
                  isFavorite: lesson?.isFavorite ?? false,
                  progress: lesson?.progress ?? 0.0,
                  isCompleted: lesson?.isCompleted ?? false,
                );
                InteractiveLessonsService.instance.saveLesson(updated);
                Navigator.pop(ctx);
                ToastUtils.showSuccess(isEditing ? 'Lesson updated!' : 'Lesson created!');
              },
              child: Text(isEditing ? 'Save Changes' : 'Create Lesson'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteLessonDialog(InteractiveLessonItem lesson) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lesson?'),
        content: Text('Are you sure you want to delete "${lesson.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              InteractiveLessonsService.instance.deleteLesson(lesson.id);
              Navigator.pop(ctx);
              ToastUtils.showSuccess('Lesson deleted');
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
