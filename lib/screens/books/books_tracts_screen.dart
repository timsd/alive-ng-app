import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../models/tract_models.dart';
import '../../services/tract_service.dart';
import '../../services/firebase_storage_service.dart';
import '../../services/donation_service.dart';
import '../../models/donation_models.dart';
import '../../screens/materials/donation_dialog.dart';
import 'tract_reader_screen.dart';

class BooksTractsScreen extends ConsumerStatefulWidget {
  const BooksTractsScreen({super.key});

  @override
  ConsumerState<BooksTractsScreen> createState() => _BooksTractsScreenState();
}

class _BooksTractsScreenState extends ConsumerState<BooksTractsScreen>
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
    _tabController = TabController(length: 3, vsync: this);
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
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Books & Tracts',
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
          tabs: const [
            Tab(icon: Icon(Icons.book), text: 'Books'),
            Tab(icon: Icon(Icons.article), text: 'Tracts'),
            Tab(icon: Icon(Icons.download), text: 'Downloaded'),
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
                    hintText: 'Search books and tracts...',
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
                SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
                DropdownButtonFormField<String>(
                  initialValue: _selectedCategory,
                  decoration: InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0),
                      vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Categories')),
                    DropdownMenuItem(value: 'Doctrine', child: Text('Doctrine')),
                    DropdownMenuItem(value: 'Prophecy', child: Text('Prophecy')),
                    DropdownMenuItem(value: 'Health', child: Text('Health')),
                    DropdownMenuItem(value: 'Youth', child: Text('Youth')),
                    DropdownMenuItem(value: 'Family', child: Text('Family')),
                    DropdownMenuItem(value: 'Evangelism', child: Text('Evangelism')),
                    DropdownMenuItem(value: 'Sabbath', child: Text('Sabbath')),
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
                _buildBooksTab(),
                _buildTractsTab(),
                _buildDownloadedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBooksTab() {
    if (_viewMode == 'grid') {
      return GridView.builder(
        padding: context.responsivePadding,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.7,
          crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
          mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
        ),
        itemCount: 20, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildBookGridItem(context, index, true);
        },
      );
    } else {
      return ListView.builder(
        padding: context.responsivePadding,
        itemCount: 20, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildBookListItem(context, index, true);
        },
      );
    }
  }

  Widget _buildTractsTab() {
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
          final matchesCategory = _selectedCategory == 'All' || t.category.tractDisplayName == _selectedCategory;
          return matchesSearch && matchesCategory;
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.search_off, size: 64),
                SizedBox(height: 12),
                Text('No tracts found'),
              ],
            ),
          );
        }

        if (_viewMode == 'grid') {
          return GridView.builder(
            padding: context.responsivePadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
              mainAxisSpacing: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 16.0, desktop: 20.0),
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

  Widget _buildDownloadedTab() {
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
                Icon(Icons.download_done, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No downloads yet',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
                ),
                const SizedBox(height: 8),
                Text(
                  'Materials you download will appear here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
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

  Widget _buildTractGridItem(BuildContext context, Tract tract) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openTractReader(context, tract);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tract Cover
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.article,
                      size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0)),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0),
                        vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
                      ),
                      child: Text(
                        'TRACT',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 9.0, tablet: 10.0, desktop: 11.0),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Tract Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tract.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0)),
                    Text(
                      tract.author ?? '',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
                              size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${tract.pages ?? 0}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.picture_as_pdf, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18.0, tablet: 20.0, desktop: 22.0)),
                              onPressed: () {
                                _viewOriginalPDF(tract);
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip: 'View PDF',
                            ),
                            IconButton(
                              icon: Icon(Icons.download, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18.0, tablet: 20.0, desktop: 22.0)),
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
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50.0, tablet: 56.0, desktop: 62.0),
          height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50.0, tablet: 56.0, desktop: 62.0),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article,
                color: Theme.of(context).primaryColor,
                size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'TRACT',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
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
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0)),
            Text(
              tract.description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
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
              icon: Icon(Icons.picture_as_pdf, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0)),
              onPressed: () {
                _viewOriginalPDF(tract);
              },
              tooltip: 'View PDF',
            ),
            IconButton(
              icon: Icon(Icons.download, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0)),
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TractReaderScreen(tract: tract),
      ),
    );
  }

  void _viewOriginalPDF(Tract tract) async {
    try {
      final donationService = DonationService();
      DownloadableMaterial? material;
      try {
        material = await donationService.getMaterialById(tract.id);
      } catch (_) {
        material = null;
      }

      if (material != null) {
        final canDownload = await donationService.canUserDownloadMaterial(material.id);
        if (!canDownload && material.requiresDonation) {
          if (!mounted) return;
          final donated = await showDialog<bool>(
            context: context,
            builder: (context) => DonationDialog(
              material: material!,
              donationType: DonationType.tractReprint,
            ),
          );
          if (donated != true) return;
        }

        final downloadUrl = await donationService.generateDownloadUrl(material.id);
        if (await canLaunchUrl(Uri.parse(downloadUrl))) {
          await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
        } else {
          throw 'Could not launch PDF viewer';
        }
        return;
      }

      // Fallback to direct Storage URL if material is not registered
      final String? pdfUrl = await FirebaseStorageService().getTractDownloadURL('${tract.id}.pdf');
      if (pdfUrl != null && await canLaunchUrl(Uri.parse(pdfUrl))) {
        await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch PDF viewer';
      }
    } catch (e) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Error'),
          content: Text('Error opening PDF: $e'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  void _downloadTract(Tract tract) async {
    try {
      final donationService = DonationService();
      DownloadableMaterial? material;
      try {
        material = await donationService.getMaterialById(tract.id);
      } catch (_) {
        material = null;
      }

      if (material != null) {
        final canDownload = await donationService.canUserDownloadMaterial(material.id);
        if (!canDownload && material.requiresDonation) {
          if (!mounted) return;
          final donated = await showDialog<bool>(
            context: context,
            builder: (context) => DonationDialog(
              material: material!,
              donationType: DonationType.tractReprint,
            ),
          );
          if (donated != true) return;
        }

        final downloadUrl = await donationService.generateDownloadUrl(material.id);
        if (await canLaunchUrl(Uri.parse(downloadUrl))) {
          // Register the download so it appears in the "Downloaded" tab
          await donationService.recordDownload(material.id);
          
          await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Downloading ${tract.title}...'),
                backgroundColor: Colors.green,
              ),
            );
            // Refresh downloads tab
            setState(() {
              _downloadsFuture = donationService.getUserDownloads();
            });
          }
        } else {
          throw 'Could not launch downloaded tract';
        }
        return;
      }

      // Fallback: direct Storage URL
      final String? pdfUrl = await FirebaseStorageService().getTractDownloadURL('${tract.id}.pdf');
      if (pdfUrl != null && await canLaunchUrl(Uri.parse(pdfUrl))) {
        await launchUrl(Uri.parse(pdfUrl), mode: LaunchMode.externalApplication);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ${tract.title}...'),
              backgroundColor: Colors.green,
            ),
          );
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

  Widget _buildBookGridItem(BuildContext context, int index, bool isBook) {
    final bookTitles = [
      'Steps to Christ',
      'The Great Controversy',
      'Desire of Ages',
      'Patriarchs and Prophets',
      'Acts of the Apostles',
      'Prophets and Kings',
      'The Ministry of Healing',
      'Education',
      'Christ\'s Object Lessons',
      'Thoughts from the Mount of Blessing',
      'Early Writings',
      'Gospel Workers',
      'Counsels to Parents, Teachers, and Students',
      'The Adventist Home',
      'Testimonies for the Church Vol. 1',
      'Christian Service',
      'Evangelism',
      'Medical Ministry',
      'Colporteur Ministry',
      'Country Living',
    ];

    final tractTitles = [
      'The Sabbath Truth',
      'What Happens When You Die?',
      'The Second Coming of Christ',
      'Health and Temperance',
      'Bible Prophecy Made Simple',
      'The State of the Dead',
      'The Millennium',
      'The Sanctuary',
      'The Law of God',
      'Baptism by Immersion',
      'The Gift of Prophecy',
      'Tithing and Offerings',
      'Christian Standards',
      'The Three Angels\' Messages',
      'Daniel\'s Prophecies',
    ];

    final authors = [
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Ellen G. White',
      'Various Authors',
      'Various Authors',
      'Church Ministry',
      'Bible Study Guide',
      'Prophecy Study',
    ];

    final titles = isBook ? bookTitles : tractTitles;
    final title = titles[index % titles.length];
    final author = authors[index % authors.length];

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          _openReader(context, title, isBook);
        },
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isBook ? Icons.menu_book : Icons.article,
                      size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 36.0, tablet: 40.0, desktop: 44.0),
                      color: Theme.of(context).primaryColor,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0)),
                    if (!isBook)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0),
                          vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
                        ),
                        child: Text(
                          'TRACT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: ResponsiveUtils.getResponsiveValue(context: context, mobile: 9.0, tablet: 10.0, desktop: 11.0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Book Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0)),
                    Text(
                      author,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(
                          Icons.star,
                          size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                          color: Colors.amber,
                        ),
                        Text(
                          '4.${7 + index % 3}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        IconButton(
                          icon: Icon(Icons.download, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 18.0, tablet: 20.0, desktop: 22.0)),
                          onPressed: () {
                            _downloadItem('Sample Book ${index + 1}', 'Book');
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
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

  Widget _buildBookListItem(BuildContext context, int index, bool isBook) {
    final bookTitles = [
      'Steps to Christ',
      'The Great Controversy',
      'Desire of Ages',
      'Patriarchs and Prophets',
      'Acts of the Apostles',
    ];

    // Removed unused descriptions list

    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50.0, tablet: 56.0, desktop: 62.0),
          height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50.0, tablet: 56.0, desktop: 62.0),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isBook ? Icons.menu_book : Icons.article,
                color: Colors.green,
                size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
              ),
              Icon(
                Icons.download_done,
                size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                color: Colors.green,
              ),
            ],
          ),
        ),
        title: Text(
          bookTitles[index % bookTitles.length],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isBook ? 'Book • Downloaded' : 'Tract • Downloaded',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0)),
            Text(
              'Downloaded on ${DateTime.now().subtract(Duration(days: index + 1)).day}/${DateTime.now().month}/${DateTime.now().year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0)),
              onPressed: () {
                _downloadItem(bookTitles[index % bookTitles.length], isBook ? 'Book' : 'Tract');
              },
            ),
          ],
        ),
        onTap: () {
          _openReader(context, bookTitles[index % bookTitles.length], isBook);
        },
      ),
    );
  }

  Widget _buildRealDownloadedItem(BuildContext context, UserDownload download) {
    return Card(
      margin: EdgeInsets.only(bottom: ResponsiveUtils.getResponsiveValue(context: context, mobile: 10.0, tablet: 12.0, desktop: 14.0)),
      child: ListTile(
        leading: Container(
          width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50.0, tablet: 56.0, desktop: 62.0),
          height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 50.0, tablet: 56.0, desktop: 62.0),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 6.0, tablet: 8.0, desktop: 10.0)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.article,
                color: Colors.green,
                size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0),
              ),
              Icon(
                Icons.download_done,
                size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 14.0, tablet: 16.0, desktop: 18.0),
                color: Colors.green,
              ),
            ],
          ),
        ),
        title: Text(
          download.materialTitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Downloaded',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.green,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 3.0, tablet: 4.0, desktop: 5.0)),
            Text(
              'On ${download.downloadedAt.day}/${download.downloadedAt.month}/${download.downloadedAt.year}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(Icons.download, size: ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 24.0, desktop: 28.0)),
              onPressed: () {
                _redownloadMaterial(download);
              },
              tooltip: 'Download PDF',
            ),
          ],
        ),
        onTap: () {
          _redownloadMaterial(download);
        },
      ),
    );
  }

  void _redownloadMaterial(UserDownload download) async {
    try {
      final downloadUrl = await DonationService().generateDownloadUrl(download.materialId);
      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl), mode: LaunchMode.externalApplication);
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

  void _openReader(BuildContext context, String title, bool isBook) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Open ${isBook ? 'Book' : 'Tract'}'),
        content: Text(
          'Opening "$title" in the reader. This will provide a full reading experience with bookmarks, notes, and highlighting.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _navigateToReader(context, title);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Opening "$title" in reader...'),
                ),
              );
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
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

  void _downloadItem(String title, String type) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Download $type'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Do you want to download "$title"?'),
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
            const SizedBox(height: 8),
            const Text('Preparing download...'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('"$title" downloaded successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }

  // Navigation Methods
  void _navigateToReader(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Open Reader'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Opening "$title" in the digital reader...'),
            const SizedBox(height: 16),
            const Text('Features available:'),
            const SizedBox(height: 8),
            const Text('• Adjustable font size'),
            const Text('• Night mode'),
            const Text('• Bookmarks'),
            const Text('• Search functionality'),
            const Text('• Offline reading'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Reader opened for: $title'),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening reader settings...')),
                      );
                    },
                  ),
                ),
              );
            },
            child: const Text('Open Reader'),
          ),
        ],
      ),
    );
  }
}



