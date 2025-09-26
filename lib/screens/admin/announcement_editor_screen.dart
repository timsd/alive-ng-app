import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../widgets/role_guard.dart';
import '../../widgets/loading_widget.dart';
import '../../utils/toast_utils.dart';
import '../../utils/text_formatter.dart';

class AnnouncementEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? announcement;
  
  const AnnouncementEditorScreen({
    super.key,
    this.announcement,
  });

  @override
  State<AnnouncementEditorScreen> createState() => _AnnouncementEditorScreenState();
}

class _AnnouncementEditorScreenState extends State<AnnouncementEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final SupabaseService _supabaseService = SupabaseService.instance;
  
  late TextEditingController _titleController;
  late TextEditingController _messageController;
  late TextEditingController _actionUrlController;
  late TextEditingController _actionTextController;
  
  bool _isLoading = false;
  bool _isActive = true;
  String _priority = 'medium';
  String _type = 'general';
  String _targetAudience = 'all';
  DateTime? _scheduledFor;
  DateTime? _expiresAt;
  
  final List<String> _priorities = ['low', 'medium', 'high', 'urgent'];
  final List<String> _types = [
    'general',
    'event',
    'maintenance',
    'update',
    'prayer_request',
    'chapter_news',
    'system',
  ];
  final List<String> _audiences = [
    'all',
    'members',
    'coordinators',
    'admins',
    'new_members',
    'active_members',
  ];

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _loadAnnouncementData();
  }

  void _initializeControllers() {
    _titleController = TextEditingController();
    _messageController = TextEditingController();
    _actionUrlController = TextEditingController();
    _actionTextController = TextEditingController();
  }

  void _loadAnnouncementData() {
    if (widget.announcement != null) {
      final announcement = widget.announcement!;
      _titleController.text = announcement['title'] ?? '';
      _messageController.text = announcement['message'] ?? '';
      _actionUrlController.text = announcement['action_url'] ?? '';
      _actionTextController.text = announcement['action_text'] ?? '';
      _isActive = announcement['is_active'] ?? true;
      _priority = announcement['priority'] ?? 'medium';
      _type = announcement['type'] ?? 'general';
      _targetAudience = announcement['target_audience'] ?? 'all';
      
      if (announcement['scheduled_for'] != null) {
        _scheduledFor = DateTime.parse(announcement['scheduled_for']);
      }
      if (announcement['expires_at'] != null) {
        _expiresAt = DateTime.parse(announcement['expires_at']);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _actionUrlController.dispose();
    _actionTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RoleVisibility(
      allowedRoles: const ['admin', 'super_admin', 'content_manager'],
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.announcement == null ? 'Create Announcement' : 'Edit Announcement'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveAnnouncement,
              tooltip: 'Save',
            ),
          ],
        ),
        body: _isLoading
            ? const LoadingWidget()
            : Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Card
                      Card(
                        color: _isActive ? Colors.green.shade50 : Colors.grey.shade50,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            children: [
                              Icon(
                                _isActive ? Icons.campaign : Icons.pause_circle_outline,
                                color: _isActive ? Colors.green : Colors.grey,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: _isActive ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                    Text(
                                      _isActive 
                                          ? 'This announcement will be shown to users'
                                          : 'This announcement is hidden from users',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: _isActive,
                                onChanged: (value) {
                                  setState(() {
                                    _isActive = value;
                                  });
                                },
                                activeTrackColor: Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Basic Information
                      const Text(
                        'Basic Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(
                          labelText: 'Announcement Title *',
                          hintText: 'Enter a clear, descriptive title',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.title),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Title is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          labelText: 'Message *',
                          hintText: 'Write your announcement message...',
                          border: OutlineInputBorder(),
                          alignLabelWithHint: true,
                        ),
                        maxLines: 6,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Message is required';
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Classification
                      const Text(
                        'Classification',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.priority_high),
                              ),
                              items: _priorities.map((priority) {
                                return DropdownMenuItem(
                                  value: priority,
                                  child: Row(
                                    children: [
                                      Icon(
                                        _getPriorityIcon(priority),
                                        color: _getPriorityColor(priority),
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(priority.toUpperCase()),
                                    ],
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _priority = value!;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _type,
                              decoration: const InputDecoration(
                                labelText: 'Type',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.category),
                              ),
                              items: _types.map((type) {
                                return DropdownMenuItem(
                                  value: type,
                                  child: Text(TextFormatter.formatNotificationType(type).toUpperCase()),
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() {
                                  _type = value!;
                                });
                              },
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      DropdownButtonFormField<String>(
        initialValue: _targetAudience,
                        decoration: const InputDecoration(
                          labelText: 'Target Audience',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.group),
                          helperText: 'Who should see this announcement?',
                        ),
                        items: _audiences.map((audience) {
                          return DropdownMenuItem(
                            value: audience,
                            child: Text(TextFormatter.formatRole(audience).toUpperCase()),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _targetAudience = value!;
                          });
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Scheduling
                      const Text(
                        'Scheduling',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectScheduledDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Scheduled For',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.schedule),
                                  helperText: 'Leave empty to publish immediately',
                                ),
                                child: Text(
                                  _scheduledFor != null
                                      ? '${_scheduledFor!.day}/${_scheduledFor!.month}/${_scheduledFor!.year} ${_scheduledFor!.hour}:${_scheduledFor!.minute.toString().padLeft(2, '0')}'
                                      : 'Publish immediately',
                                  style: TextStyle(
                                    color: _scheduledFor != null ? Colors.black : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_scheduledFor != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _scheduledFor = null;
                                });
                              },
                              tooltip: 'Clear scheduled date',
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: _selectExpiryDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Expires At',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.event_busy),
                                  helperText: 'Leave empty for no expiry',
                                ),
                                child: Text(
                                  _expiresAt != null
                                      ? '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year} ${_expiresAt!.hour}:${_expiresAt!.minute.toString().padLeft(2, '0')}'
                                      : 'No expiry',
                                  style: TextStyle(
                                    color: _expiresAt != null ? Colors.black : Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_expiresAt != null) ...[
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                setState(() {
                                  _expiresAt = null;
                                });
                              },
                              tooltip: 'Clear expiry date',
                            ),
                          ],
                        ],
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Action Button (Optional)
                      const Text(
                        'Action Button (Optional)',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _actionTextController,
                        decoration: const InputDecoration(
                          labelText: 'Button Text',
                          hintText: 'e.g., "Learn More", "Register Now"',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.smart_button),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      TextFormField(
                        controller: _actionUrlController,
                        decoration: const InputDecoration(
                          labelText: 'Button URL',
                          hintText: 'https://example.com or /internal-page',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.link),
                        ),
                        validator: (value) {
                          if (value != null && value.isNotEmpty) {
                            if (_actionTextController.text.trim().isEmpty) {
                              return 'Button text is required when URL is provided';
                            }
                          }
                          return null;
                        },
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.cancel),
                              label: const Text('Cancel'),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _saveAnnouncement,
                              icon: const Icon(Icons.save),
                              label: Text(widget.announcement == null ? 'Create' : 'Update'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  IconData _getPriorityIcon(String priority) {
    switch (priority) {
      case 'urgent':
        return Icons.warning;
      case 'high':
        return Icons.priority_high;
      case 'medium':
        return Icons.remove;
      case 'low':
        return Icons.keyboard_arrow_down;
      default:
        return Icons.remove;
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'urgent':
        return Colors.red;
      case 'high':
        return Colors.orange;
      case 'medium':
        return Colors.blue;
      case 'low':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Future<void> _selectScheduledDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _scheduledFor ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_scheduledFor ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _scheduledFor = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _selectExpiryDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_expiresAt ?? DateTime.now()),
      );

      if (time != null) {
        setState(() {
          _expiresAt = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _saveAnnouncement() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final announcementData = {
        'title': _titleController.text.trim(),
        'message': _messageController.text.trim(),
        'type': _type,
        'priority': _priority,
        'target_audience': _targetAudience,
        'is_active': _isActive,
        'scheduled_for': _scheduledFor?.toIso8601String(),
        'expires_at': _expiresAt?.toIso8601String(),
        'action_text': _actionTextController.text.trim().isNotEmpty 
            ? _actionTextController.text.trim() 
            : null,
        'action_url': _actionUrlController.text.trim().isNotEmpty 
            ? _actionUrlController.text.trim() 
            : null,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.announcement == null) {
        // Create new announcement
        announcementData['created_at'] = DateTime.now().toIso8601String();
        announcementData['created_by'] = _supabaseService.currentUser?.id;
        
        await _supabaseService.client
            .from('announcements')
            .insert(announcementData);
        
        ToastUtils.showSuccess('Announcement created successfully');
      } else {
        // Update existing announcement
        await _supabaseService.client
            .from('announcements')
            .update(announcementData)
            .eq('id', widget.announcement!['id']);
        
        ToastUtils.showSuccess('Announcement updated successfully');
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      ToastUtils.showError('Error saving announcement: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }
}



