import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/video_content_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/custom_app_bar.dart';
import '../../widgets/custom_image.dart';
import '../../widgets/standard_video_player_modal.dart';

class VideoContentAdminScreen extends StatefulWidget {
  const VideoContentAdminScreen({super.key});

  @override
  State<VideoContentAdminScreen> createState() => _VideoContentAdminScreenState();
}

class _VideoContentAdminScreenState extends State<VideoContentAdminScreen> {
  final VideoContentService _videoService = VideoContentService.instance;
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedCategory = 'All';

  final List<String> _categories = [
    'All',
    'Bible Study',
    'MEC',
    'Health & Wholeness',
    'Missions',
    'Youth Revival',
    'Music & Worship',
  ];

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos({bool forceRefresh = false}) async {
    setState(() => _isLoading = true);
    await _videoService.loadVideos(forceRefresh: forceRefresh);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredVideos {
    return _videoService.currentVideos.where((v) {
      final title = (v['title'] ?? '').toString().toLowerCase();
      final author = (v['author'] ?? '').toString().toLowerCase();
      final category = (v['category'] ?? '').toString();
      final matchesSearch = _searchQuery.isEmpty ||
          title.contains(_searchQuery.toLowerCase()) ||
          author.contains(_searchQuery.toLowerCase());
      final matchesCategory = _selectedCategory == 'All' ||
          category.toLowerCase() == _selectedCategory.toLowerCase();
      return matchesSearch && matchesCategory;
    }).toList();
  }

  void _previewVideo(Map<String, dynamic> video) {
    StandardVideoPlayerModal.show(context, videoData: video);
  }

  Future<void> _toggleActive(Map<String, dynamic> video) async {
    final currentActive = video['is_active'] == true;
    final updated = Map<String, dynamic>.from(video);
    updated['is_active'] = !currentActive;
    await _videoService.saveVideo(updated);
    if (mounted) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            !currentActive
                ? '"${video['title']}" is now visible to users.'
                : '"${video['title']}" is now hidden from users.',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteVideo(Map<String, dynamic> video) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Video?'),
        content: Text(
          'Are you sure you want to permanently delete "${video['title']}"? '
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final id = (video['id'] ?? video[r'$id'])?.toString() ?? '';
      final ok = await _videoService.deleteVideo(id);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Video deleted successfully.' : 'Failed to delete video.'),
            backgroundColor: ok
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _showVideoEditorDialog({Map<String, dynamic>? video}) {
    final isEditing = video != null;
    final titleController = TextEditingController(text: video?['title'] ?? '');
    final authorController = TextEditingController(text: video?['author'] ?? 'ALIVE Media');
    final categoryController = TextEditingController(text: video?['category'] ?? 'Bible Study');
    final durationController = TextEditingController(text: video?['duration'] ?? '15:00');
    final languageController = TextEditingController(text: video?['language'] ?? 'en');
    final videoUrlController = TextEditingController(text: video?['video_url'] ?? video?['videoUrl'] ?? '');
    final thumbnailUrlController = TextEditingController(text: video?['thumbnail_url'] ?? video?['thumbnailUrl'] ?? '');
    final descriptionController = TextEditingController(text: video?['description'] ?? '');
    final notesController = TextEditingController(text: video?['notes'] ?? '');
    bool isVertical = (video?['aspect_ratio']?.toString().contains('9:16') ?? false) ||
        (video?['aspectRatio']?.toString().contains('9:16') ?? false) ||
        (video?['isVertical'] == true);
    bool isActive = video?['is_active'] ?? true;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(
                  isEditing ? Icons.edit_note_rounded : Icons.video_call_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(isEditing ? 'Edit Video Content' : 'Upload Video Content'),
              ],
            ),
            content: SizedBox(
              width: 580,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Video Title *',
                        hintText: 'e.g. Bible Study Methods',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: authorController,
                            decoration: const InputDecoration(
                              labelText: 'Author / Presenter',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _categories.contains(categoryController.text)
                                ? categoryController.text
                                : 'Bible Study',
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: _categories
                                .where((c) => c != 'All')
                                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setDialogState(() => categoryController.text = val);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: durationController,
                            decoration: const InputDecoration(
                              labelText: 'Duration (mm:ss)',
                              hintText: '18:30',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: languageController,
                            decoration: const InputDecoration(
                              labelText: 'Language Code',
                              hintText: 'en',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Video URL & File Upload
                    TextField(
                      controller: videoUrlController,
                      decoration: InputDecoration(
                        labelText: 'Video Stream URL (MP4 / WebM / HLS) *',
                        hintText: 'https://...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.file_upload_outlined),
                          tooltip: 'Upload MP4 File to Storage',
                          onPressed: isUploading
                              ? null
                              : () async {
                                  try {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.video,
                                      withData: true,
                                    );
                                    if (result != null && result.files.isNotEmpty) {
                                      final file = result.files.first;
                                      final bytes = file.bytes;
                                      if (bytes != null) {
                                        setDialogState(() => isUploading = true);
                                        final url = await _videoService.uploadMediaFile(
                                          bytes: bytes,
                                          filename: file.name,
                                          mimeType: 'video/mp4',
                                        );
                                        setDialogState(() {
                                          isUploading = false;
                                          if (url != null) {
                                            videoUrlController.text = url;
                                          }
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploading = false);
                                  }
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Thumbnail URL & Upload
                    TextField(
                      controller: thumbnailUrlController,
                      decoration: InputDecoration(
                        labelText: 'Thumbnail Image URL',
                        hintText: 'https://...',
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add_photo_alternate_outlined),
                          tooltip: 'Upload Thumbnail Image',
                          onPressed: isUploading
                              ? null
                              : () async {
                                  try {
                                    final result = await FilePicker.platform.pickFiles(
                                      type: FileType.image,
                                      withData: true,
                                    );
                                    if (result != null && result.files.isNotEmpty) {
                                      final file = result.files.first;
                                      final bytes = file.bytes;
                                      if (bytes != null) {
                                        setDialogState(() => isUploading = true);
                                        final url = await _videoService.uploadMediaFile(
                                          bytes: bytes,
                                          filename: file.name,
                                          mimeType: 'image/jpeg',
                                        );
                                        setDialogState(() {
                                          isUploading = false;
                                          if (url != null) {
                                            thumbnailUrlController.text = url;
                                          }
                                        });
                                      }
                                    }
                                  } catch (e) {
                                    setDialogState(() => isUploading = false);
                                  }
                                },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description / Overview',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    TextField(
                      controller: notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Study Notes / Key Takeaways',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Vertical 9:16 (Shorts)'),
                            subtitle: Text(isVertical ? 'Mobile vertical mode' : 'Standard 16:9 landscape'),
                            value: isVertical,
                            onChanged: (val) => setDialogState(() => isVertical = val),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Published'),
                            subtitle: Text(isActive ? 'Visible to users' : 'Hidden'),
                            value: isActive,
                            onChanged: (val) => setDialogState(() => isActive = val),
                          ),
                        ),
                      ],
                    ),

                    if (isUploading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                      const SizedBox(height: 4),
                      const Text(
                        'Uploading media to Appwrite storage...',
                        style: TextStyle(fontSize: 12, color: Colors.blue),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: isUploading ? null : () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.check, size: 18),
                label: Text(isEditing ? 'Save Changes' : 'Publish Video'),
                onPressed: isUploading
                    ? null
                    : () async {
                        if (titleController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please enter a video title')),
                          );
                          return;
                        }
                        if (videoUrlController.text.trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Please provide or upload a video stream URL')),
                          );
                          return;
                        }

                        final payload = <String, dynamic>{
                          if (isEditing) ...video,
                          'title': titleController.text.trim(),
                          'author': authorController.text.trim(),
                          'category': categoryController.text.trim(),
                          'duration': durationController.text.trim(),
                          'language': languageController.text.trim(),
                          'video_url': videoUrlController.text.trim(),
                          'thumbnail_url': thumbnailUrlController.text.trim(),
                          'description': descriptionController.text.trim(),
                          'notes': notesController.text.trim(),
                          'aspect_ratio': isVertical ? '9:16' : '16:9',
                          'is_active': isActive,
                        };

                        Navigator.pop(dialogCtx);
                        setState(() => _isLoading = true);
                        await _videoService.saveVideo(payload);
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isEditing ? 'Video updated successfully.' : 'Video published successfully.'),
                              backgroundColor: Theme.of(context).colorScheme.primary,
                            ),
                          );
                        }
                      },
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final videos = _filteredVideos;
    final totalVideos = _videoService.currentVideos.length;
    final activeVideos = _videoService.currentVideos.where((v) => v['is_active'] == true).length;

    return RoleProtectedScreen(
      requiredRole: 'admin',
      screenName: 'Video Content Management',
      child: Scaffold(
        appBar: CustomAppBar(
          title: 'Video Content Management',
          showBackButton: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Reload from Database',
              onPressed: () => _loadVideos(forceRefresh: true),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _showVideoEditorDialog(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add Video'),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () => _loadVideos(forceRefresh: true),
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Stats overview banner
                    Card(
                      elevation: 0,
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('Total Videos', '$totalVideos', Icons.video_library_rounded, theme.colorScheme.primary),
                            _buildStatItem('Active / Live', '$activeVideos', Icons.check_circle_outline_rounded, Colors.green),
                            _buildStatItem('Categories', '${_categories.length - 1}', Icons.category_outlined, Colors.purple),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Search & Category Filters
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            onChanged: (val) => setState(() => _searchQuery = val),
                            decoration: InputDecoration(
                              hintText: 'Search videos by title or speaker...',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Category Pill Filter
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: _categories.map((c) {
                          final isSelected = _selectedCategory == c;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(c),
                              selected: isSelected,
                              onSelected: (_) => setState(() => _selectedCategory = c),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Videos list
                    if (videos.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Column(
                            children: [
                              Icon(Icons.video_library_outlined, size: 64, color: theme.colorScheme.outline),
                              const SizedBox(height: 16),
                              Text(
                                'No videos found in this category',
                                style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                              const SizedBox(height: 8),
                              FilledButton.icon(
                                onPressed: () => _showVideoEditorDialog(),
                                icon: const Icon(Icons.add),
                                label: const Text('Upload Your First Video'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...videos.map((video) => _buildVideoCard(video, theme, isDark)),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }

  Widget _buildVideoCard(Map<String, dynamic> video, ThemeData theme, bool isDark) {
    final title = video['title'] ?? 'Untitled Video';
    final author = video['author'] ?? 'ALIVE Media';
    final category = video['category'] ?? 'General';
    final duration = video['duration'] ?? '00:00';
    final thumbnailUrl = (video['thumbnail_url'] ?? video['thumbnailUrl'])?.toString() ?? '';
    final isActive = video['is_active'] == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail container with play button overlay
            Stack(
              alignment: Alignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: 140,
                    height: 84,
                    child: thumbnailUrl.isNotEmpty
                        ? CustomImage(
                            imageUrl: thumbnailUrl,
                            width: 140,
                            height: 84,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            child: Icon(Icons.video_library_rounded, color: theme.colorScheme.primary),
                          ),
                  ),
                ),
                // Play preview button
                InkWell(
                  onTap: () => _previewVideo(video),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 24),
                  ),
                ),
                // Duration pill badge
                if (duration.isNotEmpty)
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        duration,
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Metadata info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          category,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: isActive,
                        onChanged: (_) => _toggleActive(video),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    author,
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),

                  // Actions row
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.play_circle_outline, size: 16),
                        label: const Text('Preview', style: TextStyle(fontSize: 12)),
                        onPressed: () => _previewVideo(video),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Video',
                        onPressed: () => _showVideoEditorDialog(video: video),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
                        tooltip: 'Delete Video',
                        onPressed: () => _deleteVideo(video),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

