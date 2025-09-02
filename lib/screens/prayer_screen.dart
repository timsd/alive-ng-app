import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../providers/guest_provider.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../widgets/guest_access_indicator.dart';

// Provider for prayer requests
final prayerRequestsProvider = FutureProvider<List<PrayerRequest>>((ref) async {
  final supabase = ref.read(supabaseServiceProvider);
  final response = await supabase.client
      .from('prayer_requests')
      .select('*, user:profiles(*)')
      .order('created_at', ascending: false);
  return response.map((json) => PrayerRequest.fromJson(json)).toList();
});

// Provider for creating prayer requests
final createPrayerRequestProvider =
    StateNotifierProvider<CreatePrayerRequestNotifier, AsyncValue<void>>((ref) {
  return CreatePrayerRequestNotifier(ref);
});

class CreatePrayerRequestNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref ref;

  CreatePrayerRequestNotifier(this.ref) : super(const AsyncValue.data(null));

  Future<void> createRequest(String title, String description, String category,
      bool isAnonymous) async {
    state = const AsyncValue.loading();
    try {
      final supabase = ref.read(supabaseServiceProvider);
      final user = ref.read(currentUserProvider);

      await supabase.client.from('prayer_requests').insert({
        'title': title,
        'description': description,
        'category': category,
        'user_id': user?.id,
        'is_anonymous': isAnonymous,
        'created_at': DateTime.now().toIso8601String(),
      });

      state = const AsyncValue.data(null);
      ref.invalidate(prayerRequestsProvider);
    } catch (error, stackTrace) {
      state = AsyncValue.error(error, stackTrace);
    }
  }
}

class PrayerScreen extends ConsumerWidget {
  const PrayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final translate = ref.watch(translationProvider);
    final prayerRequestsAsync = ref.watch(prayerRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('prayer')),
        elevation: 0,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => _showCreatePrayerDialog(context, ref),
            icon: const Icon(Icons.add),
            tooltip: translate('add_prayer_request'),
          ),
        ],
      ),
      body: RefreshIndicator(
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
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.purple,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translate('prayer_requests'),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      translate('pray_together'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Prayer Categories
              _buildPrayerCategories(context, translate),

              const SizedBox(height: 24),

              // Guest Access Indicator
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: GuestAccessIndicator(
                  message:
                      'Create an account to submit prayer requests and connect with our community!',
                  actionText: 'Sign Up',
                ),
              ),

              // Prayer Requests List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  translate('recent_requests'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ),

              const SizedBox(height: 16),

              prayerRequestsAsync.when(
                data: (requests) =>
                    _buildPrayerRequests(context, translate, requests),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) =>
                    _buildErrorWidget(context, translate, error.toString()),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrayerCategories(
      BuildContext context, String Function(String) translate) {
    final categories = [
      PrayerCategory(
        title: translate('healing'),
        icon: Icons.healing,
        color: Colors.green,
        count: 12,
      ),
      PrayerCategory(
        title: translate('family'),
        icon: Icons.family_restroom,
        color: Colors.blue,
        count: 8,
      ),
      PrayerCategory(
        title: translate('guidance'),
        icon: Icons.explore,
        color: Colors.orange,
        count: 15,
      ),
      PrayerCategory(
        title: translate('thanksgiving'),
        icon: Icons.favorite,
        color: Colors.red,
        count: 6,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            translate('prayer_categories'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return Container(
                width: 100,
                margin: const EdgeInsets.only(right: 16),
                child: Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: InkWell(
                    onTap: () {
                      // TODO: Filter by category
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: category.color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              category.icon,
                              color: category.color,
                              size: 24,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            category.title,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${category.count}',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: category.color,
                                      fontWeight: FontWeight.bold,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerRequests(BuildContext context,
      String Function(String) translate, List<PrayerRequest> requests) {
    if (requests.isEmpty) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.favorite_outline,
              size: 48,
              color: Colors.purple.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              translate('no_prayer_requests'),
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              translate('be_first_to_share'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return PrayerRequestCard(
          request: request,
          onPray: () {
            // TODO: Implement pray functionality
          },
        );
      },
    );
  }

  Widget _buildErrorWidget(
      BuildContext context, String Function(String) translate, String error) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            translate('error_loading_data'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCreatePrayerDialog(BuildContext context, WidgetRef ref) {
    final isAuthenticated = ref.read(isAuthenticatedProvider);

    if (!isAuthenticated) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Account Required'),
          content: Text(
              'Please create an account or sign in to submit prayer requests and connect with the community.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.pushNamed(context, '/auth');
              },
              child: Text('Sign In'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => CreatePrayerRequestDialog(),
    );
  }
}

class PrayerCategory {
  final String title;
  final IconData icon;
  final Color color;
  final int count;

  const PrayerCategory({
    required this.title,
    required this.icon,
    required this.color,
    required this.count,
  });
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
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.purple.withValues(alpha: 0.2),
                  child: Text(
                    request.isAnonymous
                        ? 'M'
                        : (request.user?.fullName?.isNotEmpty == true
                            ? request.user!.fullName![0].toUpperCase()
                            : request.title.isNotEmpty
                                ? request.title[0].toUpperCase()
                                : 'P'),
                    style: TextStyle(
                      color: Colors.purple,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
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
                                  ),
                            ),
                          ),
                          if (request.isAnonymous)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Anonymous',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                      fontSize: 10,
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
                      ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${request.prayerCount} prayers',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onPray,
                  icon: const Icon(Icons.favorite, size: 16),
                  label: const Text('Pray'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
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

class CreatePrayerRequestDialog extends ConsumerStatefulWidget {
  const CreatePrayerRequestDialog({super.key});

  @override
  ConsumerState<CreatePrayerRequestDialog> createState() =>
      _CreatePrayerRequestDialogState();
}

class _CreatePrayerRequestDialogState
    extends ConsumerState<CreatePrayerRequestDialog> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'General';
  bool _isAnonymous = false;

  final _categories = [
    'General',
    'Healing',
    'Family',
    'Guidance',
    'Thanksgiving',
    'Work',
    'Relationships'
  ];

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    final createState = ref.watch(createPrayerRequestProvider);

    return AlertDialog(
      title: Text(translate('add_prayer_request')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: translate('title'),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: translate('category'),
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: translate('description'),
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value ?? false;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Submit anonymously (show as "Member")',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(translate('cancel')),
        ),
        ElevatedButton(
          onPressed: createState.isLoading
              ? null
              : () async {
                  if (_titleController.text.isNotEmpty &&
                      _descriptionController.text.isNotEmpty) {
                    await ref
                        .read(createPrayerRequestProvider.notifier)
                        .createRequest(
                          _titleController.text,
                          _descriptionController.text,
                          _selectedCategory,
                          _isAnonymous,
                        );

                    if (mounted &&
                        !ref.read(createPrayerRequestProvider).hasError) {
                      Navigator.of(context).pop();
                    }
                  }
                },
          child: createState.isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(translate('submit')),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}
