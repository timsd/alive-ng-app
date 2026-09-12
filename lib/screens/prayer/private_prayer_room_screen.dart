import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../models/app_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/prayer_requests_service.dart';
import '../../services/role_access_service.dart';
import '../../widgets/custom_app_bar.dart';

class PrivatePrayerRoomScreen extends ConsumerStatefulWidget {
  const PrivatePrayerRoomScreen({super.key});

  @override
  ConsumerState<PrivatePrayerRoomScreen> createState() =>
      _PrivatePrayerRoomScreenState();
}

class _PrivatePrayerRoomScreenState extends ConsumerState<PrivatePrayerRoomScreen>
    with SingleTickerProviderStateMixin {
  final PrayerRequestsService _prayerService = PrayerRequestsService.instance;
  final RoleAccessService _roleService = RoleAccessService.instance;

  List<PrivatePrayerRoom> _rooms = [];
  PrivatePrayerRoom? _selectedRoom;
  List<PrayerRequest> _roomRequests = [];
  final Map<String, PrayerTestimony?> _testimoniesCache = {};

  bool _loadingRooms = true;
  bool _loadingRequests = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRooms();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRooms() async {
    setState(() => _loadingRooms = true);
    try {
      final user = ref.read(currentUserProvider);
      final userId = user?.uid ?? '';
      final role = _roleService.getCurrentUserRole() ?? 'member';

      final rooms = await _prayerService.fetchPrivateRooms(
        userId: userId,
        role: role,
      );

      setState(() {
        _rooms = rooms;
        _loadingRooms = false;
        if (_selectedRoom != null) {
          // Keep current selection if still valid
          _selectedRoom = rooms.where((r) => r.id == _selectedRoom!.id).firstOrNull;
        }
        if (_selectedRoom == null && rooms.isNotEmpty) {
          _selectedRoom = rooms.first;
        }
      });

      if (_selectedRoom != null) {
        await _loadRoomRequests(_selectedRoom!.id);
      }
    } catch (e) {
      setState(() => _loadingRooms = false);
      _showSnack('Failed to load prayer rooms: $e', isError: true);
    }
  }

  Future<void> _loadRoomRequests(String roomId) async {
    setState(() => _loadingRequests = true);
    try {
      final reqs = await _prayerService.fetchRoomPrayerRequests(roomId);
      setState(() {
        _roomRequests = reqs;
        _loadingRequests = false;
      });

      // Pre-load testimonies for answered requests
      for (final req in reqs.where((r) => r.isAnswered)) {
        _loadTestimony(req.id);
      }
    } catch (e) {
      setState(() => _loadingRequests = false);
      _showSnack('Failed to load room prayers: $e', isError: true);
    }
  }

  Future<void> _loadTestimony(String requestId) async {
    if (_testimoniesCache.containsKey(requestId)) return;
    final testimony = await _prayerService.fetchPrayerTestimony(requestId);
    if (mounted) {
      setState(() {
        _testimoniesCache[requestId] = testimony;
      });
    }
  }

  bool get _canCreateRoom {
    final role = _roleService.getCurrentUserRole() ?? 'member';
    const allowed = {'admin', 'bod', 'trustee', 'director', 'chapter_leader'};
    return allowed.contains(role.toLowerCase());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Private Prayer Rooms',
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadRooms,
          ),
          if (_canCreateRoom)
            IconButton(
              tooltip: 'Create Room',
              icon: const Icon(Icons.add_business_rounded),
              onPressed: _showCreateRoomDialog,
            ),
        ],
      ),
      floatingActionButton: _selectedRoom != null
          ? FloatingActionButton.extended(
              onPressed: _showAddPrayerDialog,
              icon: const FaIcon(FontAwesomeIcons.handsPraying, size: 18),
              label: const Text('New Request'),
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: theme.colorScheme.onPrimary,
            )
          : null,
      body: _loadingRooms
          ? const Center(child: CircularProgressIndicator())
          : _rooms.isEmpty
              ? _buildNoRoomsState(theme)
              : Column(
                  children: [
                    _buildRoomSelector(theme),
                    if (_selectedRoom != null) ...[
                      _buildRoomBanner(theme),
                      TabBar(
                        controller: _tabController,
                        tabs: [
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Active Requests'),
                                const SizedBox(width: 6),
                                _buildBadge(
                                  _roomRequests.where((r) => !r.isAnswered).length,
                                  theme.colorScheme.primary,
                                ),
                              ],
                            ),
                          ),
                          Tab(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text('Answered & Testimonies'),
                                const SizedBox(width: 6),
                                _buildBadge(
                                  _roomRequests.where((r) => r.isAnswered).length,
                                  Colors.green,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                        child: _loadingRequests
                            ? const Center(child: CircularProgressIndicator())
                            : TabBarView(
                                controller: _tabController,
                                children: [
                                  _buildPrayerList(
                                    requests: _roomRequests
                                        .where((r) => !r.isAnswered)
                                        .toList(),
                                    isAnsweredTab: false,
                                    currentUserId: user?.uid ?? '',
                                  ),
                                  _buildPrayerList(
                                    requests: _roomRequests
                                        .where((r) => r.isAnswered)
                                        .toList(),
                                    isAnsweredTab: true,
                                    currentUserId: user?.uid ?? '',
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ],
                ),
    );
  }

  Widget _buildBadge(int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildNoRoomsState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_person_outlined,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Text(
              'No Private Prayer Rooms',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Private prayer rooms are restricted to Directors, Chapter Leaders, Board of Trustees, and invited members.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_canCreateRoom) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _showCreateRoomDialog,
                icon: const Icon(Icons.add),
                label: const Text('Create a Prayer Room'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildRoomSelector(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final room in _rooms)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: const Icon(Icons.lock_rounded, size: 16),
                  label: Text(room.name),
                  selected: _selectedRoom?.id == room.id,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedRoom = room);
                      _loadRoomRequests(room.id);
                    }
                  },
                ),
              ),
            if (_canCreateRoom)
              ActionChip(
                avatar: const Icon(Icons.add, size: 16),
                label: const Text('New Room'),
                onPressed: _showCreateRoomDialog,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoomBanner(ThemeData theme) {
    if (_selectedRoom == null) return const SizedBox.shrink();
    final room = _selectedRoom!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withOpacity(0.3),
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  room.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.shield_rounded,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Confidential',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (room.description.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              room.description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (room.allowedRoles.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final role in room.allowedRoles)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    label: Text(
                      role.toUpperCase().replaceAll('_', ' '),
                      style: const TextStyle(fontSize: 10),
                    ),
                    backgroundColor: theme.colorScheme.surface,
                    padding: const EdgeInsets.all(0),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrayerList({
    required List<PrayerRequest> requests,
    required bool isAnsweredTab,
    required String currentUserId,
  }) {
    if (requests.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FaIcon(
                isAnsweredTab
                    ? FontAwesomeIcons.trophy
                    : FontAwesomeIcons.handsPraying,
                size: 40,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                isAnsweredTab
                    ? 'No answered prayers yet'
                    : 'No active prayer requests in this room',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 6),
              Text(
                isAnsweredTab
                    ? 'When prayers are answered, testimonies attached to them will appear here.'
                    : 'Be the first to share a confidential request for intercession.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadRoomRequests(_selectedRoom!.id),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final req = requests[index];
          final isOwner = req.userId == currentUserId;
          final testimony = _testimoniesCache[req.id];

          return _PrivatePrayerCard(
            request: req,
            isOwner: isOwner,
            testimony: testimony,
            onPray: () => _prayForRequest(req),
            onMarkAnswered: isOwner && !req.isAnswered
                ? () => _showAnsweredPrayerDialog(req)
                : null,
            onDelete: isOwner ? () => _deleteRequest(req) : null,
          );
        },
      ),
    );
  }

  Future<void> _prayForRequest(PrayerRequest request) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      _showSnack('Please sign in to pray.', isError: true);
      return;
    }

    try {
      await _prayerService.prayForRequest(request.id, user.uid);
      _showSnack('Prayer recorded! Thank you for interceding.');
      _loadRoomRequests(_selectedRoom!.id);
    } catch (e) {
      _showSnack('Error: $e', isError: true);
    }
  }

  Future<void> _deleteRequest(PrayerRequest request) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Prayer Request'),
        content: const Text(
          'Are you sure you want to remove this prayer request?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _prayerService.deletePrayerRequest(request.id);
      _showSnack('Prayer request deleted.');
      _loadRoomRequests(_selectedRoom!.id);
    } catch (e) {
      _showSnack('Failed to delete request: $e', isError: true);
    }
  }

  void _showAddPrayerDialog() {
    if (_selectedRoom == null) return;
    final titleController = TextEditingController();
    final descController = TextEditingController();
    bool isAnonymous = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text('New Prayer in ${_selectedRoom!.name}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Prayer Title',
                    hintText: 'e.g. Guidance for board decision',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description / Details',
                    hintText: 'Share what you need prayer for...',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Share Anonymously'),
                  subtitle: const Text('Hide your name from other room members'),
                  value: isAnonymous,
                  onChanged: (val) {
                    setDlgState(() => isAnonymous = val ?? false);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                if (title.isEmpty || desc.isEmpty) {
                  _showSnack('Please fill all fields', isError: true);
                  return;
                }
                Navigator.pop(ctx);

                try {
                  final user = ref.read(currentUserProvider);
                  await _prayerService.createPrayerRequest(
                    PrayerRequest(
                      id: '',
                      userId: user?.uid ?? '',
                      title: title,
                      description: desc,
                      category: 'private_room',
                      isAnonymous: isAnonymous,
                      isPrivate: true,
                      roomId: _selectedRoom!.id,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  _showSnack('Confidential prayer request posted.');
                  _loadRoomRequests(_selectedRoom!.id);
                } catch (e) {
                  _showSnack('Error posting prayer: $e', isError: true);
                }
              },
              child: const Text('Post Request'),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnsweredPrayerDialog(PrayerRequest request) {
    final titleController = TextEditingController(text: 'Praise Report: ${request.title}');
    final bodyController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.celebration_rounded, color: Colors.amber),
            SizedBox(width: 8),
            Text('Prayer Answered!'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Give glory to God and encourage everyone who prayed with you by attaching your testimony.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Testimony Title',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: bodyController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Your Testimony / Praise Report',
                  hintText: 'Share how God answered this prayer...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              final title = titleController.text.trim();
              final body = bodyController.text.trim();
              if (title.isEmpty || body.isEmpty) {
                _showSnack('Please provide a title and testimony body.', isError: true);
                return;
              }
              Navigator.pop(ctx);

              try {
                final user = ref.read(currentUserProvider);
                await _prayerService.addPrayerTestimony(
                  PrayerTestimony(
                    id: '',
                    prayerRequestId: request.id,
                    userId: user?.uid ?? '',
                    authorName: user?.displayName ?? 'ALIVE Member',
                    title: title,
                    body: body,
                    createdAt: DateTime.now(),
                  ),
                );
                _showSnack('Praise the Lord! Testimony attached and prayer marked answered.');
                _loadRoomRequests(_selectedRoom!.id);
              } catch (e) {
                _showSnack('Failed to submit testimony: $e', isError: true);
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
            child: const Text('Submit Testimony'),
          ),
        ],
      ),
    );
  }

  void _showCreateRoomDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final selectedRoles = <String>{'admin', 'director', 'chapter_leader', 'bod'};

    final availableRoles = [
      {'key': 'director', 'label': 'Directors'},
      {'key': 'chapter_leader', 'label': 'Chapter Leaders'},
      {'key': 'bod', 'label': 'Board of Directors (BOD)'},
      {'key': 'trustee', 'label': 'Trustees'},
      {'key': 'admin', 'label': 'Administrators'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: const Text('Create Private Prayer Room'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Room Name',
                    hintText: 'e.g. National Leadership Intercessors',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Purpose of this private prayer room...',
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Allowed Roles:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                for (final roleInfo in availableRoles)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(roleInfo['label']!),
                    value: selectedRoles.contains(roleInfo['key']),
                    onChanged: (val) {
                      setDlgState(() {
                        if (val == true) {
                          selectedRoles.add(roleInfo['key']!);
                        } else {
                          selectedRoles.remove(roleInfo['key']!);
                        }
                      });
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final desc = descController.text.trim();
                if (name.isEmpty) {
                  _showSnack('Room name is required', isError: true);
                  return;
                }
                Navigator.pop(ctx);

                try {
                  final user = ref.read(currentUserProvider);
                  await _prayerService.createPrivateRoom(
                    PrivatePrayerRoom(
                      id: '',
                      name: name,
                      description: desc,
                      allowedRoles: selectedRoles.toList(),
                      createdBy: user?.uid ?? '',
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    ),
                  );
                  _showSnack('Private prayer room created!');
                  _loadRooms();
                } catch (e) {
                  _showSnack('Failed to create room: $e', isError: true);
                }
              },
              child: const Text('Create Room'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSnack(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.tertiary,
      ),
    );
  }
}

class _PrivatePrayerCard extends StatelessWidget {
  final PrayerRequest request;
  final bool isOwner;
  final PrayerTestimony? testimony;
  final VoidCallback onPray;
  final VoidCallback? onMarkAnswered;
  final VoidCallback? onDelete;

  const _PrivatePrayerCard({
    required this.request,
    required this.isOwner,
    this.testimony,
    required this.onPray,
    this.onMarkAnswered,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final author = request.isAnonymous ? 'Anonymous' : 'Room Member';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: request.isAnswered
              ? Colors.green.withOpacity(0.5)
              : theme.colorScheme.outlineVariant,
          width: request.isAnswered ? 1.5 : 1.0,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: request.isAnswered
                      ? Colors.green.shade100
                      : theme.colorScheme.primaryContainer,
                  child: Icon(
                    request.isAnswered ? Icons.check_circle : Icons.person,
                    color: request.isAnswered
                        ? Colors.green.shade800
                        : theme.colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        author,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _formatTimestamp(request.createdAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (request.isAnswered)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified_rounded,
                            size: 14, color: Colors.green.shade700),
                        const SizedBox(width: 4),
                        Text(
                          'Answered',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: onDelete,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              request.title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              request.description,
              style: theme.textTheme.bodyMedium,
            ),
            if (testimony != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.star_rounded,
                            color: Colors.amber, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Attached Testimony',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      testimony!.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      testimony!.body,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade800,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                FaIcon(
                  FontAwesomeIcons.handsPraying,
                  size: 15,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  '${request.prayerCount} prayers offered',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const Spacer(),
                if (!isOwner)
                  OutlinedButton.icon(
                    onPressed: onPray,
                    icon: const FaIcon(FontAwesomeIcons.handsPraying, size: 14),
                    label: const Text('I Prayed'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                if (onMarkAnswered != null) ...[
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: onMarkAnswered,
                    icon: const Icon(Icons.celebration_rounded, size: 16),
                    label: const Text('Testify Answer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green.shade700,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final difference = DateTime.now().difference(timestamp);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    if (difference.inDays < 7) return '${difference.inDays}d ago';
    return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
  }
}
