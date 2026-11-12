import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/appwrite_admin_export_service.dart';
import '../../services/appwrite_storage_compat_service.dart';
import '../../services/file_picker_facade.dart';
import '../../utils/error_handler.dart';
import '../../utils/logger.dart';
import '../../utils/toast_utils.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/loading_widget.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  static const String _bucket = 'system-backups';
  final AppwriteStorageCompatService _storageService = AppwriteStorageCompatService();
  final Logger _logger = Logger('BackupRestoreScreen');

  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = true;
  bool _isBackingUp = false;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
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
          _backups = rawFiles;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.error('Error loading backups: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError('Failed to load backups: ${ErrorHandler.getUserFriendlyMessage(e)}');
      }
    }
  }

  Future<void> _createBackup() async {
    final format = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Data Backup'),
        content: const Text(
          'Choose the export format for all database collections (profiles, prayer requests, chapters, donations, etc.). The generated archive will be stored in your system backups.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, 'csv'),
            child: const Text('CSV Format'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, 'json'),
            child: const Text('JSON Format'),
          ),
        ],
      ),
    );

    if (format == null) return;

    setState(() => _isBackingUp = true);
    try {
      final result = await AppwriteAdminExportService.instance.exportDataBackup(
        format: format,
        collections: [
          'profiles',
          'prayer_requests',
          'chapters',
          'donations',
          'discipleship_contacts',
          'daily_devotionals',
          'announcements',
          'testimonies',
        ],
      );

      final fileCount = (result['files'] as Map<String, dynamic>?)?.length ?? 0;
      ToastUtils.showSuccess('Backup created successfully ($fileCount collections saved)!');
      await _loadBackups();
    } catch (e) {
      _logger.error('Error creating backup: $e');
      ToastUtils.showError('Backup failed: ${ErrorHandler.getUserFriendlyMessage(e)}');
    } finally {
      if (mounted) {
        setState(() => _isBackingUp = false);
      }
    }
  }

  Future<void> _uploadBackup() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'csv', 'zip', 'gz', 'tar', 'sql'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty || result.files.single.bytes == null) {
        return;
      }

      final file = result.files.single;
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filePath = '$_bucket/backup_${timestamp}_${file.name}';

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text('Uploading ${file.name}...')),
            ],
          ),
        ),
      );

      await _storageService.uploadFile(
        filePath,
        file.bytes!,
        contentType: file.extension == 'json'
            ? 'application/json'
            : file.extension == 'csv'
                ? 'text/csv'
                : 'application/octet-stream',
      );

      if (mounted) {
        Navigator.pop(context); // Dismiss upload dialog
        ToastUtils.showSuccess('Backup file uploaded successfully!');
        await _loadBackups();
      }
    } catch (e) {
      _logger.error('Error uploading backup: $e');
      if (mounted) {
        Navigator.pop(context); // Dismiss upload dialog if open
        ToastUtils.showError('Failed to upload backup: ${ErrorHandler.getUserFriendlyMessage(e)}');
      }
    }
  }

  Future<void> _deleteBackup(Map<String, dynamic> file) async {
    final fileName = file['name'] as String? ?? 'backup';
    final fileId = file['fileId'] as String?;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Are you sure you want to permanently delete "$fileName"? This action cannot be undone.'),
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
      ToastUtils.showSuccess('Backup deleted');
      await _loadBackups();
    } catch (e) {
      _logger.error('Error deleting backup: $e');
      ToastUtils.showError('Failed to delete backup: ${ErrorHandler.getUserFriendlyMessage(e)}');
    }
  }

  Future<void> _downloadBackup(Map<String, dynamic> file) async {
    final fileId = file['fileId'] as String?;
    final name = file['name'] as String? ?? '';
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

  Future<void> _copyBackupUrl(Map<String, dynamic> file) async {
    final fileId = file['fileId'] as String?;
    final name = file['name'] as String? ?? '';
    try {
      final url = fileId != null && fileId.isNotEmpty
          ? _storageService.getDownloadUrl(_bucket, fileId: fileId)
          : await _storageService.getPublicUrl('$_bucket/$name');

      await Clipboard.setData(ClipboardData(text: url));
      ToastUtils.showSuccess('Download URL copied to clipboard');
    } catch (e) {
      ToastUtils.showError('Failed to copy URL');
    }
  }

  void _restoreBackupInfo(Map<String, dynamic> file) {
    final name = file['name'] as String? ?? 'backup';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore from Backup'),
        content: Text(
          'To restore "$name", download the backup file and import the records via the Appwrite CLI, database import scripts, or contact system administration for an automated restore run.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _downloadBackup(file);
            },
            icon: const Icon(Icons.download_rounded, size: 18),
            label: const Text('Download Archive'),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  int get _totalBytes =>
      _backups.fold<int>(0, (sum, f) => sum + ((f['size'] as int?) ?? 0));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: CustomAppBar(
        title: 'Backup & Restore',
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadBackups,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : Column(
              children: [
                // Top Action & Summary Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    border: Border(bottom: BorderSide(color: theme.dividerColor)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _isBackingUp ? null : _createBackup,
                              icon: _isBackingUp
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.backup_rounded, size: 18),
                              label: Text(_isBackingUp ? 'Creating Backup...' : 'Create Backup'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonalIcon(
                              onPressed: _uploadBackup,
                              icon: const Icon(Icons.upload_file_rounded, size: 18),
                              label: const Text('Upload Backup'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('Total Backups', '${_backups.length}', theme),
                          _buildStatItem('Storage Used', _formatFileSize(_totalBytes), theme),
                          _buildStatItem(
                            'Last Backup',
                            _backups.isNotEmpty && _backups.first['updated'] != null
                                ? DateFormat('MMM d, yyyy').format(_backups.first['updated'] as DateTime)
                                : 'None',
                            theme,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Backups List
                Expanded(
                  child: _backups.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.cloud_done_outlined,
                                size: 64,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No system backups found',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: _createBackup,
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Backup'),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _loadBackups,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            itemCount: _backups.length,
                            itemBuilder: (context, index) {
                              final backup = _backups[index];
                              final name = backup['name'] as String? ?? '';
                              final size = backup['size'] as int? ?? 0;
                              final updated = backup['updated'] as DateTime?;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 10),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Colors.blueGrey.withValues(alpha: 0.15),
                                    child: const Icon(Icons.backup_rounded, color: Colors.blueGrey),
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
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (action) {
                                      switch (action) {
                                        case 'restore':
                                          _restoreBackupInfo(backup);
                                          break;
                                        case 'download':
                                          _downloadBackup(backup);
                                          break;
                                        case 'copy_url':
                                          _copyBackupUrl(backup);
                                          break;
                                        case 'delete':
                                          _deleteBackup(backup);
                                          break;
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'download',
                                        child: ListTile(
                                          leading: Icon(Icons.download_rounded),
                                          title: Text('Download'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'restore',
                                        child: ListTile(
                                          leading: Icon(Icons.restore_rounded),
                                          title: Text('Restore Instructions'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'copy_url',
                                        child: ListTile(
                                          leading: Icon(Icons.link_rounded),
                                          title: Text('Copy URL'),
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

  Widget _buildStatItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

