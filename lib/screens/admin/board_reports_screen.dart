import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/board_models.dart';
import '../../services/appwrite_board_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/custom_app_bar.dart';

class BoardReportsScreen extends StatefulWidget {
  final String? initialCategory;
  final String? initialChapter;

  const BoardReportsScreen({
    super.key,
    this.initialCategory,
    this.initialChapter,
  });

  @override
  State<BoardReportsScreen> createState() => _BoardReportsScreenState();
}

class _BoardReportsScreenState extends State<BoardReportsScreen> {
  final AppwriteBoardService _boardService = AppwriteBoardService.instance;
  final AuthService _authService = AuthService.instance;
  List<BoardReport> _reports = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';
  String _selectedChapter = 'all';

  final List<String> _categories = [
    'all',
    'financial',
    'operational',
    'strategic',
    'ministry'
  ];
  final List<String> _statuses = [
    'all',
    'draft',
    'submitted',
    'reviewed',
    'approved'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
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
      setState(() {
        _reports = mapped;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reports: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<BoardReport> get _filteredReports {
    return _reports.where((report) {
      final categoryMatch =
          _selectedCategory == 'all' || report.category == _selectedCategory;
      final statusMatch =
          _selectedStatus == 'all' || report.status == _selectedStatus;
      final chapterMatch = _selectedChapter == 'all' ||
          (report.metadata != null &&
              report.metadata?['chapter'] == _selectedChapter);
      return categoryMatch && statusMatch && chapterMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Board Reports',
        showBackButton: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_chart),
            onPressed: () => _showCreateReportDialog(),
            tooltip: 'Create New Report',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _categories
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCategory = val!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    items: _statuses
                        .map((s) => DropdownMenuItem(
                              value: s,
                              child: Text(s.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedStatus = val!),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.description_outlined,
                                size: 64, color: colorScheme.outline),
                            const SizedBox(height: 16),
                            Text('No reports matching current filters',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                )),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      _getCategoryColor(report.category),
                                  child: Icon(_getCategoryIcon(report.category),
                                      color: Colors.white, size: 20),
                                ),
                                title: Text(report.title,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                subtitle: Text(
                                    'Submitted by: ${report.authorName}\nID: ${report.id}'),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildStatusBadge(report.status),
                                    const SizedBox(height: 4),
                                    Text(
                                      DateFormat('MMM dd, yyyy')
                                          .format(report.createdAt),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
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

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'financial':
        return Theme.of(context).colorScheme.primary;
      case 'operational':
        return Theme.of(context).colorScheme.secondary;
      case 'strategic':
        return Theme.of(context).colorScheme.tertiary;
      case 'ministry':
        return Theme.of(context).colorScheme.tertiary;
      default:
        return Theme.of(context).colorScheme.outline;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category) {
      case 'financial':
        return Icons.attach_money;
      case 'operational':
        return Icons.settings;
      case 'strategic':
        return Icons.trending_up;
      case 'ministry':
        return Icons.church;
      default:
        return Icons.report;
    }
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'approved':
        color = Theme.of(context).colorScheme.tertiary;
        break;
      case 'reviewed':
        color = Theme.of(context).colorScheme.primary;
        break;
      case 'submitted':
        color = Theme.of(context).colorScheme.secondary;
        break;
      default:
        color = Theme.of(context).colorScheme.outline;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        status.toUpperCase(),
        style:
            TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _viewReportDetails(BoardReport report) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor:
              theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
          title: Text(report.title,
              style: TextStyle(color: theme.colorScheme.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary)),
                Text(report.description,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 16),
                Text('Content:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary)),
                Text(report.content,
                    style: TextStyle(color: theme.colorScheme.onSurface)),
                const SizedBox(height: 16),
                Text('Meta Information:',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.tertiary)),
                Text('Author: ${report.authorName}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                Text(
                    'Created: ${DateFormat('MMM dd, yyyy HH:mm').format(report.createdAt)}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                Text('Category: ${report.category.toUpperCase()}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
                Text('Status: ${report.status.toUpperCase()}',
                    style: TextStyle(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.7))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            if (report.status == 'submitted')
              ElevatedButton(
                onPressed: () async {
                  final success = await _boardService.updateBoardReportStatus(
                      report.id, 'reviewed');
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    _loadReports();
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary),
                child: const Text('Mark Reviewed'),
              ),
            if (report.status == 'reviewed')
              ElevatedButton(
                onPressed: () async {
                  final success = await _boardService.updateBoardReportStatus(
                      report.id, 'approved');
                  if (success && context.mounted) {
                    Navigator.pop(context);
                    _loadReports();
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary),
                child: const Text('Approve'),
              ),
          ],
        );
      },
    );
  }

  Future<void> _showCreateReportDialog() async {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCat = 'operational';

    await showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            backgroundColor:
                theme.dialogTheme.backgroundColor ?? theme.colorScheme.surface,
            title: Text('Create New Board Report',
                style: TextStyle(color: theme.colorScheme.onSurface)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: titleController,
                    decoration:
                        const InputDecoration(labelText: 'Report Title'),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  TextField(
                    controller: descriptionController,
                    decoration:
                        const InputDecoration(labelText: 'Short Description'),
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  TextField(
                    controller: contentController,
                    decoration:
                        const InputDecoration(labelText: 'Full Content'),
                    maxLines: 5,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCat,
                    dropdownColor: theme.cardColor,
                    style: TextStyle(color: theme.colorScheme.onSurface),
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: _categories
                        .skip(1)
                        .map((c) => DropdownMenuItem(
                              value: c,
                              child: Text(c.toUpperCase()),
                            ))
                        .toList(),
                    onChanged: (val) =>
                        setDialogState(() => selectedCat = val!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  if (titleController.text.isNotEmpty &&
                      contentController.text.isNotEmpty) {
                    final report = {
                      'title': titleController.text,
                      'description': descriptionController.text,
                      'content': contentController.text,
                      'category': selectedCat,
                      'status': 'submitted',
                      'authorId': _authService.currentUser?.uid ?? 'unknown',
                      'authorName':
                          _authService.currentUser?.displayName ?? 'Admin',
                      'createdAt': DateTime.now().toIso8601String(),
                    };

                    final success = await _boardService.addBoardReport(report);
                    if (success && context.mounted) {
                      Navigator.pop(context);
                      _loadReports();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Report submitted successfully')),
                      );
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.tertiary,
                    foregroundColor: theme.colorScheme.onTertiary),
                child: const Text('Submit Report'),
              ),
            ],
          ),
        );
      },
    );
  }
}
