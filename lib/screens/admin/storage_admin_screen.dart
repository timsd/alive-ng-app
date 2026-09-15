// import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';
// import '../../services/auth_service.dart';
// import '../../services/storage_service.dart';
import '../../services/appwrite_storage_compat_service.dart';
import '../../utils/toast_utils.dart';
import '../../utils/logger.dart';
import '../../services/material_sync_service.dart';
import '../../widgets/custom_app_bar.dart';

class StorageAdminScreen extends StatefulWidget {
  final String? initialBucket;
  const StorageAdminScreen({super.key, this.initialBucket});

  @override
  State<StorageAdminScreen> createState() => _StorageAdminScreenState();
}

class _StorageAdminScreenState extends State<StorageAdminScreen>
    with SingleTickerProviderStateMixin {
  final AppwriteStorageCompatService _storageService =
      AppwriteStorageCompatService();
  final Logger _logger = Logger('StorageAdminScreen');
  late TabController _tabController;

  // Storage buckets. These names map to real Appwrite bucket IDs inside
  // AppwriteStorageCompatService._legacyBucketIds, so they must stay stable.
  // Canonical aliases are accepted for deep-links / older callers.
  static const Map<String, String> _bucketAliases = {
    // canonical -> legacy bucket name (real Appwrite bucket mapping)
    'audio': 'audio-files',
    'video': 'video-files',
    'documents': 'pdf-files',
    'images': 'profile-pictures',
    'backups': 'system-backups',
  };

  /// Maps a canonical alias (or legacy name) to the real storage bucket name.
  String _resolveBucket(String bucket) => _bucketAliases[bucket] ?? bucket;

  /// Real storage bucket names (each maps to a distinct Appwrite bucket ID).
  final List<String> _buckets = [
    'audio-files',
    'video-files',
    'pdf-files',
    'profile-pictures',
    'tract-avatars',
    'podcast-covers',
    'meeting-files',
    'system-backups',
    'app-logs',
  ];

  // File lists for each bucket
  final Map<String, List<Map<String, dynamic>>> _bucketFiles = {};
  final Map<String, bool> _bucketLoading = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _buckets.length, vsync: this);
    if (widget.initialBucket != null) {
      final resolved = _resolveBucket(widget.initialBucket!);
      final index = _buckets.indexOf(resolved);
      if (index != -1) {
        _tabController.index = index;
      }
    }
    _initializeBuckets();
    _loadAllBucketFiles();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _initializeBuckets() {
    for (String bucket in _buckets) {
      _bucketFiles[bucket] = [];
      _bucketLoading[bucket] = false;
    }
  }

  Future<void> _loadAllBucketFiles() async {
    for (String bucket in _buckets) {
      await _loadBucketFiles(bucket);
    }
  }

  Future<void> _loadBucketFiles(String bucket) async {
    final resolved = _resolveBucket(bucket);
    setState(() {
      _bucketLoading[bucket] = true;
    });

    try {
      final refs = await _storageService.listFiles(resolved);
      final files = await Future.wait(refs.map((ref) async {
        final md = await ref.getMetadata();
        return {
          'name': ref.name,
          'path': ref.fullPath,
          'size': md.size ?? 0,
          'updated': md.updated?.toLocal(),
          'contentType': md.contentType,
        };
      }));

      files.sort((a, b) {
        final ad =
            a['updated'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bd =
            b['updated'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bd.compareTo(ad);
      });

      setState(() {
        _bucketFiles[bucket] = files.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      _logger.error('Error loading files from bucket $bucket: $e');
      if (mounted) {
        ToastUtils.showError('Error loading files from $bucket bucket');
      }
    } finally {
      setState(() {
        _bucketLoading[bucket] = false;
      });
    }
  }

  // _parseFileCreatedAt removed (unused)

  Future<void> _uploadFile(String bucket) async {
    try {
      FilePickerResult? result;
      // Different file types for different buckets
      switch (_resolveBucket(bucket)) {
        case 'audio-files':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['mp3', 'wav', 'aac', 'm4a', 'ogg'],
            allowMultiple: false,
            withData: true,
          );
          break;
        case 'video-files':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['mp4', 'mov', 'm4v', 'webm', 'mkv'],
            allowMultiple: false,
            withData: true,
          );
          break;
        case 'pdf-files':
          result = await FilePicker.platform.pickFiles(
            type: FileType.custom,
            allowedExtensions: ['pdf'],
            allowMultiple: false,
            withData: true,
          );
          break;
        case 'profile-pictures':
        case 'tract-avatars':
        case 'podcast-covers':
          result = await FilePicker.platform.pickFiles(
            type: FileType.image,
            allowMultiple: false,
            withData: true,
          );
          break;
        default:
          result = await FilePicker.platform.pickFiles(
            allowMultiple: false,
            withData: true,
          );
      }
      if (result != null && result.files.single.bytes != null) {
        await _processFileUpload(bucket, result.files.single);
      }
    } catch (e) {
      _logger.error('Error picking file for bucket $bucket: $e');
      ToastUtils.showError('Error selecting file');
    }
  }

  Future<void> _processFileUpload(String bucket, PlatformFile file) async {
    if (file.bytes == null) return;
    final resolved = _resolveBucket(bucket);
    final navigator = Navigator.of(context);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text('Uploading ${file.name}...'),
          ],
        ),
      ),
    );
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$resolved/${timestamp}_${file.name}';
      await _storageService.uploadFile(
        filePath,
        file.bytes!,
        contentType:
            file.extension != null ? _inferContentType(file.extension!) : null,
      );
      await _loadBucketFiles(bucket);
      if (mounted) {
        navigator.pop();
        ToastUtils.showSuccess('File uploaded successfully!');
      }
    } catch (e) {
      _logger.error('Error uploading file to bucket $bucket: $e');
      if (mounted) {
        navigator.pop();
        ToastUtils.showError('Error uploading file: $e');
      }
    }
  }

  Future<void> _deleteFile(String bucket, String fileName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete $fileName?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _storageService.deleteFile('${_resolveBucket(bucket)}/$fileName');
        await _loadBucketFiles(bucket);
        ToastUtils.showSuccess('File deleted successfully');
      } catch (e) {
        _logger.error('Error deleting file: $e');
        ToastUtils.showError('Error deleting file');
      }
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Widget _buildBucketTab(String bucket) {
    final files = _bucketFiles[bucket] ?? [];
    final isLoading = _bucketLoading[bucket] ?? false;

    return Column(
      children: [
        // Upload button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _uploadFile(bucket),
              icon: const Icon(Icons.upload_file),
              label: Text(
                  'Upload to ${bucket.replaceAll('-', ' ').toUpperCase()}'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Files list
        Expanded(
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : files.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.folder_open,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No files in ${bucket.replaceAll('-', ' ')} bucket',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () => _loadBucketFiles(bucket),
                      child: ListView.builder(
                        itemCount: files.length,
                        itemBuilder: (context, index) {
                          final file = files[index];
                          return _buildFileCard(bucket, file);
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildFileCard(String bucket, Map<String, dynamic> file) {
    final name = file['name'] as String? ?? '';
    // Removed unused isImage detection
    final size = file['size'] as int? ?? 0;
    final updated = file['updated'] as DateTime?;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: Theme.of(context).colorScheme.surface,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getBucketColor(bucket),
          child: Icon(
            _getBucketIcon(bucket),
            color: Colors.white,
          ),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: Theme.of(context).colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Size: ${_formatFileSize(size)}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (updated != null)
              Text(
                'Updated: ${updated.toString().split('.')[0]}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            switch (value) {
              case 'copy_url':
                _copyPublicUrl(bucket, name);
                break;
              case 'download':
                final url = await _storageService
                    .getDownloadUrl('${_resolveBucket(bucket)}/$name');
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url),
                      mode: LaunchMode.externalApplication);
                }
                break;
              case 'delete':
                _deleteFile(bucket, name);
                break;
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'copy_url',
              child: ListTile(
                leading: Icon(Icons.link),
                title: Text('Copy URL'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'download',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('Download'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: ListTile(
                leading: Icon(Icons.delete, color: Colors.red),
                title: Text('Delete', style: TextStyle(color: Colors.red)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Color _getBucketColor(String bucket) {
    switch (_resolveBucket(bucket)) {
      case 'audio-files':
        return Colors.purple;
      case 'video-files':
        return Colors.indigo;
      case 'pdf-files':
        return Colors.red;
      case 'profile-pictures':
        return Colors.blue;
      case 'tract-avatars':
        return Colors.green;
      case 'podcast-covers':
        return Colors.orange;
      case 'meeting-files':
        return Colors.teal;
      case 'system-backups':
        return Colors.blueGrey;
      case 'app-logs':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  IconData _getBucketIcon(String bucket) {
    switch (_resolveBucket(bucket)) {
      case 'audio-files':
        return Icons.audiotrack;
      case 'video-files':
        return Icons.video_library;
      case 'pdf-files':
        return Icons.picture_as_pdf;
      case 'profile-pictures':
        return Icons.person;
      case 'tract-avatars':
        return Icons.book;
      case 'podcast-covers':
        return Icons.headset;
      case 'meeting-files':
        return Icons.folder;
      case 'system-backups':
        return Icons.backup;
      case 'app-logs':
        return Icons.history_edu;
      default:
        return Icons.file_present;
    }
  }

  void _copyPublicUrl(String bucket, String fileName) async {
    try {
      final resolved = _resolveBucket(bucket);
      final url = await _storageService.getDownloadUrl('$resolved/$fileName');
      await Clipboard.setData(ClipboardData(text: url));
      ToastUtils.showSuccess('URL copied to clipboard');
    } catch (e) {
      _logger.error('Error getting URL: $e');
      ToastUtils.showError('Error copying URL');
    }
  }

  // _downloadFile removed (unused)

  bool _isSyncing = false;

  Future<void> _syncTractsToMaterials() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final count =
          await MaterialSyncService.instance.syncTractsToDownloadableMaterials(
        requiresDonation: true,
        minimumDonation: 500.0,
        activate: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Synced $count tracts to downloadable materials'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: 'Storage Management',
        showBackButton: true,
        showDonationButton: false,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          Tooltip(
            message: 'Sync Tracts to Materials',
            child: IconButton(
              icon: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.sync),
              onPressed: _isSyncing ? null : _syncTractsToMaterials,
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: _buckets
              .map((bucket) => Tab(
                    text: bucket.replaceAll('-', ' ').toUpperCase(),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _buckets.map((bucket) => _buildBucketTab(bucket)).toList(),
      ),
    );
  }

  String? _inferContentType(String ext) {
    switch (ext.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'pdf':
        return 'application/pdf';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'mp3':
        return 'audio/mpeg';
      case 'wav':
        return 'audio/wav';
      case 'm4a':
        return 'audio/mp4';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      default:
        return null;
    }
  }
}
