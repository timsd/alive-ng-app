import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../constants/app_constants.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/prayer_requests_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/error_handler.dart';
import '../../widgets/add_prayer_request_dialog.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/shimmer_loading.dart';

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
    final theme = Theme.of(context);
    final roleService = RoleAccessService.instance;
    final role = roleService.getCurrentUserRole() ?? 'member';
    const privatePrayerRoles = {
      'admin',
      'bod',
      'trustee',
      'chapter_leader',
      'director',
    };
    final canAccessPrivate = privatePrayerRoles.contains(role.toLowerCase());

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Prayer Wall',
        showBackButton: true,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: false,
        actions: [
          if (canAccessPrivate)
            IconButton(
              tooltip: 'Private Prayer Rooms',
              icon: const Icon(Icons.lock_person_rounded),
              onPressed: () =>
                  context.push(AppConstants.privatePrayerRoomRoute),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.onPrimary,
          labelColor: theme.colorScheme.onPrimary,
          unselectedLabelColor:
              theme.colorScheme.onPrimary.withValues(alpha: 0.72),
          tabs: const [
            Tab(
              icon: FaIcon(FontAwesomeIcons.globe, size: 18),
              text: 'Public Prayers',
            ),
            Tab(
              icon: FaIcon(FontAwesomeIcons.user, size: 18),
              text: 'My Prayers',
            ),
            Tab(
              icon: FaIcon(FontAwesomeIcons.personPraying, size: 18),
              text: 'Praying For',
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPrayerList(
            publicPrayerWallProvider,
            emptyTitle: 'No public prayer requests yet',
            emptySubtitle:
                'Be the first to share a prayer request with the brethren.',
            showAddButtonOnEmpty: true,
          ),
          _buildPrayerList(
            myPrayerWallProvider,
            emptyTitle: 'You have not posted any prayers yet',
            emptySubtitle:
                'Tap the + button below to share a personal or public prayer request.',
            showAddButtonOnEmpty: true,
          ),
          _buildPrayerList(
            supportedPrayerWallProvider,
            emptyTitle: 'Not supporting any prayer requests yet',
            emptySubtitle:
                'Tap "Pray" on any request in the Public Prayers tab to track prayers you are interceding for.',
            showAddButtonOnEmpty: false,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddPrayerDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        tooltip: 'Add Prayer Request',
        icon: const FaIcon(FontAwesomeIcons.plus, size: 16),
        label: const Text('New Prayer'),
      ),
    );
  }

  Widget _buildPrayerList(
    AutoDisposeFutureProvider<List<PrayerRequest>> provider, {
    required String emptyTitle,
    required String emptySubtitle,
    required bool showAddButtonOnEmpty,
  }) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);
    final asyncRequests = ref.watch(provider);

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(provider),
      child: asyncRequests.when(
        loading: () => const _PrayerWallSkeleton(),
        error: (error, _) => _buildLoadErrorState(
          context,
          'Unable to load prayers',
          error,
          onRetry: () => ref.invalidate(provider),
        ),
        data: (requests) {
          if (requests.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(24),
              children: [
                SizedBox(height: MediaQuery.sizeOf(context).height * 0.14),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary
                                .withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: FaIcon(
                              FontAwesomeIcons.personPraying,
                              size: 30,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          emptyTitle,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          emptySubtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            height: 1.4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (showAddButtonOnEmpty) ...[
                          const SizedBox(height: 20),
                          FilledButton.icon(
                            onPressed: _showAddPrayerDialog,
                            icon: const Icon(Icons.add),
                            label: const Text('Add Prayer Request'),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final request = requests[index];
              final isOwner = user?.uid == request.userId;
              return _PrayerCard(
                request: request,
                isOwner: isOwner,
                onPray: () => _recordPrayer(request),
                onShare: () => _sharePrayerRequest(request),
                onMarkAnswered: isOwner && !request.isAnswered
                    ? () => _markPrayerAnswered(request)
                    : null,
                onDelete: isOwner ? () => _deletePrayer(request) : null,
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
    Object? error, {
    required VoidCallback onRetry,
  }) {
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
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
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
      _showSnack('Thank you for praying for "${request.title}"');
    } catch (e) {
      _showSnack('Failed to record prayer: $e', isError: true);
    }
  }

  Future<void> _markPrayerAnswered(PrayerRequest request) async {
    try {
      await PrayerRequestsService.instance
          .markPrayerAnswered(requestId: request.id);
      ref.invalidate(publicPrayerWallProvider);
      ref.invalidate(myPrayerWallProvider);
      ref.invalidate(supportedPrayerWallProvider);
      _showSnack('Praise God! Marked "${request.title}" as answered.');
    } catch (e) {
      _showSnack('Failed to mark prayer as answered: $e', isError: true);
    }
  }

  Future<void> _deletePrayer(PrayerRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete prayer request?'),
        content:
            Text('This will remove "${request.title}" from the prayer wall.'),
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
    final text =
        '🙏 Prayer Request: ${request.title}\n\n${request.description}\n\n— Join us in prayer on ALIVE Nigeria';
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Prayer Request: ${request.title}',
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
  final VoidCallback? onMarkAnswered;
  final VoidCallback? onDelete;

  const _PrayerCard({
    required this.request,
    required this.isOwner,
    required this.onPray,
    required this.onShare,
    this.onMarkAnswered,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = request.isAnonymous
        ? 'Anonymous'
        : (request.user?.fullName?.trim().isNotEmpty == true
            ? request.user!.fullName!
            : 'Community Member');

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: request.isAnswered
              ? Colors.green.withValues(alpha: 0.45)
              : theme.colorScheme.outlineVariant,
        ),
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
                    request.isAnonymous ? Icons.visibility_off : Icons.person,
                    size: 20,
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
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            _formatTimestamp(request.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (request.category.trim().isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary
                                    .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _formatCategory(request.category),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (request.isAnswered)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.green.withValues(alpha: 0.5)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: 14,
                          color: Colors.green,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Answered',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (request.testimonyId != null)
                  Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: Colors.amber.withValues(alpha: 0.6)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.celebration_rounded,
                          size: 14,
                          color: Colors.amber,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Testified',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: theme.colorScheme.error,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              request.description,
              style: theme.textTheme.bodyMedium?.copyWith(height: 1.45),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FaIcon(
                      FontAwesomeIcons.personPraying,
                      size: 15,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${request.prayerCount} praying',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (onMarkAnswered != null)
                      TextButton.icon(
                        onPressed: onMarkAnswered,
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 18,
                          color: Colors.green,
                        ),
                        label: const Text(
                          'Mark Answered',
                          style: TextStyle(color: Colors.green),
                        ),
                      ),
                    if (!isOwner)
                      FilledButton.tonalIcon(
                        onPressed: onPray,
                        icon: const FaIcon(
                          FontAwesomeIcons.personPraying,
                          size: 14,
                        ),
                        label: const Text('Pray'),
                      ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Share prayer request',
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded, size: 19),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatCategory(String raw) {
    final cleaned = raw.trim().replaceAll('_', ' ');
    if (cleaned.isEmpty) return raw;
    return cleaned[0].toUpperCase() + cleaned.substring(1).toLowerCase();
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

class _PrayerWallSkeleton extends StatelessWidget {
  const _PrayerWallSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .outlineVariant
                  .withValues(alpha: 0.4),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const ShimmerLoading(
                      width: 40,
                      height: 40,
                      borderRadius: 20,
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        ShimmerLoading(width: 120, height: 16, borderRadius: 4),
                        SizedBox(height: 6),
                        ShimmerLoading(width: 80, height: 12, borderRadius: 4),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const ShimmerLoading(height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerLoading(height: 16, borderRadius: 4),
                const SizedBox(height: 8),
                const ShimmerLoading(width: 200, height: 16, borderRadius: 4),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: const [
                    ShimmerLoading(width: 100, height: 32, borderRadius: 16),
                    ShimmerLoading(width: 32, height: 32, borderRadius: 16),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
