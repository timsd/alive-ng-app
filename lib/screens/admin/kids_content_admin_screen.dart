import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../constants/app_constants.dart';
import '../../services/kids_content_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/app_utils.dart';
import '../../utils/error_handler.dart';
import '../../widgets/error_widget.dart';
import '../../widgets/loading_widget.dart';

class KidsContentAdminScreen extends ConsumerStatefulWidget {
  const KidsContentAdminScreen({super.key, this.bypassGuard = false});
  final bool bypassGuard;

  @override
  ConsumerState<KidsContentAdminScreen> createState() =>
      _KidsContentAdminScreenState();
}

class _KidsContentAdminScreenState extends ConsumerState<KidsContentAdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final GlobalKey<_MemoryVersesTabState> _mvKey =
      GlobalKey<_MemoryVersesTabState>();
  final GlobalKey<_PrayerActivitiesTabState> _paKey =
      GlobalKey<_PrayerActivitiesTabState>();
  final GlobalKey<_ServiceProjectsTabState> _spKey =
      GlobalKey<_ServiceProjectsTabState>();
  final GlobalKey<_KidsStoriesTabState> _ksKey =
      GlobalKey<_KidsStoriesTabState>();
  final GlobalKey<_LearningResourcesTabState> _lrKey =
      GlobalKey<_LearningResourcesTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Guard at build time too (router already redirects)
    if (!widget.bypassGuard && !RoleAccessService.instance.canAccessAdmin()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go(AppConstants.homeRoute);
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids Content Admin'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.menu_book), text: 'Memory Verses'),
            Tab(icon: Icon(Icons.favorite), text: 'Prayer Activities'),
            Tab(icon: Icon(Icons.volunteer_activism), text: 'Service Projects'),
            Tab(icon: Icon(Icons.auto_stories), text: 'Kids Stories'),
            Tab(icon: Icon(Icons.school), text: 'Learning Resources'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _MemoryVersesTab(key: _mvKey),
          _PrayerActivitiesTab(key: _paKey),
          _ServiceProjectsTab(key: _spKey),
          _KidsStoriesTab(key: _ksKey),
          _LearningResourcesTab(key: _lrKey),
        ],
      ),
      floatingActionButton: _buildFabForTab(context),
    );
  }

  Widget _buildFabForTab(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        final idx = _tabController.index;
        try {
          if (idx == 0) {
            final result = await _showSimpleEditDialog(context,
                title: 'New Memory Verse',
                fields: const ['verse', 'reference', 'category']);
            if (result != null) {
              await KidsContentService.createMemoryVerse({
                'verse': result['verse'] ?? '',
                'reference': result['reference'] ?? '',
                'category': result['category'] ?? 'General',
                'ageGroup': 'all',
                'createdAt': FieldValue.serverTimestamp(),
              });
              _mvKey.currentState?.refresh();
            }
          } else if (idx == 1) {
            final result = await _showSimpleEditDialog(context,
                title: 'New Prayer Activity',
                fields: const ['title', 'content', 'type']);
            if (result != null) {
              await KidsContentService.createPrayerActivity({
                'title': result['title'] ?? '',
                'content': result['content'] ?? '',
                'type': result['type'] ?? 'daily',
                'ageGroup': 'all',
                'createdAt': FieldValue.serverTimestamp(),
              });
              _paKey.currentState?.refresh();
            }
          } else if (idx == 2) {
            final result = await _showSimpleEditDialog(context,
                title: 'New Service Project',
                fields: const ['title', 'category']);
            if (result != null) {
              await KidsContentService.createServiceProject({
                'title': result['title'] ?? '',
                'category': result['category'] ?? 'General',
                'ageGroup': 'all',
                'createdAt': FieldValue.serverTimestamp(),
              });
              _spKey.currentState?.refresh();
            }
          } else if (idx == 3) {
            final result = await _showSimpleEditDialog(context,
                title: 'New Kids Story', fields: const ['title', 'category']);
            if (!mounted) return;
            if (result != null) {
              await KidsContentService.createKidsStory({
                'title': result['title'] ?? '',
                'category': result['category'] ?? 'General',
                'createdAt': FieldValue.serverTimestamp(),
              });
              _ksKey.currentState?.refresh();
            }
          } else if (idx == 4) {
            final result = await _showSimpleEditDialog(context,
                title: 'New Resource', fields: const ['title', 'resourceType']);
            if (!mounted) return;
            if (result != null) {
              await KidsContentService.createLearningResource({
                'title': result['title'] ?? '',
                'resourceType': result['resourceType'] ?? 'activity_pack',
                'downloadable': true,
                'createdAt': FieldValue.serverTimestamp(),
              });
              _lrKey.currentState?.refresh();
            }
          }
        } catch (e) {
          if (!mounted) return;
          final messenger = ScaffoldMessenger.of(this.context);
          messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      },
      child: const Icon(Icons.add),
    );
  }

  Future<Map<String, String>?> _showSimpleEditDialog(
    BuildContext context, {
    required String title,
    required List<String> fields,
    Map<String, dynamic>? initialValues,
  }) async {
    final controllers = {
      for (final f in fields)
        f: TextEditingController(text: initialValues?[f]?.toString() ?? ''),
    };
    final formKey = GlobalKey<FormState>();
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final f in fields)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TextFormField(
                      controller: controllers[f],
                      decoration: InputDecoration(labelText: f.capitalize),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
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
              if (formKey.currentState!.validate()) {
                Navigator.pop(
                  context,
                  {for (final f in fields) f: controllers[f]!.text.trim()},
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    for (final c in controllers.values) {
      c.dispose();
    }
    return result;
  }

  // _buildComingSoon removed (unused)
}

class _MemoryVersesTab extends StatefulWidget {
  const _MemoryVersesTab({super.key});
  @override
  State<_MemoryVersesTab> createState() => _MemoryVersesTabState();
}

class _MemoryVersesTabState extends State<_MemoryVersesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = KidsContentService.getMemoryVerses();
  }

  void refresh() {
    setState(() {
      _future = KidsContentService.getMemoryVerses();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading memory verses...');
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            title: 'Unable to load memory verses',
            message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
            actionText: 'Retry',
            onAction: refresh,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyStateWidget(
            title: 'No memory verses yet',
            message:
                'Add a memory verse to make it available in the kids area.',
            icon: Icons.menu_book_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item['verse']?.toString() ?? 'Verse'),
              subtitle: Text((item['reference'] ?? '') +
                  (item['category'] != null ? ' • ${item['category']}' : '')),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    if (value == 'edit') {
                      final result = await (context
                          .findAncestorStateOfType<
                              _KidsContentAdminScreenState>()
                          ?._showSimpleEditDialog(
                            context,
                            title: 'Edit Memory Verse',
                            fields: const ['verse', 'reference', 'category'],
                            initialValues: item,
                          ));
                      if (result != null) {
                        await KidsContentService.updateMemoryVerse(
                            item['id'] as String, result);
                        refresh();
                      }
                    } else if (value == 'delete') {
                      await KidsContentService.deleteMemoryVerse(
                          item['id'] as String);
                      refresh();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _PrayerActivitiesTab extends StatefulWidget {
  const _PrayerActivitiesTab({super.key});
  @override
  State<_PrayerActivitiesTab> createState() => _PrayerActivitiesTabState();
}

class _PrayerActivitiesTabState extends State<_PrayerActivitiesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = KidsContentService.getPrayerActivities();
  }

  void refresh() {
    setState(() {
      _future = KidsContentService.getPrayerActivities();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading prayer activities...');
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            title: 'Unable to load prayer activities',
            message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
            actionText: 'Retry',
            onAction: refresh,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyStateWidget(
            title: 'No prayer activities yet',
            message:
                'Create a prayer activity so children can use it in the app.',
            icon: Icons.favorite_outline,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item['title']?.toString() ?? 'Untitled'),
              subtitle: Text((item['type'] ?? '') +
                  (item['ageGroup'] != null ? ' • ${item['ageGroup']}' : '')),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    if (value == 'edit') {
                      final result = await (context
                          .findAncestorStateOfType<
                              _KidsContentAdminScreenState>()
                          ?._showSimpleEditDialog(
                            context,
                            title: 'Edit Prayer Activity',
                            fields: const ['title', 'content', 'type'],
                            initialValues: item,
                          ));
                      if (result != null) {
                        await KidsContentService.updatePrayerActivity(
                            item['id'] as String, result);
                        refresh();
                      }
                    } else if (value == 'delete') {
                      await KidsContentService.deletePrayerActivity(
                          item['id'] as String);
                      refresh();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ServiceProjectsTab extends StatefulWidget {
  const _ServiceProjectsTab({super.key});
  @override
  State<_ServiceProjectsTab> createState() => _ServiceProjectsTabState();
}

class _ServiceProjectsTabState extends State<_ServiceProjectsTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = KidsContentService.getServiceProjects();
  }

  void refresh() {
    setState(() {
      _future = KidsContentService.getServiceProjects();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading service projects...');
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            title: 'Unable to load service projects',
            message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
            actionText: 'Retry',
            onAction: refresh,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyStateWidget(
            title: 'No service projects yet',
            message:
                'Add a service project to populate the kids mission section.',
            icon: Icons.volunteer_activism_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item['title']?.toString() ?? 'Untitled'),
              subtitle: Text(item['category']?.toString() ?? ''),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    if (value == 'edit') {
                      final result = await (context
                          .findAncestorStateOfType<
                              _KidsContentAdminScreenState>()
                          ?._showSimpleEditDialog(
                            context,
                            title: 'Edit Service Project',
                            fields: const ['title', 'category'],
                            initialValues: item,
                          ));
                      if (result != null) {
                        await KidsContentService.updateServiceProject(
                            item['id'] as String, result);
                        refresh();
                      }
                    } else if (value == 'delete') {
                      await KidsContentService.deleteServiceProject(
                          item['id'] as String);
                      refresh();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _KidsStoriesTab extends StatefulWidget {
  const _KidsStoriesTab({super.key});
  @override
  State<_KidsStoriesTab> createState() => _KidsStoriesTabState();
}

class _KidsStoriesTabState extends State<_KidsStoriesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = KidsContentService.getKidsStories();
  }

  void refresh() {
    setState(() {
      _future = KidsContentService.getKidsStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading kids stories...');
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            title: 'Unable to load kids stories',
            message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
            actionText: 'Retry',
            onAction: refresh,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyStateWidget(
            title: 'No stories yet',
            message: 'Add a story to make it visible in the kids stories area.',
            icon: Icons.auto_stories_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item['title']?.toString() ?? 'Untitled'),
              subtitle: Text(item['category']?.toString() ?? ''),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    if (value == 'edit') {
                      final result = await (context
                          .findAncestorStateOfType<
                              _KidsContentAdminScreenState>()
                          ?._showSimpleEditDialog(
                            context,
                            title: 'Edit Kids Story',
                            fields: const ['title', 'category'],
                            initialValues: item,
                          ));
                      if (result != null) {
                        await KidsContentService.updateKidsStory(
                            item['id'] as String, result);
                        refresh();
                      }
                    } else if (value == 'delete') {
                      await KidsContentService.deleteKidsStory(
                          item['id'] as String);
                      refresh();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _LearningResourcesTab extends StatefulWidget {
  const _LearningResourcesTab({super.key});
  @override
  State<_LearningResourcesTab> createState() => _LearningResourcesTabState();
}

class _LearningResourcesTabState extends State<_LearningResourcesTab> {
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = getLearningResources();
  }

  void refresh() {
    setState(() {
      _future = getLearningResources();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingWidget(message: 'Loading learning resources...');
        }
        if (snapshot.hasError) {
          return AppErrorWidget(
            title: 'Unable to load learning resources',
            message: ErrorHandler.getUserFriendlyMessage(snapshot.error),
            actionText: 'Retry',
            onAction: refresh,
          );
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const EmptyStateWidget(
            title: 'No learning resources yet',
            message:
                'Add a learning resource so it becomes available in the kids section.',
            icon: Icons.school_outlined,
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = items[index];
            return ListTile(
              title: Text(item['title']?.toString() ?? 'Untitled'),
              subtitle: Text(item['subject']?.toString() ?? ''),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  try {
                    if (value == 'edit') {
                      final result = await (context
                          .findAncestorStateOfType<
                              _KidsContentAdminScreenState>()
                          ?._showSimpleEditDialog(
                            context,
                            title: 'Edit Learning Resource',
                            fields: const ['title', 'resourceType'],
                            initialValues: item,
                          ));
                      if (result != null) {
                        await KidsContentService.updateLearningResource(
                            item['id'] as String, result);
                        refresh();
                      }
                    } else if (value == 'delete') {
                      await KidsContentService.deleteLearningResource(
                          item['id'] as String);
                      refresh();
                    }
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context)
                        .showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
