import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/responsive_utils.dart';
import '../../providers/podcast_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../services/podcast_audio_service.dart';
import '../../widgets/podcast_search_bar.dart';
import '../../widgets/podcast_card.dart';
import '../../widgets/podcast_episode_card.dart';
import '../../models/podcast_models.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/modern_podcast_player_sheet.dart';
import '../../utils/podcast_share_helper.dart';

class PodcastsScreen extends ConsumerStatefulWidget {
  final String? initialEpisodeId;
  final String? initialPodcastId;

  const PodcastsScreen({
    super.key,
    this.initialEpisodeId,
    this.initialPodcastId,
  });

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedCategory = 'all';
  final List<Map<String, dynamic>> _downloadedEpisodes = const [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _audioService.addListener(_onAudioUpdate);
  }

  void _onAudioUpdate() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _audioService.removeListener(_onAudioUpdate);
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
          if (_audioService.hasActiveEpisode) _buildMiniPlayer(),
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

        if (backendPodcasts.isEmpty) {
          return _buildEmptyPodcastState(context);
        }

        return Builder(
          builder: (context) {
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
              itemCount: filteredPodcasts.length,
              itemBuilder: (context, index) {
                final podcast = filteredPodcasts[index];
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
            PodcastShareHelper.shareEpisode(
              context,
              episode: filteredEpisodes[index],
            );
          },
        );
      },
    );
  }

  void _showPodcastDetails(BuildContext context, Podcast podcast) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        top: true,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  decoration: BoxDecoration(
                    color: colorScheme.onSurface.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(2),
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
                            final episode = _episodeToMap(episodeModel, podcast: podcast);
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
                                _playEpisode(context, episode, coverImage: podcast.coverImage);
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
    final play = _playEpisode;
    final download = _downloadEpisode;

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
          PodcastShareHelper.shareEpisode(context, episode: episode);
      }
    });
  }

  // Persistent audio service instance
  final PodcastAudioService _audioService = PodcastAudioService();

  Widget _buildMiniPlayer() {
    if (!_audioService.hasActiveEpisode) return const SizedBox.shrink();
    final activeEpisode = _audioService.currentEpisode!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final title = activeEpisode['title']?.toString() ?? 'Episode';
    final podcastTitle = _audioService.currentPodcastTitle ??
        activeEpisode['podcastTitle']?.toString() ??
        'Podcast';
    final coverImage = _audioService.currentCoverImage ??
        activeEpisode['coverImage']?.toString();

    return SafeArea(
      top: false,
      child: GestureDetector(
        onTap: () {
          ModernPodcastPlayerSheet.show(
            context,
            audioPlayer: _audioService.player,
            episodeData: activeEpisode,
            podcastTitle: podcastTitle,
            coverImage: coverImage,
            onDownload: () => _downloadEpisode(context, activeEpisode),
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
                stream: _audioService.player.playerStateStream,
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
                        _audioService.pause();
                      } else {
                        _audioService.resume();
                      }
                    },
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _audioService.stop();
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
      BuildContext context, Map<String, dynamic> episode, {String? coverImage}) async {
    try {
      final audioUrl = _episodeAudioUrl(episode);
      if (audioUrl.isEmpty) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No audio available for this episode')),
        );
        return;
      }

      final resolvedCover = coverImage ??
          episode['coverImage']?.toString() ??
          episode['cover_image']?.toString();

      await _audioService.playOrResumeEpisode(
        episode: episode,
        audioUrl: audioUrl,
        podcastTitle:
            episode['podcastTitle']?.toString() ?? 'ALIVE Nigeria Podcast',
        coverImage: resolvedCover,
      );

      if (!context.mounted) return;

      // Automatically present lively modern player modal with live transcript & seekbar
      ModernPodcastPlayerSheet.show(
        context,
        audioPlayer: _audioService.player,
        episodeData: episode,
        podcastTitle:
            episode['podcastTitle']?.toString() ?? 'ALIVE Nigeria Podcast',
        coverImage: resolvedCover,
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

  Map<String, dynamic> _episodeToMap(PodcastEpisode episode, {Podcast? podcast}) {
    return {
      'id': episode.id,
      'title': episode.title,
      'podcastTitle': episode.podcastTitle.isNotEmpty
          ? episode.podcastTitle
          : (podcast?.title ?? ''),
      'description': episode.description,
      'duration': episode.duration,
      'audioUrl': episode.audioUrl,
      'transcript': episode.transcript,
      'notes': episode.notes,
      'downloadDate': '',
      'category': podcast?.categoryDisplayName ?? '',
      'coverImage': podcast?.coverImage ?? '',
      'cover_image': podcast?.coverImage ?? '',
    };
  }

  String _episodeAudioUrl(Map<String, dynamic> episode) {
    return (episode['audioUrl'] ?? episode['audio_url'] ?? '').toString();
  }
}
