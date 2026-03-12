import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/layout_fix_utils.dart';
import '../../providers/podcast_provider.dart';
import '../../services/firebase_database_service.dart';
import 'package:just_audio/just_audio.dart';
import '../../widgets/podcast_search_bar.dart';
import '../../widgets/podcast_card.dart';
import '../../widgets/podcast_episode_card.dart';
import '../../models/podcast_models.dart';
import '../../widgets/custom_image.dart';

class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';

  final List<Map<String, dynamic>> _downloadedEpisodes = [
    {
      'id': '1',
      'title': 'The Power of Prayer in Daily Life',
      'podcastTitle': 'Daily Devotions with Pastor John',
      'duration': '25 min',
      'downloadDate': '2024-01-15',
      'category': 'devotional',
    },
    {
      'id': '2',
      'title': 'Understanding Bible Prophecy - Part 1',
      'podcastTitle': 'Prophecy Unveiled',
      'duration': '35 min',
      'downloadDate': '2024-01-14',
      'category': 'prophecy',
    },
    {
      'id': '3',
      'title': 'Health Tips for Busy Christians',
      'podcastTitle': 'Health and Wellness',
      'duration': '20 min',
      'downloadDate': '2024-01-13',
      'category': 'health',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Translation provider will be used when implementing localization

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Podcasts',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.headset), text: 'All Shows'),
            Tab(icon: Icon(Icons.favorite), text: 'Subscribed'),
            Tab(icon: Icon(Icons.download), text: 'Downloaded'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          PodcastSearchBar(
            controller: _searchController,
            onChanged: (value) {
              setState(() {
                _searchQuery = value.toLowerCase();
              });
            },
          ),

          // Category Filter
          Container(
            padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildCategoryChip('all', 'All'),
                  _buildCategoryChip('mec', 'MEC'),
                  _buildCategoryChip('retreat', 'Retreat'),
                  _buildCategoryChip('devotional', 'Devotional'),
                  _buildCategoryChip('bibleStudy', 'Bible Study'),
                  _buildCategoryChip('youth', 'Youth'),
                  _buildCategoryChip('health', 'Health'),
                  _buildCategoryChip('missions', 'Missions'),
                  _buildCategoryChip('sabbathSchool', 'Sabbath School'),
                  _buildCategoryChip('christianLiving', 'Christian Living'),
                  _buildCategoryChip('prophecy', 'Prophecy'),
                ],
              ),
            ),
          ),

          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllShowsTab(),
                _buildSubscribedTab(),
                _buildDownloadedTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 8.0),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedCategory = category;
          });
        },
        backgroundColor: Theme.of(context).colorScheme.surface,
        selectedColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        checkmarkColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredDownloadedEpisodes() {
    return _downloadedEpisodes.where((episode) {
      final matchesSearch = _searchQuery.isEmpty ||
          episode['title'].toString().toLowerCase().contains(_searchQuery) ||
          episode['podcastTitle']
              .toString()
              .toLowerCase()
              .contains(_searchQuery);

      final matchesCategory = _selectedCategory == 'all' ||
          episode['category'] == _selectedCategory;

      return matchesSearch && matchesCategory;
    }).toList();
  }

  Widget _buildAllShowsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final podcasts = ref.watch(podcastProvider);

        if (podcasts.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        return Builder(
          builder: (context) {
            final filteredPodcasts = podcasts.where((podcast) {
              final matchesSearch = _searchQuery.isEmpty ||
                  podcast.title.toLowerCase().contains(_searchQuery) ||
                  podcast.description.toLowerCase().contains(_searchQuery) ||
                  podcast.host.toLowerCase().contains(_searchQuery) ||
                  podcast.tags
                      .any((tag) => tag.toLowerCase().contains(_searchQuery));

              final matchesCategory = _selectedCategory == 'all' ||
                  podcast.category.name == _selectedCategory;

              return matchesSearch && matchesCategory;
            }).toList();

            if (filteredPodcasts.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_off,
                      size: 64,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No podcasts found',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Try adjusting your search or filters',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.5),
                          ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding:
                  ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
              itemCount: filteredPodcasts.length,
              itemBuilder: (context, index) {
                return PodcastCard(
                  podcast: filteredPodcasts[index],
                  onTap: () =>
                      _showPodcastDetails(context, filteredPodcasts[index]),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildSubscribedTab() {
    return Consumer(
      builder: (context, ref, child) {
        final podcasts = ref.watch(podcastProvider);
        final filteredSubscribed = podcasts.where((podcast) {
          final matchesSearch = _searchQuery.isEmpty ||
              podcast.title.toLowerCase().contains(_searchQuery) ||
              podcast.description.toLowerCase().contains(_searchQuery) ||
              podcast.host.toLowerCase().contains(_searchQuery) ||
              podcast.tags
                  .any((tag) => tag.toLowerCase().contains(_searchQuery));
          final matchesCategory = _selectedCategory == 'all' ||
              podcast.category.name == _selectedCategory;
          return matchesSearch &&
              matchesCategory &&
              podcast.isSubscribed == true;
        }).toList();

        if (filteredSubscribed.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.favorite_border,
                  size: 64,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No subscribed podcasts found',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Subscribe to podcasts to see them here',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.5),
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: ResponsiveUtils.getResponsivePadding(context),
          itemCount: filteredSubscribed.length,
          itemBuilder: (context, index) {
            return PodcastCard(
              podcast: filteredSubscribed[index],
              onTap: () =>
                  _showPodcastDetails(context, filteredSubscribed[index]),
            );
          },
        );
      },
    );
  }

  Widget _buildDownloadedTab() {
    final filteredEpisodes = _getFilteredDownloadedEpisodes();

    if (filteredEpisodes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.download_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No downloaded episodes found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Download episodes to listen offline',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                  ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePadding(context),
      itemCount: filteredEpisodes.length,
      itemBuilder: (context, index) {
        return PodcastEpisodeCard(
          title: filteredEpisodes[index]['title'],
          podcastTitle: filteredEpisodes[index]['podcastTitle'],
          duration: filteredEpisodes[index]['duration'],
          onPlay: () => _playEpisode(context, filteredEpisodes[index]),
          onDownload: () => _downloadEpisode(context, filteredEpisodes[index]),
          onShare: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Sharing: ${filteredEpisodes[index]['title']}')),
            );
          },
        );
      },
    );
  }

  void _showPodcastDetails(BuildContext context, Podcast podcast) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(
                ResponsiveUtils.getResponsiveSpacing(context, 20))),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return LayoutFixUtils.fixBottomOverflow(
            padding: EdgeInsets.zero,
            maxHeight: MediaQuery.of(context).size.height * 0.9,
            child: Column(
              children: [
                // Handle
                Container(
                  width: ResponsiveUtils.getResponsiveValue<double>(
                    context: context,
                    mobile: 40,
                    tablet: 40 * 1.2,
                    desktop: 40 * 1.4,
                  ),
                  height: ResponsiveUtils.getResponsiveSpacing(context, 4),
                  margin: EdgeInsets.symmetric(
                      vertical:
                          ResponsiveUtils.getResponsiveSpacing(context, 8)),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(
                        ResponsiveUtils.getResponsiveSpacing(context, 2)),
                  ),
                ),

                // Podcast Header
                Padding(
                  padding:
                      ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
                  child: Row(
                    children: [
                      CustomImage(
                        imageUrl: podcast.coverImage,
                        width: ResponsiveUtils.getResponsiveValue<double>(
                          context: context,
                          mobile: 100,
                          tablet: 100 * 1.2,
                          desktop: 100 * 1.4,
                        ),
                        height: ResponsiveUtils.getResponsiveValue<double>(
                          context: context,
                          mobile: 100,
                          tablet: 100 * 1.2,
                          desktop: 100 * 1.4,
                        ),
                        borderRadius: BorderRadius.circular(
                            ResponsiveUtils.getResponsiveSpacing(context, 12)),
                        backgroundColor: Theme.of(context)
                            .primaryColor
                            .withValues(alpha: 0.1),
                        placeholder: Icon(
                          Icons.headset,
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 50),
                          color: Theme.of(context).primaryColor,
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
                              podcast.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                            context, 18),
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                    context, 4)),
                            Text(
                              'by ${podcast.host}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                            context, 12),
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.7),
                                  ),
                            ),
                            SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                    context, 8)),
                            Text(
                              podcast.description,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    fontSize:
                                        ResponsiveUtils.getResponsiveFontSize(
                                            context, 14),
                                  ),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Episodes List
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: EdgeInsets.symmetric(
                        horizontal:
                            ResponsiveUtils.getResponsiveSpacing(context, 16)),
                    itemCount: podcast.episodes,
                    itemBuilder: (context, episodeIndex) {
                      // Sample episode data for the podcast
                      final sampleEpisode = {
                        'id': '${podcast.id}_episode_$episodeIndex',
                        'title':
                            'Episode ${episodeIndex + 1}: Sample Episode Title',
                        'podcastTitle': podcast.title,
                        'duration': '${20 + (episodeIndex % 10) * 3} min',
                        'downloadDate': '',
                        'category': podcast.category.name,
                      };
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .primaryColor
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.play_arrow,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        title: Text(sampleEpisode['title']!),
                        subtitle: Text(
                            '${sampleEpisode['duration']} • ${DateTime.now().subtract(Duration(days: episodeIndex)).toString().split(' ')[0]}'),
                        trailing: IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {
                            _showEpisodeOptions(context, sampleEpisode);
                          },
                        ),
                        onTap: () {
                          _playEpisode(context, sampleEpisode);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEpisodeOptions(BuildContext context, Map<String, dynamic> episode) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('Play Episode'),
            onTap: () {
              Navigator.pop(context);
              _playEpisode(context, episode);
            },
          ),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download Episode'),
            onTap: () {
              Navigator.pop(context);
              _downloadEpisode(context, episode);
            },
          ),
          ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Episode'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Sharing: ${episode['title']}')),
              );
            },
          ),
        ],
      ),
    );
  }

  // Audio player instance
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Episode Methods
  Future<void> _playEpisode(
      BuildContext context, Map<String, dynamic> episode) async {
    try {
      // Get the episode audio URL from Firebase
      final episodeId = episode['id'];
      // Derive podcastId from episodeId if needed elsewhere

      // Fetch the actual episode data from Firebase
      final firebaseService = FirebaseDatabaseService.instance;
      final episodeData =
          await firebaseService.getDocument('podcast_episodes', episodeId);
      if (!context.mounted) return;

      if (episodeData == null ||
          episodeData['audioUrl'] == null ||
          episodeData['audioUrl'].isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio available for this episode')),
        );
        return;
      }

      final audioUrl = episodeData['audioUrl'];

      // Show loading indicator
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loading audio...')),
      );

      // Play the audio
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      // Show now playing notification
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Playing: ${episode['title']}'),
          action: SnackBarAction(
            label: 'Pause',
            onPressed: () {
              _audioPlayer.pause();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Episode paused')),
              );
            },
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing episode: $e')),
      );
    }
  }

  Future<void> _downloadEpisode(
      BuildContext context, Map<String, dynamic> episode) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Episode'),
        content: Text('Download "${episode['title']}" for offline listening?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();

              // Show downloading notification
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Downloading: ${episode['title']}'),
                  duration: const Duration(seconds: 2),
                ),
              );

              try {
                // Get the episode audio URL from Firebase
                final episodeId = episode['id'];
                final firebaseService = FirebaseDatabaseService.instance;
                final episodeData = await firebaseService.getDocument(
                    'podcast_episodes', episodeId);
                if (!context.mounted) return;

                if (episodeData == null ||
                    episodeData['audioUrl'] == null ||
                    episodeData['audioUrl'].isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No audio available for this episode')),
                  );
                  return;
                }

                final audioUrl = episodeData['audioUrl'];

                // Download the file
                final audioData = await firebaseService.downloadFile(
                  Uri.parse(audioUrl).pathSegments.last,
                );
                if (!context.mounted) return;

                if (audioData == null) {
                  throw Exception('Failed to download audio file');
                }

                // Update episode in Firebase to mark as downloaded
                // In a real app, you would save the file to local storage here
                // and update the localPath field

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Downloaded: ${episode['title']}'),
                    action: SnackBarAction(
                      label: 'Play',
                      onPressed: () {
                        _playEpisode(context, episode);
                      },
                    ),
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error downloading episode: $e')),
                );
              }
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}
