import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/podcast_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../widgets/podcast_search_bar.dart';
import '../../widgets/podcast_card.dart';
import '../../widgets/podcast_episode_card.dart';
import '../../models/podcast_models.dart';
import '../../widgets/custom_image.dart';
import '../../services/sample_content_service.dart';
import '../../widgets/modern_podcast_player_sheet.dart';

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
  final SampleContentService _samples = SampleContentService();

  List<Map<String, dynamic>> get _downloadedEpisodes =>
      _samples.visibleEpisodes
          .map((e) => {
                'id': e['id'],
                'title': e['title'],
                'podcastTitle': e['podcastTitle'],
                'duration': e['duration'],
                'downloadDate': e['downloadDate'],
                'category': e['category'],
              })
          .toList();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _samples.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
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
          if (_currentPlayingEpisode != null) _buildMiniPlayer(),
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

  Widget _buildEmptyPodcastState(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.podcasts_outlined,
              size: 48,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No podcast episodes yet',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'New ALIVE messages will appear here when they are published.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAllShowsTab() {
    return Consumer(
      builder: (context, ref, child) {
        final backendPodcasts = ref.watch(podcastProvider);
        final samplePodcasts = _samples.visibleSamplePodcasts;

        if (backendPodcasts.isEmpty && samplePodcasts.isEmpty) {
          return _buildEmptyPodcastState(context);
        }

        return Builder(
          builder: (context) {
            final filteredSamplePodcasts =
                samplePodcasts.where((podcast) {
              final matchesSearch = _searchQuery.isEmpty ||
                  podcast.title.toLowerCase().contains(_searchQuery) ||
                  podcast.description.toLowerCase().contains(_searchQuery) ||
                  podcast.host.toLowerCase().contains(_searchQuery);

              final matchesCategory = _selectedCategory == 'all' ||
                  podcast.category.name == _selectedCategory;

              return matchesSearch && matchesCategory;
            }).toList();
            final filteredPodcasts = backendPodcasts.where((podcast) {
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

            if (filteredPodcasts.isEmpty &&
                filteredSamplePodcasts.isEmpty) {
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
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.7),
                            fontWeight: FontWeight.bold,
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
              itemCount:
                  filteredSamplePodcasts.length + filteredPodcasts.length,
              itemBuilder: (context, index) {
                if (index < filteredSamplePodcasts.length) {
                  final sample = filteredSamplePodcasts[index];
                  return _SamplePodcastCard(
                    sample: sample,
                    onTap: () => _showSamplePodcastDetails(context, sample),
                  );
                }
                final podcast =
                    filteredPodcasts[index - filteredSamplePodcasts.length];
                return PodcastCard(
                  podcast: podcast,
                  onTap: () => _showPodcastDetails(context, podcast),
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
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        top: true,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 640,
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(top: 12, bottom: 8),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
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
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1),
                        placeholder: Icon(
                          Icons.headset,
                          size: ResponsiveUtils.getResponsiveIconSize(
                              context, 50),
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
                  child: Consumer(
                    builder: (context, ref, child) {
                      final episodesAsync =
                          ref.watch(podcastEpisodesProvider(podcast.id));
                      return episodesAsync.when(
                        data: (episodes) => ListView.builder(
                          padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getResponsiveSpacing(
                                  context, 16)),
                          itemCount: episodes.length,
                          itemBuilder: (context, episodeIndex) {
                            final episodeModel = episodes[episodeIndex];
                            final episode = _episodeToMap(episodeModel);
                            return ListTile(
                              leading: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.play_arrow,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                              title: Text(episodeModel.title),
                              subtitle: Text(
                                  '${episodeModel.duration} • ${episodeModel.publishDate.toIso8601String().split('T').first}'),
                              trailing: Builder(
                                builder: (buttonContext) => IconButton(
                                  icon: const Icon(Icons.more_vert),
                                  onPressed: () {
                                    // Anchor the menu to this button so it opens
                                    // beside it rather than mid-screen.
                                    final box = buttonContext.findRenderObject();
                                    final offset = box is RenderBox
                                        ? box.localToGlobal(Offset.zero) & box.size
                                        : Offset.zero & const Size(40, 40);
                                    _showEpisodeOptions(
                                      context,
                                      episode,
                                      anchor: offset.topLeft,
                                    );
                                  },
                                ),
                              ),
                              onTap: () {
                                _playEpisode(context, episode);
                              },
                            );
                          },
                        ),
                        loading: () =>
                            const Center(child: CircularProgressIndicator()),
                        error: (error, stack) => Center(
                          child: Text('Unable to load episodes: $error'),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  /// Episode actions, as a popup menu anchored to the "more" button.
  ///
  /// This used to be a second showModalBottomSheet opened from inside the
  /// podcast-details sheet. Nesting two modal bottom sheets stacks their
  /// barriers, so the details sheet stayed visible as a second, translucent
  /// layer behind the options -- the same double-modal that affected the kids
  /// mission screen.
  ///
  /// A menu keeps the details sheet open and open to the episode list, so
  /// nothing is lost by acting on an episode, and there is only one overlay.
  void _showEpisodeOptions(
    BuildContext context,
    Map<String, dynamic> episode, {
    Offset? anchor,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    final play = _playEpisode;
    final download = _downloadEpisode;
    final shareLabel = 'Sharing: ${episode['title']}';

    // Without an anchor the menu is centred, which reads as detached from the
    // button. Fall back to the middle of the screen when the caller has no
    // button position to offer.
    final size = MediaQuery.sizeOf(context);
    final rect = anchor == null
        ? Rect.fromLTWH(size.width / 4, size.height / 4, 40, 40)
        : Rect.fromPoints(anchor, anchor + const Offset(0, 40));

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        rect.left,
        rect.top,
        MediaQuery.sizeOf(context).width - rect.right,
        MediaQuery.sizeOf(context).height - rect.bottom,
      ),
      items: const [
        PopupMenuItem(value: 'play', child: Text('Play Episode')),
        PopupMenuItem(value: 'download', child: Text('Download Episode')),
        PopupMenuItem(value: 'share', child: Text('Share Episode')),
      ],
    ).then((choice) {
      if (choice == null || !context.mounted) return;
      switch (choice) {
        case 'play':
          play(context, episode);
        case 'download':
          download(context, episode);
        case 'share':
          messenger.showSnackBar(SnackBar(content: Text(shareLabel)));
      }
    });
  }

  // Audio player instance & active episode
  final AudioPlayer _audioPlayer = AudioPlayer();
  Map<String, dynamic>? _currentPlayingEpisode;

  Widget _buildMiniPlayer() {
    if (_currentPlayingEpisode == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = _currentPlayingEpisode!['title']?.toString() ?? 'Episode';
    final podcastTitle =
        _currentPlayingEpisode!['podcastTitle']?.toString() ?? 'Podcast';
    final coverImage = _currentPlayingEpisode!['coverImage']?.toString();

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () {
          ModernPodcastPlayerSheet.show(
            context,
            audioPlayer: _audioPlayer,
            episodeData: _currentPlayingEpisode!,
            podcastTitle: podcastTitle,
            coverImage: coverImage,
            onDownload: () =>
                _downloadEpisode(context, _currentPlayingEpisode!),
          );
        },
        child: Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF182433)
                : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: 44,
                  height: 44,
                  color: colorScheme.primary.withValues(alpha: 0.15),
                  child: coverImage != null && coverImage.isNotEmpty
                      ? CustomImage(imageUrl: coverImage, fit: BoxFit.cover)
                      : Icon(Icons.podcasts_rounded,
                          color: colorScheme.primary, size: 24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      podcastTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurface.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              StreamBuilder<PlayerState>(
                stream: _audioPlayer.playerStateStream,
                builder: (context, snapshot) {
                  final isPlaying = snapshot.data?.playing ?? false;
                  return IconButton(
                    icon: Icon(isPlaying
                        ? Icons.pause_circle_filled_rounded
                        : Icons.play_circle_fill_rounded),
                    iconSize: 34,
                    color: colorScheme.primary,
                    onPressed: () {
                      if (isPlaying) {
                        _audioPlayer.pause();
                      } else {
                        _audioPlayer.play();
                      }
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _audioPlayer.stop();
                  setState(() {
                    _currentPlayingEpisode = null;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Episode Methods
  Future<void> _playEpisode(
      BuildContext context, Map<String, dynamic> episode) async {
    try {
      final audioUrl = _episodeAudioUrl(episode);
      if (audioUrl.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio available for this episode')),
        );
        return;
      }

      setState(() {
        _currentPlayingEpisode = episode;
      });

      // Play audio
      await _audioPlayer.setUrl(audioUrl);
      await _audioPlayer.play();

      if (!context.mounted) return;

      // Automatically present lively modern player modal with live transcript & seekbar
      ModernPodcastPlayerSheet.show(
        context,
        audioPlayer: _audioPlayer,
        episodeData: episode,
        podcastTitle:
            episode['podcastTitle']?.toString() ?? 'ALIVE Nigeria Podcast',
        coverImage: episode['coverImage']?.toString(),
        onDownload: () => _downloadEpisode(context, episode),
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
                final audioUrl = _episodeAudioUrl(episode);
                if (audioUrl.isEmpty) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('No audio available for this episode')),
                  );
                  return;
                }

                final launched = await launchUrl(
                  Uri.parse(audioUrl),
                  mode: LaunchMode.externalApplication,
                );
                if (!launched) {
                  throw Exception('Unable to open episode audio');
                }

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

  Map<String, dynamic> _episodeToMap(PodcastEpisode episode) {
    return {
      'id': episode.id,
      'title': episode.title,
      'podcastTitle': episode.podcastTitle,
      'duration': episode.duration,
      'audioUrl': episode.audioUrl,
      'downloadDate': '',
      'category': '',
    };
  }

  void _showSamplePodcastDetails(BuildContext context, Podcast sample) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SafeArea(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                  Text(sample.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Hosted by ${sample.host}'),
                  const SizedBox(height: 6),
                  Text(sample.description),
                  const SizedBox(height: 10),
                  const Text(
                      'Sample content. Publish a real podcast with the same title in admin to replace it.'),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _episodeAudioUrl(Map<String, dynamic> episode) {
    return (episode['audioUrl'] ?? episode['audio_url'] ?? '').toString();
  }
}

class _SamplePodcastCard extends StatelessWidget {
  final Podcast sample;
  final VoidCallback onTap;

  const _SamplePodcastCard({required this.sample, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.podcasts_outlined),
        title: Text(sample.title,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${sample.host} · SAMPLE',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
