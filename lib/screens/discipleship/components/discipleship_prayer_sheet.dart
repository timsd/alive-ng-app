import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/discipleship_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/discipleship_service.dart';
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
              if (isAnswered)
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

/// Dialog to record an answered prayer request with personal testimony.
void showMarkAnsweredDialog(
  BuildContext context,
  PrayerRequest prayer,
  VoidCallback onSuccess,
) {
  final testimonyController = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(Icons.celebration_rounded, color: Colors.amber, size: 44),
      title: const Text('Mark Prayer Answered'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Prayer: "${prayer.request}"',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: testimonyController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Testimony / Notes on Answer (Optional)',
                hintText: 'Share how God answered this prayer...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
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
                const SnackBar(content: Text('Prayer marked as answered. Praise the Lord!')),
              );
              onSuccess();
            } catch (e) {
              if (dialogContext.mounted) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  SnackBar(content: Text('Failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                );
              }
            }
          },
          child: const Text('Confirm Answered'),
        ),
      ],
    ),
  );
}

/// Dialog to update prayer request status or append follow-up notes.
void showUpdatePrayerStatusDialog(
  BuildContext context,
  PrayerRequest prayer,
  VoidCallback onSuccess,
) {
  var status = prayer.status;
  final notesController = TextEditingController(text: prayer.notes ?? '');
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
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
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
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Save Status'),
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

  showDialog(
    context: context,
    builder: (dialogCtx) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text(forContact != null ? 'Prayer for ${forContact.fullName}' : 'Add Prayer Request'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                        setDialogState(() => selectedContactId = val);
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
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'What specific prayer need would you like to log?',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (requestController.text.trim().isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter prayer request details')),
                );
                return;
              }
              if (selectedContactId == null || selectedContactId!.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please select a disciple for this prayer')),
                );
                return;
              }
              final user = AuthService.instance.currentUser;
              if (user == null) return;
              try {
                await DiscipleshipService().createPrayerRequest(PrayerRequest(
                  id: '',
                  contactId: selectedContactId!,
                  discipleMakerId: user.uid,
                  request: requestController.text.trim(),
                  dateRequested: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));
                if (dialogContext.mounted) Navigator.pop(dialogCtx);
                onSuccess();
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Save failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Save Prayer'),
          ),
        ],
      ),
    ),
  );
}

