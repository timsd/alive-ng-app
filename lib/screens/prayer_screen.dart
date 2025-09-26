import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/language_provider.dart';
import '../models/app_models.dart';
import '../providers/auth_provider.dart';
import '../utils/mobile_utils.dart';

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

class PrayerScreen extends ConsumerStatefulWidget {
  const PrayerScreen({super.key});

  @override
  ConsumerState<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends ConsumerState<PrayerScreen> {
  String? _selectedCategory;

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    final prayerRequestsAsync = ref.watch(prayerRequestsProvider);
    final currentUser = ref.watch(currentUserProvider);
    final isAuthenticated = currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(translate('prayer')),
        elevation: 0,
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
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
                  padding: MobileUtils.getResponsivePadding(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.lock_outline,
                        size: MobileUtils.getResponsiveIconSize(context, 64),
                        color: Colors.purple.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
                      Text(
                        translate('authentication_required'),
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: MobileUtils.getResponsiveFontSize(context, 20),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
                      Text(
                        translate('prayer_auth_message'),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: MobileUtils.getResponsiveSpacing(context, 32)),
                      ElevatedButton(
                        onPressed: () {
                          // Navigate to auth screen
                          Navigator.pushNamed(context, '/auth');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: MobileUtils.getResponsiveSpacing(context, 32), 
                            vertical: MobileUtils.getResponsiveSpacing(context, 16)
                          ),
                        ),
                        child: Text(
                          translate('sign_in'),
                          style: TextStyle(
                            fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                          ),
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
                      padding: MobileUtils.getResponsivePadding(context),
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
                                      fontSize: MobileUtils.getResponsiveFontSize(context, 24),
                                    ),
                          ),
                          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                          Text(
                            translate('pray_together'),
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                                ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),

                    // Prayer Categories
                    _buildPrayerCategories(context, translate),

                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),

                    // Prayer Requests List - Free access until onboarding complete
                    Padding(
                      padding: MobileUtils.getResponsiveHorizontalPadding(context),
                      child: Text(
                        translate('recent_requests'),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: MobileUtils.getResponsiveFontSize(context, 20),
                            ),
                      ),
                    ),

                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),

                    prayerRequestsAsync.when(
                      data: (requests) {
                        // Filter requests by selected category
                        final filteredRequests = _selectedCategory == null
                            ? requests
                            : requests.where((request) => 
                                request.category.toLowerCase() == _selectedCategory!.toLowerCase()
                              ).toList();
                        
                        return _buildPrayerRequests(context, translate, filteredRequests);
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (error, stack) =>
                          _buildErrorWidget(context, translate, error.toString()),
                    ),

                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 24)),
                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 80)), // Bottom padding for FAB
                  ],
                ),
              ),
            );
          },
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
        color: const Color(0xFF4CAF50), // Green
        count: 12,
      ),
      PrayerCategory(
        title: translate('family'),
        icon: Icons.family_restroom,
        color: const Color(0xFF2196F3), // Blue
        count: 8,
      ),
      PrayerCategory(
        title: translate('guidance'),
        icon: Icons.explore,
        color: const Color(0xFFFF9800), // Orange
        count: 15,
      ),
      PrayerCategory(
        title: translate('thanksgiving'),
        icon: Icons.favorite,
        color: const Color(0xFFF44336), // Red
        count: 6,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: MobileUtils.getResponsiveHorizontalPadding(context),
          child: Text(
            translate('prayer_categories'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: MobileUtils.getResponsiveFontSize(context, 20),
                ),
          ),
        ),
        SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: MobileUtils.getResponsiveHeight(context, 120),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: MobileUtils.getResponsiveHorizontalPadding(context),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    return Container(
                      width: MobileUtils.getResponsiveWidth(context, 100),
                      margin: EdgeInsets.only(right: MobileUtils.getResponsiveSpacing(context, 16)),
                      child: Card(
                        elevation: 2,
                        color: _selectedCategory == category.title 
                            ? category.color.withValues(alpha: 0.1)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: _selectedCategory == category.title
                              ? BorderSide(color: category.color, width: 2)
                              : BorderSide.none,
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedCategory = _selectedCategory == category.title 
                                  ? null 
                                  : category.title;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: EdgeInsets.all(MobileUtils.getResponsiveSpacing(context, 12)),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(MobileUtils.getResponsiveSpacing(context, 8)),
                                  decoration: BoxDecoration(
                                    color: category.color.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    category.icon,
                                    color: category.color,
                                    size: MobileUtils.getResponsiveIconSize(context, 24),
                                  ),
                                ),
                                SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                                Text(
                                  category.title,
                                  style:
                                      Theme.of(context).textTheme.bodySmall?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            fontSize: MobileUtils.getResponsiveFontSize(context, 12),
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
                                            fontSize: MobileUtils.getResponsiveFontSize(context, 12),
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
            ),
            if (_selectedCategory != null)
              Padding(
                padding: EdgeInsets.only(right: MobileUtils.getResponsiveSpacing(context, 20)),
                child: IconButton(
                  onPressed: () {
                    setState(() {
                      _selectedCategory = null;
                    });
                  },
                  icon: Icon(
                    Icons.clear,
                    size: MobileUtils.getResponsiveIconSize(context, 24),
                  ),
                  tooltip: 'Clear filter',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.grey.withValues(alpha: 0.1),
                    foregroundColor: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerRequests(BuildContext context,
      String Function(String) translate, List<PrayerRequest> requests) {
    if (requests.isEmpty) {
      return Container(
        margin: MobileUtils.getResponsiveHorizontalPadding(context),
        padding: MobileUtils.getResponsivePadding(context),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.favorite_outline,
              size: MobileUtils.getResponsiveIconSize(context, 48),
              color: Colors.purple.withValues(alpha: 0.5),
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
            Text(
              translate('no_prayer_requests'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: MobileUtils.getResponsiveFontSize(context, 16),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
            Text(
              translate('be_first_to_share'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                    fontSize: MobileUtils.getResponsiveFontSize(context, 14),
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
      padding: MobileUtils.getResponsiveHorizontalPadding(context),
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
          content: Text('Please sign in to pray for requests'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              Navigator.pushNamed(context, '/auth');
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
        content: Text('You are about to pray for this request. This will be recorded and the prayer count will be updated.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _recordPrayer(context, request);
            },
            child: Text('Pray'),
          ),
        ],
      ),
    );
  }

  void _recordPrayer(BuildContext context, PrayerRequest request) async {
    try {
      final supabase = ProviderScope.containerOf(context).read(supabaseServiceProvider);
      
      // Update prayer count in Supabase
      await supabase.prayForRequest(request.id, supabase.currentUser?.id ?? '');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Thank you for praying for ${request.title}'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record prayer: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Widget _buildErrorWidget(
      BuildContext context, String Function(String) translate, String error) {
    return Container(
      margin: MobileUtils.getResponsiveHorizontalPadding(context),
      padding: MobileUtils.getResponsivePadding(context),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
            size: MobileUtils.getResponsiveIconSize(context, 48),
          ),
          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
          Text(
            translate('error_loading_data'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: MobileUtils.getResponsiveFontSize(context, 16),
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
          content: Text('Please sign in to create prayer requests'),
          backgroundColor: Colors.orange,
          action: SnackBarAction(
            label: 'Sign In',
            onPressed: () {
              Navigator.pushNamed(context, '/auth');
            },
          ),
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
      margin: EdgeInsets.only(bottom: MobileUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: MobileUtils.getResponsivePadding(context),
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
                      fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                    ),
                  ),
                ),
                SizedBox(width: MobileUtils.getResponsiveSpacing(context, 12)),
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
                                    fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (request.isAnonymous)
                            Container(
                              padding: EdgeInsets.symmetric(
                                  horizontal: MobileUtils.getResponsiveSpacing(context, 8), 
                                  vertical: MobileUtils.getResponsiveSpacing(context, 2)),
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
                                      fontSize: MobileUtils.getResponsiveFontSize(context, 10),
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
                              fontSize: MobileUtils.getResponsiveFontSize(context, 12),
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
                        fontSize: MobileUtils.getResponsiveFontSize(context, 12),
                      ),
                ),
              ],
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 12)),
            Text(
              request.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: MobileUtils.getResponsiveFontSize(context, 14),
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite,
                        size: MobileUtils.getResponsiveIconSize(context, 16),
                        color: Colors.red,
                      ),
                      SizedBox(width: MobileUtils.getResponsiveSpacing(context, 4)),
                      Text(
                        '${request.prayerCount} prayers',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: MobileUtils.getResponsiveFontSize(context, 12),
                        ),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: onPray,
                  icon: Icon(Icons.favorite, size: MobileUtils.getResponsiveIconSize(context, 16)),
                  label: Text(
                    'Pray',
                    style: TextStyle(
                      fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
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
      title: Text(
        translate('add_prayer_request'),
        style: TextStyle(
          fontSize: MobileUtils.getResponsiveFontSize(context, 18),
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: translate('title'),
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                  fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                ),
              ),
              style: TextStyle(
                fontSize: MobileUtils.getResponsiveFontSize(context, 14),
              ),
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: InputDecoration(
                labelText: translate('category'),
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                  fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                ),
              ),
              style: TextStyle(
                fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                color: Theme.of(context).colorScheme.onSurface,
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(
                    category,
                    style: TextStyle(
                      fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedCategory = value!;
                });
              },
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: translate('description'),
                border: OutlineInputBorder(),
                labelStyle: TextStyle(
                  fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                ),
              ),
              style: TextStyle(
                fontSize: MobileUtils.getResponsiveFontSize(context, 14),
              ),
              maxLines: 3,
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 16)),
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
                SizedBox(width: MobileUtils.getResponsiveSpacing(context, 8)),
                Flexible(
                  child: Text(
                    'Submit anonymously (show as "Member")',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
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
          child: Text(
            translate('cancel'),
            style: TextStyle(
              fontSize: MobileUtils.getResponsiveFontSize(context, 14),
            ),
          ),
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

                    if (context.mounted) {
                      if (!ref.read(createPrayerRequestProvider).hasError) {
                        Navigator.of(context).pop();
                      }
                    }
                  }
                },
          child: createState.isLoading
              ? SizedBox(
                  width: MobileUtils.getResponsiveIconSize(context, 16),
                  height: MobileUtils.getResponsiveIconSize(context, 16),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  translate('submit'),
                  style: TextStyle(
                    fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                  ),
                ),
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




