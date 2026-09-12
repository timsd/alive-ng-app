import 'package:flutter/material.dart';

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

  @override
  void dispose() {
    _titleController.dispose();
    _categoryController.dispose();
    _descriptionController.dispose();
    _scriptureController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (_submitting) return;
    final title = _titleController.text.trim();
    final category = _categoryController.text.trim();
    final description = _descriptionController.text.trim();
    final scripture = _scriptureController.text.trim();

    if (title.isEmpty || description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title and description are required.')),
      );
      return;
    }

    setState(() => _submitting = true);
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not submit request: $e')),
      );
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

    return AlertDialog(
      title: const Text('Add Prayer Request'),
      content: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _categoryController,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _scriptureController,
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
                decoration: const InputDecoration(
                  labelText: 'Description',
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
