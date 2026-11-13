import 'package:flutter/material.dart';

import '../../../config/appwrite_backend_config.dart';
import '../../../models/chat_models.dart';
import '../../../services/appwrite_auth_service.dart';
import '../../../services/appwrite_chat_service.dart';
import '../../../services/auth_service.dart';
import '../../../services/chat_service.dart';
import '../../../services/role_access_service.dart';
import '../../../utils/text_formatter.dart';

class CreateChannelDialog extends StatefulWidget {
  final Function(ChatChannel) onChannelCreated;
  final String? currentUserId;
  final bool isAdmin;

  const CreateChannelDialog({
    super.key,
    required this.onChannelCreated,
    required this.currentUserId,
    this.isAdmin = false,
  });

  @override
  State<CreateChannelDialog> createState() => _CreateChannelDialogState();
}

class _CreateChannelDialogState extends State<CreateChannelDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  ChannelType _selectedType = ChannelType.general;
  bool _excludeLeadership = false;
  bool _isCreating = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final isAdmin = widget.isAdmin ||
          RoleAccessService.instance.canAccessAdmin() ||
          AppwriteBackendConfig.isSuperAdminEmail(
              AuthService.instance.currentUser?.email);
      if (!isAdmin) {
        throw Exception('Only admins can create channels');
      }
      final userId = widget.currentUserId;
      if (userId == null || userId.isEmpty) {
        throw Exception('Please sign in as an admin to create a channel.');
      }
      final channel = await ChatService().createChannel(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        type: _selectedType,
        members: [userId],
        admins: [userId],
        excludeLeadership: _excludeLeadership,
      );

      widget.onChannelCreated(channel);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_friendlyChannelError(e)),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }

  String _friendlyChannelError(Object e) {
    final text = e.toString().toLowerCase();
    if (text.contains('only admins can create channels')) {
      return 'Only admins can create channels';
    }
    if (text.contains('not authenticated') || text.contains('sign in')) {
      return 'Please sign in as an admin to create a channel.';
    }
    if (text.contains('permission') ||
        text.contains('unauthorized') ||
        text.contains('403')) {
      return 'Only admins can create channels';
    }
    return 'Channel could not be created. Check your connection and try again.';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Channel'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Channel Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a channel name';
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
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<ChannelType>(
              initialValue: _selectedType,
              borderRadius: BorderRadius.circular(12),
              dropdownColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              decoration: const InputDecoration(
                labelText: 'Channel Type',
                border: OutlineInputBorder(),
              ),
              items: ChannelType.values.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(TextFormatter.formatText(type.name)),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text(
                'Private / Secluded Channel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Exclude general leadership (Admins, BOD, Directors) from auto-enrollment',
                style: TextStyle(fontSize: 12),
              ),
              value: _excludeLeadership,
              onChanged: (val) => setState(() => _excludeLeadership = val),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isCreating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isCreating ? null : _createChannel,
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}

