import 'package:flutter/material.dart';
import '../../services/sample_content_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_app_bar.dart';

/// Admin screen listing every SAMPLE/seed item user-facing screens show
/// (sample podcasts, sample downloaded episodes, etc.) so admins can
/// hide (soft-delete) or restore them without touching the database.
class SampleContentAdminScreen extends StatefulWidget {
  const SampleContentAdminScreen({super.key});

  @override
  State<SampleContentAdminScreen> createState() =>
      _SampleContentAdminScreenState();
}

class _SampleContentAdminScreenState extends State<SampleContentAdminScreen> {
  final SampleContentService _sampleService = SampleContentService();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSamples();
  }

  Future<void> _loadSamples() async {
    await _sampleService.ensureLoaded();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _toggleHidden(Map<String, dynamic> sample) async {
    final id = sample['id'] as String;
    final wasHidden = _sampleService.isHidden(id);
    final ok = wasHidden
        ? await _sampleService.restoreSample(id)
        : await _sampleService.hideSample(id);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? (wasHidden
                ? '"${sample['title']}" restored for users.'
                : '"${sample['title']}" hidden from users.')
            : 'Action failed. Please try again.'),
        backgroundColor: ok
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.error,
      ),
    );
  }

  Future<void> _deleteSample(Map<String, dynamic> sample) async {
    final theme = Theme.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete sample?'),
        content: Text(
          '"${sample['title']}" will be permanently removed from this app '
          'build and from every user-facing screen. You can restore it '
          'later from this screen if you change your mind.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.error,
              foregroundColor: theme.colorScheme.onError,
            ),
            icon: const Icon(Icons.delete_forever, size: 18),
            label: const Text('Delete'),
            onPressed: () => Navigator.pop(ctx, true),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    final ok = await _sampleService.deleteSample(sample['id'] as String);
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok
            ? '"${sample['title']}" deleted permanently.'
            : 'Delete failed. Please try again.'),
        backgroundColor: ok
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RoleProtectedScreen(
      requiredRole: 'admin',
      screenName: 'Sample Content',
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Sample Content',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload',
              onPressed: _loadSamples,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSamples,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      color: theme.colorScheme.secondaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: theme.colorScheme.onSecondaryContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'These are the built-in sample items users see '
                                'before real content is published. Hide a '
                                'sample to remove it from user-facing screens '
                                '(restorable anytime), or delete it '
                                'permanently from this app build.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSecondaryContainer,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._sampleService.allSamples.map(_buildSampleCard),
                  ],
                ),
              ),
      ),
    );
  }


  Widget _buildSampleCard(Map<String, dynamic> sample) {
    final theme = Theme.of(context);
    final id = sample['id'] as String;
    final hidden = _sampleService.isHidden(id);
    final deleted = _sampleService.isDeleted(id);
    final isPodcast = sample['type'] == 'podcast';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: deleted
              ? theme.colorScheme.errorContainer
              : hidden
                  ? theme.colorScheme.outlineVariant
                  : theme.colorScheme.primaryContainer,
          child: Icon(
            isPodcast ? Icons.mic : Icons.headphones,
            color: deleted
                ? theme.colorScheme.onErrorContainer
                : hidden
                    ? theme.colorScheme.onSurfaceVariant
                    : theme.colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          sample['title'] as String? ?? 'Untitled sample',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: hidden ? TextDecoration.lineThrough : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isPodcast
                  ? 'Sample podcast · ${sample['host'] ?? 'Unknown host'}'
                  : 'Sample episode · ${sample['podcastTitle'] ?? ''}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _pill(
                  deleted
                      ? 'DELETED'
                      : hidden
                          ? 'HIDDEN'
                          : 'VISIBLE',
                  deleted
                      ? theme.colorScheme.error
                      : hidden
                          ? theme.colorScheme.outline
                          : theme.colorScheme.primary,
                ),
                _pill(
                  (sample['category'] as String? ?? 'general').toUpperCase(),
                  theme.colorScheme.tertiary,
                ),
                if (sample['hasAudio'] == true)
                  _pill('AUDIO', theme.colorScheme.secondary),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'toggle':
                _toggleHidden(sample);
                break;
              case 'delete':
                _deleteSample(sample);
                break;
            }
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'toggle',
              child: Row(
                children: [
                  Icon(
                    hidden ? Icons.visibility : Icons.visibility_off,
                    color: hidden ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Text(hidden
                      ? 'Restore (show users)'
                      : 'Hide from users'),
                ],
              ),
            ),
            if (!deleted)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_forever, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete permanently',
                        style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
