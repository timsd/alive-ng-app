import 'package:share_plus/share_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:alive_flutter_app/widgets/custom_app_bar.dart';
import 'package:go_router/go_router.dart';
import '../../providers/language_provider.dart';
import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../constants/app_constants.dart';
import '../../config/meeting_links_config.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../widgets/add_prayer_request_dialog.dart';
import '../../services/prayer_requests_service.dart';
import '../../utils/app_exception.dart';

// Provider for prayer requests
final prayerRequestsProvider = FutureProvider<List<PrayerRequest>>((ref) async {
  return PrayerRequestsService.instance.fetchPrayerRequests();
});

// Provider for creating prayer requests
final createPrayerRequestProvider =
    StateNotifierProvider<CreatePrayerRequestNotifier, AsyncValue<void>>((ref) {
  return CreatePrayerRequestNotifier(ref);
});

class CreatePrayerRequestNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CreatePrayerRequestNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createRequest(
    String title,
    String description,
    String category,
    bool isAnonymous, {
    bool isPublic = true,
    String? scriptureReference,
    String urgencyLevel = 'normal',
  }) async {
    state = const AsyncValue.loading();
    try {
      final user = ref.read(currentUserProvider);

      final prayerRequest = PrayerRequest(
        id: '',
        title: title,
        description: description,
        category: category,
        userId: user?.uid ?? '',
        isAnonymous: isAnonymous,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await PrayerRequestsService.instance.createPrayerRequest(prayerRequest);

      state = const AsyncValue.data(null);
      ref.invalidate(prayerRequestsProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  String? _selectedCategory;

  Future<void> _submitPrayerRequest({
    required String title,
    required String category,
    required String description,
    required bool isAnonymous,
    required bool isPublic,
    String? scriptureReference,
    required String urgencyLevel,
  }) async {
    await ref.read(createPrayerRequestProvider.notifier).createRequest(
          title,
          description,
          category,
          isAnonymous,
          isPublic: isPublic,
          scriptureReference: scriptureReference,
          urgencyLevel: urgencyLevel,
        );
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final onPrimary = theme.colorScheme.onPrimary;
    final prayerRequestsAsync = ref.watch(prayerRequestsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAuthenticated = currentUser != null;
    final availableCategories = prayerRequestsAsync.maybeWhen(
      data: (requests) {
        final values = requests
            .map((r) => r.category.trim())
            .where((c) => c.isNotEmpty)
            .toSet()
            .toList();
        values.sort();
        return values;
      },
      orElse: () => <String>[],
    );

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('prayer'),
        showBackButton: true,
        backgroundColor: primary,
        foregroundColor: onPrimary,
        actions: [
          if (isAuthenticated)
            IconButton(
              onPressed: () => _showCreatePrayerDialog(context, ref),
              icon: const Icon(Icons.add),
              tooltip: translate('add_prayer_request'),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Show authentication required message if not authenticated
            if (!isAuthenticated) {
              return Center(
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size:
                            ResponsiveUtils.getResponsiveIconSize(context, 64),
                        color: primary.withValues(alpha: 0.5),
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 24)),
                      Text(
                        translate('authentication_required'),
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 20),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 16)),
                      Text(
                        translate('prayer_auth_message'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.7),
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 16),
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 32)),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to auth screen
                          context.go(AppConstants.authRoute);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primary,
                          foregroundColor: onPrimary,
                          padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getResponsiveSpacing(
                                  context, 32),
                              vertical: ResponsiveUtils.getResponsiveSpacing(
                                  context, 16)),
                        ),
                        child: Text(
                          translate('sign_in'),
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(prayerRequestsProvider);
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header section
                    Container(
                      width: double.infinity,
                      padding: ResponsiveUtils.getResponsivePadding(context),
                      decoration: BoxDecoration(
                        color: primary,
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(24),
                          bottomRight: Radius.circular(24),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            translate('prayer_requests'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(
                                  color: onPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                          context, 24),
                                ),
                          ),
                          SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                  context, 8)),
                          Text(
                            _humanizeLabel(translate('pray_together')),
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: onPrimary.withValues(alpha: 0.9),
                                      fontSize:
                                          ResponsiveUtils.getResponsiveFontSize(
                                              context, 16),
                                    ),
                          ),
                          SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                  context, 16)),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openPrayerMeeting();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.surface,
                                foregroundColor: primary,
                              ),
                              icon: const Icon(Icons.video_call_rounded),
                              label: Text(
                                translate('join_prayer_meeting'),
                                style: Theme.of(context)
                                    .textTheme
                                    .labelLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 24)),

                    // Prayer Categories
                    _buildPrayerCategories(
                        context, translate, availableCategories),

                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 24)),

                    // Prayer Requests List - Free access until onboarding complete
                    Padding(
                      padding: ResponsiveUtils.getResponsiveHorizontalPadding(
                          context),
                      child: Text(
                        translate('recent_requests'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 20),
                            ),
                      ),
                    ),

                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 16)),

                    prayerRequestsAsync.when(
                      data: (requests) {
                        // Filter requests by selected category
                        final filteredRequests = _selectedCategory == null
                            ? requests
                            : requests
                                .where((request) =>
                                    request.category.toLowerCase() ==
                                    _selectedCategory!.toLowerCase())
                                .toList();

                        return _buildPrayerRequests(
                            context, translate, filteredRequests);
                      },
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (error, stack) => _buildErrorWidget(
                          context, translate, error.toString()),
                    ),

                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 24)),
                  ],
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: isAuthenticated
          ? FloatingActionButton(
              onPressed: () => _showCreatePrayerDialog(context, ref),
              backgroundColor: primary,
              foregroundColor: onPrimary,
              tooltip: translate('add_prayer_request'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildPrayerCategories(BuildContext context,
      String Function(String) translate, List<String> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
          child: Text(
            translate('prayer_categories'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 20),
                ),
          ),
        ),
        SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
        if (categories.isEmpty)
          Padding(
            padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
            child: Text(
              'No categories yet. Add a prayer request to create one.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else
          Padding(
            padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final category in categories)
                  FilterChip(
                    label: Text(_humanizeLabel(category)),
                    selected: _selectedCategory == category,
                    onSelected: (_) {
                      setState(() {
                        _selectedCategory =
                            _selectedCategory == category ? null : category;
                      });
                    },
                  ),
                if (_selectedCategory != null)
                  ActionChip(
                    avatar: const Icon(Icons.clear, size: 18),
                    label: const Text('Clear'),
                    onPressed: () {
                      setState(() {
                        _selectedCategory = null;
                      });
                    },
                  ),
              ],
            ),
          ),
      ],
    );
  }

  String _humanizeLabel(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return value;
    final replaced = trimmed.replaceAll('_', ' ');
    return replaced.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _openPrayerMeeting() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveKitMeetingScreen(
          meetingType: MeetingType.prayer,
        ),
      ),
    );
  }

  Widget _buildPrayerRequests(BuildContext context,
      String Function(String) translate, List<PrayerRequest> requests) {
    if (requests.isEmpty) {
      return Container(
        margin: ResponsiveUtils.getResponsiveHorizontalPadding(context),
        padding: ResponsiveUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.favorite_outline,
              size: ResponsiveUtils.getResponsiveIconSize(context, 48),
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            Text(
              translate('no_prayer_requests'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 16),
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            Text(
              translate('be_first_to_share'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: ResponsiveUtils.getResponsiveHorizontalPadding(context),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return PrayerRequestCard(
          request: request,
          onPray: () => _prayForRequest(context, request),
        );
      },
    );
  }

  void _prayForRequest(BuildContext context, PrayerRequest request) {
    final currentUser = ref.read(currentUserProvider);

    // Check if user is authenticated
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to pray for requests'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              context.go(AppConstants.authRoute);
            },
          ),
        ),
      );
      return;
    }

    // Show a confirmation dialog
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pray for ${request.title}'),
        content: const Text(
            'You are about to pray for this request. This will be recorded and the prayer count will be updated.'),
        actions: [
          TextButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.of(context).pop();
                _recordPrayer(context, request);
              }
            },
            child: const Text('Pray'),
          ),
        ],
      ),
    );
  }

  void _recordPrayer(BuildContext context, PrayerRequest request) async {
    try {
      final currentUser = ref.read(currentUserProvider);
      if (currentUser == null) {
        throw AuthException('Please sign in to pray for requests');
      }

      await PrayerRequestsService.instance.prayForRequest(
        request.id,
        currentUser.uid,
      );
      ref.invalidate(prayerRequestsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for praying for ${request.title}'),
            backgroundColor: Theme.of(context).colorScheme.tertiary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record prayer: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildErrorWidget(
      BuildContext context, String Function(String) translate, String error) {
    return Container(
      margin: ResponsiveUtils.getResponsiveHorizontalPadding(context),
      padding: ResponsiveUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: ResponsiveUtils.getResponsiveIconSize(context, 48),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
          Text(
            translate('error_loading_data'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: ResponsiveUtils.getResponsiveFontSize(context, 16),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCreatePrayerDialog(BuildContext context, WidgetRef ref) {
    final currentUser = ref.read(currentUserProvider);

    // Check if user is authenticated
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please sign in to create prayer requests'),
          backgroundColor: Theme.of(context).colorScheme.secondary,
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              context.go(AppConstants.authRoute);
            },
          ),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) =>
          AddPrayerRequestDialog(onSubmit: _submitPrayerRequest),
    );
  }
}

class PrayerRequestCard extends StatelessWidget {
  final PrayerRequest request;
  final VoidCallback onPray;

  const PrayerRequestCard({
    super.key,
    required this.request,
    required this.onPray,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.2),
                  child: Text(
                    request.isAnonymous
                        ? 'M'
                        : (request.user?.fullName?.isNotEmpty == true
                            ? request.user!.fullName![0].toUpperCase()
                            : request.title.isNotEmpty
                                ? request.title[0].toUpperCase()
                                : 'P'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                SizedBox(
                    width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              request.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                            context, 16),
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (request.isAnonymous)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal:
                                      ResponsiveUtils.getResponsiveSpacing(
                                          context, 8),
                                  vertical:
                                      ResponsiveUtils.getResponsiveSpacing(
                                          context, 2)),
                              decoration: BoxDecoration(
                                color: Theme.of(context)
                                    .colorScheme
                                    .outline
                                    .withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Anonymous',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                      fontSize:
                                          ResponsiveUtils.getResponsiveFontSize(
                                              context, 10),
                                    ),
                              ),
                            ),
                        ],
                      ),
                      Text(
                        request.isAnonymous
                            ? 'Member'
                            : (request.user?.fullName ?? 'Unknown'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 12),
                            ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatDate(request.createdAt),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                        fontSize:
                            ResponsiveUtils.getResponsiveFontSize(context, 12),
                      ),
                ),
              ],
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14),
                  ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size:
                            ResponsiveUtils.getResponsiveIconSize(context, 16),
                        color: Theme.of(context).colorScheme.error,
                      ),
                      SizedBox(
                          width:
                              ResponsiveUtils.getResponsiveSpacing(context, 4)),
                      Text(
                        '${request.prayerCount} prayers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 12),
                            ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onPray,
                  icon: Icon(Icons.favorite,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 16)),
                  label: Text(
                    'Pray',
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
                SizedBox(width: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                IconButton(
                  tooltip: 'Share prayer',
                  onPressed: () {
                    final text = '${request.title}\n\n${request.description}\n\n— Shared from ALIVE Nigeria Prayer';
                    SharePlus.instance.share(ShareParams(text: text));
                  },
                  icon: Icon(Icons.share,
                      size: ResponsiveUtils.getResponsiveIconSize(context, 18)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inMinutes}m ago';
    }
  }
}
