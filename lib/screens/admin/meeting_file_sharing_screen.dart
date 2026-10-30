import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/appwrite_meeting_file_service.dart';
import '../../services/auth_service.dart';
import '../../services/role_access_service.dart';
import '../../utils/responsive_utils.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import 'leader_meeting_transcription_screen.dart';

class MeetingFileSharingScreen extends StatefulWidget {
  const MeetingFileSharingScreen({super.key});

  @override
  State<MeetingFileSharingScreen> createState() =>
      _MeetingFileSharingScreenState();
}

class _MeetingFileSharingScreenState extends State<MeetingFileSharingScreen> {
  final AppwriteMeetingFileService _meetingFileService =
      AppwriteMeetingFileService.instance;
  final AuthService _authService = AuthService.instance;
  List<MeetingFile> _files = [];
  bool _isLoading = true;
  StreamSubscription? _filesSubscription;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadFiles();
    _setupRealtimeSubscription();
  }

  @override
  void dispose() {
    _filesSubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _setupRealtimeSubscription() {
    // Set up real-time subscription for file changes
    _filesSubscription =
        _meetingFileService.getMeetingFilesStream().listen((files) {
      if (mounted) {
        setState(() {
          _files = files.map((json) => MeetingFile.fromJson(json)).toList();
        });
      }
    });
  }

  Future<void> _loadFiles() async {
    try {
      setState(() => _isLoading = true);

      final files = await _meetingFileService.getMeetingFiles();

      if (mounted) {
        setState(() {
          _files = files.map((json) => MeetingFile.fromJson(json)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ToastUtils.showError('Error loading files: $e');
      }
    }
  }

  List<MeetingFile> get _filteredFiles {
    if (_searchQuery.isEmpty) return _files;
    return _files
        .where((file) =>
            file.fileName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            file.uploadedBy
                .toLowerCase()
                .contains(_searchQuery.toLowerCase()) ||
            file.description.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Meeting File Sharing',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic_none_outlined, color: Colors.white),
            tooltip: 'Leader Scribe & Notes',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const LeaderMeetingTranscriptionScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadFiles,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: ResponsiveUtils.getResponsivePadding(context),
            color: colorScheme.surfaceContainerHighest,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search files...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: colorScheme.surface,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Files List
          Expanded(
            child: _isLoading
                ? const LoadingWidget()
                : _filteredFiles.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_open,
                              size: 64,
                              color: colorScheme.onSurfaceVariant,
                            ),
                            SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                    context, 16)),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No files shared yet'
                                  : 'No files match your search',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context, 16),
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadFiles,
                        child: ListView.builder(
                          padding:
                              ResponsiveUtils.getResponsivePadding(context),
                          itemCount: _filteredFiles.length,
                          itemBuilder: (context, index) {
                            final file = _filteredFiles[index];
                            return _buildFileCard(file);
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadDialog,
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        icon: const Icon(Icons.upload_file),
        label: const Text('Share File'),
      ),
    );
  }

  Widget _buildFileCard(MeetingFile file) {
    final colorScheme = Theme.of(context).colorScheme;
    IconData fileIcon;
    Color fileIconColor;

    switch (file.fileType.toLowerCase()) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        fileIconColor = Colors.red;
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description;
        fileIconColor = Colors.blue;
        break;
      case 'xls':
      case 'xlsx':
        fileIcon = Icons.table_chart;
        fileIconColor = Colors.green;
        break;
      case 'ppt':
      case 'pptx':
        fileIcon = Icons.slideshow;
        fileIconColor = Colors.orange;
        break;
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
        fileIcon = Icons.image;
        fileIconColor = Colors.purple;
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        fileIconColor = Colors.grey;
    }

    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _downloadFile(file),
        borderRadius: BorderRadius.circular(
            ResponsiveUtils.getResponsiveBorderRadiusValue(context, 8)),
        child: Padding(
          padding: ResponsiveUtils.getResponsivePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    fileIcon,
                    color: fileIconColor,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 32),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          file.fileName,
                          style: TextStyle(
                            fontSize: ResponsiveUtils.getResponsiveFontSize(
                                context, 16),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (file.description.isNotEmpty) ...[
                          SizedBox(
                              height: ResponsiveUtils.getResponsiveSpacing(
                                  context, 4)),
                          Text(
                            file.description,
                            style: TextStyle(
                              fontSize: ResponsiveUtils.getResponsiveFontSize(
                                  context, 14),
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'download':
                          _downloadFile(file);
                          break;
                        case 'delete':
                          _confirmDeleteFile(file);
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'download',
                        child: Row(
                          children: [
                            Icon(Icons.download),
                            SizedBox(width: 8),
                            Text('Download'),
                          ],
                        ),
                      ),
                      if (_canDeleteFile(file))
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete',
                                  style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    file.uploadedBy,
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  Icon(
                    Icons.access_time,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    _formatTimeAgo(file.uploadedAt),
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 12),
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  Icon(
                    Icons.storage,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    _formatFileSize(file.fileSize),
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 12),
                      color: colorScheme.onSurfaceVariant,
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

  bool _canDeleteFile(MeetingFile file) {
    final currentUser = _authService.currentUser;
    return currentUser != null &&
        (file.uploaderId == currentUser.uid ||
            RoleAccessService.instance.canAccessAdmin());
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM dd').format(dateTime);
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

  void _showUploadDialog() {
    final descriptionController = TextEditingController();
    String? selectedFileName;
    Uint8List? selectedBytes;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Share File'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // File Selection
                ListTile(
                  title: const Text('Select File'),
                  subtitle: Text(
                    selectedFileName ?? 'Tap to choose file',
                    style: TextStyle(
                      color:
                          selectedFileName != null ? Colors.green : Colors.grey,
                    ),
                  ),
                  leading: const Icon(Icons.attach_file),
                  onTap: () async {
                    try {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        allowMultiple: false,
                        withData: true,
                      );

                      if (result != null && result.files.isNotEmpty) {
                        final file = result.files.single;
                        setDialogState(() {
                          selectedFileName = file.name;
                          selectedBytes = file.bytes;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ToastUtils.showError('Error selecting file: $e');
                      }
                    }
                  },
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description (optional)',
                    border: OutlineInputBorder(),
                    hintText: 'Brief description of the file...',
                  ),
                  maxLines: 2,
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
              onPressed: selectedBytes != null && selectedFileName != null
                  ? () async {
                      Navigator.pop(context);
                      await _uploadFileBytes(
                        selectedBytes!,
                        selectedFileName!,
                        descriptionController.text,
                      );
                    }
                  : null,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text(
                'Share',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadFileBytes(
      Uint8List data, String fileName, String description) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Uploading file...'),
            ],
          ),
        ),
      );

      await _meetingFileService.uploadMeetingFileBytes(
        data,
        fileName: fileName,
        description: description,
        uploaderId: _authService.currentUser?.uid ?? '',
        uploadedBy: _authService.currentUser?.email ?? 'Unknown',
      );

      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        ToastUtils.showSuccess('File shared successfully!');
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.pop(context);
        ToastUtils.showError('Error uploading file: $e');
      }
    }
  }

  Future<void> _downloadFile(MeetingFile file) async {
    try {
      // Get the download URL from Appwrite Storage.
      final downloadUrl =
          _meetingFileService.getMeetingFileDownloadUrl(file.filePath);

      // Launch the URL to download the file
      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl),
            mode: LaunchMode.externalApplication);

        if (mounted) {
          ToastUtils.showSuccess('Downloading ${file.fileName}...');
        }
      } else {
        throw 'Could not launch download URL';
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Error downloading file: $e');
      }
    }
  }

  void _confirmDeleteFile(MeetingFile file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete File'),
        content: Text('Are you sure you want to delete "${file.fileName}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _deleteFile(file);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text(
              'Delete',
              style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFile(MeetingFile file) async {
    try {
      // Delete from Appwrite Storage and database.
      await _meetingFileService.deleteMeetingFile(file.id, file.filePath);

      if (mounted) {
        ToastUtils.showSuccess('File deleted successfully');
      }
    } catch (e) {
      if (mounted) {
        ToastUtils.showError('Error deleting file: $e');
      }
    }
  }
}

class MeetingFile {
  final String id;
  final String fileName;
  final String filePath;
  final String fileType;
  final int fileSize;
  final String description;
  final String uploadedBy;
  final String uploaderId;
  final DateTime uploadedAt;

  MeetingFile({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.fileSize,
    required this.description,
    required this.uploadedBy,
    required this.uploaderId,
    required this.uploadedAt,
  });

  factory MeetingFile.fromJson(Map<String, dynamic> json) {
    DateTime uploadedAt;
    final rawUploadedAt = json['uploaded_at'];
    if (rawUploadedAt is String) {
      uploadedAt = DateTime.parse(rawUploadedAt);
    } else if (rawUploadedAt is DateTime) {
      uploadedAt = rawUploadedAt;
    } else {
      uploadedAt = DateTime.now();
    }

    return MeetingFile(
      id: json['id'].toString(),
      fileName: json['file_name'] ?? '',
      filePath: json['file_path'] ?? '',
      fileType: json['file_type'] ?? '',
      fileSize: json['file_size'] ?? 0,
      description: json['description'] ?? '',
      uploadedBy: json['uploaded_by'] ?? '',
      uploaderId: json['uploader_id'] ?? '',
      uploadedAt: uploadedAt,
    );
  }
}
