import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/board_models.dart';
import '../../services/supabase_service.dart';

class BoardDocumentsScreen extends StatefulWidget {
  const BoardDocumentsScreen({super.key});

  @override
  State<BoardDocumentsScreen> createState() => _BoardDocumentsScreenState();
}

class _BoardDocumentsScreenState extends State<BoardDocumentsScreen> {
  final SupabaseService _supabaseService = SupabaseService.instance;
  List<BoardDocument> _documents = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _selectedAccessLevel = 'all';
  String _searchQuery = '';

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
      // Mock data for demonstration - replace with actual Supabase query
      await Future.delayed(const Duration(milliseconds: 500));

      _documents = [
        BoardDocument(
          id: '1',
          title: 'ALIVE Nigeria Constitution',
          description: 'Official organizational constitution and bylaws',
          fileName: 'alive_constitution_2024.pdf',
          fileUrl: 'https://example.com/documents/constitution.pdf',
          fileType: 'pdf',
          fileSize: 2048576, // 2MB
          uploadedBy: 'Nwoko Patience Mfon',
          uploaderId: 'user1',
          uploadedAt: DateTime.now().subtract(const Duration(days: 30)),
          category: 'policy',
          accessLevel: 'board_only',
          tags: ['constitution', 'governance', 'legal'],
        ),
        BoardDocument(
          id: '2',
          title: 'Q4 2024 Financial Statements',
          description: 'Detailed financial reports and audit results',
          fileName: 'q4_2024_financials.xlsx',
          fileUrl: 'https://example.com/documents/financials.xlsx',
          fileType: 'xlsx',
          fileSize: 1536000, // 1.5MB
          uploadedBy: 'Timothy Olodude',
          uploaderId: 'user2',
          uploadedAt: DateTime.now().subtract(const Duration(days: 5)),
          category: 'financial',
          accessLevel: 'trustees_only',
          tags: ['financial', 'audit', 'quarterly'],
        ),
        BoardDocument(
          id: '3',
          title: 'Board Meeting Minutes - January 2025',
          description: 'Minutes from the January board meeting',
          fileName: 'board_minutes_jan_2025.docx',
          fileUrl: 'https://example.com/documents/minutes.docx',
          fileType: 'docx',
          fileSize: 512000, // 512KB
          uploadedBy: 'Caleb Peters',
          uploaderId: 'user3',
          uploadedAt: DateTime.now().subtract(const Duration(days: 2)),
          category: 'meeting_minutes',
          accessLevel: 'board_only',
          tags: ['minutes', 'meeting', 'january'],
        ),
        BoardDocument(
          id: '4',
          title: 'Strategic Plan 2025-2030',
          description: 'Five-year strategic development plan',
          fileName: 'strategic_plan_2025_2030.pdf',
          fileUrl: 'https://example.com/documents/strategic_plan.pdf',
          fileType: 'pdf',
          fileSize: 3072000, // 3MB
          uploadedBy: 'Godstime Esuku',
          uploaderId: 'user4',
          uploadedAt: DateTime.now().subtract(const Duration(days: 10)),
          category: 'strategic',
          accessLevel: 'board_only',
          tags: ['strategy', 'planning', '2025-2030'],
        ),
        BoardDocument(
          id: '5',
          title: 'Health Ministry Guidelines',
          description: 'Operational guidelines for health programs',
          fileName: 'health_ministry_guidelines.pdf',
          fileUrl: 'https://example.com/documents/health_guidelines.pdf',
          fileType: 'pdf',
          fileSize: 1024000, // 1MB
          uploadedBy: 'Emenike Ekechi',
          uploaderId: 'user5',
          uploadedAt: DateTime.now().subtract(const Duration(days: 7)),
          category: 'policy',
          accessLevel: 'public',
          tags: ['health', 'ministry', 'guidelines'],
        ),
      ];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading documents: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
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
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Column(
              children: [
                // Search Bar
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Search documents...',
                    prefixIcon: Icon(Icons.search),
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
                const SizedBox(height: 12),

                // Filter Dropdowns
                Row(
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
                            child: Text(
                                category.replaceAll('_', ' ').toUpperCase()),
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
                        initialValue: _selectedAccessLevel,
                        decoration: const InputDecoration(
                          labelText: 'Access Level',
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: _accessLevels.map((level) {
                          return DropdownMenuItem(
                            value: level,
                            child:
                                Text(level.replaceAll('_', ' ').toUpperCase()),
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
                ? const Center(
                    child: CircularProgressIndicator(color: Colors.green),
                  )
                : _filteredDocuments.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.folder_outlined,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No documents found',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadDocuments,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
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
      default:
        fileIcon = Icons.insert_drive_file;
        fileIconColor = Colors.grey;
    }

    Color accessLevelColor;
    switch (document.accessLevel) {
      case 'public':
        accessLevelColor = Colors.green;
        break;
      case 'board_only':
        accessLevelColor = Colors.blue;
        break;
      case 'trustees_only':
        accessLevelColor = Colors.orange;
        break;
      case 'admin_only':
        accessLevelColor = Colors.red;
        break;
      default:
        accessLevelColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () => _viewDocument(document),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    fileIcon,
                    color: fileIconColor,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          document.fileName,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accessLevelColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accessLevelColor),
                    ),
                    child: Text(
                      document.accessLevel.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: accessLevelColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                document.description,
                style: const TextStyle(
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 12),

              // Tags
              if (document.tags.isNotEmpty) ...[
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: document.tags
                      .map((tag) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                  color: Colors.green.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              '#$tag',
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.green,
                              ),
                            ),
                          ))
                      .toList(),
                ),
                const SizedBox(height: 12),
              ],

              Row(
                children: [
                  Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    document.uploadedBy,
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
                    DateFormat('MMM dd, yyyy').format(document.uploadedAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.storage,
                    size: 16,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatFileSize(document.fileSize),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      document.category.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
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
                  const Text(
                    'File: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(document.fileName),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Size: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(_formatFileSize(document.fileSize)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Uploaded by: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(document.uploadedBy),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text(
                    'Date: ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(DateFormat('MMM dd, yyyy HH:mm')
                      .format(document.uploadedAt)),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                document.description,
                style: const TextStyle(fontStyle: FontStyle.italic),
              ),
              if (document.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Tags:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: document.tags
                      .map((tag) => Chip(
                            label: Text(
                              tag,
                              style: const TextStyle(fontSize: 12),
                            ),
                            backgroundColor:
                                Colors.green.withValues(alpha: 0.1),
                            side: BorderSide(
                                color: Colors.green.withValues(alpha: 0.3)),
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
            icon: const Icon(Icons.download, color: Colors.white),
            label:
                const Text('Download', style: TextStyle(color: Colors.white)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadDocument(BoardDocument document) async {
    try {
      // Get the signed URL for the document
      final signedUrl = await _supabaseService.client.storage
          .from('board-documents')
          .createSignedUrl(document.fileUrl, 3600); // 1 hour expiry

      // Launch the URL to download the file
      if (await canLaunchUrl(Uri.parse(signedUrl))) {
        await launchUrl(Uri.parse(signedUrl), mode: LaunchMode.externalApplication);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloading ${document.fileName}...'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw 'Could not launch download URL';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading document: $e'),
            backgroundColor: Colors.red,
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
    String? selectedFileName;

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
                    selectedFileName ?? 'No file selected',
                    style: TextStyle(
                      color:
                          selectedFileName != null ? Colors.green : Colors.grey,
                    ),
                  ),
                  trailing: const Icon(Icons.attach_file),
                  onTap: () async {
                    try {
                      FilePickerResult? result = await FilePicker.platform.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'doc', 'docx', 'xls', 'xlsx', 'ppt', 'pptx'],
                        allowMultiple: false,
                      );

                      if (result != null && result.files.single.path != null) {
                        setDialogState(() {
                          selectedFileName = result.files.single.name;
                        });
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error selecting file: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                ),
                const SizedBox(height: 16),

                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Document Title',
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
                  maxLines: 3,
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
                      child: Text(category.replaceAll('_', ' ').toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) => selectedCategory = value!,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccessLevel,
                  decoration: const InputDecoration(
                    labelText: 'Access Level',
                    border: OutlineInputBorder(),
                  ),
                  items: _accessLevels.skip(1).map((level) {
                    return DropdownMenuItem(
                      value: level,
                      child: Text(level.replaceAll('_', ' ').toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) => selectedAccessLevel = value!,
                ),
                const SizedBox(height: 16),
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
                    selectedFileName != null) {
                  Navigator.pop(context);
                  await _uploadDocument(
                    titleController.text,
                    descriptionController.text,
                    selectedFileName!,
                    selectedCategory,
                    selectedAccessLevel,
                    tagsController.text,
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child:
                  const Text('Upload', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDocument(String title, String description, String fileName,
      String category, String accessLevel, String tagsText) async {
    try {
      final tags = tagsText
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();

      // Save document metadata to database
      await _supabaseService.client.from('board_documents').insert({
        'title': title,
        'description': description,
        'file_name': fileName,
        'file_url': 'documents/$fileName',
        'file_type': fileName.split('.').last,
        'file_size': 1024000, // This would be actual file size in real implementation
        'uploaded_by': _supabaseService.currentUser?.email ?? 'Unknown',
        'uploader_id': _supabaseService.currentUser?.id ?? '',
        'uploaded_at': DateTime.now().toIso8601String(),
        'category': category,
        'access_level': accessLevel,
        'tags': tags,
        'is_archived': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload documents to show the new upload
      await _loadDocuments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
