import 'package:flutter/material.dart';

import '../../models/discipleship_models.dart';
import '../../services/discipleship_service.dart';
import '../../utils/error_handler.dart';

/// Opens the modern, responsive Discipleship Operations Modal.
/// Uses a bottom sheet on mobile and a centered dialog on tablets/desktops.
Future<void> showDiscipleshipOperationsModal(
  BuildContext context, {
  int initialTab = 0,
}) {
  final isMobile = MediaQuery.of(context).size.width < 700;

  if (isMobile) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _DiscipleshipOperationsSheet(initialTab: initialTab),
    );
  } else {
    return showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
          child: _DiscipleshipOperationsSheet(
            initialTab: initialTab,
            isDialog: true,
          ),
        ),
      ),
    );
  }
}

class _DiscipleshipOperationsSheet extends StatefulWidget {
  final int initialTab;
  final bool isDialog;

  const _DiscipleshipOperationsSheet({
    this.initialTab = 0,
    this.isDialog = false,
  });

  @override
  State<_DiscipleshipOperationsSheet> createState() =>
      _DiscipleshipOperationsSheetState();
}

class _DiscipleshipOperationsSheetState
    extends State<_DiscipleshipOperationsSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DiscipleshipService _service = DiscipleshipService.instance;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final content = Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: widget.isDialog
            ? BorderRadius.circular(20)
            : const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle for bottom sheet
          if (!widget.isDialog)
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 4),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

          // Header Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 12, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.groups_3_outlined,
                    color: colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Discipleship Operations',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Routing officers & disciple deletion approvals',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close',
                ),
              ],
            ),
          ),

          // Segmented Tabs Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                indicator: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                labelColor: colorScheme.primary,
                unselectedLabelColor: colorScheme.onSurfaceVariant,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 13),
                tabs: const [
                  Tab(
                    iconMargin: EdgeInsets.zero,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.mark_email_read_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Report Officers'),
                      ],
                    ),
                  ),
                  Tab(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_remove_outlined, size: 16),
                        SizedBox(width: 6),
                        Text('Deletion Queue'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Tab Content Area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _ReportOfficersTab(
                  service: _service,
                  onReload: () => setState(() {}),
                ),
                _DeletionRequestsTab(
                  service: _service,
                  onReload: () => setState(() {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (widget.isDialog) {
      return content;
    }

    return SizedBox(
      height: mediaQuery.size.height * 0.85,
      child: content,
    );
  }
}

// -----------------------------------------------------------------------------
// TAB 1: Report Officers & Routing
// -----------------------------------------------------------------------------
class _ReportOfficersTab extends StatelessWidget {
  final DiscipleshipService service;
  final VoidCallback onReload;

  const _ReportOfficersTab({
    required this.service,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<OfficerOfficeAssignment>>(
      future: service.getOfficerAssignments(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final assignments = snapshot.data ?? [];

        return Column(
          children: [
            // Top action banner
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              color: colorScheme.surfaceContainerLow,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Officers designated to receive dispatched discipleship reports:',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () => _openOfficerForm(context),
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Assign Officer'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
              ),
            ),

            // Content List
            Expanded(
              child: assignments.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment_ind_outlined,
                              size: 48,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No Report Officers Assigned',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Assign coordinators and directors to route progress reports from the field.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _openOfficerForm(context),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add First Officer'),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: assignments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final a = assignments[index];
                        final isDirector = a.officeType.toLowerCase() == 'director';
                        final badgeColor = isDirector ? Colors.indigo : Colors.teal;

                        return Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: badgeColor.withValues(alpha: 0.15),
                                  child: Icon(
                                    isDirector
                                        ? Icons.shield_outlined
                                        : Icons.co_present_outlined,
                                    color: badgeColor,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              a.officeTitle,
                                              style: theme.textTheme.titleSmall?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: badgeColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              a.officeType.toUpperCase(),
                                              style: TextStyle(
                                                color: badgeColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        a.officerName,
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      Text(
                                        a.officerEmail,
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 18,
                                        color: colorScheme.primary,
                                      ),
                                      tooltip: 'Handover / Edit Assignment',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _openOfficerForm(context, existing: a),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 18,
                                        color: Colors.redAccent,
                                      ),
                                      tooltip: 'Remove Assignment',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () => _confirmDelete(context, a),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }

  void _openOfficerForm(BuildContext context, {OfficerOfficeAssignment? existing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _OfficerFormSheet(
        existing: existing,
        onSaved: onReload,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    OfficerOfficeAssignment assignment,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Assignment?'),
        content: Text(
          'Are you sure you want to remove ${assignment.officerName} from ${assignment.officeTitle}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await service.removeOfficerAssignment(assignment.id);
      onReload();
    }
  }
}

// -----------------------------------------------------------------------------
// TAB 2: Disciple Deletion Queue
// -----------------------------------------------------------------------------
class _DeletionRequestsTab extends StatelessWidget {
  final DiscipleshipService service;
  final VoidCallback onReload;

  const _DeletionRequestsTab({
    required this.service,
    required this.onReload,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return FutureBuilder<List<DiscipleDeletionRequest>>(
      future: service.getDeletionRequests(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final requests = snapshot.data ?? [];

        if (requests.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 52,
                    color: Colors.green.withValues(alpha: 0.8),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'No Pending Requests',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Coordinators and Directors submit deletion requests when a disciple profile is duplicate or inactive with zero records.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final req = requests[index];
            final isPending = req.status == DeletionRequestStatus.pending;
            final isApproved = req.status == DeletionRequestStatus.approved;

            final statusColor = isPending
                ? Colors.orange
                : (isApproved ? Colors.green : Colors.red);

            return Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isPending
                      ? Colors.orange.withValues(alpha: 0.5)
                      : colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            req.contactName,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            req.status.name.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Requested by: ${req.requesterName} (${req.requesterRole})',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'Reason: "${req.reason}"',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    if (isPending) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _handleReview(context, req, false),
                            child: const Text('Reject'),
                          ),
                          const SizedBox(width: 8),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => _handleReview(context, req, true),
                            child: const Text('Approve Deletion'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _handleReview(
    BuildContext context,
    DiscipleDeletionRequest request,
    bool approve,
  ) async {
    final notesController = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(approve ? 'Approve Deletion' : 'Reject Request'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Confirm deleting "${request.contactName}". This action removes the profile.'
                  : 'Reject deletion request for "${request.contactName}".',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(
                labelText: 'Reviewer Notes (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.redAccent,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(approve ? 'Confirm Approval' : 'Confirm Rejection'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (approve) {
        await service.approveDeletionRequest(
          request.id,
          adminNotes: notesController.text.trim(),
        );
      } else {
        await service.rejectDeletionRequest(
          request.id,
          reason: notesController.text.trim(),
        );
      }
      onReload();
    }
  }
}

// -----------------------------------------------------------------------------
// OFFICER ASSIGNMENT BOTTOM SHEET FORM
// -----------------------------------------------------------------------------
class _OfficerFormSheet extends StatefulWidget {
  final OfficerOfficeAssignment? existing;
  final VoidCallback onSaved;

  const _OfficerFormSheet({
    this.existing,
    required this.onSaved,
  });

  @override
  State<_OfficerFormSheet> createState() => _OfficerFormSheetState();
}

class _OfficerFormSheetState extends State<_OfficerFormSheet> {
  late TextEditingController _titleController;
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _idController;
  late String _officeType;
  bool _isSaving = false;

  static const List<String> _suggestedDirectorTitles = [
    'Director of Evangelism & Missions',
    'Director of Evangelism & Programming',
    'Director of Health',
    'Director of AMTC',
    'Director of Finance & Treasury',
  ];

  static const List<String> _suggestedCoordinatorTitles = [
    'Chapter Coordinator',
    'Field Work Coordinator',
    'Campus Missionary Coordinator',
    'AMTC Coordinator',
    'Prayer Coordinator',
  ];

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.existing?.officeTitle ?? '');
    _nameController = TextEditingController(text: widget.existing?.officerName ?? '');
    _emailController = TextEditingController(text: widget.existing?.officerEmail ?? '');
    _idController = TextEditingController(text: widget.existing?.officerId ?? '');
    _officeType = (widget.existing?.officeType.toLowerCase() == 'director')
        ? 'director'
        : 'coordinator';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final mediaQuery = MediaQuery.of(context);

    final suggestions = _officeType == 'director'
        ? _suggestedDirectorTitles
        : _suggestedCoordinatorTitles;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                widget.existing != null
                    ? 'Handover / Edit Office Assignment'
                    : 'Assign Report Officer',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'Designate which officer receives dispatched reports for this post.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Segmented Office Type
              Text('Office Type', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'coordinator',
                    label: Text('Coordinator'),
                    icon: Icon(Icons.co_present_outlined),
                  ),
                  ButtonSegment(
                    value: 'director',
                    label: Text('Director'),
                    icon: Icon(Icons.shield_outlined),
                  ),
                ],
                selected: {_officeType},
                onSelectionChanged: (val) {
                  setState(() {
                    _officeType = val.first;
                  });
                },
              ),

              const SizedBox(height: 16),

              // Quick title presets
              Text('Quick Office Presets', style: theme.textTheme.labelSmall),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: suggestions.map((title) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(title, style: const TextStyle(fontSize: 11)),
                        onPressed: () {
                          setState(() {
                            _titleController.text = title;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Office / Role Title *',
                  hintText: 'e.g. Director of Evangelism, AMTC Coordinator',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Officer Full Name *',
                  hintText: 'e.g. Emenike Praise',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),

              const SizedBox(height: 12),

              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Officer Email *',
                  hintText: 'e.g. officer@alivenigeria.org',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_rounded, size: 16),
                    label: Text(
                      widget.existing != null ? 'Update Officer' : 'Save Assignment',
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

  Future<void> _save() async {
    if (_titleController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final officerId = _idController.text.trim().isEmpty
          ? _emailController.text.trim().toLowerCase()
          : _idController.text.trim();

      await DiscipleshipService.instance.assignOfficerToOffice(
        existingId: widget.existing?.id,
        officeTitle: _titleController.text.trim(),
        officeType: _officeType,
        officerName: _nameController.text.trim(),
        officerEmail: _emailController.text.trim(),
        officerId: officerId,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save assignment: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

