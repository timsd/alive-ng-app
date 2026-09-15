import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../../services/auth_service.dart';
import '../../services/appwrite_storage_service.dart';
import '../../models/chat_models.dart';
import '../../utils/responsive_utils.dart';
import '../../config/chat_config.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSendMessage;
  final Function(String, MessageType, List<String>)?
      onSendMessageWithAttachments;
  final Future<List<TaggedEntity>> Function(String) onTagSearch;

  const ChatInputWidget({
    super.key,
    required this.controller,
    required this.onSendMessage,
    this.onSendMessageWithAttachments,
    required this.onTagSearch,
  });

  @override
  State<ChatInputWidget> createState() => _ChatInputWidgetState();
}

class _ChatInputWidgetState extends State<ChatInputWidget> {
  final AuthService _authService = AuthService.instance;
  final ImagePicker _imagePicker = ImagePicker();
  bool _isComposing = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  // --- Discord-style tag autocomplete state (@user, #role/group, !special) ---
  List<TaggedEntity> _tagSuggestions = [];
  bool _showTagSuggestions = false;
  int _activeTagStart = -1;
  String _activeTagPrefix = '';
  int _selectedTagIndex = 0;
  Timer? _tagDebounce;

  @override
  void dispose() {
    _tagDebounce?.cancel();
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = widget.controller.text.trim().isNotEmpty;
    });
    _updateTagSuggestions();
  }

  /// Detects a trailing tag token (`@`, `#`, `!`) at the caret and loads
  /// matching suggestions. `@` searches users via [onTagSearch]; `#` and `!`
  /// resolve locally from ChatConfig roles/special tags.
  void _updateTagSuggestions() {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (cursor < 0 || cursor > text.length) {
      _hideTagSuggestions();
      return;
    }

    final beforeCaret = text.substring(0, cursor);
    final match = RegExp(r'([@#!])([a-zA-Z0-9_]*)$').firstMatch(beforeCaret);
    if (match == null) {
      _hideTagSuggestions();
      return;
    }

    final prefix = match.group(1)!;
    final query = match.group(2)!.toLowerCase();
    _activeTagStart = cursor - query.length - 1;
    _activeTagPrefix = prefix;

    _tagDebounce?.cancel();
    _tagDebounce = Timer(const Duration(milliseconds: 120), () async {
      final results = await _resolveTagSuggestions(prefix, query);
      if (!mounted) return;
      setState(() {
        _tagSuggestions = results;
        _showTagSuggestions = results.isNotEmpty;
        _selectedTagIndex = 0;
      });
    });
  }

  Future<List<TaggedEntity>> _resolveTagSuggestions(
    String prefix,
    String query,
  ) async {
    try {
      if (prefix == '#') {
        return ChatConfig.getTaggableRoles()
            .where((role) => role.toLowerCase().contains(query))
            .map((role) => TaggedEntity(
                  id: role,
                  name: _prettyTagName(role),
                  type: TagType.role,
                ))
            .take(8)
            .toList();
      }
      if (prefix == '!') {
        return ChatConfig.getSpecialTags()
            .map((tag) => tag.replaceAll('#', ''))
            .where((tag) => tag.toLowerCase().contains(query))
            .map((tag) => TaggedEntity(
                  id: tag,
                  name: tag.toUpperCase(),
                  type: TagType.special,
                ))
            .take(8)
            .toList();
      }
      // Users: delegate to the chat screen's search implementation.
      final users = await widget.onTagSearch(query);
      return users.take(8).toList();
    } catch (_) {
      return [];
    }
  }

  /// Replaces the active tag token with the chosen suggestion.
  void _insertTagSuggestion(TaggedEntity entity) {
    final text = widget.controller.text;
    final cursor = widget.controller.selection.baseOffset;
    if (_activeTagStart < 0 || cursor < 0) return;

    final replacement = '$_activeTagPrefix${entity.id} ';
    final newText =
        text.substring(0, _activeTagStart) + replacement + text.substring(cursor);

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: _activeTagStart + replacement.length,
      ),
    );
    _hideTagSuggestions();
  }

  void _hideTagSuggestions() {
    if (!_showTagSuggestions && _tagSuggestions.isEmpty) return;
    if (!mounted) return;
    setState(() {
      _showTagSuggestions = false;
      _tagSuggestions = [];
      _selectedTagIndex = 0;
    });
  }

  Widget _buildTagSuggestions() {
    if (!_showTagSuggestions || _tagSuggestions.isEmpty) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _tagSuggestions.length,
        itemBuilder: (context, index) {
          final entity = _tagSuggestions[index];
          final isSelected = index == _selectedTagIndex;
          return ListTile(
            dense: true,
            selected: isSelected,
            leading: Icon(_tagIcon(entity.type), size: 18),
            title: Text(
              entity.name,
              style: theme.textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              entity.id,
              style: theme.textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _insertTagSuggestion(entity),
          );
        },
      ),
    );
  }

  /// Converts a raw tag value (`campus_coor`) into a readable label.
  String _prettyTagName(String value) {
    return value
        .split('_')
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  IconData _tagIcon(TagType type) {
    switch (type) {
      case TagType.user:
        return Icons.alternate_email;
      case TagType.role:
        return Icons.groups;
      case TagType.special:
        return Icons.bolt;
      case TagType.group:
        return Icons.forum;
    }
  }

  void _handleSubmitted() {
    final text = widget.controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text);
      widget.controller.clear();
      setState(() {
        _isComposing = false;
      });
    }
  }

  Future<void> _handleAttachment() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: [
              if (!kIsWeb) // Hide camera on web where ImageSource.camera is not supported
                ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? image = await _imagePicker.pickImage(
                      source: ImageSource.camera,
                    );
                    if (image != null) {
                      // Handle image attachment
                      _handleImageAttachment(image);
                    }
                  },
                ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Photo Library'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image = await _imagePicker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (image != null) {
                    // Handle image attachment
                    _handleImageAttachment(image);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_file),
                title: const Text('File'),
                onTap: () async {
                  Navigator.pop(context);
                  final FilePickerResult? result =
                      await FilePicker.platform.pickFiles(withData: true);
                  if (result != null) {
                    // Handle file attachment
                    _handleFileAttachment(result.files.first);
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleImageAttachment(XFile image) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final extension = image.name.split('.').last.toLowerCase();
      final contentType = _getContentType(extension);
      final Uint8List imageData = await image.readAsBytes();
      _validateAttachment(
        fileName: image.name,
        size: imageData.lengthInBytes,
        contentType: contentType,
        extension: extension,
      );

      final String fileName =
          'chat_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final String downloadUrl =
          await AppwriteStorageService.instance.uploadChatFile(
        bytes: imageData,
        fileName: fileName,
        contentType: contentType,
      );

      // Send message with image attachment
      if (widget.onSendMessageWithAttachments != null) {
        widget.onSendMessageWithAttachments!(
            'Image shared', MessageType.image, [downloadUrl]);
      } else {
        widget.onSendMessage('Image shared: ${image.name}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _handleFileAttachment(PlatformFile file) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final extension = (file.extension ?? '').toLowerCase();
      final contentType = _getContentType(extension);
      _validateAttachment(
        fileName: file.name,
        size: file.size,
        contentType: contentType,
        extension: extension,
      );

      final String fileName =
          'chat_files/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      if (file.bytes == null) {
        throw Exception('Failed to read file bytes. Please try again.');
      }

      final String downloadUrl =
          await AppwriteStorageService.instance.uploadChatFile(
        bytes: file.bytes!,
        fileName: fileName,
        contentType: contentType,
      );

      // Send message with file attachment
      if (widget.onSendMessageWithAttachments != null) {
        widget.onSendMessageWithAttachments!(
            'File shared: ${file.name}', MessageType.file, [downloadUrl]);
      } else {
        widget.onSendMessage('File shared: ${file.name}');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload file: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'xls':
      case 'xlsx':
        return 'application/vnd.ms-excel';
      case 'ppt':
      case 'pptx':
        return 'application/vnd.ms-powerpoint';
      case 'txt':
        return 'text/plain';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }

  void _validateAttachment({
    required String fileName,
    required int size,
    required String contentType,
    required String extension,
  }) {
    const uploadConfig = ChatConfig.fileUpload;
    final sizeLimit = uploadConfig.sizeLimit;
    final allowedExtensions = uploadConfig.allowedFileExtensions;
    final allowedMimeTypes = uploadConfig.allowedMimeTypes;

    if (size > sizeLimit) {
      final sizeLimitMb = sizeLimit ~/ (1024 * 1024);
      throw Exception('File size must be less than ${sizeLimitMb}MB');
    }
    if (!allowedExtensions.contains(extension)) {
      throw Exception('Unsupported file type for $fileName');
    }
    if (!allowedMimeTypes.contains(contentType)) {
      throw Exception('Unsupported file format for $fileName');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if user is authenticated
    if (!_authService.isAuthenticated) {
      return Container(
        padding: context.responsivePadding,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 0.5,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: context.responsiveIconSize(32),
              color: Theme.of(context).disabledColor,
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 8.0,
                    tablet: 10.0,
                    desktop: 12.0)),
            Text(
              'Please sign in to send messages',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).disabledColor,
                  ),
            ),
            SizedBox(
                height: ResponsiveUtils.getResponsiveValue(
                    context: context,
                    mobile: 12.0,
                    tablet: 14.0,
                    desktop: 16.0)),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, '/auth');
              },
              child: const Text('Sign In'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
          vertical: ResponsiveUtils.getResponsiveValue(
              context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        children: [
          // Upload progress indicator
          if (_isUploading)
            Container(
              padding: context.responsivePadding,
              child: Row(
                children: [
                  SizedBox(
                    width: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 16.0,
                        tablet: 18.0,
                        desktop: 20.0),
                    height: ResponsiveUtils.getResponsiveValue(
                        context: context,
                        mobile: 16.0,
                        tablet: 18.0,
                        desktop: 20.0),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(
                      width: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0)),
                  Text(
                    'Uploading...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          // Discord-style tag suggestions appear above the composer
          _buildTagSuggestions(),
          Row(
            children: [
              // Attachment button
              IconButton(
                icon: Icon(Icons.attach_file,
                    size: context.responsiveIconSize(24)),
                onPressed: _isUploading ? null : _handleAttachment,
              ),
              // Text input field
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText:
                        'Type a message... @ to tag people, # for roles, ! for special tags',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(
                          ResponsiveUtils.getResponsiveValue(
                              context: context,
                              mobile: 20.0,
                              tablet: 22.0,
                              desktop: 24.0))),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 16.0,
                          tablet: 18.0,
                          desktop: 20.0),
                      vertical: ResponsiveUtils.getResponsiveValue(
                          context: context,
                          mobile: 8.0,
                          tablet: 10.0,
                          desktop: 12.0),
                    ),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => _handleSubmitted(),
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  enabled: !_isUploading,
                ),
              ),
              // Send button
              IconButton(
                icon: Icon(
                  Icons.send,
                  size: context.responsiveIconSize(24),
                  color: (_isComposing && !_isUploading)
                      ? Theme.of(context).primaryColor
                      : Theme.of(context).disabledColor,
                ),
                onPressed:
                    (_isComposing && !_isUploading) ? _handleSubmitted : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
