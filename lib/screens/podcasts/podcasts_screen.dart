import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/custom_app_bar.dart';
import '../../utils/mobile_utils.dart';

class PodcastsScreen extends ConsumerStatefulWidget {
  const PodcastsScreen({super.key});

  @override
  ConsumerState<PodcastsScreen> createState() => _PodcastsScreenState();
}

class _PodcastsScreenState extends ConsumerState<PodcastsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

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
          tabs: [
            const Tab(icon: Icon(Icons.headset), text: 'All Shows'),
            const Tab(icon: Icon(Icons.favorite), text: 'Subscribed'),
            const Tab(icon: Icon(Icons.download), text: 'Downloaded'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: MobileUtils.getResponsivePadding(context, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search podcasts...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 12)),
                ),
              ),
              onChanged: (value) {
                // Search functionality will be implemented later
              },
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

  Widget _buildAllShowsTab() {
    return ListView.builder(
      padding: MobileUtils.getResponsivePadding(context, 16),
      itemCount: 10, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildPodcastCard(context, index, false);
      },
    );
  }

  Widget _buildSubscribedTab() {
    return ListView.builder(
      padding: MobileUtils.getResponsivePadding(context, 16),
      itemCount: 5, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildPodcastCard(context, index, true);
      },
    );
  }

  Widget _buildDownloadedTab() {
    return ListView.builder(
      padding: MobileUtils.getResponsivePadding(context, 16),
      itemCount: 3, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildEpisodeCard(context, index, true);
      },
    );
  }

  Widget _buildPodcastCard(BuildContext context, int index, bool isSubscribed) {
    final podcastTitles = [
      'Daily Devotions with Pastor John',
      'Bible Study Deep Dive',
      'Youth Ministry Talks',
      'Health and Wellness',
      'Mission Stories from Around the World',
      'Sabbath School Lessons',
      'Christian Living Today',
      'Prophecy Unveiled',
      'Family Worship Time',
      'Adventist Heritage',
    ];

    final descriptions = [
      'Daily inspirational messages and Bible reflections',
      'In-depth study of Bible books and themes',
      'Engaging content for young people',
      'Tips for healthy Christian living',
      'Stories from missionaries worldwide',
      'Weekly Sabbath School lesson discussions',
      'Practical advice for modern Christians',
      'Understanding Bible prophecy',
      'Resources for family devotions',
      'History and heritage of the Adventist church',
    ];

    return Card(
      margin: EdgeInsets.only(bottom: MobileUtils.getResponsiveSpacing(context, 16)),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 12)),
      ),
      child: InkWell(
        onTap: () {
          _showPodcastDetails(context, index);
        },
        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 12)),
        child: Padding(
          padding: MobileUtils.getResponsivePadding(context, 16),
          child: Row(
            children: [
              // Podcast Cover
              Container(
                width: MobileUtils.getResponsiveWidth(context, 80),
                height: MobileUtils.getResponsiveWidth(context, 80),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 26 / 255.0),
                  borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 8)),
                ),
                child: Icon(
                  Icons.headset,
                  size: MobileUtils.getResponsiveIconSize(context, 40),
                  color: Theme.of(context).primaryColor,
                ),
              ),
              SizedBox(width: MobileUtils.getResponsiveSpacing(context, 16)),
              
              // Podcast Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      podcastTitles[index % podcastTitles.length],
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: MobileUtils.getResponsiveFontSize(context, 16),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 4)),
                    Text(
                      descriptions[index % descriptions.length],
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: MobileUtils.getResponsiveFontSize(context, 14),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: MobileUtils.getResponsiveIconSize(context, 16),
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: MobileUtils.getResponsiveSpacing(context, 4)),
                        Text(
                          '${20 + index * 5} episodes',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: MobileUtils.getResponsiveFontSize(context, 12),
                          ),
                        ),
                        SizedBox(width: MobileUtils.getResponsiveSpacing(context, 16)),
                        Icon(
                          Icons.star,
                          size: MobileUtils.getResponsiveIconSize(context, 16),
                          color: Colors.amber,
                        ),
                        SizedBox(width: MobileUtils.getResponsiveSpacing(context, 4)),
                        Text(
                          '4.${7 + index % 3}',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: MobileUtils.getResponsiveFontSize(context, 12),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Subscribe Button
              Column(
                children: [
                  IconButton(
                    onPressed: () {
                      _toggleSubscription(context, index);
                    },
                    icon: Icon(
                      isSubscribed ? Icons.notifications : Icons.notifications_none,
                      color: isSubscribed ? Theme.of(context).primaryColor : null,
                      size: MobileUtils.getResponsiveIconSize(context, 24),
                    ),
                  ),
                  Text(
                    isSubscribed ? 'Subscribed' : 'Subscribe',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: MobileUtils.getResponsiveFontSize(context, 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEpisodeCard(BuildContext context, int index, bool isDownloaded) {
    final episodeTitles = [
      'The Power of Prayer in Daily Life',
      'Understanding Bible Prophecy - Part 1',
      'Health Tips for Busy Christians',
      'Youth Leadership in the Church',
      'Mission Stories from Africa',
    ];

    return Card(
      margin: EdgeInsets.only(bottom: MobileUtils.getResponsiveSpacing(context, 12)),
      child: ListTile(
        leading: Container(
          width: MobileUtils.getResponsiveWidth(context, 56),
          height: MobileUtils.getResponsiveWidth(context, 56),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 26 / 255.0),
            borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 8)),
          ),
          child: Icon(
            Icons.headphones,
            color: Theme.of(context).primaryColor,
            size: MobileUtils.getResponsiveIconSize(context, 24),
          ),
        ),
        title: Text(
          episodeTitles[index % episodeTitles.length],
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: MobileUtils.getResponsiveFontSize(context, 14)),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Daily Devotions • ${25 + index * 5} min',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: MobileUtils.getResponsiveFontSize(context, 12)),
            ),
            SizedBox(height: MobileUtils.getResponsiveSpacing(context, 4)),
            if (isDownloaded)
              Row(
                children: [
                  Icon(
                    Icons.download_done,
                    size: MobileUtils.getResponsiveIconSize(context, 16),
                    color: Colors.green,
                  ),
                  SizedBox(width: MobileUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    'Downloaded',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.green,
                      fontSize: MobileUtils.getResponsiveFontSize(context, 10),
                    ),
                  ),
                ],
              ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                Icons.play_arrow,
                size: MobileUtils.getResponsiveIconSize(context, 24),
              ),
              onPressed: () {
                _playEpisode(context, episodeTitles[index % episodeTitles.length]);
              },
            ),
            if (!isDownloaded)
              IconButton(
                icon: Icon(
                  Icons.download,
                  size: MobileUtils.getResponsiveIconSize(context, 24),
                ),
                onPressed: () {
                  _downloadEpisode(context, episodeTitles[index % episodeTitles.length]);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showPodcastDetails(BuildContext context, int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(MobileUtils.getResponsiveSpacing(context, 20))),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              // Handle
              Container(
                width: MobileUtils.getResponsiveWidth(context, 40),
                height: MobileUtils.getResponsiveSpacing(context, 4),
                margin: EdgeInsets.symmetric(vertical: MobileUtils.getResponsiveSpacing(context, 8)),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 2)),
                ),
              ),
              
              // Podcast Header
              Padding(
                padding: MobileUtils.getResponsivePadding(context, 16),
                child: Row(
                  children: [
                    Container(
                      width: MobileUtils.getResponsiveWidth(context, 100),
                      height: MobileUtils.getResponsiveWidth(context, 100),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withValues(alpha: 26 / 255.0),
                        borderRadius: BorderRadius.circular(MobileUtils.getResponsiveSpacing(context, 12)),
                      ),
                      child: Icon(
                        Icons.headset,
                        size: MobileUtils.getResponsiveIconSize(context, 50),
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(width: MobileUtils.getResponsiveSpacing(context, 16)),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Daily Devotions with Pastor John',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: MobileUtils.getResponsiveFontSize(context, 18),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: MobileUtils.getResponsiveSpacing(context, 8)),
                          Text(
                            'Daily inspirational messages and Bible reflections to strengthen your faith journey.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontSize: MobileUtils.getResponsiveFontSize(context, 14),
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
                  padding: EdgeInsets.symmetric(horizontal: MobileUtils.getResponsiveSpacing(context, 16)),
                  itemCount: 15,
                  itemBuilder: (context, episodeIndex) {
                    return _buildEpisodeCard(context, episodeIndex, false);
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Subscription Methods
  void _toggleSubscription(BuildContext context, int podcastIndex) {
    final podcastTitles = [
      'Daily Devotions',
      'Bible Study Hour',
      'Youth Corner',
      'Health & Wellness',
      'Mission Stories',
    ];
    
    final podcastTitle = podcastTitles[podcastIndex % podcastTitles.length];
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription'),
        content: Text('Toggle subscription for "$podcastTitle"?'),
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
                  content: Text('Subscription toggled for $podcastTitle'),
                ),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  // Episode Methods
  void _playEpisode(BuildContext context, String episodeTitle) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Playing: $episodeTitle'),
        action: SnackBarAction(
          label: 'Pause',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Episode paused')),
            );
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _downloadEpisode(BuildContext context, String episodeTitle) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Download Episode'),
        content: Text('Download "$episodeTitle" for offline listening?'),
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
                  content: Text('Downloading: $episodeTitle'),
                  action: SnackBarAction(
                    label: 'View',
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Opening downloads...')),
                      );
                    },
                  ),
                ),
              );
            },
            child: const Text('Download'),
          ),
        ],
      ),
    );
  }
}



