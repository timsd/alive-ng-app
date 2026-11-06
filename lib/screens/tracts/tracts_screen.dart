import '../../widgets/in_app_pdf_viewer.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_image.dart';
import '../../utils/responsive_utils.dart';
import '../../models/tract_models.dart';
import '../../services/tract_service.dart';
import '../../services/appwrite_storage_compat_service.dart';
import '../../services/donation_service.dart';
import '../../models/donation_models.dart';
import '../../screens/materials/donation_dialog.dart';
import '../../providers/language_provider.dart';

class TractsScreen extends ConsumerStatefulWidget {
  const TractsScreen({super.key});

  @override
  ConsumerState<TractsScreen> createState() => _TractsScreenState();
}

class _TractsScreenState extends ConsumerState<TractsScreen>

    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  String _viewMode = 'grid'; // 'grid' or 'list'
  late Future<List<Tract>> _tractsFuture;
  late Future<List<UserDownload>> _downloadsFuture;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tractsFuture = TractService().getAllTracts();
    _downloadsFuture = DonationService().getUserDownloads();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(languageProvider);
    return Scaffold(
      appBar: CustomAppBar(
        title: translate('tracts'),
        showBackButton: true,
        actions: [
          IconButton(
            icon: Icon(_viewMode == 'grid' ? Icons.view_list : Icons.grid_view),
            onPressed: () {
              setState(() {
                _viewMode = _viewMode == 'grid' ? 'list' : 'grid';
              });
            },
            tooltip: 'Toggle View',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: const Icon(Icons.article), text: translate('tracts')),
            Tab(
                icon: const Icon(Icons.download),
                text: translate('downloaded')),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search and Filter Bar
          Container(
            padding: context.responsivePadding,
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: translate('search_tracts'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: context.responsiveBorderRadius,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {
                      // Search functionality can be implemented here if needed
                    });
                  },
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 12.0,
                        tablet: 14.0,
                        desktop: 16.0)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 8.0,
                              tablet: 10.0,
                              desktop: 12.0)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 12.0,
                          tablet: 14.0,
                          desktop: 16.0),
                      vertical: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0),
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                        value: 'All', child: Text(translate('all_categories'))),
                    DropdownMenuItem(
                        value: 'Doctrine',
                        child: Text(translate('category_doctrine'))),
                    DropdownMenuItem(
                        value: 'Prophecy',
                        child: Text(translate('category_prophecy'))),
                    DropdownMenuItem(
                        value: 'Health',
                        child: Text(translate('category_health'))),
                    DropdownMenuItem(
                        value: 'Youth',
                        child: Text(translate('category_youth'))),
                    DropdownMenuItem(
                        value: 'Family',
                        child: Text(translate('category_family'))),
                    DropdownMenuItem(
                        value: 'Evangelism',
                        child: Text(translate('category_evangelism'))),
                    DropdownMenuItem(
                        value: 'Sabbath',
                        child: Text(translate('category_sabbath'))),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value!;
                    });
                    _applyCategoryFilter(value!);
                  },
                ),
              ],
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTractsTab(translate),
                _buildDownloadedTab(translate),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTractsTab(String Function(String) translate) {
    return FutureBuilder<List<Tract>>(
      future: _tractsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load tracts'));
        }
        final allTracts = (snapshot.data ?? []);
        final query = _searchController.text.toLowerCase();
        final filtered = allTracts.where((t) {
          final matchesSearch = query.isEmpty ||
              t.title.toLowerCase().contains(query) ||
              t.description.toLowerCase().contains(query);
          final matchesCategory = _selectedCategory == 'All' ||
              t.category.tractDisplayName == _selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();

        if (filtered.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 64),
                const SizedBox(height: 12),
                Text(translate('no_tracts_found')),
              ],
            ),
          );
        }

        if (_viewMode == 'grid') {
          return GridView.builder(
            padding: context.responsivePadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 2,
                tablet: 3,
                desktop: 4,
              ),
              childAspectRatio: ResponsiveUtils.getResponsiveValue(
                context: context,
                mobile: 0.58,
                tablet: 0.64,
                desktop: 0.70,
              ),
              crossAxisSpacing: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
              mainAxisSpacing: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 14.0, tablet: 18.0, desktop: 20.0),
            ),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _buildTractGridItem(context, filtered[index]);
            },
          );
        } else {
          return ListView.builder(
            padding: context.responsivePadding,
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              return _buildTractListItem(context, filtered[index]);
            },
          );
        }
      },
    );
  }

  Widget _buildDownloadedTab(String Function(String) translate) {
    return FutureBuilder<List<UserDownload>>(
      future: _downloadsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Failed to load downloads'));
        }

        final downloads = snapshot.data ?? [];
        if (downloads.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.download_done,
                    size: 64,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: 16),
                Text(
                  translate('no_downloads_yet'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 8),
                Text(
                  translate('materials_download_message'),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5)),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _downloadsFuture = DonationService().getUserDownloads();
            });
          },
          child: ListView.builder(
            padding: context.responsivePadding,
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              return _buildRealDownloadedItem(context, downloads[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildRealDownloadedItem(BuildContext context, UserDownload download) {
    return Card(
      margin: EdgeInsets.only(
        bottom: ResponsiveUtils.getResponsiveValue(
            context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.article_rounded, color: Colors.green, size: 24),
          ),
        ),
        title: Text(
          download.materialTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          'Downloaded on ${download.downloadedAt.day}/${download.downloadedAt.month}/${download.downloadedAt.year}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download_rounded),
          tooltip: 'Re-download',
          onPressed: () => _redownloadMaterial(download),
        ),
        onTap: () => _redownloadMaterial(download),
      ),
    );
  }

  Widget _buildTractCoverWidget(BuildContext context, Tract tract) {
    String coverUrl = '';
    if (tract.coverImage != null && tract.coverImage!.trim().isNotEmpty) {
      coverUrl = tract.coverImage!.trim();
    } else if (tract.imageUrl != null && tract.imageUrl!.trim().isNotEmpty) {
      coverUrl = tract.imageUrl!.trim();
    } else if (tract.coverImages.isNotEmpty && tract.coverImages.first.trim().isNotEmpty) {
      coverUrl = tract.coverImages.first.trim();
    } else if (tract.id.contains('lesson_1') ||
        tract.id.contains('bible_says_1') ||
        tract.title.toLowerCase().contains('something we can trust')) {
      coverUrl = 'assets/images/series/what_the_bible_says_lesson_1.jpg';
    }

    if (coverUrl.isNotEmpty) {
      if (coverUrl.startsWith('assets/')) {
        return Image.asset(
          coverUrl,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        );
      }
      return CustomImage(
        imageUrl: coverUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    }

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.12),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_rounded,
              size: ResponsiveUtils.getResponsiveValue(
                  context: context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'TRACT',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTractGridItem(BuildContext context, Tract tract) {
    return Card(
      elevation: 2,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openTractReader(context, tract);
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tract Cover (Top of card)
            Expanded(
              flex: 12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildTractCoverWidget(context, tract),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'TRACT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Tract Info (Bottom of card)
            Expanded(
              flex: 9,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title in full without clipping
                    Text(
                      tract.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.5,
                            height: 1.22,
                          ),
                      maxLines: 3,
                      softWrap: true,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tract.author ?? 'Alive by the Truth',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.pages,
                              size: 14,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${tract.pages ?? 6}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontSize: 11),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              onPressed: () {
                                _viewOriginalPDF(tract);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'View PDF',
                            ),
                            const SizedBox(width: 10),
                            IconButton(
                              icon: const Icon(Icons.download, size: 18),
                              onPressed: () {
                                _downloadTract(tract);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'Download',
                            ),
                          ],
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

  Widget _buildTractListItem(BuildContext context, Tract tract) {
    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
      child: ListTile(
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 48,
            height: 60,
            child: _buildTractCoverWidget(context, tract),
          ),
        ),
        title: Text(
          tract.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tract.author} • ${tract.pages} pages',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0)),
            Text(
              tract.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.picture_as_pdf,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 20.0,
                      tablet: 24.0,
                      desktop: 28.0)),
              onPressed: () {
                _viewOriginalPDF(tract);
              },
              tooltip: 'View PDF',
            ),
            IconButton(
              icon: Icon(Icons.download,
                  size: ResponsiveUtils.getResponsiveValue(
                      context: context,
                      mobile: 20.0,
                      tablet: 24.0,
                      desktop: 28.0)),
              onPressed: () {
                _downloadTract(tract);
              },
              tooltip: 'Download',
            ),
          ],
        ),
        onTap: () {
          _openTractReader(context, tract);
        },
      ),
    );
  }

  // Tract interaction methods
  void _openTractReader(BuildContext context, Tract tract) {
    // Open in-app PDF preview directly for uploaded tracts
    _viewOriginalPDF(tract);
  }

  Future<String?> _resolveTractPdfUrl(Tract tract) async {
    final existingUrl = tract.downloadUrl?.trim();
    if (existingUrl != null && existingUrl.isNotEmpty) return existingUrl;
    return AppwriteStorageCompatService().getTractDownloadURL('${tract.id}.pdf');
  }

  /// Opens the tract PDF directly in the in-app viewer without requiring
  /// a donation. The PDF icon is for previewing/reading only.
  void _viewOriginalPDF(Tract tract) async {
    try {
      // Resolve the PDF URL directly - no donation check needed for viewing
      String? downloadUrl = await _resolveTractPdfUrl(tract);

      // Fallback: try to get URL from donation service if storage lookup fails
      if (downloadUrl == null || downloadUrl.isEmpty) {
        try {
          downloadUrl =
              await DonationService().generateDownloadUrl(tract.id);
        } catch (_) {
          downloadUrl = null;
        }
      }

      if (downloadUrl != null && downloadUrl.isNotEmpty) {
        if (!mounted) return;
        if (kIsWeb) {
          final uri = Uri.tryParse(downloadUrl);
          if (uri != null) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
            return;
          }
        }
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => InAppPdfViewerScreen(
              title: tract.title,
              pdfUrl: downloadUrl!,
            ),
          ),
        );
      } else {
        throw 'Could not locate PDF document';
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error opening PDF: $e'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK')),
          ],
        ),
      );
    }
  }

  /// Resolves the tract cover image URL for passing to the DonationDialog.
  String? _resolveTractCoverImage(Tract tract) {
    if (tract.coverImage != null && tract.coverImage!.trim().isNotEmpty) {
      return tract.coverImage!.trim();
    } else if (tract.imageUrl != null && tract.imageUrl!.trim().isNotEmpty) {
      return tract.imageUrl!.trim();
    } else if (tract.coverImages.isNotEmpty && tract.coverImages.first.trim().isNotEmpty) {
      return tract.coverImages.first.trim();
    } else if (tract.id.contains('lesson_1') ||
        tract.id.contains('bible_says_1') ||
        tract.title.toLowerCase().contains('something we can trust')) {
      return 'assets/images/series/what_the_bible_says_lesson_1.jpg';
    }
    return null;
  }

  /// Downloads a tract after prompting for a donation (if required).
  /// The download icon triggers the donation dialog with the tract cover image
  /// and currency toggle. After successful payment, the tract is downloaded
  /// and recorded in the user's downloads list.
  void _downloadTract(Tract tract) async {
    try {
      final donationService = DonationService();
      DownloadableMaterial? fetched;
      try {
        fetched = await donationService.getMaterialById(tract.id);
      } catch (_) {
        fetched = null;
      }

      // Build the material with thumbnailUrl from the tract cover image
      final tractCoverUrl = _resolveTractCoverImage(tract);
      final material = fetched?.copyWith(thumbnailUrl: tractCoverUrl) ??
          DownloadableMaterial(
            id: tract.id,
            title: tract.title,
            description: tract.description,
            category: 'tracts',
            thumbnailUrl: tractCoverUrl,
            fileSizeBytes: 0,
            fileType: 'pdf',
            downloadCount: 0,
            fileUrl: await _resolveTractPdfUrl(tract) ?? '',
            minimumDonation: DonationConstants.tractDonationByRegion['NG'] ??
                DonationConstants.minimumTractDonation,
            requiresDonation: true,
            isActive: true,
            createdAt: tract.createdAt ?? DateTime.now(),
            updatedAt: tract.updatedAt ?? DateTime.now(),
          );

      bool canDownload = false;
      try {
        canDownload = await donationService.canUserDownloadMaterial(material.id);
      } catch (_) {
        canDownload = false;
      }
      if (!canDownload && material.requiresDonation) {
        if (!mounted) return;
        final donated = await showDialog<bool>(
          context: context,
          builder: (context) => DonationDialog(
            material: material,
            donationType: DonationType.tractProduction,
          ),
        );
        if (donated != true) return;
      }

      String? downloadUrl;
      try {
        downloadUrl = await donationService.generateDownloadUrl(material.id);
      } catch (_) {
        downloadUrl = null;
      }
      downloadUrl ??= await _resolveTractPdfUrl(tract);

      if (downloadUrl != null && await canLaunchUrl(Uri.parse(downloadUrl))) {
        await donationService.recordDownload(material.id);
        await launchUrl(Uri.parse(downloadUrl),
            mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ${tract.title}...'),
              backgroundColor: Theme.of(context).colorScheme.tertiary,
            ),
          );
          setState(() {
            _downloadsFuture = donationService.getUserDownloads();
          });
        }
      } else {
        throw 'Could not launch downloaded tract';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to download tract: $e')),
      );
    }
  }

  void _redownloadMaterial(UserDownload download) async {
    try {
      final downloadUrl =
          await DonationService().generateDownloadUrl(download.materialId);
      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch downloaded content';
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to re-download: $e')),
      );
    }
  }

  void _applyCategoryFilter(String category) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Filtering by category: $category'),
        duration: const Duration(seconds: 2),
      ),
    );
    // In a real app, this would filter the displayed items
  }

  }
