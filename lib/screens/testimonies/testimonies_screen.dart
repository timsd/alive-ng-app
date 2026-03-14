import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/testimony_model.dart';
import '../../providers/testimony_provider.dart';
import '../../providers/language_provider.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_card.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_input.dart';

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
    final testimonyService = ref.read(testimonyServiceProvider);
    _publicTestimoniesFuture = testimonyService.fetchTestimonies();
    _myTestimoniesFuture = testimonyService.fetchMyTestimonies();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _refreshTestimonies() {
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
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
        child: Icon(
          Icons.add,
          size: ResponsiveUtils.getResponsiveIconSize(context, 24),
        ),
      ),
    );
  }

  Widget _buildTestimonyList(
      Future<List<Testimony>> future, bool isMyTestimonies) {
    final translate = ref.watch(translationProvider);
    return RefreshIndicator(
      onRefresh: () async => _refreshTestimonies(),
      child: FutureBuilder<List<Testimony>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: LoadingWidget());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                '${translate('error')}: ${snapshot.error}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 14)),
              ),
            );
          }

          final testimonies = snapshot.data ?? [];

          if (testimonies.isEmpty) {
            return Center(
              child: Text(
                isMyTestimonies
                    ? translate('no_my_testimonies')
                    : translate('no_testimonies'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize:
                        ResponsiveUtils.getResponsiveFontSize(context, 16)),
              ),
            );
          }

          return ListView.separated(
            padding: ResponsiveUtils.getResponsivePadding(context),
            itemCount: testimonies.length,
            separatorBuilder: (context, index) => SizedBox(
                height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
            itemBuilder: (context, index) {
              final testimony = testimonies[index];
              return CustomCard(
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
                                ? Text(testimony.userName.isNotEmpty
                                    ? testimony.userName[0].toUpperCase()
                                    : '?',
                                    style: TextStyle(color: Theme.of(context).colorScheme.primary))
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
          color: isApproved ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.secondary,
          width: 1,
        ),
      ),
      child: Text(
        isApproved ? translate('approved') : translate('pending'),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: isApproved ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.secondary,
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
