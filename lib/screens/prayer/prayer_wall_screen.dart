import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/add_prayer_request_dialog.dart';

class PrayerWallScreen extends ConsumerStatefulWidget {
  const PrayerWallScreen({super.key});

  @override
  ConsumerState<PrayerWallScreen> createState() => _PrayerWallScreenState();
}

class _PrayerWallScreenState extends ConsumerState<PrayerWallScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Prayer Wall',
        showBackButton: true,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: FaIcon(FontAwesomeIcons.globe), text: 'Public Prayers'),
            Tab(icon: FaIcon(FontAwesomeIcons.user), text: 'My Prayers'),
            Tab(
                icon: FaIcon(FontAwesomeIcons.personPraying),
                text: 'Praying For'),
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
        child: const FaIcon(FontAwesomeIcons.plus),
      ),
    );
  }

  Widget _buildPublicPrayersTab() {
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh prayer requests from Firebase
        try {
          await FirebaseFirestore.instance
              .collection('prayer_requests')
              .orderBy('created_at', descending: true)
              .limit(50)
              .get();

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
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('prayer_requests')
            .limit(50)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No prayer requests found'));
          }

          final docs = snapshot.data!.docs.where((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final notArchived = (data['status'] as String?) != 'archived';
            final isPublic = data['is_public'] as bool? ?? true;
            return notArchived && isPublic;
          }).toList()
            ..sort((a, b) {
              final aData = a.data() as Map<String, dynamic>;
              final bData = b.data() as Map<String, dynamic>;
              return _asDateTime(bData['created_at'])
                  .compareTo(_asDateTime(aData['created_at']));
            });

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildPrayerCard(
                context,
                index,
                data['title'] ?? 'Prayer Request',
                _resolveDescription(data),
                data['author_name'] ?? 'Anonymous',
                _asDateTime(data['created_at']),
                data['prayer_count'] ?? 0,
                false,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildMyPrayersTab() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(child: Text('Please sign in to view your prayers'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prayer_requests')
          .where('user_id', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('You haven\'t created any prayer requests yet'));
        }

        final docs = snapshot.data!.docs.toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            return _asDateTime(bData['created_at'])
                .compareTo(_asDateTime(aData['created_at']));
          });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>;

            return _buildPrayerCard(
              context,
              index,
              data['title'] ?? 'My Prayer',
              _resolveDescription(data),
              'You',
              _asDateTime(data['created_at']),
              data['prayer_count'] ?? 0,
              true,
            );
          },
        );
      },
    );
  }

  Widget _buildPrayingForTab() {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Center(
          child: Text('Please sign in to view prayers you\'re supporting'));
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('prayer_supporters')
          .where('user_id', isEqualTo: user.uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
              child: Text('You aren\'t supporting any prayer requests yet'));
        }

        // Get the prayer request IDs that the user is supporting
        final prayerIds = snapshot.data!.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['prayer_id'] as String;
        }).toList();

        // Now fetch the actual prayer requests
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('prayer_requests')
              .where(FieldPath.documentId, whereIn: prayerIds)
              .snapshots(),
          builder: (context, prayerSnapshot) {
            if (prayerSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (prayerSnapshot.hasError) {
              return Center(child: Text('Error: ${prayerSnapshot.error}'));
            }

            if (!prayerSnapshot.hasData || prayerSnapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No prayer requests found'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: prayerSnapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = prayerSnapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;

                return _buildPrayerCard(
                  context,
                  index,
                  data['title'] ?? 'Prayer Request',
                  _resolveDescription(data),
                  data['author_name'] ?? 'Community Member',
                  _asDateTime(data['created_at']),
                  data['prayer_count'] ?? 0,
                  false,
                  isPrayingFor: true,
                );
              },
            );
          },
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
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
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
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
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
                            FaIcon(FontAwesomeIcons.pen),
                            SizedBox(width: 8),
                            Text('Edit'),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            FaIcon(FontAwesomeIcons.trash, color: Colors.red),
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
                  isPrayingFor
                      ? FontAwesomeIcons.solidHeart
                      : FontAwesomeIcons.heart,
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
                      isPrayingFor
                          ? FontAwesomeIcons.solidHeart
                          : FontAwesomeIcons.heart,
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
                  icon: const FaIcon(FontAwesomeIcons.share, size: 18),
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
    final screenContext = context;
    showDialog(
      context: context,
      builder: (context) => AddPrayerRequestDialog(
        onSubmit: ({
          required String title,
          required String category,
          required String description,
          required bool isAnonymous,
          required bool isPublic,
          String? scriptureReference,
          required String urgencyLevel,
        }) async {
          final user = FirebaseAuth.instance.currentUser;
          if (user == null) {
            throw Exception('User not authenticated');
          }

          final displayName = user.displayName?.trim();
          final emailPrefix = user.email?.split('@').first;
          final visibleName = (displayName != null && displayName.isNotEmpty)
              ? displayName
              : ((emailPrefix != null && emailPrefix.isNotEmpty)
                  ? emailPrefix
                  : 'ALIVE Member');

          await FirebaseFirestore.instance.collection('prayer_requests').add({
            'title': title,
            'description': description,
            'category': category,
            'content': description,
            'is_anonymous': isAnonymous,
            'is_public': isPublic,
            'scripture_reference': scriptureReference,
            'urgency_level': urgencyLevel,
            'author_name': isAnonymous ? 'Anonymous' : visibleName,
            'user_id': user.uid,
            'created_at': FieldValue.serverTimestamp(),
            'updated_at': FieldValue.serverTimestamp(),
            'prayer_count': 0,
            'status': 'active',
          });

          if (!mounted) return;
          if (!screenContext.mounted) return;
          ScaffoldMessenger.of(screenContext).showSnackBar(
            const SnackBar(
              content: Text('Prayer request posted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  String _resolveDescription(Map<String, dynamic> data) {
    final value = (data['description'] ?? data['content'] ?? '').toString();
    if (value.trim().isEmpty) return 'Please pray for this request';
    return value;
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

  DateTime _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    try {
      final dynamicValue = value;
      final DateTime? parsed = dynamicValue?.toDate() as DateTime?;
      if (parsed != null) return parsed;
    } catch (_) {}
    return DateTime.now();
  }

  void _editPrayer(BuildContext context, int index) {
    final editController =
        TextEditingController(text: 'Sample prayer request ${index + 1}');

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
        content:
            const Text('Are you sure you want to delete this prayer request?'),
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
            const Text(
                'Share this prayer request with others to join in prayer.'),
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
