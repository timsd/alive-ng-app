import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/appwrite_storage_compat_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/logger.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';

class SystemLogsScreen extends StatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  State<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends State<SystemLogsScreen> {
  static const String _bucket = 'app-logs';
  final AppwriteStorageCompatService _storageService = AppwriteStorageCompatService();
  final Logger _logger = Logger('SystemLogsScreen');

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLogs();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final refs = await _storageService.listFiles(_bucket);
      final rawFiles = await Future.wait(refs.map((ref) async {
        final md = await ref.getMetadata();
        return {
          'name': ref.name,
          'path': ref.fullPath,
          'size': md.size,
          'updated': md.updated,
          'fileId': md.fileId,
        };
      }));

      // Sort newest first
      rawFiles.sort((a, b) {
        final aDate = a['updated'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b['updated'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

      if (mounted) {
        setState(() {
          _logs = rawFiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.error('Error loading logs: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError('Failed to load system logs: ${ErrorHandler.getUserFriendlyMessage(e)}');
      }
    }
  }

  List<Map<String, dynamic>> get _filteredLogs {
    if (_searchQuery.isEmpty) return _logs;
    return _logs.where((log) {
      final name = (log['name'] as String? ?? '').toLowerCase();
      return name.contains(_searchQuery);
    }).toList();
  }

  Future<void> _viewLogContent(Map<String, dynamic> log) async {
    final fileName = log['name'] as String? ?? 'log';
    final fileId = log['fileId'] as String?;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    String content = '';
    try {
      final url = fileId != null && fileId.isNotEmpty
          ? _storageService.getDownloadUrl(_bucket, fileId: fileId)
          : await _storageService.getPublicUrl('$_bucket/$fileName');

      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        content = utf8.decode(response.bodyBytes, allowMalformed: true);
      } else {
        content = 'Failed to fetch log contents (HTTP ${response.statusCode})';
      }
    } catch (e) {
      content = 'Error loading log: ${ErrorHandler.getUserFriendlyMessage(e)}';
    }

    if (!mounted) return;
    Navigator.pop(context); // Dismiss loading dialog

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.bug_report_outlined, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                fileName,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                content.isEmpty ? '(Empty log file)' : content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: Colors.greenAccent,
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: content));
              ToastUtils.showSuccess('Log content copied to clipboard');
            },
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text('Copy All'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(Map<String, dynamic> log) async {
    final fileName = log['name'] as String? ?? 'log';
    final fileId = log['fileId'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Log File'),
        content: Text('Are you sure you want to permanently delete "$fileName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _storageService.deleteFile(_bucket, fileName, fileId: fileId);
      ToastUtils.showSuccess('Log file deleted');
      await _loadLogs();
    } catch (e) {
      _logger.error('Error deleting log: $e');
      ToastUtils.showError('Failed to delete log: ${ErrorHandler.getUserFriendlyMessage(e)}');
    }
  }

  Future<void> _downloadLog(Map<String, dynamic> log) async {
    final fileId = log['fileId'] as String?;
    final name = log['name'] as String? ?? '';
    try {
      final url = fileId != null && fileId.isNotEmpty
          ? _storageService.getDownloadUrl(_bucket, fileId: fileId)
          : await _storageService.getPublicUrl('$_bucket/$name');

      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ToastUtils.showError('Could not open download link');
      }
    } catch (e) {
      ToastUtils.showError('Error downloading: $e');
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayed = _filteredLogs;

    return Scaffold(
      appBar: CustomAppBar(
        title: 'System Logs',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadLogs,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : Column(
              children: [
                // Search bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Column(
                    children: [
                      TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Filter logs by filename or date...',
                          prefixIcon: const Icon(Icons.search, size: 20),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () => _searchController.clear(),
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total Logs: ${_logs.length}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (_logs.isNotEmpty && _logs.first['updated'] != null)
                            Text(
                              'Latest: ${DateFormat('MMM dd, HH:mm').format(_logs.first['updated'] as DateTime)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Log Files List
                Expanded(
                  child: displayed.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bug_report_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No logs match "$_searchQuery"'
                                    : 'No system logs found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'System is operating normally without error archives.',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadLogs,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: displayed.length,
                            itemBuilder: (context, index) {
                              final log = displayed[index];
                              final name = log['name'] as String? ?? '';
                              final size = log['size'] as int? ?? 0;
                              final updated = log['updated'] as DateTime?;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.deepOrange.withValues(alpha: 0.15),
                                    child: const Icon(Icons.bug_report_rounded, color: Colors.deepOrange),
                                  ),
                                  title: Text(
                                    name,
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${_formatFileSize(size)} • ${updated != null ? DateFormat('MMM dd, yyyy HH:mm').format(updated) : 'Unknown date'}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  onTap: () => _viewLogContent(log),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'view':
                                          _viewLogContent(log);
                                          break;
                                        case 'download':
                                          _downloadLog(log);
                                          break;
                                        case 'delete':
                                          _deleteLog(log);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'view',
                                        child: ListTile(
                                          leading: Icon(Icons.visibility_rounded),
                                          title: Text('View Content'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'download',
                                        child: ListTile(
                                          leading: Icon(Icons.download_rounded),
                                          title: Text('Download'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuDivider(),
                                      const PopupMenuItem(
                                        value: 'delete',
                                        child: ListTile(
                                          leading: Icon(Icons.delete_outline, color: Colors.red),
                                          title: Text('Delete', style: TextStyle(color: Colors.red)),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  ),
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
}
