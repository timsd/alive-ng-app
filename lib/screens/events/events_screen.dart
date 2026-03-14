import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../providers/language_provider.dart';
import '../../services/role_access_service.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/error_widget.dart' as custom_error;
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_app_bar.dart';

class EventsScreen extends ConsumerStatefulWidget {
  const EventsScreen({super.key});

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  List<Map<String, dynamic>> _events = [];
  List<Map<String, dynamic>> _announcements = [];
  bool _isLoading = true;
  String? _error;
  String _selectedTab = 'events';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load events
      final eventsSnapshot = await FirebaseFirestore.instance
          .collection('events')
          .orderBy('created_at', descending: true)
          .get();
          
      final eventsResponse = eventsSnapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();

      // Load announcements
      final announcementsSnapshot = await FirebaseFirestore.instance
          .collection('announcements')
          .orderBy('created_at', descending: true)
          .get();
          
      final announcementsResponse = announcementsSnapshot.docs.map((doc) => {
        ...doc.data(),
        'id': doc.id,
      }).toList();

      setState(() {
        _events = List<Map<String, dynamic>>.from(eventsResponse);
        _announcements = List<Map<String, dynamic>>.from(announcementsResponse);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('events_announcements'),
        showBackButton: true,
      ),
      floatingActionButton: RoleAccessService.instance.canCreateEvents() 
          ? FloatingActionButton(
              onPressed: () => _showCreateContentDialog(context, translate),
              tooltip: translate('create_content'),
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          // Tab selector
          Container(
            margin: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: context.responsiveBorderRadius,
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    context,
                    'events',
                    translate('events'),
                    Icons.event,
                  ),
                ),
                Expanded(
                  child: _buildTabButton(
                    context,
                    'announcements',
                    translate('announcements'),
                    Icons.campaign,
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _error != null
                    ? custom_error.AppErrorWidget(
                        message: _error!,
                        onAction: _loadData,
                      )
                    : _selectedTab == 'events'
                        ? _buildEventsList(context, translate)
                        : _buildAnnouncementsList(context, translate),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(
    BuildContext context,
    String tabId,
    String label,
    IconData icon,
  ) {
    final isSelected = _selectedTab == tabId;
    
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = tabId),
      child: Container(
        padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          borderRadius: context.responsiveBorderRadius,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: context.responsiveIconSize(20),
              color: isSelected
                  ? Theme.of(context).colorScheme.onPrimary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEventsList(BuildContext context, String Function(String) translate) {
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: context.responsiveIconSize(64),
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              translate('no_events_available'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index];
        return _buildEventCard(context, event, translate);
      },
    );
  }

  Widget _buildAnnouncementsList(BuildContext context, String Function(String) translate) {
    if (_announcements.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.campaign_outlined,
              size: context.responsiveIconSize(64),
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              translate('no_announcements_available'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
      itemCount: _announcements.length,
      itemBuilder: (context, index) {
        final announcement = _announcements[index];
        return _buildAnnouncementCard(context, announcement, translate);
      },
    );
  }

  Widget _buildEventCard(BuildContext context, Map<String, dynamic> event, String Function(String) translate) {
    final scheduledFor = DateTime.tryParse(event['scheduled_for'] ?? '');
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    translate('event'),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                const Spacer(),
                if (scheduledFor != null)
                  Text(
                    '${scheduledFor.day}/${scheduledFor.month}/${scheduledFor.year}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event['title'] ?? translate('untitled_event'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (event['description'] != null) ...[
              const SizedBox(height: 8),
              Text(
                event['description'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (event['location'] != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: context.responsiveIconSize(16),
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event['location'],
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Map<String, dynamic> announcement, String Function(String) translate) {
    final createdAt = DateTime.tryParse(announcement['created_at'] ?? '');
    final priority = announcement['priority'] ?? 'medium';
    
    Color priorityColor = Theme.of(context).colorScheme.primary;
    switch (priority) {
      case 'urgent':
        priorityColor = Colors.red;
        break;
      case 'high':
        priorityColor = Colors.orange;
        break;
      case 'low':
        priorityColor = Colors.green;
        break;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: priorityColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    translate(priority),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: priorityColor,
                    ),
                  ),
                ),
                const Spacer(),
                if (createdAt != null)
                  Text(
                    '${createdAt.day}/${createdAt.month}/${createdAt.year}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement['title'] ?? translate('untitled_announcement'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (announcement['message'] != null) ...[
              const SizedBox(height: 8),
              Text(
                announcement['message'],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (announcement['action_text'] != null && announcement['action_url'] != null) ...[
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () {
                  // Handle action URL
                  ToastUtils.showInfo('Opening: ${announcement['action_url']}');
                },
                child: Text(announcement['action_text']),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCreateContentDialog(BuildContext context, String Function(String) translate) {
    // Check permissions before showing dialog
    if (!RoleAccessService.instance.canCreateEvents()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You do not have permission to create content. Only executives can create events and announcements.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(translate('create_content')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event),
              title: Text(translate('create_event')),
              subtitle: Text(translate('create_event_description')),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateEventForm(context, translate);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.campaign),
              title: Text(translate('create_announcement')),
              subtitle: Text(translate('create_announcement_description')),
              onTap: () {
                Navigator.of(context).pop();
                _showCreateAnnouncementForm(context, translate);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(translate('cancel')),
          ),
        ],
      ),
    );
  }

  void _showCreateEventForm(BuildContext context, String Function(String) translate) {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final locationController = TextEditingController();
    DateTime? scheduledDate;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(translate('create_event')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: translate('event_title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: InputDecoration(
                    labelText: translate('event_description'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: translate('event_location'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (date != null) {
                      setDialogState(() {
                        scheduledDate = date;
                      });
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: translate('event_date'),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(
                      scheduledDate != null
                          ? '${scheduledDate!.day}/${scheduledDate!.month}/${scheduledDate!.year}'
                          : translate('select_date'),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final rootCtx = context;
                if (titleController.text.trim().isEmpty) {
                  ToastUtils.showError('Event title is required');
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ToastUtils.showError('User not authenticated');
                    return;
                  }
                  
                  await FirebaseFirestore.instance.collection('events').add({
                    'title': titleController.text.trim(),
                    'description': descriptionController.text.trim(),
                    'location': locationController.text.trim(),
                    'scheduled_for': scheduledDate?.toIso8601String(),
                    'created_at': DateTime.now().toIso8601String(),
                    'created_by': user.uid,
                  });

                  if (!rootCtx.mounted) return;
                  Navigator.of(rootCtx).pop();
                  ToastUtils.showSuccess('Event created successfully');
                  _loadData();
                } catch (e) {
                  ToastUtils.showError('Error creating event: $e');
                }
              },
              child: Text(translate('create')),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateAnnouncementForm(BuildContext context, String Function(String) translate) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String priority = 'medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(translate('create_announcement')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: InputDecoration(
                    labelText: translate('announcement_title'),
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: messageController,
                  decoration: InputDecoration(
                    labelText: translate('announcement_message'),
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(
                    labelText: translate('priority'),
                    border: const OutlineInputBorder(),
                  ),
                  items: ['low', 'medium', 'high', 'urgent'].map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text(translate(p)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      priority = value!;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(translate('cancel')),
            ),
            ElevatedButton(
              onPressed: () async {
                final rootCtx = context;
                if (titleController.text.trim().isEmpty) {
                  ToastUtils.showError('Announcement title is required');
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  if (user == null) {
                    ToastUtils.showError('User not authenticated');
                    return;
                  }
                  
                  await FirebaseFirestore.instance.collection('announcements').add({
                    'title': titleController.text.trim(),
                    'message': messageController.text.trim(),
                    'priority': priority,
                    'type': 'general',
                    'target_audience': 'all',
                    'is_active': true,
                    'created_at': DateTime.now().toIso8601String(),
                    'created_by': user.uid,
                  });

                  if (!rootCtx.mounted) return;
                  Navigator.of(rootCtx).pop();
                  ToastUtils.showSuccess('Announcement created successfully');
                  _loadData();
                } catch (e) {
                  ToastUtils.showError('Error creating announcement: $e');
                }
              },
              child: Text(translate('create')),
            ),
          ],
        ),
      ),
    );
  }
}
