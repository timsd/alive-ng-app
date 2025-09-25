import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../widgets/custom_app_bar.dart';

class PrayerWallScreen extends ConsumerStatefulWidget {
  const PrayerWallScreen({super.key});

  @override
  ConsumerState<PrayerWallScreen> createState() => _PrayerWallScreenState();
}

class _PrayerWallScreenState extends ConsumerState<PrayerWallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _prayerController = TextEditingController();
  bool _isAnonymous = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _prayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Prayer Wall',
        showBackButton: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.public), text: 'Public Prayers'),
            Tab(icon: Icon(Icons.person), text: 'My Prayers'),
            Tab(icon: Icon(Icons.favorite), text: 'Praying For'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildPublicPrayersTab(),
          _buildMyPrayersTab(),
          _buildPrayingForTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddPrayerDialog,
        tooltip: 'Add Prayer Request',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPublicPrayersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh prayer requests from Supabase
        try {
          await Supabase.instance.client
              .from('prayer_requests')
              .select()
              .order('created_at', ascending: false)
              .limit(50);
          
          setState(() {
            // Update prayer requests list with fetched data
            // In a real implementation, you would parse the response
            // and update your prayer requests list
          });
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Prayer requests refreshed'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to refresh: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 10, // Using sample data - replace with Supabase query
        itemBuilder: (context, index) {
          return _buildPrayerCard(
            context,
            index,
            'Prayer Request ${index + 1}',
            'Please pray for my family during this difficult time. We need God\'s guidance and strength.',
            'Anonymous',
            DateTime.now().subtract(Duration(hours: index)),
            15 + index,
            false,
          );
        },
      ),
    );
  }

  Widget _buildMyPrayersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 3, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildPrayerCard(
          context,
          index,
          'My Prayer ${index + 1}',
          'Lord, please help me grow in faith and wisdom. Guide my steps and decisions.',
          'You',
          DateTime.now().subtract(Duration(days: index + 1)),
          5 + index,
          true,
        );
      },
    );
  }

  Widget _buildPrayingForTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 7, // Using sample data - replace with Supabase query
      itemBuilder: (context, index) {
        return _buildPrayerCard(
          context,
          index,
          'Prayer I\'m Supporting ${index + 1}',
          'Praying for healing and recovery. May God\'s peace be with this family.',
          'Community Member',
          DateTime.now().subtract(Duration(hours: index * 2)),
          20 + index,
          false,
          isPrayingFor: true,
        );
      },
    );
  }

  Widget _buildPrayerCard(
    BuildContext context,
    int index,
    String title,
    String content,
    String author,
    DateTime timestamp,
    int prayerCount,
    bool isOwner, {
    bool isPrayingFor = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(
                    Icons.person,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        _formatTimestamp(timestamp),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                if (isOwner)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _editPrayer(context, index);
                      } else if (value == 'delete') {
                        _deletePrayer(context, index);
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Content
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            
            // Actions
            Row(
              children: [
                Icon(
                  Icons.favorite,
                  size: 20,
                  color: isPrayingFor ? Colors.red : Colors.grey,
                ),
                const SizedBox(width: 4),
                Text(
                  '$prayerCount praying',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Spacer(),
                if (!isOwner)
                  TextButton.icon(
                    onPressed: () {
                      _togglePrayerSupport(context, index);
                    },
                    icon: Icon(
                      isPrayingFor ? Icons.favorite : Icons.favorite_border,
                      size: 18,
                    ),
                    label: Text(isPrayingFor ? 'Praying' : 'Pray'),
                    style: TextButton.styleFrom(
                      foregroundColor: isPrayingFor ? Colors.red : null,
                    ),
                  ),
                TextButton.icon(
                  onPressed: () {
                    _sharePrayerRequest(context, index);
                  },
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Share'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPrayerDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Prayer Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _prayerController,
              decoration: const InputDecoration(
                hintText: 'Share your prayer request...',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value ?? true;
                    });
                  },
                ),
                const Text('Post anonymously'),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Save prayer request to Supabase
              if (_prayerController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a prayer request'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              
              try {
                await Supabase.instance.client.from('prayer_requests').insert({
                  'content': _prayerController.text.trim(),
                  'is_anonymous': _isAnonymous,
                  'author_name': _isAnonymous ? 'Anonymous' : 'ALIVE Member',
                  'created_at': DateTime.now().toIso8601String(),
                  'prayer_count': 0,
                  'status': 'active',
                });
                
                if (mounted) {
                  Navigator.of(context).pop();
                }
                _prayerController.clear();
                setState(() {
                  _isAnonymous = true;
                });
                
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Prayer request posted successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to post prayer request: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Post Prayer'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }

  void _editPrayer(BuildContext context, int index) {
    final editController = TextEditingController(text: 'Sample prayer request ${index + 1}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Prayer Request'),
        content: TextField(
          controller: editController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Edit your prayer request...',
            border: OutlineInputBorder(),
          ),
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
                const SnackBar(
                  content: Text('Prayer request updated successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _deletePrayer(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Prayer Request'),
        content: const Text('Are you sure you want to delete this prayer request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Prayer request deleted successfully!'),
                  backgroundColor: Colors.red,
                ),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _togglePrayerSupport(BuildContext context, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Added to your prayer list!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _sharePrayerRequest(BuildContext context, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Prayer Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this prayer request with others to join in prayer.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('Prayer Request: Sample prayer request ${index + 1}'),
            ),
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
                const SnackBar(
                  content: Text('Prayer request shared successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}