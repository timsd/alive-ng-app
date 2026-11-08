import 'package:flutter/material.dart';
import '../../../services/file_picker_facade.dart';
import '../../../utils/error_handler.dart';
import '../../../services/appwrite_admin_content_service.dart';
import '../../../services/appwrite_storage_compat_service.dart';
import '../../../widgets/custom_image.dart';
import 'tract_podcast_shared.dart';

class CategoryManagementTab extends StatefulWidget {
  @override
  State<CategoryManagementTab> createState() => _CategoryManagementTabState();
}

class _CategoryManagementTabState extends State<CategoryManagementTab> {
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
                  'isActive': activeFlag(d),
                })
            .toList();
        _podcastCategoryDocs = podcastDocs
            .map((d) => {
                  'id': d['id'] ?? d['docId'] ?? d['uid'],
                  'name': d['name'],
                  'order': d['order'] ?? 0,
                  'isActive': activeFlag(d),
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 380;
                      return Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(Icons.article, color: Colors.orange),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Tract Categories',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showAddCategoryDialog('tract'),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              isCompact ? 'Add' : 'Add Category',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      );
                    },
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 380;
                      return Row(
                        children: [
                          Expanded(
                            child: Row(
                              children: const [
                                Icon(Icons.podcasts, color: Colors.blue),
                                SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    'Podcast Categories',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _showAddCategoryDialog('podcast'),
                            icon: const Icon(Icons.add, size: 16),
                            label: Text(
                              isCompact ? 'Add' : 'Add Category',
                              style: const TextStyle(fontSize: 12.5),
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ],
                      );
                    },
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
                    categoryPayload(name: name, order: order),
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
                      content: Text('Error adding category: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
                      content: Text('Error updating category: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
    try {
      final contentService = AppwriteAdminContentService.instance;
      int usageCount = 0;
      try {
        if (type == 'tract') {
          final tractsUsing =
              await contentService.listWhere('tracts', 'category', name);
          usageCount = tractsUsing.length;
        } else {
          final byDisplay =
              await contentService.listWhere('podcasts', 'category', name);
          final byEnum = await contentService.listWhere(
              'podcasts', 'category', name.toLowerCase());
          usageCount = byDisplay.length + byEnum.length;
        }
      } catch (_) {
        usageCount = 0;
      }

      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          title: Text('Delete $name?'),
          content: Text(
            usageCount > 0
                ? 'The $type category "$name" is currently assigned to $usageCount item(s).\n\n'
                  'Deleting it will remove the category from the list. Are you sure you want to proceed?'
                : 'Are you sure you want to delete "$name"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(dialogCtx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;
      if (!mounted) return;

      // Optimistically remove from state immediately
      setState(() {
        if (type == 'tract') {
          _tractCategoryDocs.removeWhere((c) => c['id'] == id || c['name'] == name);
        } else {
          _podcastCategoryDocs.removeWhere((c) => c['id'] == id || c['name'] == name);
        }
      });

      final collection =
          type == 'tract' ? 'tract_categories' : 'podcast_categories';
      await contentService.deleteDocument(collection, id);
      if (!mounted) return;
      await _refreshCategories();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${type.capitalize()} category "$name" deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting category: ${ErrorHandler.getUserFriendlyMessage(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
