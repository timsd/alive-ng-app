import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/board_models.dart';
import '../../services/supabase_service.dart';

class BoardReportsScreen extends StatefulWidget {
  const BoardReportsScreen({super.key});

  @override
  State<BoardReportsScreen> createState() => _BoardReportsScreenState();
}

class _BoardReportsScreenState extends State<BoardReportsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  List<BoardReport> _reports = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedStatus = 'all';

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
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      // Mock data for demonstration - replace with actual Supabase query
      await Future.delayed(const Duration(milliseconds: 500));

      _reports = [
        BoardReport(
          id: '1',
          title: 'Q4 2024 Financial Report',
          description:
              'Comprehensive financial overview for the fourth quarter',
          content:
              'Detailed financial analysis including revenue, expenses, and projections...',
          authorId: 'user1',
          authorName: 'Timothy Olodude',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
          category: 'financial',
          status: 'approved',
        ),
        BoardReport(
          id: '2',
          title: 'AMTC Training Program Progress',
          description: 'Update on missionary training center activities',
          content:
              'Current enrollment, curriculum updates, and graduation statistics...',
          authorId: 'user2',
          authorName: 'Godstime Esuku',
          createdAt: DateTime.now().subtract(const Duration(days: 3)),
          category: 'ministry',
          status: 'submitted',
        ),
        BoardReport(
          id: '3',
          title: 'Health Ministry Outreach Report',
          description: 'Summary of health programs and community impact',
          content:
              'Health screening events, vaccination drives, and wellness programs...',
          authorId: 'user3',
          authorName: 'Emenike Ekechi',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
          category: 'ministry',
          status: 'draft',
        ),
      ];
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
      return categoryMatch && statusMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Reports'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showCreateReportDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _categories.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(category.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategory = value!);
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(status.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedStatus = value!);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Reports List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : _filteredReports.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assessment_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No reports found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReports,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _filteredReports.length,
                          itemBuilder: (context, index) {
                            final report = _filteredReports[index];
                            return _buildReportCard(report);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(BoardReport report) {
    Color statusColor;
    switch (report.status) {
      case 'approved':
        statusColor = Colors.green;
        break;
      case 'submitted':
        statusColor = Colors.blue;
        break;
      case 'reviewed':
        statusColor = Colors.orange;
        break;
      default:
        statusColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewReport(report),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      report.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      report.status.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                report.description,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    report.authorName,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.calendar_today,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('MMM dd, yyyy').format(report.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      report.category.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
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

  void _viewReport(BoardReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Author: ${report.authorName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Created: ${DateFormat('MMM dd, yyyy HH:mm').format(report.createdAt)}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 16),
              Text(
                report.description,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              const SizedBox(height: 16),
              const Text(
                'Content:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(report.content),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (report.status == 'draft')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _submitReport(report);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }

  void _showCreateReportDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final contentController = TextEditingController();
    String selectedCategory = 'operational';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Report'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Report Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: _categories.skip(1).map((category) {
                  return DropdownMenuItem(
                    value: category,
                    child: Text(category.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) => selectedCategory = value!,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Report Content',
                  border: OutlineInputBorder(),
                ),
                maxLines: 5,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty &&
                  contentController.text.isNotEmpty) {
                _createReport(
                  titleController.text,
                  descriptionController.text,
                  contentController.text,
                  selectedCategory,
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('Create', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _createReport(
      String title, String description, String content, String category) {
    final newReport = BoardReport(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      description: description,
      content: content,
      authorId: _supabaseService.currentUser?.id ?? '',
      authorName: _supabaseService.currentUser?.email ?? 'Unknown',
      createdAt: DateTime.now(),
      category: category,
      status: 'draft',
    );

    setState(() {
      _reports.insert(0, newReport);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report created successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _submitReport(BoardReport report) {
    setState(() {
      final index = _reports.indexWhere((r) => r.id == report.id);
      if (index != -1) {
        _reports[index] = BoardReport(
          id: report.id,
          title: report.title,
          description: report.description,
          content: report.content,
          authorId: report.authorId,
          authorName: report.authorName,
          createdAt: report.createdAt,
          updatedAt: DateTime.now(),
          category: report.category,
          status: 'submitted',
        );
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report submitted for review'),
        backgroundColor: Colors.green,
      ),
    );
  }
}




