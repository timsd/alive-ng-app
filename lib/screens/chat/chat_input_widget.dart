import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../../services/auth_service.dart';
import '../../models/chat_models.dart';
import '../../utils/responsive_utils.dart';

class ChatInputWidget extends StatefulWidget {
  final TextEditingController controller;
  final Function(String) onSendMessage;
  final Function(String, MessageType, List<String>)? onSendMessageWithAttachments;
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
  final FirebaseStorage _storage = FirebaseStorage.instance;
  bool _isComposing = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {
      _isComposing = widget.controller.text.trim().isNotEmpty;
    });
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
                  final FilePickerResult? result = await FilePicker.platform.pickFiles(withData: true);
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
      // Upload image to Firebase Storage
      final String fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final Reference ref = _storage.ref().child(fileName);
      
      // Read image as bytes on all platforms
      final Uint8List imageData = await image.readAsBytes();
      final UploadTask uploadTask = ref.putData(
        imageData,
        SettableMetadata(contentType: 'image/${image.name.split('.').last}'),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Send message with image attachment
      if (widget.onSendMessageWithAttachments != null) {
        widget.onSendMessageWithAttachments!(
          'Image shared', 
          MessageType.image, 
          [downloadUrl]
        );
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
      // Check file size (limit to 10MB)
      if (file.size > 10 * 1024 * 1024) {
        throw Exception('File size must be less than 10MB');
      }

      // Upload file to Firebase Storage
      final String fileName = 'chat_files/${DateTime.now().millisecondsSinceEpoch}_${file.name}';
      final Reference ref = _storage.ref().child(fileName);
      
      // Use bytes for upload across platforms
      if (file.bytes == null) {
        throw Exception('Failed to read file bytes. Please try again.');
      }

      final UploadTask uploadTask = ref.putData(
        file.bytes!,
        SettableMetadata(contentType: _getContentType(file.extension ?? '')),
      );
      
      final TaskSnapshot snapshot = await uploadTask;
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      
      // Send message with file attachment
      if (widget.onSendMessageWithAttachments != null) {
        widget.onSendMessageWithAttachments!(
          'File shared: ${file.name}', 
          MessageType.file, 
          [downloadUrl]
        );
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
      case 'docx':
        return 'application/msword';
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
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
            Text(
              'Please sign in to send messages',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).disabledColor,
              ),
            ),
            SizedBox(height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 12.0, tablet: 14.0, desktop: 16.0)),
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
        horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0), 
        vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 4.0, tablet: 5.0, desktop: 6.0)
      ),
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
                    width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                    height: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0)),
                  Text(
                    'Uploading...',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          Row(
            children: [
              // Attachment button
              IconButton(
                icon: Icon(Icons.attach_file, size: context.responsiveIconSize(24)),
                onPressed: _isUploading ? null : _handleAttachment,
              ),
              // Text input field
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(ResponsiveUtils.getResponsiveValue(context: context, mobile: 20.0, tablet: 22.0, desktop: 24.0))),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Theme.of(context).scaffoldBackgroundColor,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: ResponsiveUtils.getResponsiveValue(context: context, mobile: 16.0, tablet: 18.0, desktop: 20.0),
                      vertical: ResponsiveUtils.getResponsiveValue(context: context, mobile: 8.0, tablet: 10.0, desktop: 12.0),
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
                onPressed: (_isComposing && !_isUploading) ? _handleSubmitted : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
