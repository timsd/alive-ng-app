import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/board_models.dart';
import '../../services/appwrite_board_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';
import '../../constants/chapters.dart';
import '../../utils/toast_utils.dart';

class ChapterReportsScreen extends StatefulWidget {
  final String? initialChapter;

  const ChapterReportsScreen({
    super.key,
    this.initialChapter,
  });

  @override
  State<ChapterReportsScreen> createState() => _ChapterReportsScreenState();
}

class _ChapterReportsScreenState extends State<ChapterReportsScreen> {
  final AppwriteBoardService _boardService = AppwriteBoardService.instance;
  final AuthService _authService = AuthService.instance;
  List<BoardReport> _reports = [];
  bool _isLoading = true;
  String _selectedChapter = 'all';
  String _selectedStatus = 'all';
  String _searchQuery = '';

  final List<String> _statuses = [
    'all',
    'draft',
    'submitted',
    'reviewed',
    'approved',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialChapter != null) {
      _selectedChapter = widget.initialChapter!;
    }
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final reports = await _boardService.getBoardReports();
      final mapped = reports.map((e) => BoardReport.fromJson(e)).toList();
      // Filter for chapter reports (category == 'operational' or has chapter metadata)
      final chapterReports = mapped.where((r) {
        final hasChapterMeta = r.metadata != null &&
            (r.metadata?['chapter'] != null || r.metadata?['chapter_name'] != null);
        return hasChapterMeta || r.category == 'operational' || r.title.toLowerCase().contains('chapter');
      }).toList();

      setState(() {
        _reports = chapterReports.isNotEmpty ? chapterReports : mapped;
      });
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Error loading chapter reports: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<BoardReport> get _filteredReports {
    return _reports.where((report) {
      final statusMatch =
          _selectedStatus == 'all' || report.status == _selectedStatus;
      final reportChapter = report.metadata?['chapter'] ?? report.metadata?['chapter_name'] ?? '';
      final chapterMatch = _selectedChapter == 'all' ||
          reportChapter.toString().toLowerCase() == _selectedChapter.toLowerCase() ||
          report.title.toLowerCase().contains(_selectedChapter.toLowerCase());
      final queryMatch = _searchQuery.isEmpty ||
          report.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.authorName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          report.content.toLowerCase().contains(_searchQuery.toLowerCase());
      return statusMatch && chapterMatch && queryMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Chapter Reports',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart_rounded),
            onPressed: () => _showCreateReportDialog(),
            tooltip: 'Submit Chapter Report',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filters Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
              ),
            ),
            child: Column(
              children: [
                // Search field
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search chapter reports...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim()),
                ),
                const SizedBox(height: 10),
                // Filter dropdowns
                Row(
                  children: [
                    // Chapter filter
                    Expanded(
                      flex: 3,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedChapter,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Chapter',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: [
                          const DropdownMenuItem(value: 'all', child: Text('All Chapters')),
                          ...ChapterConstants.availableChapters.map(
                            (c) => DropdownMenuItem(value: c, child: Text(c)),
                          ),
                        ],
                        onChanged: (val) => setState(() => _selectedChapter = val ?? 'all'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Status filter
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedStatus,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Status',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        ),
                        items: _statuses
                            .map((s) => DropdownMenuItem(
                                  value: s,
                                  child: Text(s.toUpperCase()),
                                ))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedStatus = val ?? 'all'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.assessment_outlined,
                                size: 64, color: colorScheme.outline),
                            const SizedBox(height: 16),
                            Text(
                              'No chapter reports found',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Submit a new chapter activity report using the + button',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            final chapterName = report.metadata?['chapter'] ??
                                report.metadata?['chapter_name'] ??
                                'General';

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: colorScheme.primaryContainer,
                                  child: Icon(Icons.location_city_rounded,
                                      color: colorScheme.onPrimaryContainer, size: 22),
                                ),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        report.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: colorScheme.primary.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        chapterName.toString().toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 4),
                                    Text('Submitted by: ${report.authorName}'),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('MMMM dd, yyyy').format(report.createdAt),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStatusBadge(report.status),
                                  ],
                                ),
                                isThreeLine: true,
                                onTap: () => _viewReportDetails(report),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _viewReportDetails(BoardReport report) {
    final chapterName = report.metadata?['chapter'] ??
        report.metadata?['chapter_name'] ??
        'General';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    _buildStatusBadge(report.status),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(chapterName.toString()),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Submitted by ${report.authorName} on ${DateFormat('MMM dd, yyyy – hh:mm a').format(report.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const Divider(height: 24),
                const Text(
                  'Report Content:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Text(
                  report.content,
                  style: const TextStyle(fontSize: 14, height: 1.4),
                ),
                if (report.metadata != null && report.metadata!.isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Details & Metrics:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  ...report.metadata!.entries.map((entry) {
                    if (entry.key == 'chapter' || entry.key == 'chapter_name') {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${entry.key}: ',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                          Expanded(
                            child: Text(entry.value.toString(),
                                style: const TextStyle(fontSize: 12)),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (report.status != 'approved')
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _updateReportStatus(report.id, 'approved');
              },
              child: const Text('Approve Report'),
            ),
        ],
      ),
    );
  }

  Future<void> _updateReportStatus(String reportId, String newStatus) async {
    try {
      await _boardService.updateBoardReportStatus(reportId, newStatus);
      ToastUtils.showSuccess('Report status updated to ${newStatus.toUpperCase()}');
      _loadReports();
    } catch (e) {
      ToastUtils.showError('Failed to update status: $e');
    }
  }

  void _showCreateReportDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    final attendeesController = TextEditingController();
    final challengesController = TextEditingController();
    String selectedChapter =
        _selectedChapter != 'all' ? _selectedChapter : (ChapterConstants.availableChapters.first);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Submit Chapter Report'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedChapter,
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
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Report Title *',
                      hintText: 'e.g. Monthly Chapter Activity & Outreach',
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
                      labelText: 'Executive Summary & Activities *',
                      hintText: 'Detail meetings held, ministry outreach, and accomplishments...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: challengesController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Challenges & Prayer Points',
                      hintText: 'Any hurdles faced or requests for leadership...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty ||
                    contentController.text.trim().isEmpty) {
                  ToastUtils.showError('Title and content are required');
                  return;
                }

                try {
                  final user = _authService.currentUser;
                  final authorName = user?.name ?? 'Chapter Coordinator';
                  final authorId = user?.uid ?? 'unknown';

                  await _boardService.addBoardReport({
                    'title': titleController.text.trim(),
                    'content': contentController.text.trim(),
                    'category': 'operational',
                    'author_id': authorId,
                    'author_name': authorName,
                    'status': 'submitted',
                    'created_at': DateTime.now().toIso8601String(),
                    'metadata': {
                      'chapter': selectedChapter,
                      'chapter_name': selectedChapter,
                      'attendees': attendeesController.text.trim(),
                      'challenges': challengesController.text.trim(),
                    },
                  });

                  if (context.mounted) {
                    Navigator.pop(context);
                    ToastUtils.showSuccess('Chapter report submitted successfully');
                    _loadReports();
                  }
                } catch (e) {
                  ToastUtils.showError('Failed to submit report: $e');
                }
              },
              child: const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}
