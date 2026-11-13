import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/app_models.dart' as app_models;
import '../../../models/discipleship_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/discipleship_service.dart';
import '../../../services/prayer_requests_service.dart';
import '../../../utils/error_handler.dart';
import '../../../utils/text_formatter.dart';

/// A card widget displaying an individual discipleship prayer request with status
/// chips and action popups.
class DiscipleshipPrayerCard extends StatelessWidget {
  final PrayerRequest prayer;
  final DiscipleshipContact contact;
  final VoidCallback onRefresh;

  const DiscipleshipPrayerCard({
    super.key,
    required this.prayer,
    required this.contact,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isAnswered = prayer.status == PrayerRequestStatus.answered;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isAnswered
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.red.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAnswered ? Icons.check_circle_rounded : Icons.favorite_rounded,
              color: isAnswered ? Colors.green : Colors.red,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  prayer.request,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (prayer.isPublicOnPrayerWall) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.public_rounded,
                        size: 10,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'PRAYER WALL',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isAnswered) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'ANSWERED',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ),
              ],
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                'For: ${contact.fullName}',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                'Requested: ${DateFormat('MMM dd, yyyy').format(prayer.dateRequested)}'
                '${prayer.status != PrayerRequestStatus.active ? ' • Status: ${prayer.status.name.toUpperCase()}' : ''}',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (prayer.category != null)
                Text('Category: ${prayer.category}', style: theme.textTheme.bodySmall),
              if (prayer.notes != null && prayer.notes!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Note: ${prayer.notes}',
                    style: TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              if (isAnswered && prayer.answer != null && prayer.answer!.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Testimony: ${prayer.answer}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.green,
                    ),
                  ),
                ),
            ],
          ),
          trailing: PopupMenuButton<String>(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'history',
                child: Text('View Prayer History'),
              ),
              if (!isAnswered)
                const PopupMenuItem(
                  value: 'answer',
                  child: Text('Mark as Answered'),
                ),
              const PopupMenuItem(
                value: 'update',
                child: Text('Update Status & Notes'),
              ),
            ],
            onSelected: (value) {
              if (value == 'history') {
                showPrayerHistoryDialog(context, prayer);
              } else if (value == 'answer') {
                showMarkAnsweredDialog(context, prayer, onRefresh);
              } else if (value == 'update') {
                showUpdatePrayerStatusDialog(context, prayer, onRefresh);
              }
            },
          ),
        ),
      ),
    );
  }
}

/// Modernized Modal to record an answered prayer request with personal testimony.
void showMarkAnsweredDialog(
  BuildContext context,
  PrayerRequest prayer,
  VoidCallback onSuccess,
) {
  final isNarrow = MediaQuery.of(context).size.width < 600;

  Widget buildContent(BuildContext dialogContext, StateSetter setDialogState, TextEditingController testimonyController, {String? inDialogError, bool isSaving = false, required VoidCallback onSave}) {
    final theme = Theme.of(dialogContext);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: isNarrow ? 12 : 20,
        bottom: MediaQuery.of(dialogContext).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle for bottom sheet on mobile
          if (isNarrow) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],

          // Header with celebratory icon pill and close button
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFD49B28).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFFD49B28),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mark Prayer Answered',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Praise God for His faithfulness!',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: 'Close',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // In-dialog error banner
          if (inDialogError != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: colorScheme.errorContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: colorScheme.error, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      inDialogError,
                      style: TextStyle(
                        color: colorScheme.onErrorContainer,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Prayer quote callout card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.format_quote_rounded,
                  color: colorScheme.primary.withValues(alpha: 0.7),
                  size: 22,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    prayer.request.isNotEmpty ? prayer.request : 'Unspecified prayer request',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Testimony input field
          TextField(
            controller: testimonyController,
            maxLines: 4,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              labelText: 'Testimony / Notes on Answer (Optional)',
              labelStyle: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
              hintText: 'Share how God answered this prayer...',
              hintStyle: TextStyle(
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                fontSize: 13,
              ),
              filled: true,
              fillColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: colorScheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Actions Row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: isSaving ? null : () => Navigator.of(dialogContext).pop(),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981), // Emerald 500
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: isSaving ? null : onSave,
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.check_circle_rounded, size: 18),
                label: Text(
                  isSaving ? 'Saving...' : 'Confirm Answered',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  final testimonyController = TextEditingController();
  String? inDialogError;
  bool isSaving = false;

  void handleSave(BuildContext dialogContext, StateSetter setDialogState) async {
    setDialogState(() {
      isSaving = true;
      inDialogError = null;
    });
    final user = AuthService.instance.currentUser;
    final navigator = Navigator.of(dialogContext);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await DiscipleshipService().markPrayerAnswered(
        requestId: prayer.id,
        testimony: testimonyController.text.trim(),
        actorName: user?.displayName ?? 'Disciple Maker',
      );

      if (dialogContext.mounted) {
        navigator.pop();
      }
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Prayer marked as answered. Praise the Lord!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      onSuccess();
    } catch (e) {
      if (dialogContext.mounted) {
        setDialogState(() {
          isSaving = false;
          inDialogError = 'Failed: ${ErrorHandler.getUserFriendlyMessage(e)}';
        });
      }
    }
  }

  if (isNarrow) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) => StatefulBuilder(
        builder: (bottomSheetContext, setDialogState) => buildContent(
          bottomSheetContext,
          setDialogState,
          testimonyController,
          inDialogError: inDialogError,
          isSaving: isSaving,
          onSave: () => handleSave(bottomSheetContext, setDialogState),
        ),
      ),
    );
  } else {
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: buildContent(
              dialogContext,
              setDialogState,
              testimonyController,
              inDialogError: inDialogError,
              isSaving: isSaving,
              onSave: () => handleSave(dialogContext, setDialogState),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialog to update prayer request status or append follow-up notes.
void showUpdatePrayerStatusDialog(
  BuildContext context,
  PrayerRequest prayer,
  VoidCallback onSuccess,
) {
  var status = prayer.status;
  final notesController = TextEditingController(text: prayer.notes ?? '');
  String? inDialogError;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Update Prayer Status & Notes'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inDialogError != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    inDialogError!,
                    style: TextStyle(
                      color: Theme.of(dialogContext).colorScheme.onErrorContainer,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
              Text('Prayer: "${prayer.request}"', style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              DropdownButtonFormField<PrayerRequestStatus>(
                initialValue: status,
                borderRadius: BorderRadius.circular(12),
                dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                icon: const Icon(Icons.arrow_drop_down_rounded),
                decoration: const InputDecoration(labelText: 'Status', border: OutlineInputBorder()),
                items: PrayerRequestStatus.values
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(TextFormatter.formatText(s.name)),
                        ))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setDialogState(() => status = val);
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Progress Notes / Update',
                  hintText: 'Add ongoing notes or state updates...',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isSaving
                ? null
                : () async {
                    setDialogState(() {
                      isSaving = true;
                      inDialogError = null;
                    });
                    final user = AuthService.instance.currentUser;
                    try {
                      await DiscipleshipService().updatePrayerStatusAndNotes(
                        requestId: prayer.id,
                        status: status,
                        note: notesController.text.trim(),
                        actorName: user?.displayName ?? 'Disciple Maker',
                      );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Prayer status updated.')),
                        );
                        onSuccess();
                      }
                    } catch (e) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          isSaving = false;
                          inDialogError = 'Failed: ${ErrorHandler.getUserFriendlyMessage(e)}';
                        });
                      }
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Status'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog displaying the audit timeline of prayer request status changes.
void showPrayerHistoryDialog(BuildContext context, PrayerRequest prayer) {
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Prayer History & Timeline'),
      content: SizedBox(
        width: double.maxFinite,
        child: prayer.history.isEmpty
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.history_rounded, size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(
                    'Requested on ${DateFormat('MMM dd, yyyy').format(prayer.dateRequested)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  if (prayer.status == PrayerRequestStatus.answered && prayer.dateAnswered != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Answered on ${DateFormat('MMM dd, yyyy').format(prayer.dateAnswered!)}',
                        style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              )
            : ListView.separated(
                shrinkWrap: true,
                itemCount: prayer.history.length,
                separatorBuilder: (dialogContext, i) => const Divider(),
                itemBuilder: (dialogContext, i) {
                  final h = prayer.history[i];
                  final isAns = h.status == PrayerRequestStatus.answered;
                  return ListTile(
                    dense: true,
                    leading: Icon(
                      isAns ? Icons.check_circle : Icons.history,
                      color: isAns ? Colors.green : Colors.blue,
                    ),
                    title: Text(
                      '${h.action.replaceAll('_', ' ').toUpperCase()} • ${h.status.name.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (h.note != null && h.note!.isNotEmpty)
                          Text(h.note!, style: const TextStyle(fontSize: 12)),
                        Text(
                          '${DateFormat('MMM dd, yyyy HH:mm').format(h.timestamp.toLocal())}${h.actorName != null ? ' by ${h.actorName}' : ''}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

/// Dialog to record a new prayer request for a specific disciple or general contact.
void showAddPrayerRequestDialog(
  BuildContext context, {
  DiscipleshipContact? forContact,
  required List<DiscipleshipContact> contacts,
  required VoidCallback onSuccess,
}) {
  final requestController = TextEditingController();
  String? selectedContactId = forContact?.id ?? (contacts.isNotEmpty ? contacts.first.id : null);
  bool shareToGeneralPrayerWall = false;
  String? inDialogError;
  bool isSaving = false;

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.favorite_rounded, color: Theme.of(dialogContext).colorScheme.primary, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                forContact != null ? 'Prayer for ${forContact.fullName}' : 'Add Discipleship Prayer',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (inDialogError != null) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(dialogContext).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Theme.of(dialogContext).colorScheme.error.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline_rounded,
                          size: 18, color: Theme.of(dialogContext).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          inDialogError!,
                          style: TextStyle(
                            color: Theme.of(dialogContext).colorScheme.onErrorContainer,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (forContact == null) ...[
                const Text('Select Disciple *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                if (contacts.isEmpty)
                  const Text(
                    'No disciples available. Please add a disciple first.',
                    style: TextStyle(color: Colors.redAccent, fontSize: 12),
                  )
                else
                  DropdownButtonFormField<String>(
                    initialValue: selectedContactId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: contacts.map((c) {
                      return DropdownMenuItem<String>(
                        value: c.id,
                        child: Text(c.fullName),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          selectedContactId = val;
                          inDialogError = null;
                        });
                      }
                    },
                  ),
                const SizedBox(height: 12),
              ],
              const Text('Prayer Request *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 6),
              TextField(
                controller: requestController,
                maxLines: 3,
                onChanged: (_) {
                  if (inDialogError != null) {
                    setDialogState(() => inDialogError = null);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'What specific prayer need would you like to log?',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(dialogContext).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(dialogContext).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: shareToGeneralPrayerWall,
                  title: const Text(
                    'Show on General Prayer Wall',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  subtitle: Text(
                    shareToGeneralPrayerWall
                        ? 'Visible to the entire ALIVE community for intercession'
                        : 'Private to this discipleship record only',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(dialogContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  onChanged: (val) {
                    setDialogState(() => shareToGeneralPrayerWall = val);
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: isSaving ? null : () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: isSaving
                ? null
                : () async {
                    final text = requestController.text.trim();
                    if (text.isEmpty) {
                      setDialogState(() => inDialogError = 'Please enter prayer request details.');
                      return;
                    }
                    if (selectedContactId == null || selectedContactId!.isEmpty) {
                      setDialogState(() => inDialogError = 'Please select a disciple for this prayer.');
                      return;
                    }
                    final user = AuthService.instance.currentUser;
                    if (user == null) {
                      setDialogState(() => inDialogError = 'Please sign in to save prayer.');
                      return;
                    }

                    setDialogState(() {
                      isSaving = true;
                      inDialogError = null;
                    });

                    try {
                      await DiscipleshipService().createPrayerRequest(PrayerRequest(
                        id: '',
                        contactId: selectedContactId!,
                        discipleMakerId: user.uid,
                        request: text,
                        isPublicOnPrayerWall: shareToGeneralPrayerWall,
                        dateRequested: DateTime.now(),
                        createdAt: DateTime.now(),
                        updatedAt: DateTime.now(),
                      ));

                      // When enabled, also mirror to public prayer wall for community intercession
                      if (shareToGeneralPrayerWall) {
                        try {
                          String contactName = '';
                          if (forContact != null) {
                            contactName = forContact.fullName;
                          } else {
                            final match = contacts.where((c) => c.id == selectedContactId);
                            if (match.isNotEmpty) {
                              contactName = match.first.fullName;
                            }
                          }

                          await PrayerRequestsService.instance.createPrayerRequest(
                            app_models.PrayerRequest(
                              id: '',
                              userId: user.uid,
                              title: contactName.isNotEmpty
                                  ? 'Prayer for $contactName'
                                  : 'Discipleship Prayer Request',
                              description: text,
                              category: 'Discipleship',
                              isAnonymous: false,
                              isPrivate: false,
                              createdAt: DateTime.now(),
                              updatedAt: DateTime.now(),
                            ),
                          );
                        } catch (mirrorErr) {
                          debugPrint('Note: public prayer wall mirroring error: $mirrorErr');
                        }
                      }

                      if (dialogContext.mounted) Navigator.pop(dialogCtx);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              shareToGeneralPrayerWall
                                  ? 'Prayer saved & published to Prayer Wall.'
                                  : 'Discipleship prayer request saved.',
                            ),
                          ),
                        );
                      }
                      onSuccess();
                    } catch (e) {
                      if (dialogContext.mounted) {
                        setDialogState(() {
                          isSaving = false;
                          inDialogError = ErrorHandler.getUserFriendlyMessage(e);
                        });
                      }
                    }
                  },
            child: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Prayer'),
          ),
        ],
      ),
    ),
  );
}

