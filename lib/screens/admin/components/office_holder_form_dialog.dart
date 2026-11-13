import 'package:flutter/material.dart';

/// Form dialog component for adding or editing leadership office holders (BOD, Trustees, Directors).
class OfficeHolderFormDialog extends StatefulWidget {
  final Map<String, dynamic>? holder;
  final String category;
  final List<dynamic> registeredUsers;
  final Future<void> Function({
    String? docId,
    required String fullName,
    required String officeTitle,
    required String description,
    required String tenureYear,
    required String tenureEndYear,
    required bool isCurrent,
    required String email,
    required String userId,
    required String category,
    required String officeId,
  }) onSave;

  const OfficeHolderFormDialog({
    super.key,
    this.holder,
    required this.category,
    required this.registeredUsers,
    required this.onSave,
  });

  static Future<void> show(
    BuildContext context, {
    Map<String, dynamic>? holder,
    required String category,
    required List<dynamic> registeredUsers,
    required Future<void> Function({
      String? docId,
      required String fullName,
      required String officeTitle,
      required String description,
      required String tenureYear,
      required String tenureEndYear,
      required bool isCurrent,
      required String email,
      required String userId,
      required String category,
      required String officeId,
    }) onSave,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => OfficeHolderFormDialog(
        holder: holder,
        category: category,
        registeredUsers: registeredUsers,
        onSave: onSave,
      ),
    );
  }

  @override
  State<OfficeHolderFormDialog> createState() => _OfficeHolderFormDialogState();
}

class _OfficeHolderFormDialogState extends State<OfficeHolderFormDialog> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _tenureStartCtrl;
  late final TextEditingController _tenureEndCtrl;
  late final TextEditingController _emailCtrl;

  late bool _isCurrentTenure;
  late String _selectedUserId;
  late final bool _isTrustee;
  late final bool _isBod;
  late final String _officeId;

  @override
  void initState() {
    super.initState();
    final holder = widget.holder;
    _nameCtrl = TextEditingController(text: holder?['full_name'] ?? '');
    _titleCtrl = TextEditingController(text: holder?['office_title'] ?? '');
    _descriptionCtrl = TextEditingController(text: holder?['description'] ?? '');
    _tenureStartCtrl = TextEditingController(
      text: (holder?['tenure_year'] ?? DateTime.now().year).toString(),
    );
    _tenureEndCtrl = TextEditingController(
      text: holder?['tenure_end_year']?.toString() ?? '',
    );
    _emailCtrl = TextEditingController(text: holder?['email'] ?? '');

    _isCurrentTenure = holder?['is_current'] != false &&
        (holder?['status'] ?? '').toString().toLowerCase() != 'archived';
    _selectedUserId = holder?['user_id'] ?? '';

    _isTrustee = widget.category == 'trustee';
    _isBod = widget.category == 'bod';
    final defaultOfficeId = _isTrustee ? 'trustee' : (_isBod ? 'bod' : 'director');
    _officeId = holder?['office_id'] ?? defaultOfficeId;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _tenureStartCtrl.dispose();
    _tenureEndCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.holder != null
        ? 'Edit ${_isTrustee ? 'Trustee' : (_isBod ? 'Board Member' : 'Officer')}'
        : 'Add New ${_isTrustee ? 'Trustee' : (_isBod ? 'Board Member' : 'Officer')}';

    return AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Link Registered User Account',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              initialValue: _selectedUserId.isNotEmpty ? _selectedUserId : null,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                hintText: 'Select registered app member...',
              ),
              items: [
                const DropdownMenuItem<String>(
                  value: '',
                  child: Text('-- Unlinked / Not yet registered --'),
                ),
                ...widget.registeredUsers.map((u) {
                  final label = '${u.fullName} (${u.email})';
                  return DropdownMenuItem<String>(
                    value: u.id,
                    child: Text(label, overflow: TextOverflow.ellipsis),
                  );
                }),
              ],
              onChanged: (val) {
                setState(() {
                  _selectedUserId = val ?? '';
                  if (_selectedUserId.isNotEmpty) {
                    final match = widget.registeredUsers
                        .where((u) => u.id == _selectedUserId)
                        .firstOrNull;
                    if (match != null) {
                      _nameCtrl.text = match.fullName ?? '';
                      _emailCtrl.text = match.email ?? '';
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _titleCtrl,
              decoration: InputDecoration(
                labelText: 'Office / Role Title *',
                border: const OutlineInputBorder(),
                helperText: _isTrustee
                    ? 'e.g. Chairman of Trustees or Trustee'
                    : _isBod
                        ? 'e.g. Director (Board Member), Affairs Liaison'
                        : 'e.g. Executive President, Secretary, Treasurer',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Tenure Period',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _tenureStartCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Start Year *',
                      hintText: 'e.g. 2026',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today_outlined, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _tenureEndCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'End Year',
                      hintText: 'e.g. 2029',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.event_available_outlined, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Currently in Tenure (Active)'),
              subtitle: Text(
                _isCurrentTenure
                    ? 'Actively serving in this office / role'
                    : 'Tenure completed; record will be archived',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              value: _isCurrentTenure,
              activeThumbColor: Colors.green,
              onChanged: (val) => setState(() => _isCurrentTenure = val),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Role Summary / Description',
                hintText: 'e.g. Leading strategic direction and operations of ALIVE Nigeria',
                border: OutlineInputBorder(),
              ),
            ),
            if (_selectedUserId.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Linked Account ID: $_selectedUserId\nRole will be updated to ${_isTrustee ? 'trustee' : (_isBod ? 'bod' : 'director')} & enrolled in leadership channels.',
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () async {
            if (_nameCtrl.text.trim().isEmpty || _titleCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Name and title are required')),
              );
              return;
            }
            Navigator.pop(context);
            await widget.onSave(
              docId: widget.holder?['\$id'],
              fullName: _nameCtrl.text.trim(),
              officeTitle: _titleCtrl.text.trim(),
              description: _descriptionCtrl.text.trim(),
              tenureYear: _tenureStartCtrl.text.trim(),
              tenureEndYear: _tenureEndCtrl.text.trim(),
              isCurrent: _isCurrentTenure,
              email: _emailCtrl.text.trim(),
              userId: _selectedUserId,
              category: widget.category,
              officeId: _officeId,
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
