import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants/chapters.dart';
import '../../models/board_models.dart';
import '../../services/appwrite_board_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../services/auth_service.dart';
import '../../services/file_picker_facade.dart';
import '../../services/office_access_service.dart';
import '../../services/org_structure_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/custom_app_bar.dart';

/// Hierarchy levels for organizational reporting
enum ReportingLevel {
  all,
  chapter,
  directorate,
  executive,
  board,
}

class ChapterReportsScreen extends StatefulWidget {
  final String? initialChapter;
  final ReportingLevel initialLevel;
  final bool openSubmitOnLaunch;

  const ChapterReportsScreen({
    super.key,
    this.initialChapter,
    this.initialLevel = ReportingLevel.all,
    this.openSubmitOnLaunch = false,
  });

  @override
  State<ChapterReportsScreen> createState() => _ChapterReportsScreenState();
}

class _ChapterReportsScreenState extends State<ChapterReportsScreen> {
  final AppwriteBoardService _boardService = AppwriteBoardService.instance;
  final AuthService _authService = AuthService.instance;
  final RoleAccessService _roleService = RoleAccessService.instance;
  final OfficeAccessService _officeService = OfficeAccessService.instance;
  final OrgStructureService _orgStructureService = OrgStructureService.instance;

  List<BoardReport> _reports = [];
  bool _isLoading = true;
  String _selectedChapter = 'all';
  String _selectedStatus = 'all';
  ReportingLevel _selectedLevel = ReportingLevel.all;
  String _searchQuery = '';

  bool _holdsPresidentOffice = false;
  bool _holdsDirectorOffice = false;
  bool _holdsCoordinatorOffice = false;
  List<String> _dynamicDirectors = [];

  final List<String> _statuses = [
    'all',
    'submitted',
    'reviewed',
    'approved',
    'draft',
  ];

  @override
  void initState() {
    super.initState();
    _selectedLevel = widget.initialLevel;
    if (widget.initialChapter != null) {
      _selectedChapter = widget.initialChapter!;
    }
    _initDynamicOffices();
    _loadReports();
    if (widget.openSubmitOnLaunch) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _showSubmitChapterReportDialog();
      });
    }
  }

  Future<void> _initDynamicOffices() async {
    try {
      final user = _authService.currentUser;
      if (user != null) {
        final offices = await _officeService.officesFor(
          userId: user.uid,
          email: user.email,
        );
        final isPres = offices.any((o) =>
            o.officeId == 'executive_president' || o.officeId == 'president');
        final isDir = offices.any((o) =>
            o.officeId.startsWith('director_') ||
            o.officeId == 'secretary' ||
            o.officeId == 'treasurer' ||
            o.officeId == 'speaker');
        final isCoord = offices.any((o) => o.officeId.contains('coordinator'));

        if (mounted) {
          setState(() {
            _holdsPresidentOffice = isPres;
            _holdsDirectorOffice = isDir;
            _holdsCoordinatorOffice = isCoord;
          });
        }
      }

      final dirTitles = await _orgStructureService.getDirectorTitles();
      if (mounted && dirTitles.isNotEmpty) {
        setState(() {
          _dynamicDirectors = dirTitles;
        });
      }
    } catch (_) {}
  }

  bool get _isCoordinator =>
      _roleService.hasRole('coordinator') ||
      _roleService.hasRole('leader') ||
      _holdsCoordinatorOffice ||
      _roleService.hasRole('admin');

  bool get _isDirector =>
      _roleService.hasRole('director') ||
      _roleService.hasRole('leader') ||
      _holdsDirectorOffice ||
      _roleService.hasRole('admin');

  bool get _isPresident =>
      _roleService.hasRole('president') ||
      _roleService.hasRole('super_admin') ||
      _holdsPresidentOffice ||
      _roleService.hasRole('admin');

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final rawReports = await _boardService.getBoardReports();
      final mapped = rawReports.map((e) => BoardReport.fromJson(e)).toList();

      // Sort newest first
      mapped.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (mounted) {
        setState(() {
          _reports = mapped;
        });
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Error loading reports: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _getReportLevel(BoardReport report) {
    final metaLevel = report.metadata?['hierarchy_level']?.toString().toLowerCase();
    if (metaLevel != null && metaLevel.isNotEmpty) {
      return metaLevel;
    }
    if (report.category == 'board' || report.title.toLowerCase().contains('board')) {
      return 'board';
    }
    if (report.category == 'executive' || report.title.toLowerCase().contains('executive')) {
      return 'executive';
    }
    if (report.category == 'directorate' || report.title.toLowerCase().contains('directorate')) {
      return 'directorate';
    }
    return 'chapter';
  }

  List<BoardReport> get _filteredReports {
    return _reports.where((report) {
      final level = _getReportLevel(report);

      // Level filter
      if (_selectedLevel != ReportingLevel.all) {
        final targetLevelName = _selectedLevel.name.toLowerCase();
        if (level != targetLevelName) return false;
      }

      // Status filter
      final statusMatch =
          _selectedStatus == 'all' || report.status.toLowerCase() == _selectedStatus.toLowerCase();

      // Chapter filter
      final reportChapter =
          report.metadata?['chapter'] ?? report.metadata?['chapter_name'] ?? '';
      final chapterMatch = _selectedChapter == 'all' ||
          reportChapter.toString().toLowerCase() == _selectedChapter.toLowerCase() ||
          report.title.toLowerCase().contains(_selectedChapter.toLowerCase());

      // Search query match
      final queryMatch = _searchQuery.isEmpty ||
          report.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.authorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.content.toLowerCase().contains(_searchQuery.toLowerCase());

      return statusMatch && chapterMatch && queryMatch;
    }).toList();
  }

  int _countForLevel(ReportingLevel level) {
    if (level == ReportingLevel.all) return _reports.length;
    return _reports.where((r) => _getReportLevel(r) == level.name.toLowerCase()).length;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Hierarchical Reports',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadReports,
            tooltip: 'Refresh Reports',
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. Hierarchy Filter Strip with Icon-with-Name Pills
          _buildHierarchyPillStrip(theme),

          // 2. Search & Chapter Filter Header
          _buildSearchAndFilterHeader(colorScheme),

          // 3. Role-Gated Action Bar
          _buildRoleGatedActionBar(theme),

          // 4. Reports List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? _buildEmptyState(colorScheme, theme)
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            return _buildReportCard(_filteredReports[index], theme);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // --- 1. Hierarchy Filter Strip ---
  Widget _buildHierarchyPillStrip(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4)),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildHierarchyPill(
              ReportingLevel.all,
              'All',
              Icons.layers_outlined,
              theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            _buildHierarchyPill(
              ReportingLevel.chapter,
              'Chapter',
              Icons.location_city_rounded,
              const Color(0xFF1976D2),
            ),
            const SizedBox(width: 8),
            _buildHierarchyPill(
              ReportingLevel.directorate,
              'Directorate',
              Icons.account_tree_rounded,
              const Color(0xFF7B1FA2),
            ),
            const SizedBox(width: 8),
            _buildHierarchyPill(
              ReportingLevel.executive,
              'Executive',
              Icons.verified_user_rounded,
              const Color(0xFFE65100),
            ),
            const SizedBox(width: 8),
            _buildHierarchyPill(
              ReportingLevel.board,
              'Board (BOD)',
              Icons.gavel_rounded,
              const Color(0xFF2E7D32),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHierarchyPill(
    ReportingLevel level,
    String label,
    IconData icon,
    Color activeColor,
  ) {
    final isSelected = _selectedLevel == level;
    final count = _countForLevel(level);

    return InkWell(
      onTap: () => setState(() => _selectedLevel = level),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 2. Search & Chapter Filter Header ---
  Widget _buildSearchAndFilterHeader(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search reports or authors...',
                prefixIcon: const Icon(Icons.search, size: 18),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: DropdownButtonFormField<String>(
              value: _selectedChapter,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Chapter',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: [
                const DropdownMenuItem(value: 'all', child: Text('All Chapters', style: TextStyle(fontSize: 12))),
                ...ChapterConstants.availableChapters.map(
                  (c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12))),
                ),
              ],
              onChanged: (val) => setState(() => _selectedChapter = val ?? 'all'),
            ),
          ),
        ],
      ),
    );
  }

  // --- 3. Role-Gated Action Bar ---
  Widget _buildRoleGatedActionBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: theme.colorScheme.surfaceContainerLowest,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            // Member / Officer: Submit Chapter Report
            ElevatedButton.icon(
              icon: const Icon(Icons.add_chart_rounded, size: 16),
              label: const Text('Submit Report', style: TextStyle(fontSize: 12)),
              onPressed: () => _showSubmitChapterReportDialog(),
              style: ElevatedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              ),
            ),
            const SizedBox(width: 8),

            // Coordinator: Compile Chapter -> Directorate
            if (_isCoordinator) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.post_add_rounded, size: 16),
                label: const Text('Compile for Director', style: TextStyle(fontSize: 12)),
                onPressed: () => _showCompileCoordinatorDialog(),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: const Color(0xFF7B1FA2),
                  side: const BorderSide(color: Color(0xFF7B1FA2)),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Director: Compile Directorate -> President
            if (_isDirector) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.publish_rounded, size: 16),
                label: const Text('Compile for President', style: TextStyle(fontSize: 12)),
                onPressed: () => _showCompileDirectorDialog(),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: const Color(0xFFE65100),
                  side: const BorderSide(color: Color(0xFFE65100)),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // President / Admin: Compile Executive -> Board of Directors (BOD)
            if (_isPresident) ...[
              OutlinedButton.icon(
                icon: const Icon(Icons.account_balance_rounded, size: 16),
                label: const Text('Compile for Board (BOD)', style: TextStyle(fontSize: 12)),
                onPressed: () => _showCompilePresidentDialog(),
                style: OutlinedButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF2E7D32)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- 4. Report Card ---
  Widget _buildReportCard(BoardReport report, ThemeData theme) {
    final level = _getReportLevel(report);
    final colorScheme = theme.colorScheme;
    final chapterName =
        report.metadata?['chapter'] ?? report.metadata?['chapter_name'] ?? 'General';
    final routedTo = report.metadata?['routed_to_name']?.toString() ?? '';
    final attendees = report.metadata?['attendees']?.toString();
    final hasAttachment = report.attachments.isNotEmpty;

    Color levelColor;
    IconData levelIcon;
    String levelTitle;

    switch (level) {
      case 'board':
        levelColor = const Color(0xFF2E7D32);
        levelIcon = Icons.gavel_rounded;
        levelTitle = 'Board Report';
        break;
      case 'executive':
        levelColor = const Color(0xFFE65100);
        levelIcon = Icons.verified_user_rounded;
        levelTitle = 'Executive Report';
        break;
      case 'directorate':
        levelColor = const Color(0xFF7B1FA2);
        levelIcon = Icons.account_tree_rounded;
        levelTitle = 'Directorate Report';
        break;
      case 'chapter':
      default:
        levelColor = const Color(0xFF1976D2);
        levelIcon = Icons.location_city_rounded;
        levelTitle = 'Chapter Report';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: levelColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => _viewReportDetails(report),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Hierarchy Level Pill + Status Badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: levelColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: levelColor.withValues(alpha: 0.5)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(levelIcon, size: 13, color: levelColor),
                        const SizedBox(width: 5),
                        Text(
                          levelTitle,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: levelColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      chapterName.toString().toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const Spacer(),
                  _buildStatusBadge(report.status),
                ],
              ),
              const SizedBox(height: 8),

              // Title
              Text(
                report.title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  height: 1.25,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Author & Date
              Text(
                'By ${report.authorName} • ${DateFormat('MMM dd, yyyy').format(report.createdAt)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 8),

              // Content Preview (2 lines)
              Text(
                report.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.35,
                ),
              ),

              // Apex / Leadership Directive Banner if feedback exists
              if (report.metadata?['review_feedback'] != null &&
                  report.metadata!['review_feedback'].toString().trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: (report.metadata?['apex_directive'] == true ? Colors.amber : Colors.blue)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: (report.metadata?['apex_directive'] == true ? Colors.amber : Colors.blue)
                          .withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        report.metadata?['apex_directive'] == true
                            ? Icons.verified_user_rounded
                            : Icons.rate_review_outlined,
                        size: 14,
                        color: report.metadata?['apex_directive'] == true
                            ? Colors.amber.shade800
                            : Colors.blue.shade700,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${report.metadata?['reviewer_office'] ?? "Leadership"}: "${report.metadata!['review_feedback']}"',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: report.metadata?['apex_directive'] == true
                                ? Colors.amber.shade900
                                : Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 10),

              // Bottom Metadata Strip
              Row(
                children: [
                  if (routedTo.isNotEmpty) ...[
                    Icon(Icons.send_rounded, size: 12, color: colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'To: $routedTo',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (attendees != null && attendees.isNotEmpty && attendees != '0') ...[
                    Icon(Icons.groups_rounded, size: 13, color: colorScheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      '$attendees attendees',
                      style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (hasAttachment) ...[
                    Icon(Icons.attach_file_rounded, size: 13, color: colorScheme.secondary),
                    const SizedBox(width: 2),
                    Text(
                      'Attachment',
                      style: TextStyle(fontSize: 11, color: colorScheme.secondary),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    'View Details →',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colorScheme.primary,
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

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        break;
      case 'reviewed':
        color = Colors.blue;
        break;
      case 'submitted':
        color = Colors.orange;
        break;
      case 'draft':
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme colorScheme, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assessment_outlined, size: 56, color: colorScheme.outline),
          const SizedBox(height: 14),
          Text(
            'No reports found in this section',
            style: theme.textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Use the buttons above to submit or compile reports',
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  // --- 5. Dialog: Submit Chapter Report (Tier 1) ---
  void _showSubmitChapterReportDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final attendeesController = TextEditingController();
    final challengesController = TextEditingController();
    String selectedChapter =
        _selectedChapter != 'all' ? _selectedChapter : ChapterConstants.availableChapters.first;

    final currentUserRole = _roleService.getCurrentUserRole()?.toLowerCase() ?? '';
    String selectedReportingArm = 'coordinator';
    if (currentUserRole == 'field_worker') {
      selectedReportingArm = 'field_worker';
    } else if (currentUserRole == 'campus_missionary') {
      selectedReportingArm = 'campus_missionary';
    } else if (currentUserRole == 'amtc_team') {
      selectedReportingArm = 'amtc_team';
    }

    PlatformFile? attachedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.location_city_rounded, color: Color(0xFF1976D2), size: 20),
              SizedBox(width: 8),
              Text('Submit Chapter Report'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedChapter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Chapter *',
                      border: OutlineInputBorder(),
                    ),
                    items: ChapterConstants.availableChapters.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedChapter = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedReportingArm,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Reporting Category / Destination *',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'coordinator',
                        child: Text('Chapter Member → Chapter Coordinator'),
                      ),
                      DropdownMenuItem(
                        value: 'field_worker',
                        child: Text('Field Workers → Director of Evangelism & Missions'),
                      ),
                      DropdownMenuItem(
                        value: 'campus_missionary',
                        child: Text('Campus Missionary Team → Director of Evangelism & Programming'),
                      ),
                      DropdownMenuItem(
                        value: 'amtc_team',
                        child: Text('AMTC Team → Director of AMTC'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedReportingArm = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Report Title *',
                      hintText: 'e.g. Monthly Outreach & Member Discipleship',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: attendeesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Active Attendees / Members',
                      hintText: 'e.g. 45',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: contentController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Summary & Ministry Activities *',
                      hintText: 'Detail meetings held, ministry outreach, and accomplishments...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: challengesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Challenges & Needs (Optional)',
                      hintText: 'Key hurdles faced or requests for leadership support...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Optional Image or Document Attachment
                  _buildAttachmentPicker(
                    attachedFile: attachedFile,
                    onPick: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Select Photo or Report Document',
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'xlsx'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() {
                          attachedFile = result.files.first;
                        });
                      }
                    },
                    onRemove: () {
                      setDialogState(() {
                        attachedFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      if (titleController.text.trim().isEmpty ||
                          contentController.text.trim().isEmpty) {
                        ToastUtils.showError('Title and activities content are required');
                        return;
                      }

                      setDialogState(() => isUploading = true);
                      try {
                        final user = _authService.currentUser;
                        final authorName = user?.name ?? 'Chapter Member';
                        final authorId = user?.uid ?? 'unknown';

                        List<String> attachments = [];
                        if (attachedFile != null && attachedFile!.bytes != null) {
                          final fileUrl = await AppwriteStorageService.instance.uploadContentFile(
                            bytes: attachedFile!.bytes!,
                            fileName: attachedFile!.name,
                            contentType: attachedFile!.extension == 'pdf'
                                ? 'application/pdf'
                                : 'image/jpeg',
                          );
                          attachments.add(fileUrl);
                        }

                        await _boardService.addBoardReport({
                          'title': titleController.text.trim(),
                          'content': contentController.text.trim(),
                          'category': 'operational',
                          'author_id': authorId,
                          'author_name': authorName,
                          'status': 'submitted',
                          'attachments': attachments,
                          'metadata': {
                            'hierarchy_level': 'chapter',
                            'chapter': selectedChapter,
                            'chapter_name': selectedChapter,
                            'reporting_arm': selectedReportingArm,
                            'routed_to_role': selectedReportingArm == 'field_worker' ||
                                    selectedReportingArm == 'campus_missionary' ||
                                    selectedReportingArm == 'amtc_team'
                                ? 'director'
                                : 'coordinator',
                            'routed_to_name': selectedReportingArm == 'field_worker'
                                ? 'Director of Evangelism & Missions'
                                : selectedReportingArm == 'campus_missionary'
                                    ? 'Director of Evangelism & Programming'
                                    : selectedReportingArm == 'amtc_team'
                                        ? 'Director, ALIVE Mission Training Center (AMTC)'
                                        : '$selectedChapter Coordinator',
                            'attendees': attendeesController.text.trim(),
                            'challenges': challengesController.text.trim(),
                            if (attachedFile != null) 'attachment_name': attachedFile!.name,
                          },
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          final dest = selectedReportingArm == 'field_worker' ||
                                  selectedReportingArm == 'campus_missionary' ||
                                  selectedReportingArm == 'amtc_team'
                              ? 'assigned Director'
                              : 'Coordinator';
                          ToastUtils.showSuccess('Report submitted to $dest');
                          _loadReports();
                        }
                      } catch (e) {
                        ToastUtils.showError('Failed to submit report: $e');
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isUploading = false);
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. Dialog: Coordinator Compile for Director (Tier 2) ---
  void _showCompileCoordinatorDialog() {
    final titleController = TextEditingController();
    final summaryController = TextEditingController();
    String selectedChapter =
        _selectedChapter != 'all' ? _selectedChapter : ChapterConstants.availableChapters.first;
    // Departmental Directors in ALIVE Nigeria (dynamic from OrgStructureService)
    final directorsList = _dynamicDirectors.isNotEmpty
        ? _dynamicDirectors
        : [
            'Director of Evangelism',
            'Director of Logistics',
            'Communication Director',
            'Director, ALIVE Mission Training Center (AMTC)',
            'Treasurer',
            'Secretary',
          ];
    String selectedDirector = directorsList.first;

    // Pre-calculate chapter reports
    final chapterReports = _reports.where((r) {
      final rChapter = r.metadata?['chapter'] ?? r.metadata?['chapter_name'] ?? '';
      return rChapter.toString().toLowerCase() == selectedChapter.toLowerCase();
    }).toList();

    int totalAttendees = 0;
    for (final r in chapterReports) {
      final att = int.tryParse(r.metadata?['attendees']?.toString() ?? '0') ?? 0;
      totalAttendees += att;
    }

    titleController.text = 'Q4 Comprehensive Report - $selectedChapter Chapter';
    summaryController.text =
        'Compiled from ${chapterReports.length} chapter activities. Total active attendees: $totalAttendees.\n\nKey accomplishments:\n- Active discipleship sessions held\n- Outreach tracts distributed\n\nChallenges:\n- Need additional ministry literature materials.';

    PlatformFile? attachedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.account_tree_rounded, color: Color(0xFF7B1FA2), size: 20),
              SizedBox(width: 8),
              Text('Compile for Director'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedChapter,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Compiling for Chapter *',
                      border: OutlineInputBorder(),
                    ),
                    items: ChapterConstants.availableChapters.map((c) {
                      return DropdownMenuItem(value: c, child: Text(c));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedChapter = val;
                          titleController.text = 'Comprehensive Report - $selectedChapter Chapter';
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDirector,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Route to Departmental Director *',
                      border: OutlineInputBorder(),
                    ),
                    items: directorsList.map((d) {
                      return DropdownMenuItem(value: d, child: Text(d, style: const TextStyle(fontSize: 12)));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedDirector = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Compiled Report Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Directorate Executive Summary *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildAttachmentPicker(
                    attachedFile: attachedFile,
                    onPick: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Select Supplementary Document or Photo',
                        type: FileType.custom,
                        allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf', 'docx', 'xlsx'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() {
                          attachedFile = result.files.first;
                        });
                      }
                    },
                    onRemove: () {
                      setDialogState(() {
                        attachedFile = null;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        final user = _authService.currentUser;
                        final authorName = user?.name ?? 'Chapter Coordinator';

                        List<String> attachments = [];
                        if (attachedFile != null && attachedFile!.bytes != null) {
                          final fileUrl = await AppwriteStorageService.instance.uploadContentFile(
                            bytes: attachedFile!.bytes!,
                            fileName: attachedFile!.name,
                            contentType: 'application/pdf',
                          );
                          attachments.add(fileUrl);
                        }

                        await _boardService.addBoardReport({
                          'title': titleController.text.trim(),
                          'content': summaryController.text.trim(),
                          'category': 'directorate',
                          'author_id': user?.uid ?? 'unknown',
                          'author_name': authorName,
                          'status': 'submitted',
                          'attachments': attachments,
                          'metadata': {
                            'hierarchy_level': 'directorate',
                            'chapter': selectedChapter,
                            'chapter_name': selectedChapter,
                            'routed_to_role': 'director',
                            'routed_to_name': selectedDirector,
                            'compiled_reports_count': chapterReports.length,
                            if (attachedFile != null) 'attachment_name': attachedFile!.name,
                          },
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ToastUtils.showSuccess('Report compiled and escalated to Director');
                          _loadReports();
                        }
                      } catch (e) {
                        ToastUtils.showError('Failed to compile report: $e');
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isUploading = false);
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Compile & Escalate'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 7. Dialog: Director Compile for President (Tier 3) ---
  void _showCompileDirectorDialog() {
    final titleController = TextEditingController(text: 'Directorate Quarterly Review & Departmental Report');
    final summaryController = TextEditingController(
      text:
          'Consolidated Directorate Report across all chapters.\n\nEvangelism activities and missionary centers are progressing steadily. Key resources allocated to zonal coordinates.',
    );

    PlatformFile? attachedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.publish_rounded, color: Color(0xFFE65100), size: 20),
              SizedBox(width: 8),
              Text('Compile for President'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This report synthesizes all chapter activity into an Executive submission for the Executive President.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Directorate Report Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Departmental Summary & Policy Requests *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildAttachmentPicker(
                    attachedFile: attachedFile,
                    onPick: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Attach Directorate Document',
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'docx', 'xlsx', 'jpg', 'png'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() => attachedFile = result.files.first);
                      }
                    },
                    onRemove: () => setDialogState(() => attachedFile = null),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        final user = _authService.currentUser;
                        List<String> attachments = [];
                        if (attachedFile != null && attachedFile!.bytes != null) {
                          final fileUrl = await AppwriteStorageService.instance.uploadContentFile(
                            bytes: attachedFile!.bytes!,
                            fileName: attachedFile!.name,
                            contentType: 'application/pdf',
                          );
                          attachments.add(fileUrl);
                        }

                        await _boardService.addBoardReport({
                          'title': titleController.text.trim(),
                          'content': summaryController.text.trim(),
                          'category': 'executive',
                          'author_id': user?.uid ?? 'unknown',
                          'author_name': user?.name ?? 'Departmental Director',
                          'status': 'submitted',
                          'attachments': attachments,
                          'metadata': {
                            'hierarchy_level': 'executive',
                            'chapter': 'National',
                            'chapter_name': 'National Directorate',
                            'routed_to_role': 'president',
                            'routed_to_name': 'Executive President',
                            if (attachedFile != null) 'attachment_name': attachedFile!.name,
                          },
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ToastUtils.showSuccess('Report submitted to Executive President');
                          _loadReports();
                        }
                      } catch (e) {
                        ToastUtils.showError('Failed to submit report: $e');
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isUploading = false);
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Submit to President'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 8. Dialog: President Compile for Board (Tier 4) ---
  void _showCompilePresidentDialog() {
    final titleController = TextEditingController(text: 'ALIVE Nigeria Executive Governance & Operations Report');
    final summaryController = TextEditingController(
      text:
          'Executive presentation to the Board of Directors and Trustees.\n\nOrganizational growth, financial accountability, and missionary activities across Nigeria are presented for board review and minuted adoption.',
    );

    PlatformFile? attachedFile;
    bool isUploading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.gavel_rounded, color: Color(0xFF2E7D32), size: 20),
              SizedBox(width: 8),
              Text('Compile for Board (BOD)'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'This report is published directly to the Board of Directors & Trustees portal for formal governance review, resolution adoption, and minuting.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Board Report Title *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: summaryController,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Executive Review & Board Recommendations *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),

                  _buildAttachmentPicker(
                    attachedFile: attachedFile,
                    onPick: () async {
                      final result = await FilePicker.platform.pickFiles(
                        dialogTitle: 'Attach Board Comprehensive PDF/Document',
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'docx', 'xlsx', 'jpg', 'png'],
                      );
                      if (result != null && result.files.isNotEmpty) {
                        setDialogState(() => attachedFile = result.files.first);
                      }
                    },
                    onRemove: () => setDialogState(() => attachedFile = null),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isUploading ? null : () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isUploading
                  ? null
                  : () async {
                      setDialogState(() => isUploading = true);
                      try {
                        final user = _authService.currentUser;
                        List<String> attachments = [];
                        if (attachedFile != null && attachedFile!.bytes != null) {
                          final fileUrl = await AppwriteStorageService.instance.uploadContentFile(
                            bytes: attachedFile!.bytes!,
                            fileName: attachedFile!.name,
                            contentType: 'application/pdf',
                          );
                          attachments.add(fileUrl);
                        }

                        await _boardService.addBoardReport({
                          'title': titleController.text.trim(),
                          'content': summaryController.text.trim(),
                          'category': 'board',
                          'author_id': user?.uid ?? 'unknown',
                          'author_name': user?.name ?? 'Executive President',
                          'status': 'submitted',
                          'attachments': attachments,
                          'metadata': {
                            'hierarchy_level': 'board',
                            'chapter': 'National',
                            'chapter_name': 'ALIVE Nigeria Board',
                            'routed_to_role': 'bod',
                            'routed_to_name': 'Board of Directors & Trustees',
                            if (attachedFile != null) 'attachment_name': attachedFile!.name,
                          },
                        });

                        if (context.mounted) {
                          Navigator.pop(context);
                          ToastUtils.showSuccess('Report presented to Board of Directors');
                          _loadReports();
                        }
                      } catch (e) {
                        ToastUtils.showError('Failed to present board report: $e');
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isUploading = false);
                        }
                      }
                    },
              child: isUploading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Present to Board'),
            ),
          ],
        ),
      ),
    );
  }

  // --- 9. View Report Details & Review Feedback Dialog ---
  void _viewReportDetails(BoardReport report) {
    final level = _getReportLevel(report);
    final chapterName =
        report.metadata?['chapter'] ?? report.metadata?['chapter_name'] ?? 'General';
    final routedTo = report.metadata?['routed_to_name']?.toString() ?? '';
    final existingFeedback = report.metadata?['review_feedback']?.toString() ?? '';
    final reviewedBy = report.metadata?['reviewed_by_name']?.toString() ?? '';
    final feedbackController = TextEditingController(text: existingFeedback);
    final hasAttachments = report.attachments.isNotEmpty;
    final attachmentName = report.metadata?['attachment_name']?.toString() ?? 'Attached Document';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Expanded(child: Text(report.title, style: const TextStyle(fontWeight: FontWeight.bold))),
            _buildStatusBadge(report.status),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Routing Info & Chapter Tag
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    Chip(
                      avatar: const Icon(Icons.location_city_rounded, size: 14),
                      label: Text(chapterName.toString()),
                      visualDensity: VisualDensity.compact,
                    ),
                    if (routedTo.isNotEmpty)
                      Chip(
                        avatar: const Icon(Icons.send_rounded, size: 14),
                        label: Text('To: $routedTo'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Submitted by ${report.authorName} on ${DateFormat('MMM dd, yyyy – hh:mm a').format(report.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 20),

                const Text(
                  'Report Summary & Activities:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  report.content,
                  style: const TextStyle(fontSize: 13, height: 1.45),
                ),

                // Metrics & Challenges
                if (report.metadata != null && report.metadata!.isNotEmpty) ...[
                  const Divider(height: 20),
                  const Text('Report Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (report.metadata?['attendees'] != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• Active Attendees: ${report.metadata!['attendees']}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                  if (report.metadata?['challenges'] != null &&
                      report.metadata!['challenges'].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text('• Challenges & Needs: ${report.metadata!['challenges']}',
                          style: const TextStyle(fontSize: 12)),
                    ),
                ],

                // Attachments
                if (hasAttachments) ...[
                  const Divider(height: 20),
                  const Text('Attachments:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: report.attachments.map((url) {
                      return ActionChip(
                        avatar: const Icon(Icons.attach_file_rounded, size: 16),
                        label: Text(attachmentName, style: const TextStyle(fontSize: 12)),
                        onPressed: () async {
                          final uri = Uri.parse(url);
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(uri, mode: LaunchMode.externalApplication);
                          } else {
                            ToastUtils.showError('Could not open attachment link');
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],

                // Feedback section
                const Divider(height: 24),
                Row(
                  children: [
                    const Icon(Icons.feedback_outlined, size: 16, color: Colors.blue),
                    const SizedBox(width: 6),
                    Text(
                      reviewedBy.isNotEmpty ? 'Leadership Feedback (by $reviewedBy):' : 'Leadership Feedback:',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: feedbackController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Enter review comments, guidance, or resolution...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 16),
            label: const Text('Save Feedback & Approve'),
            onPressed: () async {
              try {
                final user = _authService.currentUser;
                final meta = Map<String, dynamic>.from(report.metadata ?? {});
                meta['review_feedback'] = feedbackController.text.trim();
                meta['reviewed_by_name'] = user?.name ?? 'Leadership Officer';
                meta['reviewed_at'] = DateTime.now().toIso8601String();

                String reviewerOffice = 'Leadership Officer';
                if (_isPresident) {
                  reviewerOffice = 'Executive President';
                } else if (_roleService.hasRole('bod') || _roleService.hasRole('trustee')) {
                  reviewerOffice = 'Board of Directors / Trustees';
                } else if (_isDirector) {
                  reviewerOffice = 'Departmental Directorate';
                } else if (_isCoordinator) {
                  reviewerOffice = 'Chapter Coordinator';
                }
                meta['reviewer_office'] = reviewerOffice;
                meta['apex_directive'] = (_isPresident || _roleService.hasRole('bod') || _roleService.hasRole('trustee'));

                await _boardService.updateBoardReportReview(
                  reportId: report.id,
                  status: 'approved',
                  feedback: feedbackController.text.trim(),
                  reviewerName: user?.name,
                  updatedMetadata: meta,
                );

                if (context.mounted) {
                  Navigator.pop(context);
                  ToastUtils.showSuccess('Report approved with feedback');
                  _loadReports();
                }
              } catch (e) {
                ToastUtils.showError('Failed to save review: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  // Helper: Attachment Picker UI
  Widget _buildAttachmentPicker({
    required PlatformFile? attachedFile,
    required VoidCallback onPick,
    required VoidCallback onRemove,
  }) {
    if (attachedFile != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.attach_file_rounded, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                attachedFile.name,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
              tooltip: 'Remove Attachment',
            ),
          ],
        ),
      );
    }

    return OutlinedButton.icon(
      icon: const Icon(Icons.attach_file_rounded, size: 16),
      label: const Text('Add Optional Attachment (Photo/Document)', style: TextStyle(fontSize: 12)),
      onPressed: onPick,
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
}
