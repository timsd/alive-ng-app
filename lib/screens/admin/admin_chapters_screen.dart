import 'package:flutter/material.dart';
import '../../models/chapter_models.dart';
import '../../services/chapter_service.dart';
import '../../constants/chapters.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import 'chapter_reports_screen.dart';

class AdminChaptersScreen extends StatefulWidget {
  const AdminChaptersScreen({super.key});

  @override
  State<AdminChaptersScreen> createState() => _AdminChaptersScreenState();
}

class _AdminChaptersScreenState extends State<AdminChaptersScreen> {
  final ChapterService _chapterService = ChapterService();
  bool _isLoading = true;
  List<Chapter> _chapters = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);
    try {
      final chapters = await _chapterService.getChapters();
      if (chapters.isEmpty) {
        await _seedSampleChapters();
        return;
      }
      if (!mounted) return;
      setState(() => _chapters = chapters);
    } catch (e) {
      debugPrint('Error loading chapters: $e');
      if (mounted) {
        ToastUtils.showError('Error loading chapters: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _seedSampleChapters() async {
    try {
      for (final name in ChapterConstants.availableChapters) {
        final description = ChapterConstants.chapterDescriptions[name] ??
            'ALIVE Nigeria $name Chapter';
        final chapter = Chapter(
          id: name.toLowerCase().replaceAll(' ', '_'),
          name: name,
          description: description,
          type: WorkersType.main,
          memberIds: const [],
          settings: const {},
          isActive: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await _chapterService.createChapter(chapter);
      }
      final chapters = await _chapterService.getChapters();
      if (!mounted) return;
      setState(() => _chapters = chapters);
    } catch (e) {
      debugPrint('Error seeding chapters: $e');
    }
  }

  List<Chapter> get _filteredChapters {
    if (_searchQuery.isEmpty) return _chapters;
    final query = _searchQuery.toLowerCase();
    return _chapters.where((c) {
      return c.name.toLowerCase().contains(query) ||
          c.description.toLowerCase().contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chapter Overview',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_location_alt_rounded),
            onPressed: () => _showChapterDialog(),
            tooltip: 'New Chapter',
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search chapters by name or region...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _filteredChapters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off_outlined,
                                size: 64, color: colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No chapters found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () => _showChapterDialog(),
                              icon: const Icon(Icons.add),
                              label: const Text('Add Chapter'),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadChapters,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredChapters.length,
                          itemBuilder: (context, index) {
                            final chapter = _filteredChapters[index];
                            return _buildChapterCard(chapter);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterCard(Chapter chapter) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12.0),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: chapter.isActive
                      ? colorScheme.primaryContainer
                      : colorScheme.outline.withValues(alpha: 0.2),
                  child: Icon(
                    Icons.location_city_rounded,
                    color: chapter.isActive
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        chapter.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        chapter.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    PopupMenuItem(
                      value: chapter.isActive ? 'deactivate' : 'activate',
                      child: ListTile(
                        leading: Icon(chapter.isActive
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline),
                        title: Text(chapter.isActive
                            ? 'Deactivate'
                            : 'Activate'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title:
                            Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                  onSelected: (action) => _handleAction(action, chapter),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    chapter.type.name.toUpperCase(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${chapter.memberIds.length} members',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ChapterReportsScreen(initialChapter: chapter.name),
                      ),
                    );
                  },
                  icon: const Icon(Icons.assessment_outlined, size: 16),
                  label: const Text('Chapter Reports',
                      style: TextStyle(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _handleAction(String action, Chapter chapter) {
    switch (action) {
      case 'edit':
        _showChapterDialog(chapter: chapter);
        break;
      case 'activate':
        _toggleActive(chapter, true);
        break;
      case 'deactivate':
        _toggleActive(chapter, false);
        break;
      case 'delete':
        _deleteChapter(chapter);
        break;
    }
  }

  Future<void> _toggleActive(Chapter chapter, bool active) async {
    try {
      await _chapterService.updateChapterFields(chapter.id, {'is_active': active});
      ToastUtils.showSuccess(
          'Chapter ${active ? 'activated' : 'deactivated'} successfully');
      _loadChapters();
    } catch (e) {
      ToastUtils.showError('Error updating chapter: $e');
    }
  }

  Future<void> _deleteChapter(Chapter chapter) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chapter'),
        content: Text('Are you sure you want to delete "${chapter.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _chapterService.deleteChapter(chapter.id);
        ToastUtils.showSuccess('Chapter deleted successfully');
        _loadChapters();
      } catch (e) {
        ToastUtils.showError('Error deleting chapter: $e');
      }
    }
  }

  void _showChapterDialog({Chapter? chapter}) {
    final isEditing = chapter != null;
    final nameController = TextEditingController(text: chapter?.name ?? '');
    final descController =
        TextEditingController(text: chapter?.description ?? '');
    WorkersType selectedType = chapter?.type ?? WorkersType.main;
    bool isActive = chapter?.isActive ?? true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(isEditing ? 'Edit Chapter' : 'Create Chapter'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Chapter Name *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<WorkersType>(
                  initialValue: selectedType,
                  decoration: const InputDecoration(
                    labelText: 'Chapter Type',
                    border: OutlineInputBorder(),
                  ),
                  items: WorkersType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(type.name.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedType = val);
                  },
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Is Active'),
                  value: isActive,
                  onChanged: (val) => setDialogState(() => isActive = val),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ToastUtils.showError('Chapter name is required');
                  return;
                }

                try {
                  if (isEditing) {
                    await _chapterService.updateChapterFields(chapter.id, {
                      'name': nameController.text.trim(),
                      'description': descController.text.trim(),
                      'type': selectedType.name,
                      'is_active': isActive,
                    });
                    ToastUtils.showSuccess('Chapter updated');
                  } else {
                    final newChapter = Chapter(
                      id: nameController.text.trim().toLowerCase().replaceAll(' ', '_'),
                      name: nameController.text.trim(),
                      description: descController.text.trim(),
                      type: selectedType,
                      memberIds: const [],
                      settings: const {},
                      isActive: isActive,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await _chapterService.createChapter(newChapter);
                    ToastUtils.showSuccess('Chapter created');
                  }
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadChapters();
                  }
                } catch (e) {
                  ToastUtils.showError('Error saving chapter: $e');
                }
              },
              child: Text(isEditing ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }
}
