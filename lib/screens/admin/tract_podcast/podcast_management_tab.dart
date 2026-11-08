import 'package:flutter/material.dart';
import '../../../services/file_picker_facade.dart';
import '../../../models/podcast_models.dart';
import '../../../utils/error_handler.dart';
import '../../../utils/responsive_utils.dart';
import '../../../services/appwrite_admin_content_service.dart';
import '../../../services/appwrite_storage_compat_service.dart';
import '../../../widgets/custom_image.dart';
import '../podcast_episode_form_dialog.dart';
import 'tract_podcast_shared.dart';

class PodcastManagementTab extends StatefulWidget {
  @override
  State<PodcastManagementTab> createState() => _PodcastManagementTabState();
}

class _PodcastManagementTabState extends State<PodcastManagementTab> {
  Future<List<Podcast>> _loadPodcasts() async {
    final docs = await AppwriteAdminContentService.instance.listCollection(
      'podcasts',
    );
    final podcasts = docs.map((doc) => Podcast.fromJson(doc)).toList();
    podcasts.sort((a, b) => a.title.compareTo(b.title));
    return podcasts;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Add new podcast button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showAddPodcastDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add New Podcast'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ),

        // Podcasts list
        Expanded(
          child: FutureBuilder<List<Podcast>>(
            future: _loadPodcasts(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text(
                    'Unable to load podcasts right now.',
                    textAlign: TextAlign.center,
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final podcasts = snapshot.data ?? [];
              if (podcasts.isEmpty) {
                return const Center(
                    child: Text('No podcasts yet. Tap + to add one.'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: podcasts.length,
                itemBuilder: (context, index) {
                  final podcast = podcasts[index];

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: podcast.coverImage != null
                            ? CustomImage(
                                imageUrl: podcast.coverImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                borderRadius: BorderRadius.circular(8),
                                placeholder: const Icon(
                                  Icons.mic,
                                  color: Colors.blue,
                                ),
                              )
                            : const Icon(
                                Icons.mic,
                                color: Colors.blue,
                              ),
                      ),
                      title: Text(
                        podcast.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                              '${podcast.host} — ${podcast.episodes} episodes'),
                          Text(
                            podcast.category.displayName,
                            style: const TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _showEditPodcastDialog(podcast);
                              break;
                            case 'episodes':
                              _showEpisodesDialog(podcast);
                              break;
                            case 'delete':
                              _showDeletePodcastDialog(podcast);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'episodes',
                            child: Row(
                              children: [
                                Icon(Icons.queue_music),
                                SizedBox(width: 8),
                                Text('Manage Episodes'),
                              ],
                            ),
                          ),
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
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showAddPodcastDialog() {
    showDialog(
      context: context,
      builder: (context) => const _PodcastFormDialog(),
    ).then((result) {
      if (result is Podcast && mounted) {
        setState(() {});
      }
    });
  }

  void _showEditPodcastDialog(Podcast podcast) {
    showDialog(
      context: context,
      builder: (context) => _PodcastFormDialog(podcast: podcast),
    ).then((result) {
      if (result is Podcast && mounted) {
        setState(() {});
      }
    });
  }

  void _showEpisodesDialog(Podcast podcast) {
    showDialog(
      context: context,
      builder: (context) => _EpisodeManagementDialog(podcast: podcast),
    );
  }

  void _showDeletePodcastDialog(Podcast podcast) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Podcast'),
        content: Text(
            'Are you sure you want to delete "${podcast.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () {
              if (!mounted) return;
              navigator.pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final contentService = AppwriteAdminContentService.instance;
                final storageService = AppwriteStorageCompatService();

                // Delete associated cover image if present
                if (podcast.coverImage != null &&
                    podcast.coverImage!.isNotEmpty) {
                  try {
                    await storageService.deleteFileByUrl(podcast.coverImage!);
                  } catch (e) {
                    debugPrint(
                        'Warning: Could not delete podcast cover image: $e');
                  }
                }

                // Find and delete all episodes and their audio files
                final episodes = await contentService.listWhere(
                  'podcast_episodes',
                  'podcast_id',
                  podcast.id,
                );

                for (final ep in episodes) {
                  final audioUrl = (ep['audio_url'] as String?) ??
                      (ep['audioUrl'] as String?) ??
                      '';
                  final episodeId = ep['id'] as String?;

                  if (audioUrl.isNotEmpty) {
                    try {
                      await storageService.deleteFileByUrl(audioUrl);
                    } catch (e) {
                      debugPrint(
                          'Warning: Could not delete episode audio $audioUrl: $e');
                    }
                  }

                  if (episodeId != null && episodeId.isNotEmpty) {
                    try {
                      await contentService.deleteDocument(
                          'podcast_episodes', episodeId);
                    } catch (e) {
                      debugPrint(
                          'Warning: Could not delete episode doc $episodeId: $e');
                    }
                  }
                }

                // Delete podcast document
                await contentService.deleteDocument('podcasts', podcast.id);

                if (mounted) {
                  setState(() {});
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                          'Podcast "${podcast.title}" and associated episodes deleted successfully'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting podcast: ${ErrorHandler.getUserFriendlyMessage(e)}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}


class _PodcastFormDialog extends StatefulWidget {
  final Podcast? podcast;

  const _PodcastFormDialog({this.podcast});

  @override
  State<_PodcastFormDialog> createState() => _PodcastFormDialogState();
}

class _PodcastFormDialogState extends State<_PodcastFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _hostController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _notesController = TextEditingController();
  final _transcriptController = TextEditingController();

  // Dynamic podcast categories from Appwrite with robust defaults
  List<String> _podcastCategories =
      List<String>.from(defaultPodcastCategoryNames);
  String? _selectedPodcastCategoryName;
  bool _loadingPodcastCategories = true;
  PodcastCategory _selectedCategory =
      PodcastCategory.mec; // fallback for local visuals
  bool _isFeatured = false;
  Uint8List? _selectedCoverImageBytes;
  String? _selectedCoverImageName;
  Uint8List? _selectedAudioBytes;
  String? _selectedAudioName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.podcast != null) {
      _titleController.text = widget.podcast!.title;
      _hostController.text = widget.podcast!.host;
      _descriptionController.text = widget.podcast!.description;
      _tagsController.text = widget.podcast!.tags.join(', ');
      _notesController.text = widget.podcast!.notes ?? '';
      _transcriptController.text = widget.podcast!.transcript ?? '';
      _selectedCategory = widget.podcast!.category;
      _selectedPodcastCategoryName = widget.podcast!.categoryDisplayName;
    } else {
      _selectedPodcastCategoryName = defaultPodcastCategoryNames.first;
    }
    _loadPodcastCategories();
  }

  Future<void> _loadPodcastCategories() async {
    setState(() {
      _loadingPodcastCategories = true;
    });
    try {
      final docs = await AppwriteAdminContentService.instance
          .listCollection('podcast_categories', orderBy: 'order');
      final names = docs
          .map((d) => (d['name'] as String?)?.trim() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      if (!mounted) return;
      setState(() {
        final merged = <String>{
          ...defaultPodcastCategoryNames,
          ...names,
          if (_selectedPodcastCategoryName != null &&
              _selectedPodcastCategoryName!.isNotEmpty)
            _selectedPodcastCategoryName!,
        };
        _podcastCategories = merged.toList();
        _selectedPodcastCategoryName ??= _podcastCategories.first;
        _loadingPodcastCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final merged = <String>{
          ...defaultPodcastCategoryNames,
          if (_selectedPodcastCategoryName != null &&
              _selectedPodcastCategoryName!.isNotEmpty)
            _selectedPodcastCategoryName!,
        };
        _podcastCategories = merged.toList();
        _selectedPodcastCategoryName ??= _podcastCategories.first;
        _loadingPodcastCategories = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hostController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _notesController.dispose();
    _transcriptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: MediaQuery.of(context).size.width * 0.9,
          tablet: 600,
          desktop: 700,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.podcast == null ? Icons.add : Icons.edit,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.podcast == null ? 'Add New Podcast' : 'Edit Podcast',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Form content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Podcast Title *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Host
                      TextFormField(
                        controller: _hostController,
                        decoration: const InputDecoration(
                          labelText: 'Host *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a host';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Category (dynamic from Appwrite)
                      DropdownButtonFormField<String>(
                        value: _selectedPodcastCategoryName,
                        decoration: InputDecoration(
                          labelText: 'Category *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.category),
                          suffixIcon: _loadingPodcastCategories
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                        items: <String>{
                          if (_selectedPodcastCategoryName != null &&
                              _selectedPodcastCategoryName!.isNotEmpty)
                            _selectedPodcastCategoryName!,
                          ..._podcastCategories,
                          ...defaultPodcastCategoryNames,
                        }.map((name) {
                          return DropdownMenuItem(
                            value: name,
                            child: Text(name),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedPodcastCategoryName = value;
                            final match =
                                PodcastCategory.values.firstWhere(
                              (c) =>
                                  c.displayName.toLowerCase() ==
                                  (value ?? '').toLowerCase(),
                              orElse: () => _selectedCategory,
                            );
                            _selectedCategory = match;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a category';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Description
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a description';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tags
                      TextFormField(
                        controller: _tagsController,
                        decoration: const InputDecoration(
                          labelText: 'Tags (comma separated)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.tag),
                          helperText: 'e.g., sermon, teaching, worship',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Study Notes & Overview
                      TextFormField(
                        controller: _notesController,
                        decoration: const InputDecoration(
                          labelText: 'Study Notes & Ministry Summary',
                          hintText: 'Paste overview, key scriptural references, sermon outline, or study points...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.sticky_note_2_outlined),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Audio Transcript
                      TextFormField(
                        controller: _transcriptController,
                        decoration: const InputDecoration(
                          labelText: 'Audio Transcript (Timestamped)',
                          hintText: 'Paste audio transcription with speaker tags and timestamps...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.subtitles_outlined),
                        ),
                        maxLines: 4,
                      ),
                      const SizedBox(height: 16),

                      // Featured toggle
                      SwitchListTile(
                        title: const Text('Featured Podcast'),
                        subtitle: const Text('Show this podcast prominently'),
                        value: _isFeatured,
                        onChanged: (value) {
                          setState(() {
                            _isFeatured = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cover Image Upload
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cover Image',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedCoverImageName ??
                                          widget.podcast?.coverImage ??
                                          'No cover image selected',
                                      style: TextStyle(
                                        color: _selectedCoverImageName != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed: _isUploading
                                        ? null
                                        : _selectPodcastCoverImage,
                                    icon: const Icon(Icons.image),
                                    label: const Text('Select Image'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Trailer / intro audio upload (was cover-image only)
                      Card(
                        color: Theme.of(context).colorScheme.surface,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Trailer / Intro Audio',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Optional show-level audio. Full episodes live under Manage Episodes.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _selectedAudioName ??
                                          widget.podcast?.audioUrl ??
                                          'No audio selected',
                                      style: TextStyle(
                                        color: _selectedAudioName != null
                                            ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                            : Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton.icon(
                                    onPressed:
                                        _isUploading ? null : _selectAudioFile,
                                    icon: const Icon(Icons.audio_file),
                                    label: const Text('Select Audio'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Action buttons
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isUploading ? null : _savePodcast,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              ),
                              SizedBox(width: 8),
                              Text('Uploading...'),
                            ],
                          )
                        : Text(widget.podcast == null
                            ? 'Add Podcast'
                            : 'Save Changes'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _selectPodcastCoverImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result != null && result.files.single.bytes != null) {
      setState(() {
        _selectedCoverImageBytes = result.files.single.bytes;
        _selectedCoverImageName = result.files.single.name;
      });
    }
  }

  Future<void> _selectAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'wav', 'aac', 'ogg'],
      withData: true,
    );
    if (result != null && result.files.single.bytes != null) {
      final bytes = result.files.single.bytes!;
      if (bytes.lengthInBytes > 200000000) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audio file is too large (max 200 MB).')),
        );
        return;
      }
      setState(() {
        _selectedAudioBytes = bytes;
        _selectedAudioName = result.files.single.name;
      });
    }
  }

  String _audioContentType(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'm4a':
        return 'audio/mp4';
      case 'wav':
        return 'audio/wav';
      case 'aac':
        return 'audio/aac';
      case 'ogg':
        return 'audio/ogg';
      default:
        return 'audio/mpeg';
    }
  }

  void _savePodcast() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isUploading = true;
      });

      final navigator = Navigator.of(context);
      final messenger = ScaffoldMessenger.of(context);
      try {
        final contentService = AppwriteAdminContentService.instance;
        final storageService = AppwriteStorageCompatService();

        // Upload cover image
        String? coverImageUrl;
        if (_selectedCoverImageBytes != null &&
            _selectedCoverImageName != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_${_selectedCoverImageName!}';
          coverImageUrl = await storageService.uploadFile(
            'podcast-covers/$fileName',
            _selectedCoverImageBytes!,
            contentType: 'image/jpeg',
          );
        }

        // Upload trailer / intro audio (show-level audio)
        String? audioUrl;
        if (_selectedAudioBytes != null && _selectedAudioName != null) {
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final fileName = '${timestamp}_${_selectedAudioName!}';
          audioUrl = await storageService.uploadFile(
            'audio-files/podcasts/$fileName',
            _selectedAudioBytes!,
            contentType: _audioContentType(_selectedAudioName!),
          );
        }

        // Create podcast object with uploaded URL
        final podcast = Podcast(
          id: widget.podcast?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          title: _titleController.text,
          description: _descriptionController.text,
          category: _selectedCategory,
          customCategory: _selectedPodcastCategoryName ??
              widget.podcast?.categoryDisplayName,
          host: _hostController.text,
          episodes: widget.podcast?.episodes ?? 0,
          rating: widget.podcast?.rating ?? 0.0,
          isSubscribed: widget.podcast?.isSubscribed ?? false,
          tags: _tagsController.text
              .split(',')
              .map((tag) => tag.trim())
              .where((tag) => tag.isNotEmpty)
              .toList(),
          coverImage: coverImageUrl ?? widget.podcast?.coverImage,
          audioUrl: audioUrl ?? widget.podcast?.audioUrl,
          notes: _notesController.text.trim().isNotEmpty
              ? _notesController.text.trim()
              : widget.podcast?.notes,
          transcript: _transcriptController.text.trim().isNotEmpty
              ? _transcriptController.text.trim()
              : widget.podcast?.transcript,
        );

        final payload = podcastPayload(
          podcast,
          category:
              _selectedPodcastCategoryName ?? podcast.categoryDisplayName,
          notes: _notesController.text.trim(),
          transcript: _transcriptController.text.trim(),
        );
        await contentService.upsertDocument(
          'podcasts',
          podcast.id,
          payload,
        );

        try {
          if (_isFeatured) {
            await contentService.upsertDocument(
              'featured_content',
              'podcast_${podcast.id}',
              {
                'title': podcast.title,
                'description': podcast.description,
                'content_id': podcast.id,
                'content_type': 'podcast',
                'priority': 1,
                'is_active': true,
                'created_at': DateTime.now().toUtc().toIso8601String(),
                'updated_at': DateTime.now().toUtc().toIso8601String(),
              },
            );
          } else {
            await contentService.deleteDocument(
              'featured_content',
              'podcast_${podcast.id}',
            );
          }
        } catch (_) {}

        if (!mounted) return;
        navigator.pop(podcast);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              widget.podcast == null
                  ? 'Podcast created successfully!'
                  : 'Podcast updated successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Second notification removed to avoid duplication
      } catch (e) {
        if (!mounted) return;
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error uploading podcast: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
}

class _EpisodeManagementDialog extends StatefulWidget {
  final Podcast podcast;

  const _EpisodeManagementDialog({required this.podcast});

  @override
  State<_EpisodeManagementDialog> createState() =>
      _EpisodeManagementDialogState();
}

class _EpisodeManagementDialogState extends State<_EpisodeManagementDialog> {
  Future<List<PodcastEpisode>>? _episodesFuture;

  @override
  void initState() {
    super.initState();
    _episodesFuture = _loadEpisodes();
  }

  Future<List<PodcastEpisode>> _loadEpisodes() async {
    final docs = await AppwriteAdminContentService.instance.listWhere(
      'podcast_episodes',
      'podcast_id',
      widget.podcast.id,
    );
    final episodes =
        docs.map((doc) => PodcastEpisode.fromJson(doc)).toList();
    episodes.sort((a, b) => b.publishDate.compareTo(a.publishDate));
    return episodes;
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _episodesFuture = _loadEpisodes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        width: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: MediaQuery.of(context).size.width * 0.95,
          tablet: 800,
          desktop: 900,
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.queue_music, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Manage Episodes - ${widget.podcast.title}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            // Add episode button
            Container(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _showAddEpisodeDialog(),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Episode'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ),

            // Episodes list
            Expanded(
              child: FutureBuilder<List<PodcastEpisode>>(
                future: _episodesFuture,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Unable to load episodes right now. Pull to retry.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ),
                    );
                  }
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final episodes = snapshot.data ?? const <PodcastEpisode>[];
                  if (episodes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.queue_music,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No episodes yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Add your first episode to get started',
                            style: TextStyle(
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: () async => _refresh(),
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: episodes.length,
                      itemBuilder: (context, index) {
                        final episode = episodes[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.blue.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.audiotrack,
                                  color: Colors.blue),
                            ),
                            title: Text(
                              episode.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              [
                                if (episode.duration.isNotEmpty)
                                  episode.duration,
                                '${episode.publishDate.day}/${episode.publishDate.month}/${episode.publishDate.year}',
                              ].join(' • '),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit,
                                      color: Colors.blue),
                                  onPressed: () =>
                                      _showEditEpisodeDialog(episode),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete,
                                      color: Colors.red),
                                  onPressed: () =>
                                      _showDeleteEpisodeDialog(episode),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddEpisodeDialog() {
    showDialog(
      context: context,
      builder: (context) => PodcastEpisodeFormDialog(
        podcast: widget.podcast,
        onEpisodeSaved: _refresh,
      ),
    );
  }

  void _showEditEpisodeDialog(PodcastEpisode episode) {
    showDialog(
      context: context,
      builder: (context) => PodcastEpisodeFormDialog(
        podcast: widget.podcast,
        episode: episode,
        onEpisodeSaved: _refresh,
      ),
    );
  }

  void _showDeleteEpisodeDialog(PodcastEpisode episode) {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Episode'),
        content: Text(
            'Are you sure you want to delete "${episode.title}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => navigator.pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              try {
                final contentService = AppwriteAdminContentService.instance;
                final storageService = AppwriteStorageCompatService();

                await contentService.deleteDocument(
                    'podcast_episodes', episode.id);

                // Delete audio file from storage if it exists
                if (episode.audioUrl.isNotEmpty) {
                  await storageService.deleteFileByUrl(episode.audioUrl);
                }

                // Update podcast episode count
                final updatedPodcast = widget.podcast.copyWith(
                  episodes: widget.podcast.episodes - 1,
                );

                await contentService.upsertDocument(
                  'podcasts',
                  updatedPodcast.id,
                  podcastPayload(updatedPodcast),
                );

                if (!mounted) return;
                navigator.pop();
                _refresh();
                messenger.showSnackBar(
                  SnackBar(
                    content:
                        Text('Episode "${episode.title}" deleted successfully'),
                    backgroundColor: Colors.red,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  navigator.pop();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error deleting episode: ${ErrorHandler.getUserFriendlyMessage(e)}'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
