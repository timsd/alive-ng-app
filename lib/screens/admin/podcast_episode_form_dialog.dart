import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../models/podcast_models.dart';
import '../../services/appwrite_admin_content_service.dart';
import '../../services/appwrite_storage_compat_service.dart';
import '../../utils/responsive_utils.dart';

const int maxPodcastAudioBytes = 200000000;

String formatFileSize(int bytes) {
  const mb = 1024 * 1024;
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  const kb = 1024;
  if (bytes >= kb) return '${(bytes / kb).toStringAsFixed(1)} KB';
  return '$bytes B';
}

String audioContentType(String fileName) {
  final extension = fileName.split('.').last.toLowerCase();
  return switch (extension) {
    'm4a' => 'audio/mp4',
    'wav' => 'audio/wav',
    'aac' => 'audio/aac',
    'ogg' => 'audio/ogg',
    _ => 'audio/mpeg',
  };
}

Map<String, dynamic> podcastEpisodePayload(PodcastEpisode episode) {
  return {
    'title': episode.title,
    'podcast_id': episode.podcastId,
    'podcast_title': episode.podcastTitle,
    'description': episode.description,
    'duration': episode.duration,
    'audio_url': episode.audioUrl,
    'publish_date': episode.publishDate.toUtc().toIso8601String(),
    'is_downloaded': episode.isDownloaded,
    'local_path': episode.localPath,
  };
}

Map<String, dynamic> podcastPayload(Podcast podcast, {String? category}) {
  final now = DateTime.now().toUtc().toIso8601String();
  return {
    'title': podcast.title,
    'description': podcast.description,
    'category': category ?? podcast.category.displayName,
    'host': podcast.host,
    'episodes': podcast.episodes,
    'rating': podcast.rating,
    'is_subscribed': podcast.isSubscribed,
    'tags': podcast.tags,
    'cover_image': podcast.coverImage,
    'audio_url': podcast.audioUrl,
    'created_at': now,
    'updated_at': now,
  };
}

class PodcastEpisodeFormDialog extends StatefulWidget {
  final Podcast podcast;
  final PodcastEpisode? episode;
  final VoidCallback? onEpisodeSaved;

  const PodcastEpisodeFormDialog({
    super.key,
    required this.podcast,
    this.episode,
    this.onEpisodeSaved,
  });

  @override
  State<PodcastEpisodeFormDialog> createState() =>
      _PodcastEpisodeFormDialogState();
}

class _PodcastEpisodeFormDialogState extends State<PodcastEpisodeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  final _audioContentController = TextEditingController();

  DateTime _publishDate = DateTime.now();
  Uint8List? _audioBytes;
  String? _audioFileName;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.episode != null) {
      _titleController.text = widget.episode!.title;
      _descriptionController.text = widget.episode!.description;
      _durationController.text = widget.episode!.duration;
      _publishDate = widget.episode!.publishDate;
      _audioContentController.text = widget.episode!.audioUrl;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _durationController.dispose();
    _audioContentController.dispose();
    super.dispose();
  }

  Future<void> _pickAudioFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Selected audio file is empty.')),
        );
      }
      return;
    }
    setState(() {
      _audioBytes = file.bytes;
      _audioFileName = file.name;
      _audioContentController.text = file.name;
    });
  }

  Future<void> _saveEpisode() async {
    if (!_formKey.currentState!.validate()) return;
    final isExistingEdit = widget.episode != null;
    if ((_audioBytes == null || _audioFileName == null) &&
        (!isExistingEdit || widget.episode!.audioUrl.isEmpty)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an audio file.')),
        );
      }
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final contentService = AppwriteAdminContentService.instance;
    final storageService = AppwriteStorageCompatService();

    try {
      final episodeId = widget.episode?.id ??
          DateTime.now().millisecondsSinceEpoch.toString();

      String audioUrl;
      if (_audioBytes != null && _audioFileName != null) {
        if (_audioBytes!.length > maxPodcastAudioBytes) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Audio file is too large. Maximum allowed is ${formatFileSize(maxPodcastAudioBytes)}.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final safeFileName = _audioFileName!.replaceAll(
          RegExp(r'[^a-zA-Z0-9._-]'),
          '_',
        );
        final storagePath =
            'podcast_media/${widget.podcast.id}/episodes/$episodeId/$safeFileName';

        // Upload audio to Appwrite Storage (podcast_media bucket).
        audioUrl = await storageService.uploadFile(
          storagePath,
          _audioBytes!,
          contentType: audioContentType(safeFileName),
        );
      } else if (isExistingEdit) {
        audioUrl = widget.episode!.audioUrl;
      } else {
        throw StateError('No audio file selected for new episode.');
      }

      final episode = PodcastEpisode(
        id: episodeId,
        title: _titleController.text.trim(),
        podcastId: widget.podcast.id,
        podcastTitle: widget.podcast.title,
        description: _descriptionController.text.trim(),
        duration: _durationController.text.trim(),
        audioUrl: audioUrl,
        publishDate: _publishDate,
        isDownloaded: false,
        localPath: null,
      );

      await contentService.upsertDocument(
        'podcast_episodes',
        episode.id,
        podcastEpisodePayload(episode),
      );

      // Increment the podcast episode count if this is a new episode.
      if (widget.episode == null) {
        final updatedPodcast = widget.podcast.copyWith(
          episodes: widget.podcast.episodes + 1,
        );
        await contentService.upsertDocument(
          'podcasts',
          updatedPodcast.id,
          podcastPayload(updatedPodcast),
        );
      }

      if (!mounted) return;
      widget.onEpisodeSaved?.call();
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.episode == null
                ? 'Episode uploaded successfully!'
                : 'Episode updated successfully!',
          ),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error uploading episode: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<void> _selectPublishDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _publishDate = picked);
    }
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
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Form(
          key: _formKey,
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
                      widget.episode == null ? Icons.upload_file : Icons.edit,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.episode == null
                            ? 'Add Episode - ${widget.podcast.title}'
                            : 'Edit Episode - ${widget.episode!.title}',
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

              // Form body
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Episode Title *',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter an episode title';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.description),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _durationController,
                        decoration: const InputDecoration(
                          labelText: 'Duration (e.g. 25:30)',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.timer),
                        ),
                      ),
                      const SizedBox(height: 16),

                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.calendar_today),
                        title: const Text('Publish Date'),
                        subtitle: Text(
                          '${_publishDate.day}/${_publishDate.month}/${_publishDate.year}',
                        ),
                        trailing: TextButton(
                          onPressed: _selectPublishDate,
                          child: const Text('Change'),
                        ),
                      ),
                      const SizedBox(height: 16),


                      TextFormField(
                        controller: _audioContentController,
                        decoration: InputDecoration(
                          labelText: 'Audio File *',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.audio_file),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.folder_open),
                            onPressed: _isUploading ? null : _pickAudioFile,
                          ),
                        ),
                        readOnly: true,
                        validator: (value) {
                          if ((value == null || value.trim().isEmpty) &&
                              (_audioBytes == null || _audioBytes!.isEmpty)) {
                            return 'Please select an audio file';
                          }
                          return null;
                        },
                      ),
                      if (_audioFileName != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Selected: $_audioFileName',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                      if (_isUploading) ...[
                        const SizedBox(height: 16),
                        const LinearProgressIndicator(),
                        const SizedBox(height: 8),
                        const Text(
                          'Uploading audio... please keep this dialog open.',
                          style: TextStyle(fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Footer actions
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.black12)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: _isUploading ? null : _saveEpisode,
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
                          : Text(widget.episode == null
                              ? 'Add Episode'
                              : 'Save Changes'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

