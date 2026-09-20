import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'leader_meeting_transcription_screen.dart';
import '../../services/appwrite_profile_service.dart';
import '../../services/auth_service.dart';
import '../../services/leadership_service.dart';
import '../../services/role_access_service.dart';
import '../../models/app_models.dart' hide LeadershipRecord;
import '../../models/leadership_models.dart';
import 'board_reports_screen.dart';
import 'board_decisions_screen.dart';
import 'board_documents_screen.dart';
import '../conference/livekit_meeting_screen.dart';
import '../../config/meeting_links_config.dart';
import '../../widgets/custom_app_bar.dart';

class BodTrusteesScreen extends StatefulWidget {
  const BodTrusteesScreen({super.key});

  @override
  State<BodTrusteesScreen> createState() => _BodTrusteesScreenState();
}

class _BodTrusteesScreenState extends State<BodTrusteesScreen> {
  final AppwriteProfileService _profileService = AppwriteProfileService();
  final AuthService _authService = AuthService.instance;
  final LeadershipService _leadershipService = LeadershipService();
  bool _isLoading = true;
  bool _hasAccess = false;
  bool _isAdmin = false;
  String? _currentUserId;
  List<LeadershipRecord> _records = [];
  String _tenureFilter = 'all';

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    try {
      // Check if user has admin, leader, or BOD access
      final user = _authService.currentUser;
      if (user != null) {
        final userProfile = await _profileService.getUserProfileModel(user.uid);
        _currentUserId = user.uid;

        // Only admin, leader, and BOD members can access this page
        final role = userProfile?.role ?? '';
        _hasAccess = role == 'admin' ||
            role == 'leader' ||
            role == 'bod' ||
            role == 'trustee';
        _isAdmin = RoleAccessService.instance.hasRole('admin');
        if (_hasAccess) await _loadLeadership();
      }
    } catch (e) {
      _hasAccess = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadLeadership() async {
    try {
      final results = await Future.wait([
        _leadershipService.getRecordsByPosition(LeadershipPosition.bod),
        _leadershipService.getRecordsByPosition(LeadershipPosition.trustee),
      ]);
      final merged = <LeadershipRecord>[...results[0], ...results[1]];
      merged.sort((a, b) => b.startDate.compareTo(a.startDate));
      if (mounted) setState(() => _records = merged);
    } catch (_) {
      // Board screen still works when leadership history is unavailable.
    }
  }

  List<String> get _tenures {
    final tenures = _records.map(_tenureLabel).toSet().toList()..sort();
    return ['all', ...tenures];
  }

  String _tenureLabel(LeadershipRecord record) {
    final end = record.endDate;
    final startYear = record.startDate.year;
    final endYear = end?.year ?? DateTime.now().year;
    return startYear == endYear ? '$startYear' : '$startYear–$endYear';
  }


  List<LeadershipRecord> _filteredRecords(LeadershipPosition position) {
    return _records.where((record) {
      if (record.position != position) return false;
      if (_tenureFilter != 'all' && _tenureLabel(record) != _tenureFilter) return false;
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: colorScheme.primary,
          ),
        ),
      );
    }

    if (!_hasAccess) {
      return Scaffold(
        appBar: const CustomAppBar(
          title: 'Access Denied',
          showBackButton: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 72,
                  color: colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.error,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.',
                  style: TextStyle(
                    fontSize: 15,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'This portal is restricted to Board of Directors,\nTrustees, Leaders, and Administrators only.',
                  style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Board of Directors & Trustees',
        showBackButton: true,
        actions: [
          if (_isAdmin)
            IconButton(
              tooltip: 'Add Leader',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _showLeaderEditor(),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Message
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: colorScheme.outlineVariant),
              ),
              color: colorScheme.primaryContainer.withValues(alpha: 0.35),
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.admin_panel_settings_rounded,
                            color: colorScheme.onPrimaryContainer,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        FutureBuilder<UserProfile?>(
                          future: _currentUserId != null
                              ? _profileService
                                  .getUserProfileModel(_currentUserId!)
                              : Future<UserProfile?>.value(null),
                          builder: (context, snapshot) {
                            final profile = snapshot.data;
                            final userEmail = profile?.fullName?.isNotEmpty == true
                                ? profile!.fullName!
                                : profile?.email ?? 'Administrator';
                            return Expanded(
                              child: Text(
                                'Welcome, $userEmail',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'This is the exclusive Board of Directors and Trustees portal for ALIVE Nigeria leadership.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Icon(Icons.history_edu_rounded, color: colorScheme.primary, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Leadership by tenure',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _tenureFilter,
                      borderRadius: BorderRadius.circular(12),
                      dropdownColor: colorScheme.surface,
                      items: _tenures
                          .map((tenure) => DropdownMenuItem(
                                value: tenure,
                                child: Text(
                                  tenure == 'all' ? 'All Tenures' : tenure,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurface,
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _tenureFilter = value);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Board of Directors Section
            _buildLeadershipSection(
              'Directors',
              Icons.business_center_rounded,
              _filteredRecords(LeadershipPosition.bod),
              fallback: [
                _buildMemberCard(
                  'Nwoko Patience Mfon',
                  'Executive President & Chairman',
                  'Leading the strategic direction of ALIVE Nigeria',
                  Icons.person_rounded,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Trustees Section
            _buildLeadershipSection(
              'Board of Trustees',
              Icons.security_rounded,
              _filteredRecords(LeadershipPosition.trustee),
              fallback: [
                _buildMemberCard(
                  'Trustee Position 1',
                  'Chairman',
                  'Overseeing organizational governance and compliance',
                  Icons.gavel_rounded,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Quick Actions
            Text(
              'Quick Actions',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Board Meeting',
                    Icons.video_call_rounded,
                    'Start a board meeting',
                    () => _startBoardMeeting(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Reports',
                    Icons.assessment_rounded,
                    'View organizational reports',
                    () => _viewReports(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Decisions',
                    Icons.how_to_vote_rounded,
                    'Board decisions & voting',
                    () => _viewDecisions(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Documents',
                    Icons.folder_rounded,
                    'Access board documents',
                    () => _viewDocuments(),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildActionCard(
                    'Meeting Files',
                    Icons.share_rounded,
                    'Share meeting files',
                    () => context.go('/meeting-file-sharing'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildActionCard(
                    'Meeting Notes',
                    Icons.note_alt_rounded,
                    'Fathom-style notes + transcript',
                    () => _openMeetingNotes(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLeadershipSection(
    String title,
    IconData icon,
    List<LeadershipRecord> records, {
    required List<Widget> fallback,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (records.isEmpty) ...fallback else ...records.map(_buildLeadershipCard),
      ],
    );
  }

  Widget _buildLeadershipCard(LeadershipRecord record) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFormat = DateFormat('MMM yyyy');
    final tenure = _tenureLabel(record);
    final range =
        '${dateFormat.format(record.startDate)} - ${record.endDate == null ? 'Present' : dateFormat.format(record.endDate!)}';

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                record.position == LeadershipPosition.trustee
                    ? Icons.security_rounded
                    : Icons.person_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          record.userName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildServiceStatusBadge(record),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    record.positionTitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Tenure: $tenure ($range)',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_isAdmin)
              IconButton(
                tooltip: 'Edit Leader & Tenure',
                icon: Icon(Icons.edit_note_rounded, color: colorScheme.primary),
                onPressed: () => _showLeaderEditor(record: record),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStatusBadge(LeadershipRecord record) {
    final colorScheme = Theme.of(context).colorScheme;
    Color bg;
    Color fg;
    String label;

    switch (record.status) {
      case ServiceStatus.active:
        bg = colorScheme.primaryContainer;
        fg = colorScheme.onPrimaryContainer;
        label = 'ACTIVE';
        break;
      case ServiceStatus.completed:
        bg = colorScheme.secondaryContainer;
        fg = colorScheme.onSecondaryContainer;
        label = 'COMPLETED';
        break;
      case ServiceStatus.archived:
        bg = colorScheme.surfaceContainerHighest;
        fg = colorScheme.onSurfaceVariant;
        label = 'ARCHIVED';
        break;
      default:
        bg = colorScheme.surfaceContainerHighest;
        fg = colorScheme.onSurfaceVariant;
        label = record.status.name.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _openMeetingNotes() {
    Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LeaderMeetingTranscriptionScreen()));
  }

  Future<void> _showLeaderEditor({LeadershipRecord? record}) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nameController =
        TextEditingController(text: record?.userName ?? '');
    final emailController =
        TextEditingController(text: record?.userEmail ?? '');
    final titleController =
        TextEditingController(text: record?.positionTitle ?? '');
    var position = record?.position == LeadershipPosition.trustee
        ? LeadershipPosition.trustee
        : LeadershipPosition.bod;
    var start = record?.startDate ?? DateTime.now();
    DateTime? end = record?.endDate;
    bool isCurrentlyServing = end == null;
    var status = record?.status ?? ServiceStatus.active;
    final dateFormat = DateFormat('MMM dd, yyyy');

    int calculateYearsOfService(DateTime s, DateTime? e) {
      final effectiveEnd = e ?? DateTime.now();
      final diffDays = effectiveEnd.difference(s).inDays;
      if (diffDays <= 0) return 0;
      final years = (diffDays / 365.25).round();
      return years < 1 ? 1 : years;
    }

    await showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final computedYears =
              calculateYearsOfService(start, isCurrentlyServing ? null : end);

          return AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24)),
            title: Row(
              children: [
                Icon(
                  record == null
                      ? Icons.person_add_alt_1_rounded
                      : Icons.edit_note_rounded,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    record == null
                        ? 'Add Leadership Member'
                        : 'Edit Leader & Tenure',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: 'Full Name *',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email Address *',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                        labelText: 'Position / Role Title *',
                        hintText: 'e.g. Chairman, Secretary, Trustee',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<LeadershipPosition>(
                      initialValue: position,
                      decoration: InputDecoration(
                        labelText: 'Leadership Role',
                        prefixIcon: const Icon(Icons.work_outline),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: LeadershipPosition.bod,
                          child: Text('Board of Directors (2-year term)'),
                        ),
                        DropdownMenuItem(
                          value: LeadershipPosition.trustee,
                          child: Text('Board of Trustees'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() => position = value);
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Tenure & Service Status',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ServiceStatus>(
                      initialValue: status,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: const Icon(Icons.verified_user_outlined),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: ServiceStatus.active,
                          child: Text('Active (Currently Serving)'),
                        ),
                        DropdownMenuItem(
                          value: ServiceStatus.completed,
                          child: Text('Completed (Term Ended)'),
                        ),
                        DropdownMenuItem(
                          value: ServiceStatus.archived,
                          child: Text('Archived (Former Leader)'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setDialogState(() {
                            status = value;
                            if (status == ServiceStatus.archived ||
                                status == ServiceStatus.completed) {
                              isCurrentlyServing = false;
                              end ??= DateTime.now();
                            } else if (status == ServiceStatus.active) {
                              isCurrentlyServing = true;
                              end = null;
                            }
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: colorScheme.outlineVariant),
                      ),
                      leading: Icon(Icons.calendar_today_rounded,
                          color: colorScheme.primary, size: 20),
                      title: const Text('Start Date',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text(dateFormat.format(start),
                          style: TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold)),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: start,
                          firstDate: DateTime(1980),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setDialogState(() => start = picked);
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Currently Serving',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      subtitle: Text(
                        isCurrentlyServing
                            ? 'Ongoing term (no end date)'
                            : 'Tenure ended — archived or completed',
                        style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.onSurfaceVariant),
                      ),
                      value: isCurrentlyServing,
                      onChanged: (val) {
                        setDialogState(() {
                          isCurrentlyServing = val;
                          if (isCurrentlyServing) {
                            end = null;
                            if (status == ServiceStatus.archived ||
                                status == ServiceStatus.completed) {
                              status = ServiceStatus.active;
                            }
                          } else {
                            end ??= DateTime.now();
                            if (status == ServiceStatus.active) {
                              status = ServiceStatus.completed;
                            }
                          }
                        });
                      },
                    ),
                    if (!isCurrentlyServing) ...[
                      const SizedBox(height: 4),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: colorScheme.outlineVariant),
                        ),
                        leading: Icon(Icons.event_busy_rounded,
                            color: colorScheme.error, size: 20),
                        title: const Text('End Date',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          end != null
                              ? dateFormat.format(end!)
                              : 'Select end date',
                          style: TextStyle(
                            color: end != null
                                ? colorScheme.onSurface
                                : colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: end ?? DateTime.now(),
                            firstDate: start,
                            lastDate:
                                DateTime.now().add(const Duration(days: 3650)),
                          );
                          if (picked != null) {
                            setDialogState(() => end = picked);
                          }
                        },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 16, color: colorScheme.onSurfaceVariant),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Calculated duration: ~$computedYears year(s) of service',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              if (record != null && status != ServiceStatus.archived)
                TextButton.icon(
                  onPressed: () {
                    setDialogState(() {
                      status = ServiceStatus.archived;
                      isCurrentlyServing = false;
                      end ??= DateTime.now();
                    });
                  },
                  icon: Icon(Icons.archive_outlined,
                      size: 18, color: colorScheme.error),
                  label: Text('Archive Leader',
                      style: TextStyle(color: colorScheme.error)),
                ),
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final name = nameController.text.trim();
                  final email = emailController.text.trim();
                  final title = titleController.text.trim();
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(dialogCtx);
                  if (name.isEmpty || email.isEmpty || title.isEmpty) {
                    messenger.showSnackBar(
                      const SnackBar(
                          content: Text('Please fill all required fields.')),
                    );
                    return;
                  }
                  final years = calculateYearsOfService(
                      start, isCurrentlyServing ? null : end);
                  try {
                    if (record == null) {
                      await _leadershipService.createRecord(LeadershipRecord(
                        id: 'new',
                        userId: _currentUserId ?? 'admin',
                        userName: name,
                        userEmail: email,
                        position: position,
                        positionTitle: title,
                        startDate: start,
                        endDate: isCurrentlyServing ? null : end,
                        yearsOfService: years,
                        status: status,
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ));
                    } else {
                      await _leadershipService.updateRecord(record.id, {
                        'user_name': name,
                        'user_email': email,
                        'position': position.name,
                        'position_title': title,
                        'start_date': start.toIso8601String(),
                        'end_date': isCurrentlyServing
                            ? null
                            : end?.toIso8601String(),
                        'years_of_service': years,
                        'status': status.name,
                      });
                    }
                    if (!mounted) return;
                    nav.pop();
                    await _loadLeadership();
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text(record == null
                            ? 'Leader record created successfully.'
                            : 'Leader record updated successfully.'),
                      ),
                    );
                  } catch (e) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text('Save failed: $e')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMemberCard(
      String name, String position, String description, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: colorScheme.primaryContainer,
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              position,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Widget _buildActionCard(
      String title, IconData icon, String subtitle, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      color: colorScheme.surface,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14.0, vertical: 16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  size: 26,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 11,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startBoardMeeting() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Expanded(child: Text('Start Board Meeting')),
            IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Choose how to start the board meeting:'),
            SizedBox(height: 16),
            Text('• Quick Meeting: Start immediately'),
            Text('• Scheduled Meeting: Join existing meeting'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _startQuickMeeting();
            },
            child: const Text('Quick Meeting'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToConferencePlatform();
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
            ),
            child: const Text('Conference Platform'),
          ),
        ],
      ),
    );
  }

  void _startQuickMeeting() {
    final roomName = 'board-meeting-${DateTime.now().millisecondsSinceEpoch}';
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Expanded(child: Text('Quick Board Meeting')),
            IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Meeting room created successfully!'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                children: [
                  Text(
                    'Room Name:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    roomName,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Share this room name with other board members to join the meeting.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _joinMeeting(roomName);
            },
            style: FilledButton.styleFrom(
              backgroundColor: colorScheme.tertiary,
              foregroundColor: colorScheme.onTertiary,
            ),
            child: const Text('Join Meeting'),
          ),
        ],
      ),
    );
  }

  void _navigateToConferencePlatform() {
    context.push('/conference');
  }

  void _viewReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardReportsScreen(),
      ),
    );
  }

  void _viewDecisions() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardDecisionsScreen(),
      ),
    );
  }

  void _viewDocuments() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const BoardDocumentsScreen(),
      ),
    );
  }

  Future<void> _joinMeeting(String _) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveKitMeetingScreen(
          meetingType: MeetingType.board,
        ),
      ),
    );
  }
}

