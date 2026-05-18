import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/prayer_requests_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/add_prayer_request_dialog.dart';
import '../../widgets/custom_app_bar.dart';

final publicPrayerWallProvider =
    FutureProvider.autoDispose<List<PrayerRequest>>((ref) {
  return PrayerRequestsService.instance.fetchPrayerRequests();
});

final myPrayerWallProvider =
    FutureProvider.autoDispose<List<PrayerRequest>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <PrayerRequest>[];
  return PrayerRequestsService.instance.fetchUserPrayerRequests(user.uid);
});

final supportedPrayerWallProvider =
    FutureProvider.autoDispose<List<PrayerRequest>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return <PrayerRequest>[];
  return PrayerRequestsService.instance.fetchSupportedPrayerRequests(user.uid);
});

class PrayerWallScreen extends ConsumerStatefulWidget {
  const PrayerWallScreen({super.key});

  @override
  ConsumerState<PrayerWallScreen> createState() => _PrayerWallScreenState();
}

class _PrayerWallScreenState extends ConsumerState<PrayerWallScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Prayer Wall',
        showBackButton: true,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: FaIcon(FontAwesomeIcons.globe), text: 'Public Prayers'),
            Tab(icon: FaIcon(FontAwesomeIcons.user), text: 'My Prayers'),
            Tab(
              icon: FaIcon(FontAwesomeIcons.personPraying),
              text: 'Praying For',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrayerList(publicPrayerWallProvider, emptyText: 'No prayer requests found'),
          _buildPrayerList(myPrayerWallProvider, emptyText: 'You have not created any prayer requests yet'),
          _buildPrayerList(supportedPrayerWallProvider, emptyText: 'You are not supporting any prayer requests yet'),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPrayerDialog,
        tooltip: 'Add Prayer Request',
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
    );
  }

  Widget _buildPrayerList(
    AutoDisposeFutureProvider<List<PrayerRequest>> provider, {
    required String emptyText,
  }) {
    final user = ref.watch(currentUserProvider);
    final asyncRequests = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: asyncRequests.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _buildLoadErrorState(
          context,
          'Unable to load prayers',
          error,
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.25),
                Center(child: Text(emptyText, textAlign: TextAlign.center)),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              return _PrayerCard(
                request: request,
                isOwner: user?.uid == request.userId,
                onPray: () => _recordPrayer(request),
                onShare: () => _sharePrayerRequest(request),
                onDelete: user?.uid == request.userId
                    ? () => _deletePrayer(request)
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadErrorState(
    BuildContext context,
    String title,
    Object? error,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.colorScheme.outlineVariant),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off_rounded,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    ErrorHandler.getUserFriendlyMessage(error),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _recordPrayer(PrayerRequest request) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showSnack('Please sign in to pray for requests', isError: true);
      return;
    }

    try {
      await PrayerRequestsService.instance.prayForRequest(request.id, user.uid);
      ref.invalidate(publicPrayerWallProvider);
      ref.invalidate(myPrayerWallProvider);
      ref.invalidate(supportedPrayerWallProvider);
      _showSnack('Thank you for praying for ${request.title}');
    } catch (e) {
      _showSnack('Failed to record prayer: $e', isError: true);
    }
  }

  Future<void> _deletePrayer(PrayerRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete prayer request?'),
        content: Text('This will remove "${request.title}" from the prayer wall.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await PrayerRequestsService.instance.deletePrayerRequest(request.id);
      ref.invalidate(publicPrayerWallProvider);
      ref.invalidate(myPrayerWallProvider);
      ref.invalidate(supportedPrayerWallProvider);
      _showSnack('Prayer request deleted');
    } catch (e) {
      _showSnack('Failed to delete prayer: $e', isError: true);
    }
  }

  void _showAddPrayerDialog() {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showSnack('Please sign in to create prayer requests', isError: true);
      return;
    }

    final screenContext = context;
    showDialog(
      context: context,
      builder: (context) => AddPrayerRequestDialog(
        onSubmit: ({
          required String title,
          required String category,
          required String description,
          required bool isAnonymous,
          required bool isPublic,
          String? scriptureReference,
          required String urgencyLevel,
        }) async {
          final request = PrayerRequest(
            id: '',
            userId: user.uid,
            title: title,
            description: description,
            category: category,
            isAnonymous: isAnonymous,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await PrayerRequestsService.instance.createPrayerRequest(request);
          ref.invalidate(publicPrayerWallProvider);
          ref.invalidate(myPrayerWallProvider);

          if (!screenContext.mounted) return;
          ScaffoldMessenger.of(screenContext).showSnackBar(
            SnackBar(
              content: const Text('Prayer request posted successfully'),
              backgroundColor: Theme.of(screenContext).colorScheme.tertiary,
            ),
          );
        },
      ),
    );
  }

  void _sharePrayerRequest(PrayerRequest request) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Prayer Request'),
        content: Text(
          '${request.title}\n\n${request.description}\n\nShare this prayer request with others to join in prayer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary,
      ),
    );
  }
}

class _PrayerCard extends StatelessWidget {
  final PrayerRequest request;
  final bool isOwner;
  final VoidCallback onPray;
  final VoidCallback onShare;
  final VoidCallback? onDelete;

  const _PrayerCard({
    required this.request,
    required this.isOwner,
    required this.onPray,
    required this.onShare,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = request.isAnonymous ? 'Anonymous' : 'Community Member';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: theme.colorScheme.primaryContainer,
                  child: Icon(
                    Icons.person,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatTimestamp(request.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: const FaIcon(FontAwesomeIcons.trash, size: 18),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              request.description,
              style: theme.textTheme.bodyMedium,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  FontAwesomeIcons.heart,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '${request.prayerCount} praying',
                  style: theme.textTheme.bodySmall,
                ),
                const Spacer(),
                if (!isOwner)
                  TextButton.icon(
                    onPressed: onPray,
                    icon: const FaIcon(FontAwesomeIcons.handsPraying, size: 18),
                    label: const Text('Pray'),
                  ),
                TextButton.icon(
                  onPressed: onShare,
                  icon: const FaIcon(FontAwesomeIcons.share, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
