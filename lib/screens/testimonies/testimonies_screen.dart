import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/testimony_model.dart';
import '../../providers/testimony_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';
import '../../utils/error_handler.dart';

class TestimoniesScreen extends ConsumerStatefulWidget {
  const TestimoniesScreen({super.key});

  @override
  ConsumerState<TestimoniesScreen> createState() => _TestimoniesScreenState();
}

class _TestimoniesScreenState extends ConsumerState<TestimoniesScreen>
    with SingleTickerProviderStateMixin {
  late Future<List<Testimony>> _publicTestimoniesFuture;
  late Future<List<Testimony>> _myTestimoniesFuture;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) {
      _publicTestimoniesFuture = Future.value(const <Testimony>[]);
      _myTestimoniesFuture = Future.value(const <Testimony>[]);
    } else {
      final testimonyService = ref.read(testimonyServiceProvider);
      _publicTestimoniesFuture = testimonyService.fetchTestimonies();
      _myTestimoniesFuture = testimonyService.fetchMyTestimonies();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshTestimonies() {
    if (ref.read(currentUserProvider) == null) return;
    final testimonyService = ref.read(testimonyServiceProvider);
    setState(() {
      _publicTestimoniesFuture = testimonyService.fetchTestimonies();
      _myTestimoniesFuture = testimonyService.fetchMyTestimonies();
    });
  }

  void _showAddTestimonyDialog() {
    final contentController = TextEditingController();
    bool isAnonymous = false;
    final translate = ref.read(translationProvider);
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(
                ResponsiveUtils.getResponsiveBorderRadiusValue(context, 20))),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: ResponsiveUtils.getResponsiveSpacing(context, 16),
                right: ResponsiveUtils.getResponsiveSpacing(context, 16),
                top: ResponsiveUtils.getResponsiveSpacing(context, 16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    translate('share_testimony'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 20),
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  CustomInput(
                    controller: contentController,
                    label: translate('your_testimony'),
                    hint: translate('share_what_god_has_done'),
                    maxLines: 5,
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  Row(
                    children: [
                      Checkbox(
                        value: isAnonymous,
                        fillColor: WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return theme.colorScheme.primary;
                          }
                          return theme.colorScheme.surfaceContainerHighest;
                        }),
                        onChanged: (value) {
                          setModalState(() {
                            isAnonymous = value ?? false;
                          });
                        },
                      ),
                      Text(
                        translate('share_anonymously'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 14),
                            ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  CustomButton(
                    text: translate('submit'),
                    onPressed: () async {
                      if (contentController.text.trim().isEmpty) {
                        return;
                      }
                      final rootContext = this.context;
                      Navigator.pop(context);
                      try {
                        await ref
                            .read(testimonyServiceProvider)
                            .createTestimony(
                              content: contentController.text.trim(),
                              isAnonymous: isAnonymous,
                            );
                        if (!rootContext.mounted) return;
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(
                            content: Text(translate('testimony_submitted')),
                          ),
                        );
                        _refreshTestimonies();
                      } catch (e) {
                        if (!rootContext.mounted) return;
                        ScaffoldMessenger.of(rootContext).showSnackBar(
                          SnackBar(content: Text('${translate('error')}: $e')),
                        );
                      }
                    },
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 32)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser == null) {
      return Scaffold(
        appBar: CustomAppBar(
          title: translate('testimonies'),
          showBackButton: true,
        ),
        body: _buildGuestState(context),
      );
    }
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('testimonies'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: translate('all_testimonies')),
            Tab(text: translate('my_testimonies')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTestimonyList(_publicTestimoniesFuture, false),
          _buildTestimonyList(_myTestimoniesFuture, true),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddTestimonyDialog,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: Icon(
          Icons.add,
          size: ResponsiveUtils.getResponsiveIconSize(context, 24),
        ),
      ),
    );
  }

  Widget _buildGuestState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CustomCard(
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.forum_outlined,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 48),
                  color: theme.colorScheme.primary,
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16),
                ),
                Text(
                  'Community testimonies',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8),
                ),
                Text(
                  'Sign in to read approved testimonies and share what God has done.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 18),
                ),
                FilledButton.icon(
                  onPressed: () => context.go('/auth'),
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Sign in'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTestimonyList(
      Future<List<Testimony>> future, bool isMyTestimonies) {
    return RefreshIndicator(
      onRefresh: () async => _refreshTestimonies(),
      child: FutureBuilder<List<Testimony>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget());
          }

          if (snapshot.hasError) {
            return _buildErrorState(context, snapshot.error);
          }

          final testimonies = snapshot.data ?? [];

          if (testimonies.isEmpty) {
            return _buildEmptyState(context, isMyTestimonies);
          }

          return ListView.separated(
            padding: ResponsiveUtils.getResponsivePadding(context),
            itemCount: testimonies.length,
            separatorBuilder: (context, index) => SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            itemBuilder: (context, index) {
              final testimony = testimonies[index];
              return CustomCard(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      Theme.of(context).colorScheme.outlineVariant.withValues(
                            alpha: 0.4,
                          ),
                ),
                child: Padding(
                  padding: ResponsiveUtils.getResponsivePadding(context),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: ResponsiveUtils.getResponsiveValue(
                                context: context,
                                mobile: 20,
                                tablet: 24,
                                desktop: 28),
                            backgroundImage: testimony.userAvatarUrl != null
                                ? NetworkImage(testimony.userAvatarUrl!)
                                : null,
                            child: testimony.userAvatarUrl == null
                                ? Text(
                                    testimony.userName.isNotEmpty
                                        ? testimony.userName[0].toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  )
                                : null,
                          ),
                          SizedBox(
                              width: ResponsiveUtils.getResponsiveSpacing(
                                  context, 12)),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        testimony.userName,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                              fontSize: ResponsiveUtils
                                                  .getResponsiveFontSize(
                                                      context, 16),
                                            ),
                                      ),
                                    ),
                                    if (isMyTestimonies)
                                      _buildStatusBadge(
                                          context, testimony.isApproved),
                                  ],
                                ),
                                Text(
                                  _formatDate(testimony.createdAt),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                        fontSize: ResponsiveUtils
                                            .getResponsiveFontSize(context, 12),
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      SizedBox(
                          height: ResponsiveUtils.getResponsiveSpacing(
                              context, 12)),
                      Text(
                        testimony.content,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface,
                              height: 1.55,
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 14),
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isMyTestimonies) {
    final translate = ref.watch(translationProvider);
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: CustomCard(
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isMyTestimonies ? Icons.edit_note : Icons.forum_outlined,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 48),
                  color: theme.colorScheme.primary,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Text(
                  isMyTestimonies
                      ? translate('no_my_testimonies')
                      : translate('no_testimonies'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Text(
                  isMyTestimonies
                      ? 'Your shared testimonies will appear here after submission.'
                      : 'Approved testimonies from the community will appear here when available.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object? error) {
    final theme = Theme.of(context);
    final friendlyMessage = ErrorHandler.getUserFriendlyMessage(error);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: CustomCard(
          borderRadius: BorderRadius.circular(22),
          child: Padding(
            padding: ResponsiveUtils.getResponsivePadding(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.cloud_off_rounded,
                  size: ResponsiveUtils.getResponsiveIconSize(context, 50),
                  color: theme.colorScheme.error,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Text(
                  'Unable to load testimonies right now',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Text(
                  friendlyMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                OutlinedButton.icon(
                  onPressed: _refreshTestimonies,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(BuildContext context, bool isApproved) {
    final translate = ref.watch(translationProvider);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveSpacing(context, 8),
        vertical: ResponsiveUtils.getResponsiveSpacing(context, 2),
      ),
      decoration: BoxDecoration(
        color: isApproved
            ? Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1)
            : Theme.of(context).colorScheme.secondary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 12)),
        border: Border.all(
          color: isApproved
              ? Theme.of(context).colorScheme.tertiary
              : Theme.of(context).colorScheme.secondary,
          width: 1,
        ),
      ),
      child: Text(
        isApproved ? translate('approved') : translate('pending'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: isApproved
                  ? Theme.of(context).colorScheme.tertiary
                  : Theme.of(context).colorScheme.secondary,
              fontSize: ResponsiveUtils.getResponsiveFontSize(context, 10),
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
