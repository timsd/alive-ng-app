import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/board_models.dart';
import '../../services/firebase_database_service.dart';
import '../../services/appwrite_storage_compat_service.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_utils.dart';
import '../../utils/text_formatter.dart';

class BoardDocumentsScreen extends StatefulWidget {
  const BoardDocumentsScreen({super.key});

  @override
  State<BoardDocumentsScreen> createState() => _BoardDocumentsScreenState();
}

class _BoardDocumentsScreenState extends State<BoardDocumentsScreen> {
  final FirebaseDatabaseService _databaseService =
      FirebaseDatabaseService.instance;
  final AuthService _authService = AuthService.instance;
  List<BoardDocument> _documents = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedAccessLevel = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _categories = [
    'all',
    'policy',
    'financial',
    'meeting_minutes',
    'strategic',
    'legal'
  ];
  final List<String> _accessLevels = [
    'all',
    'public',
    'board_only',
    'trustees_only',
    'admin_only'
  ];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);

    try {
      final snapshot = await _databaseService.firestore
          .collection('board_documents')
          .orderBy('uploaded_at', descending: true)
          .get();

      setState(() {
        _documents = snapshot.docs
            .map((doc) => BoardDocument.fromJson(doc.data()))
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading documents: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading documents: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
      setState(() => _isLoading = false);
    }
  }

  void _filterDocuments(String query) {
    setState(() {
      _searchQuery = query;
    });
  }

  List<BoardDocument> get _filteredDocuments {
    return _documents.where((document) {
      final categoryMatch =
          _selectedCategory == 'all' || document.category == _selectedCategory;
      final accessMatch = _selectedAccessLevel == 'all' ||
          document.accessLevel == _selectedAccessLevel;
      final searchMatch = _searchQuery.isEmpty ||
          document.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          document.description
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          document.tags.any(
              (tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));

      return categoryMatch &&
          accessMatch &&
          searchMatch &&
          !document.isArchived;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Board Documents'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: () => _showUploadDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filters
          Container(
            padding: ResponsiveUtils.getResponsivePadding(context),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(
                  ResponsiveUtils.getResponsiveBorderRadiusValue(context, 12)),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search documents...',
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveUtils.getResponsiveSpacing(context, 12),
                      vertical:
                          ResponsiveUtils.getResponsiveSpacing(context, 8),
                    ),
                  ),
                  onChanged: _filterDocuments,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 12)),

                // Filter Dropdowns
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCategory,
                        decoration: InputDecoration(
                          labelText: 'Category',
                          border: const OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveSpacing(
                                context, 12),
                            vertical: ResponsiveUtils.getResponsiveSpacing(
                                context, 8),
                          ),
                        ),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(TextFormatter.formatCategory(category)
                                .toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedCategory = value!);
                        },
                      ),
                    ),
                    SizedBox(
                        width:
                            ResponsiveUtils.getResponsiveSpacing(context, 16)),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedAccessLevel,
                        decoration: InputDecoration(
                          labelText: 'Access Level',
                          border: const OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: ResponsiveUtils.getResponsiveSpacing(
                                context, 12),
                            vertical: ResponsiveUtils.getResponsiveSpacing(
                                context, 8),
                          ),
                        ),
                        items: _accessLevels.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child: Text(
                                TextFormatter.formatRole(level).toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => _selectedAccessLevel = value!);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Documents List
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.primary),
                  )
                : _filteredDocuments.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: ResponsiveUtils.getResponsiveIconSize(
                                  context, 64),
                              color: Colors.grey,
                            ),
                            SizedBox(
                                height: ResponsiveUtils.getResponsiveSpacing(
                                    context, 16)),
                            Text(
                              'No documents found',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context, 18),
                                color: Theme.of(context).colorScheme.outline,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDocuments,
                        child: ListView.builder(
                          padding:
                              ResponsiveUtils.getResponsivePadding(context),
                          itemCount: _filteredDocuments.length,
                          itemBuilder: (context, index) {
                            final document = _filteredDocuments[index];
                            return _buildDocumentCard(document);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentCard(BoardDocument document) {
    IconData fileIcon;
    Color fileIconColor;

    switch (document.fileType.toLowerCase()) {
      case 'pdf':
        fileIcon = Icons.picture_as_pdf;
        fileIconColor = Theme.of(context).colorScheme.error;
        break;
      case 'doc':
      case 'docx':
        fileIcon = Icons.description;
        fileIconColor = Theme.of(context).colorScheme.secondary;
        break;
      case 'xls':
      case 'xlsx':
        fileIcon = Icons.table_chart;
        fileIconColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'ppt':
      case 'pptx':
        fileIcon = Icons.slideshow;
        fileIconColor = Colors
            .orange; // Keep orange as it's common for ppt, but maybe use a theme color if possible
        break;
      default:
        fileIcon = Icons.insert_drive_file;
        fileIconColor = Theme.of(context).colorScheme.outline;
    }

    Color accessLevelColor;
    switch (document.accessLevel) {
      case 'public':
        accessLevelColor = Theme.of(context).colorScheme.tertiary;
        break;
      case 'board_only':
        accessLevelColor = Theme.of(context).colorScheme.secondary;
        break;
      case 'trustees_only':
        accessLevelColor = Colors.orange;
        break;
      case 'admin_only':
        accessLevelColor = Theme.of(context).colorScheme.error;
        break;
      default:
        accessLevelColor = Theme.of(context).colorScheme.outline;
    }

    return Card(
      margin: EdgeInsets.only(
          bottom: ResponsiveUtils.getResponsiveSpacing(context, 12)),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewDocument(document),
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
                    size: ResponsiveUtils.getResponsiveIconSize(context, 24),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context, 16),
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        SizedBox(
                            height: ResponsiveUtils.getResponsiveSpacing(
                                context, 4)),
                        Text(
                          document.fileName,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context, 12),
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveUtils.getResponsiveSpacing(context, 8),
                      vertical:
                          ResponsiveUtils.getResponsiveSpacing(context, 4),
                    ),
                    decoration: BoxDecoration(
                      color: accessLevelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadiusValue(
                              context, 12)),
                      border: Border.all(color: accessLevelColor),
                    ),
                    child: Text(
                      TextFormatter.formatRole(document.accessLevel)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize:
                            ResponsiveUtils.getResponsiveFontSize(context, 10),
                        fontWeight: FontWeight.bold,
                        color: accessLevelColor,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Text(
                document.description,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 12)),

              // Tags
              if (document.tags.isNotEmpty) ...[
                Wrap(
                  spacing: ResponsiveUtils.getResponsiveSpacing(context, 6),
                  runSpacing: ResponsiveUtils.getResponsiveSpacing(context, 4),
                  children: document.tags
                      .map((tag) => Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: ResponsiveUtils.getResponsiveSpacing(
                                  context, 6),
                              vertical: ResponsiveUtils.getResponsiveSpacing(
                                  context, 2),
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                  ResponsiveUtils
                                      .getResponsiveBorderRadiusValue(
                                          context, 8)),
                              border: Border.all(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary
                                      .withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '#$tag',
                              style: TextStyle(
                                fontSize: ResponsiveUtils.getResponsiveFontSize(
                                    context, 10),
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 12)),
              ],

              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    document.uploadedBy,
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 12),
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  Icon(
                    Icons.calendar_today,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    DateFormat('MMM dd, yyyy').format(document.uploadedAt),
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 12),
                      color: Colors.grey.shade600,
                    ),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                  Icon(
                    Icons.storage,
                    size: ResponsiveUtils.getResponsiveIconSize(context, 16),
                    color: Colors.grey.shade600,
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveSpacing(context, 4)),
                  Text(
                    _formatFileSize(document.fileSize),
                    style: TextStyle(
                      fontSize:
                          ResponsiveUtils.getResponsiveFontSize(context, 12),
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal:
                          ResponsiveUtils.getResponsiveSpacing(context, 6),
                      vertical:
                          ResponsiveUtils.getResponsiveSpacing(context, 2),
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .secondary
                          .withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                          ResponsiveUtils.getResponsiveBorderRadiusValue(
                              context, 8)),
                    ),
                    child: Text(
                      TextFormatter.formatCategory(document.category)
                          .toUpperCase(),
                      style: TextStyle(
                        fontSize:
                            ResponsiveUtils.getResponsiveFontSize(context, 10),
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.secondary,
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  void _viewDocument(BoardDocument document) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(document.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Text(
                    'File: ',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(document.fileName),
                  ),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Row(
                children: [
                  Text(
                    'Size: ',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(_formatFileSize(document.fileSize)),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Row(
                children: [
                  Text(
                    'Uploaded by: ',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(document.uploadedBy),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
              Row(
                children: [
                  Text(
                    'Date: ',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(DateFormat('MMM dd, yyyy HH:mm')
                      .format(document.uploadedAt)),
                ],
              ),
              SizedBox(
                  height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
              Text(
                document.description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(fontStyle: FontStyle.italic),
              ),
              if (document.tags.isNotEmpty) ...[
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                Text(
                  'Tags:',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 8)),
                Wrap(
                  spacing: ResponsiveUtils.getResponsiveSpacing(context, 6),
                  runSpacing: ResponsiveUtils.getResponsiveSpacing(context, 4),
                  children: document.tags
                      .map((tag) => Chip(
                            label: Text(
                              tag,
                              style: TextStyle(
                                  fontSize:
                                      ResponsiveUtils.getResponsiveFontSize(
                                          context, 12),
                                  color: Theme.of(context).colorScheme.primary),
                            ),
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(alpha: 0.1),
                            side: BorderSide(
                                color: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.3)),
                          ))
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _downloadDocument(document);
            },
            icon: Icon(Icons.download,
                color: Theme.of(context).colorScheme.onPrimary),
            label: Text('Download',
                style:
                    TextStyle(color: Theme.of(context).colorScheme.onPrimary)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(BoardDocument document) async {
    try {
      String downloadUrl = document.fileUrl;

      // If it's a storage path (not a full URL), get the download URL
      if (!downloadUrl.startsWith('http')) {
        final url = await AppwriteStorageCompatService()
            .getBoardDocumentDownloadURL(document.fileName);
        if (url != null) {
          downloadUrl = url;
        } else {
          throw 'Could not generate download URL for path: ${document.fileUrl}';
        }
      }

      if (await canLaunchUrl(Uri.parse(downloadUrl))) {
        await launchUrl(Uri.parse(downloadUrl),
            mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch download URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading document: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showUploadDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    final tagsController = TextEditingController();
    String selectedCategory = 'policy';
    String selectedAccessLevel = 'board_only';
    PlatformFile? selectedFile;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Upload Document'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // File Selection
                ListTile(
                  title: const Text('Select File'),
                  subtitle: Text(
                    selectedFile?.name ?? 'No file selected',
                    style: TextStyle(
                      color: selectedFile != null
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  trailing: const Icon(Icons.attach_file),
                  onTap: () async {
                    // Capture ScaffoldMessenger before async operation
                    final messenger = ScaffoldMessenger.of(context);
                    final theme = Theme.of(context);

                    try {
                      FilePickerResult? result =
                          await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: [
                          'pdf',
                          'doc',
                          'docx',
                          'xls',
                          'xlsx',
                          'ppt',
                          'pptx'
                        ],
                        allowMultiple: false,
                        withData: true,
                      );

                      if (result != null) {
                        setDialogState(() {
                          selectedFile = result.files.single;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('Error selecting file: $e'),
                            backgroundColor: theme.colorScheme.error,
                          ),
                        );
                      }
                    }
                  },
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),

                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Document Title',
                    border: OutlineInputBorder(),
                  ),
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                DropdownButtonFormField<String>(
                  initialValue: selectedCategory,
                  decoration: const InputDecoration(
                    labelText: 'Category',
                    border: OutlineInputBorder(),
                  ),
                  items: _categories.skip(1).map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(
                          TextFormatter.formatCategory(category).toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) => selectedCategory = value!,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccessLevel,
                  decoration: const InputDecoration(
                    labelText: 'Access Level',
                    border: OutlineInputBorder(),
                  ),
                  items: _accessLevels.skip(1).map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child:
                          Text(TextFormatter.formatRole(level).toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) => selectedAccessLevel = value!,
                ),
                SizedBox(
                    height: ResponsiveUtils.getResponsiveSpacing(context, 16)),
                TextField(
                  controller: tagsController,
                  decoration: const InputDecoration(
                    labelText: 'Tags (comma-separated)',
                    border: OutlineInputBorder(),
                    hintText: 'e.g. policy, governance, legal',
                  ),
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
              onPressed: () async {
                if (titleController.text.isNotEmpty &&
                    descriptionController.text.isNotEmpty &&
                    selectedFile != null) {
                  Navigator.pop(context);
                  await _uploadDocument(
                    titleController.text,
                    descriptionController.text,
                    selectedFile!,
                    selectedCategory,
                    selectedAccessLevel,
                    tagsController.text,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Theme.of(context).colorScheme.onPrimary,
              ),
              child: Text('Upload',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument(
      String title,
      String description,
      PlatformFile file,
      String category,
      String accessLevel,
      String tagsText) async {
    try {
      final messenger = ScaffoldMessenger.of(context);
      final theme = Theme.of(context);

      // Show loading indicator
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            content: const Text('Uploading document...'),
            backgroundColor: theme.colorScheme.secondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }

      final tags = tagsText
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      String? fileUrl;
      if (file.bytes != null) {
        fileUrl = await AppwriteStorageCompatService().uploadBoardDocument(
            file.bytes!,
            file.name,
            'application/${file.extension ?? 'octet-stream'}');
      }

      if (fileUrl == null) {
        throw 'Failed to upload file to storage';
      }

      // Save document metadata to Firebase
      final currentUser = _authService.currentUser;
      final document = BoardDocument(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: title,
        description: description,
        fileName: file.name,
        fileUrl: fileUrl,
        fileType: file.extension ?? 'unknown',
        fileSize: file.size,
        uploadedBy: currentUser?.displayName ?? currentUser?.email ?? 'Unknown',
        uploaderId: currentUser?.uid ?? '',
        uploadedAt: DateTime.now(),
        category: category,
        accessLevel: accessLevel,
        tags: tags,
      );

      await _databaseService.createDocument(
          'board_documents', document.toJson());

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Document uploaded successfully'),
          backgroundColor: theme.colorScheme.tertiary,
        ),
      );

      // Reload documents to show the new upload
      await _loadDocuments();
    } catch (e) {
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        final theme = Theme.of(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error uploading document: $e'),
            backgroundColor: theme.colorScheme.error,
          ),
        );
      }
    }
  }
}
