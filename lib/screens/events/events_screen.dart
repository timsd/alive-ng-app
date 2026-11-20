import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../widgets/modern_dropdown.dart';
import '../../utils/error_handler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/event_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/appwrite_events_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/smart_link_helper.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/error_widget.dart' as custom_error;
import '../../widgets/loading_widget.dart';
import '../../widgets/custom_app_bar.dart';

class EventsScreen extends ConsumerStatefulWidget {
  final String initialTab;
  final String? initialItemId;

  const EventsScreen({
    super.key,
    this.initialTab = 'events',
    this.initialItemId,
  });

  @override
  ConsumerState<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends ConsumerState<EventsScreen> {
  List<Event> _events = [];
  List<Announcement> _announcements = [];
  bool _isLoading = true;
  String? _error;
  late String _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab == 'announcements'
        ? 'announcements'
        : 'events';
    _loadData();
  }

  @override
  void didUpdateWidget(covariant EventsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _selectedTab = widget.initialTab == 'announcements'
            ? 'announcements'
            : 'events';
      });
    }
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final service = AppwriteEventsService.instance;
      final eventsResponse = await service.listEvents();
      final announcementsResponse = await service.listAnnouncements();

      setState(() {
        _events = eventsResponse;
        _announcements = announcementsResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = ErrorHandler.getUserFriendlyMessage(e);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final translate = ref.watch(translationProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: translate('news_feed'),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    final targetId = widget.initialItemId?.trim() ?? '';
    final orderedEvents = targetId.isEmpty
        ? _events
        : [
            ..._events.where((e) => e.id == targetId),
            ..._events.where((e) => e.id != targetId),
          ];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
        itemCount: orderedEvents.length,
        itemBuilder: (context, index) {
          final event = orderedEvents[index];
          return _buildEventCard(context, event, translate);
        },
      ),
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
              color: Theme.of(context).colorScheme.onSurfaceVariant,
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

    final targetId = widget.initialItemId?.trim() ?? '';
    final orderedAnnouncements = targetId.isEmpty
        ? _announcements
        : [
            ..._announcements.where((a) => a.id == targetId),
            ..._announcements.where((a) => a.id != targetId),
          ];

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: ResponsiveUtils.getResponsivePaddingWithBase(context, 16),
        itemCount: orderedAnnouncements.length,
        itemBuilder: (context, index) {
          final announcement = orderedAnnouncements[index];
          return _buildAnnouncementCard(context, announcement, translate);
        },
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, Event event, String Function(String) translate) {
    final scheduledFor = event.scheduledTime;
    
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
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share Event',
                  onPressed: () {
                    final url = event.id.isNotEmpty
                        ? 'https://app.alivenigeria.org/events?tab=events&id=${Uri.encodeComponent(event.id)}'
                        : 'https://app.alivenigeria.org/events?tab=events';
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            '📅 *${event.title}*\n\n${event.description}\n\nView event on ALIVE Nigeria:\n$url',
                        subject: event.title,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              event.title.isNotEmpty ? event.title : translate('untitled_event'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              SmartLinkHelper.buildLinkifiedText(
                context,
                event.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
            if (event.location != null && event.location!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.location_on,
                    size: context.responsiveIconSize(16),
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    event.location!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
            ..._buildSmartCtaSection(
              context,
              textToScan: event.description,
              extraTextToScan: event.location,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Announcement announcement, String Function(String) translate) {
    final createdAt = announcement.createdAt;
    final priority = announcement.priority;
    final message = announcement.content;
    
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
                IconButton(
                  icon: const Icon(Icons.share_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Share Announcement',
                  onPressed: () {
                    final url = announcement.id.isNotEmpty
                        ? 'https://app.alivenigeria.org/events?tab=announcements&id=${Uri.encodeComponent(announcement.id)}'
                        : 'https://app.alivenigeria.org/events?tab=announcements';
                    SharePlus.instance.share(
                      ShareParams(
                        text:
                            '📢 *${announcement.title}*\n\n$message\n\nRead on ALIVE Nigeria:\n$url',
                        subject: announcement.title,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              announcement.title.isNotEmpty ? announcement.title : translate('untitled_announcement'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 8),
              SmartLinkHelper.buildLinkifiedText(
                context,
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
            ..._buildSmartCtaSection(
              context,
              explicitUrl: announcement.actionUrl,
              explicitLabel: announcement.actionText,
              textToScan: message,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildSmartCtaSection(
    BuildContext context, {
    String? explicitUrl,
    String? explicitLabel,
    required String textToScan,
    String? extraTextToScan,
  }) {
    final links = <_SmartCtaLink>[];
    final seen = <String>{};

    final trimmedExplicit = explicitUrl?.trim() ?? '';
    if (trimmedExplicit.isNotEmpty) {
      final normalized = SmartLinkHelper.normalizeUrl(trimmedExplicit);
      if (seen.add(normalized)) {
        links.add(
          _SmartCtaLink(
            url: normalized,
            label: SmartLinkHelper.inferSmartCtaLabel(
              normalized,
              customLabel: explicitLabel,
              contextText: textToScan,
            ),
          ),
        );
      }
    }

    final combinedText = [
      textToScan,
      if (extraTextToScan != null && extraTextToScan.isNotEmpty)
        extraTextToScan,
    ].join(' ');

    for (final extracted in SmartLinkHelper.extractUrls(combinedText)) {
      if (seen.add(extracted)) {
        links.add(
          _SmartCtaLink(
            url: extracted,
            label: SmartLinkHelper.inferSmartCtaLabel(
              extracted,
              contextText: combinedText,
            ),
          ),
        );
      }
    }

    if (links.isEmpty) return const [];

    return [
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: links
            .map(
              (item) => ElevatedButton.icon(
                onPressed: () => SmartLinkHelper.openSmartLink(context, item.url),
                icon: Icon(
                  SmartLinkHelper.inferSmartCtaIcon(
                    item.url,
                    contextText: combinedText,
                  ),
                  size: 18,
                ),
                label: Text(item.label),
              ),
            )
            .toList(),
      ),
    ];
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
                  final user = await ref.read(authGatewayProvider).getCurrentUser();
                  if (user == null) {
                    ToastUtils.showError('User not authenticated');
                    return;
                  }
                  
                  await AppwriteEventsService.instance.createEvent(
                    title: titleController.text.trim(),
                    description: descriptionController.text.trim(),
                    location: locationController.text.trim(),
                    authorId: user.uid,
                    scheduledDate: scheduledDate,
                  );

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
                ModernDropdownFormField<String>(
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
                  final user = await ref.read(authGatewayProvider).getCurrentUser();
                  if (user == null) {
                    ToastUtils.showError('User not authenticated');
                    return;
                  }
                  
                  await AppwriteEventsService.instance.createAnnouncement(
                    title: titleController.text.trim(),
                    content: messageController.text.trim(),
                    authorId: user.uid,
                    audience: 'all:$priority',
                  );

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

class _SmartCtaLink {
  final String url;
  final String label;

  const _SmartCtaLink({
    required this.url,
    required this.label,
  });
}
