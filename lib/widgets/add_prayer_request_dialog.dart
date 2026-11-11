import 'package:flutter/material.dart';
import '../utils/error_handler.dart';

class AddPrayerRequestDialog extends StatefulWidget {
  final Future<void> Function({
    required String title,
    required String category,
    required String description,
    required bool isAnonymous,
    required bool isPublic,
    String? scriptureReference,
    required String urgencyLevel,
  }) onSubmit;

  const AddPrayerRequestDialog({
    super.key,
    required this.onSubmit,
  });

  @override
  State<AddPrayerRequestDialog> createState() => _AddPrayerRequestDialogState();
}

class _AddPrayerRequestDialogState extends State<AddPrayerRequestDialog> {
  final _titleController = TextEditingController();
  final _categoryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _scriptureController = TextEditingController();
  bool _isAnonymous = true;
  bool _isPublic = true;
  String _urgencyLevel = 'normal';
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _scriptureController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_errorMessage != null) {
      setState(() => _errorMessage = null);
    }
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final scripture = _scriptureController.text.trim();
    var title = _titleController.text.trim();

    if (description.isEmpty) {
      setState(() => _errorMessage = 'Please enter a description for your prayer request.');
      return;
    }

    // Smart auto-derivation: if user gave category & description but omitted title,
    // do not block them — smoothly derive title from category or description.
    if (title.isEmpty) {
      if (category.isNotEmpty && category.toLowerCase() != 'general') {
        title = category;
      } else if (description.length > 35) {
        title = '${description.substring(0, 35)}...';
      } else {
        title = description;
      }
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.onSubmit(
        title: title,
        category: category.isEmpty ? 'General' : category,
        description: description,
        isAnonymous: _isAnonymous,
        isPublic: _isPublic,
        scriptureReference: scripture.isEmpty ? null : scripture,
        urgencyLevel: _urgencyLevel,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not submit request: ${ErrorHandler.getUserFriendlyMessage(e)}';
      });
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final maxWidth = width < 600 ? width * 0.95 : 560.0;
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.favorite_rounded, color: theme.colorScheme.primary, size: 22),
          const SizedBox(width: 8),
          const Expanded(child: Text('Add Prayer Request')),
        ],
      ),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_errorMessage != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.colorScheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: theme.colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: _titleController,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Title (Optional - auto-derived if empty)',
                  hintText: 'e.g. Healing, Provision, Guidance',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Category (Optional)',
                  hintText: 'e.g. Health, Family, Evangelism',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scriptureController,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Scripture Reference (Optional)',
                  hintText: 'e.g. Philippians 4:6',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _urgencyLevel,
                decoration: const InputDecoration(
                  labelText: 'Urgency Level',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'low', child: Text('Low')),
                  DropdownMenuItem(value: 'normal', child: Text('Normal')),
                  DropdownMenuItem(value: 'high', child: Text('High')),
                  DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                ],
                onChanged: (value) {
                  setState(() => _urgencyLevel = value ?? 'normal');
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _descriptionController,
                maxLines: 4,
                maxLength: 500,
                onChanged: (_) => _clearError(),
                decoration: const InputDecoration(
                  labelText: 'Description *',
                  hintText: 'Share what you need prayer for...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                value: _isPublic,
                contentPadding: EdgeInsets.zero,
                title: const Text('Public Request'),
                subtitle: Text(_isPublic
                    ? 'Visible to community prayer feed'
                    : 'Private request (only visible to you)'),
                onChanged: (value) {
                  setState(() => _isPublic = value);
                },
              ),
              CheckboxListTile(
                value: _isAnonymous,
                contentPadding: EdgeInsets.zero,
                title: const Text('Post anonymously'),
                onChanged: (value) {
                  setState(() => _isAnonymous = value ?? true);
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submitting ? null : _handleSubmit,
          child: _submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit'),
        ),
      ],
    );
  }
}
