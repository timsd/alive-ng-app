import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../providers/language_provider.dart';
import '../../config/resources_config.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final List<Resource> _resources = [
    Resource(
      id: '1',
      title: 'Bible Study Guides',
      description:
          'Comprehensive guides for personal and group Bible study sessions.',
      category: 'Study Materials',
      type: ResourceType.pdf,
      downloadUrl: '${ResourcesConfig.baseUrl}/bible-study-guides.pdf',
      imageUrl:
          'https://via.placeholder.com/150x200/4CAF50/FFFFFF?text=Bible+Study',
      downloads: 1250,
    ),
    Resource(
      id: '2',
      title: 'Prayer Journal Template',
      description:
          'A structured template to help organize your daily prayers and reflections.',
      category: 'Prayer Resources',
      type: ResourceType.pdf,
      downloadUrl: '${ResourcesConfig.baseUrl}/prayer-journal-template.pdf',
      imageUrl:
          'https://via.placeholder.com/150x200/2196F3/FFFFFF?text=Prayer+Journal',
      downloads: 890,
    ),
    Resource(
      id: '3',
      title: 'Health & Wellness Guide',
      description:
          'Biblical principles for maintaining physical and spiritual health.',
      category: 'Health',
      type: ResourceType.pdf,
      downloadUrl: '${ResourcesConfig.baseUrl}/health-and-wellness-guide.pdf',
      imageUrl:
          'https://via.placeholder.com/150x200/FF9800/FFFFFF?text=Health+Guide',
      downloads: 675,
    ),
    Resource(
      id: '4',
      title: 'Worship Songs Collection',
      description:
          'A collection of contemporary and traditional worship songs with lyrics.',
      category: 'Music',
      type: ResourceType.audio,
      downloadUrl: '${ResourcesConfig.baseUrl}/worship-songs-collection.zip',
      imageUrl:
          'https://via.placeholder.com/150x200/9C27B0/FFFFFF?text=Worship+Songs',
      downloads: 2100,
    ),
    Resource(
      id: '5',
      title: 'Evangelism Training Video',
      description:
          'Step-by-step video training for effective evangelism and witnessing.',
      category: 'Training',
      type: ResourceType.video,
      downloadUrl: '${ResourcesConfig.baseUrl}/evangelism-training-video.mp4',
      imageUrl:
          'https://via.placeholder.com/150x200/F44336/FFFFFF?text=Evangelism+Video',
      downloads: 1450,
    ),
  ];

  String _selectedCategory = 'All';
  final List<String> _categories = [
    'All',
    'Study Materials',
    'Prayer Resources',
    'Health',
    'Music',
    'Training'
  ];

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(languageProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('resources'),
        showBackButton: true,
        showThemeToggle: true,
        showLanguageToggle: true,
      ),
      body: LayoutFixUtils.safeColumn(
        padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        )),
        children: [
          _buildHeader(context, translate),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),
          _buildCategoryFilter(context),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 20)),
          _buildResourcesGrid(context),
        ],
      ),
      floatingActionButton: _buildDonationButton(context),
    );
  }

  Widget _buildHeader(BuildContext context, String Function(String) translate) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
        context: context,
        mobile: 20.0,
        tablet: 24.0,
        desktop: 28.0,
      )),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primaryContainer,
            theme.colorScheme.surface,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            translate('resources_title'),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 24.0,
                tablet: 28.0,
                desktop: 32.0,
              ),
            ),
          ),
          SizedBox(height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
          Text(
            translate('resources_subtitle'),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 16.0,
                tablet: 18.0,
                desktop: 20.0,
              ),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    return SizedBox(
      height: ResponsiveUtils.getResponsiveSpacing(context, 40),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;

          return Container(
            margin: EdgeInsets.only(
                right: ResponsiveUtils.getResponsiveSpacing(context, 8)),
            child: FilterChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedCategory = category;
                });
              },
              backgroundColor: Theme.of(context).colorScheme.surface,
              side: BorderSide(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
              selectedColor:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              checkmarkColor: Theme.of(context).colorScheme.primary,
            ),
          );
        },
      ),
    );
  }

  Widget _buildResourcesGrid(BuildContext context) {
    final filteredResources = _selectedCategory == 'All'
        ? _resources
        : _resources.where((r) => r.category == _selectedCategory).toList();

    final crossAxisCount = ResponsiveUtils.getResponsiveGridColumns(context);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 0.75,
          tablet: 0.8,
          desktop: 0.85,
        ),
        crossAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context, 16),
        mainAxisSpacing: ResponsiveUtils.getResponsiveSpacing(context, 16),
      ),
      itemCount: filteredResources.length,
      itemBuilder: (context, index) {
        return _buildResourceCard(context, filteredResources[index]);
      },
    );
  }

  Widget _buildResourceCard(BuildContext context, Resource resource) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 18)),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showResourceDetails(context, resource),
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(
                        ResponsiveUtils.getResponsiveBorderRadiusValue(
                            context, 18)),
                  ),
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
                ),
                child: Stack(
                  children: [
                    Center(
                      child: Icon(
                        _getResourceTypeIcon(resource.type),
                        size:
                            ResponsiveUtils.getResponsiveIconSize(context, 48),
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal:
                              ResponsiveUtils.getResponsiveSpacing(context, 6),
                          vertical:
                              ResponsiveUtils.getResponsiveSpacing(context, 2),
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadiusValue(
                                  context, 8)),
                        ),
                        child: Text(
                          resource.type.name.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color:
                                    Theme.of(context).colorScheme.onSecondary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                  context: context,
                  mobile: 12.0,
                  tablet: 14.0,
                  desktop: 16.0,
                )),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      resource.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 14),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 4)),
                    Text(
                      resource.description,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 12),
                          ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Icons.download,
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 14),
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                        SizedBox(
                            width: ResponsiveUtils.getResponsiveSpacing(
                                context, 4)),
                        Text(
                          '${resource.downloads}',
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonationButton(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        // Navigate to donation page
        context.go('/donation');
      },
      icon: const Text('🤍'),
      label: const Text('Support ALIVE'),
      backgroundColor: Theme.of(context).colorScheme.primary,
      foregroundColor: Theme.of(context).colorScheme.onPrimary,
    );
  }

  IconData _getResourceTypeIcon(ResourceType type) {
    switch (type) {
      case ResourceType.pdf:
        return Icons.picture_as_pdf;
      case ResourceType.audio:
        return Icons.audiotrack;
      case ResourceType.video:
        return Icons.play_circle_filled;
      case ResourceType.image:
        return Icons.image;
      case ResourceType.document:
        return Icons.description;
    }
  }

  void _showResourceDetails(BuildContext context, Resource resource) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _buildResourceDetailsSheet(context, resource),
    );
  }

  Widget _buildResourceDetailsSheet(BuildContext context, Resource resource) {
    final translate = ref.watch(languageProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
              ResponsiveUtils.getResponsiveBorderRadiusValue(context, 24)),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: ResponsiveUtils.getResponsiveSpacing(context, 40),
            height: ResponsiveUtils.getResponsiveSpacing(context, 4),
            margin: EdgeInsets.symmetric(
                vertical: ResponsiveUtils.getResponsiveSpacing(context, 12)),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadiusValue(context, 2)),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 20.0,
                tablet: 24.0,
                desktop: 28.0,
              )),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width:
                            ResponsiveUtils.getResponsiveSpacing(context, 60),
                        height:
                            ResponsiveUtils.getResponsiveSpacing(context, 60),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primary
                              .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadiusValue(
                                  context, 12)),
                        ),
                        child: Icon(
                          _getResourceTypeIcon(resource.type),
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 32),
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      SizedBox(
                          width: ResponsiveUtils.getResponsiveSpacing(
                              context, 16)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                            context, 20),
                                  ),
                            ),
                            SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                    context, 4)),
                            Text(
                              resource.category,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                            context, 14),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 24)),
                  Text(
                    translate('description'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 18),
                        ),
                  ),
                  SizedBox(
                      height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  Text(
                    resource.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: ResponsiveUtils.getResponsiveFontSize(
                              context, 16),
                          height: 1.5,
                        ),
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 24)),
                  Row(
                    children: [
                      Icon(
                        Icons.download,
                        size:
                            ResponsiveUtils.getResponsiveIconSize(context, 20),
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                      SizedBox(
                          width:
                              ResponsiveUtils.getResponsiveSpacing(context, 8)),
                      Text(
                        '${resource.downloads} ${translate('downloads')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 14),
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                    ],
                  ),
                  SizedBox(
                      height:
                          ResponsiveUtils.getResponsiveSpacing(context, 32)),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);
                        final tertiary = Theme.of(context).colorScheme.tertiary;
                        final errorColor = Theme.of(context).colorScheme.error;
                        try {
                          // Launch the download URL
                          final Uri downloadUri =
                              Uri.parse(resource.downloadUrl);
                          if (await canLaunchUrl(downloadUri)) {
                            await launchUrl(downloadUri,
                                mode: LaunchMode.externalApplication);

                            navigator.pop();
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                    '${translate('downloading')} ${resource.title}...'),
                                backgroundColor: tertiary,
                              ),
                            );
                          } else {
                            throw Exception('Could not launch download URL');
                          }
                        } catch (e) {
                          navigator.pop();
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Download failed: $e'),
                              backgroundColor: errorColor,
                            ),
                          );
                        }
                      },
                      icon: Icon(
                        Icons.download,
                        size:
                            ResponsiveUtils.getResponsiveIconSize(context, 20),
                      ),
                      label: Text(
                        translate('download'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: Theme.of(context).colorScheme.onPrimary,
                            ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical:
                              ResponsiveUtils.getResponsiveSpacing(context, 16),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                              ResponsiveUtils.getResponsiveBorderRadiusValue(
                                  context, 12)),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum ResourceType {
  pdf,
  audio,
  video,
  image,
  document,
}

class Resource {
  final String id;
  final String title;
  final String description;
  final String category;
  final ResourceType type;
  final String downloadUrl;
  final String imageUrl;
  final int downloads;

  Resource({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.type,
    required this.downloadUrl,
    required this.imageUrl,
    required this.downloads,
  });
}
