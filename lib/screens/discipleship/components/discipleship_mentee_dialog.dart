import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/discipleship_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/discipleship_service.dart';
import '../../../utils/error_handler.dart';
import '../../../utils/responsive_utils.dart';
import '../../../utils/text_formatter.dart';
import 'discipleship_helpers.dart';
import 'discipleship_stages_card.dart';

Future<void> _makePhoneCall(String phone) async {
  final Uri launchUri = Uri(scheme: 'tel', path: phone.trim());
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  }
}

Future<void> _sendSms(String phone) async {
  final Uri launchUri = Uri(scheme: 'sms', path: phone.trim());
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  }
}

Future<void> _sendEmail(String email) async {
  final Uri launchUri = Uri(scheme: 'mailto', path: email.trim());
  if (await canLaunchUrl(launchUri)) {
    await launchUrl(launchUri);
  }
}

/// A card representing a mentee/disciple contact in the contact list.
class DiscipleshipContactCard extends StatelessWidget {
  final DiscipleshipContact contact;
  final VoidCallback onTap;
  final void Function(String action) onAction;

  const DiscipleshipContactCard({
    super.key,
    required this.contact,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final levelColor = DiscipleshipHelpers.getLevelColor(contact.currentLevel);

    return Card(
      margin: EdgeInsets.symmetric(
        horizontal: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 16.0,
          tablet: 20.0,
          desktop: 24.0,
        ),
        vertical: ResponsiveUtils.getResponsiveValue(
          context: context,
          mobile: 4.0,
          tablet: 6.0,
          desktop: 8.0,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: levelColor,
          child: Text(
            contact.firstName.isNotEmpty ? contact.firstName[0].toUpperCase() : 'D',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(contact.fullName),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DiscipleshipHelpers.getLevelDisplayName(contact.currentLevel)),
            if (contact.lastContact != null)
              Text(
                'Last contact: ${DateFormat('MMM dd, yyyy').format(contact.lastContact!)}',
                style: Theme.of(context).textTheme.labelMedium,
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'view', child: Text('View Details')),
            const PopupMenuItem(value: 'interaction', child: Text('Add Interaction')),
            const PopupMenuItem(value: 'study', child: Text('Add Study Session')),
            const PopupMenuItem(value: 'prayer', child: Text('Add Prayer Request')),
            const PopupMenuItem(value: 'level', child: Text('Update Level')),
            const PopupMenuItem(
              value: 'request_deletion',
              child: Text('Request Deletion', style: TextStyle(color: Colors.red)),
            ),
          ],
          onSelected: onAction,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Dialog to add a new Disciple / Mentee profile.
void showAddContactDialog(BuildContext context, VoidCallback onSuccess) {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  var level = DiscipleshipLevel.prospect;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: const Text('Add Disciple'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: firstNameController,
                decoration: const InputDecoration(labelText: 'First Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: lastNameController,
                decoration: const InputDecoration(labelText: 'Last Name *'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email Address *',
                  hintText: 'example@domain.com',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: '+234...',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DiscipleshipLevel>(
                initialValue: level,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Initial Level'),
                items: DiscipleshipLevel.values
                    .map((l) => DropdownMenuItem(
                          value: l,
                          child: Text(DiscipleshipHelpers.getLevelDisplayName(l)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => level = value);
                },
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
              if (user == null) return;
              final fName = firstNameController.text.trim();
              final lName = lastNameController.text.trim();
              final email = emailController.text.trim();
              final phone = phoneController.text.trim();

              if (fName.isEmpty || lName.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('First and last name are required.')),
                );
                return;
              }
              if (email.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Email address is mandatory.')),
                );
                return;
              }
              if (!RegExp(r'^[\w\.-]+@[\w\.-]+\.\w+$').hasMatch(email)) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a valid email address.')),
                );
                return;
              }
              if (phone.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Phone number is mandatory.')),
                );
                return;
              }

              try {
                await DiscipleshipService().createContact(DiscipleshipContact(
                  id: '',
                  discipleMakerId: user.uid,
                  firstName: fName,
                  lastName: lName,
                  email: email,
                  phone: phone,
                  currentLevel: level,
                  firstContact: DateTime.now(),
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                ));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                onSuccess();
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Could not add disciple: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Add Disciple'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog displaying full mentee profile details, contact actions, and milestones.
void showContactDetailsDialog(
  BuildContext context, {
  required DiscipleshipContact contact,
  required List<ContactInteraction> recentInteractions,
  required List<StudySession> recentStudySessions,
  required List<PrayerRequest> activePrayerRequests,
  required void Function(DiscipleshipContact c) onAddInteraction,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  final levelColor = DiscipleshipHelpers.getLevelColor(contact.currentLevel);

  final contactInteractions =
      recentInteractions.where((i) => i.contactId == contact.id).toList();
  final contactStudies =
      recentStudySessions.where((s) => s.contactId == contact.id).toList();
  final contactPrayers =
      activePrayerRequests.where((p) => p.contactId == contact.id).toList();

  showDialog(
    context: context,
    builder: (dialogContext) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Avatar and Level
              Row(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: levelColor,
                    child: Text(
                      contact.firstName.isNotEmpty
                          ? contact.firstName[0].toUpperCase()
                          : 'D',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contact.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: levelColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: levelColor.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            DiscipleshipHelpers.getLevelDisplayName(contact.currentLevel),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: levelColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Phone (Clickable to Call & SMS)
              if (contact.phone != null && contact.phone!.trim().isNotEmpty) ...[
                InkWell(
                  onTap: () => _makePhoneCall(contact.phone!),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.phone_rounded, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Phone (Tap to call)',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                contact.phone!,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: colorScheme.primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_rounded, size: 20),
                          color: Colors.green,
                          tooltip: 'Call Phone',
                          onPressed: () => _makePhoneCall(contact.phone!),
                        ),
                        IconButton(
                          icon: const Icon(Icons.message_rounded, size: 20),
                          color: colorScheme.primary,
                          tooltip: 'Send SMS',
                          onPressed: () => _sendSms(contact.phone!),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Email
              if (contact.email != null && contact.email!.trim().isNotEmpty) ...[
                InkWell(
                  onTap: () => _sendEmail(contact.email!),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.email_outlined, size: 20, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Email Address',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                              Text(
                                contact.email!,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: colorScheme.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.send_rounded, size: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Address / Location
              if (contact.address != null && contact.address!.trim().isNotEmpty) ...[
                _buildMenteeDetailRow(
                  context,
                  icon: Icons.location_on_outlined,
                  label: 'Address / Location',
                  value: contact.address!,
                ),
                const SizedBox(height: 10),
              ],

              // Occupation
              if (contact.occupation != null && contact.occupation!.trim().isNotEmpty) ...[
                _buildMenteeDetailRow(
                  context,
                  icon: Icons.work_outline_rounded,
                  label: 'Occupation',
                  value: contact.occupation!,
                ),
                const SizedBox(height: 10),
              ],

              // Interests / Background
              if (contact.interests != null && contact.interests!.trim().isNotEmpty) ...[
                _buildMenteeDetailRow(
                  context,
                  icon: Icons.interests_outlined,
                  label: 'Interests / Background',
                  value: contact.interests!,
                ),
                const SizedBox(height: 10),
              ],

              // Date of Birth
              if (contact.dateOfBirth != null) ...[
                _buildMenteeDetailRow(
                  context,
                  icon: Icons.cake_outlined,
                  label: 'Date of Birth',
                  value: DateFormat.yMMMd().format(contact.dateOfBirth!),
                ),
                const SizedBox(height: 10),
              ],

              // Contact Timeline Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Text('First Contact:', style: theme.textTheme.labelMedium),
                          ],
                        ),
                        Text(
                          DateFormat.yMMMd().format(contact.firstContact),
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.history_rounded, size: 14, color: colorScheme.primary),
                            const SizedBox(width: 6),
                            Text('Last Contact:', style: theme.textTheme.labelMedium),
                          ],
                        ),
                        Text(
                          contact.lastContact != null
                              ? DateFormat.yMMMd().format(contact.lastContact!)
                              : 'None yet',
                          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (contact.baptismDate != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water_drop_rounded, size: 14, color: Colors.blue),
                              const SizedBox(width: 6),
                              Text('Baptized:', style: theme.textTheme.labelMedium),
                            ],
                          ),
                          Text(
                            DateFormat.yMMMd().format(contact.baptismDate!),
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Notes
              if (contact.notes != null && contact.notes!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text('Notes:', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    contact.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                ),
              ],

              // Discipleship Journey Summary Stats
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DiscipleshipMiniStatCard(
                      title: 'Studies',
                      value: contactStudies.length.toString(),
                      icon: Icons.menu_book_rounded,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DiscipleshipMiniStatCard(
                      title: 'Interactions',
                      value: contactInteractions.length.toString(),
                      icon: Icons.people_outline_rounded,
                      color: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DiscipleshipMiniStatCard(
                      title: 'Prayers',
                      value: contactPrayers.length.toString(),
                      icon: Icons.favorite_border_rounded,
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded, size: 16),
                    label: const Text('Add Interaction'),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      onAddInteraction(contact);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildMenteeDetailRow(
  BuildContext context, {
  required IconData icon,
  required String label,
  required String value,
}) {
  final theme = Theme.of(context);
  final colorScheme = theme.colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: colorScheme.outline.withValues(alpha: 0.2)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 2),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Dialog to update a mentee's spiritual growth level.
void showUpdateLevelDialog(
  BuildContext context, {
  required DiscipleshipContact contact,
  required VoidCallback onSuccess,
}) {
  var level = contact.currentLevel;
  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Update ${contact.firstName}\'s level'),
        content: DropdownButton<DiscipleshipLevel>(
          value: level,
          isExpanded: true,
          items: DiscipleshipLevel.values
              .map((l) => DropdownMenuItem(
                    value: l,
                    child: Text(DiscipleshipHelpers.getLevelDisplayName(l)),
                  ))
              .toList(),
          onChanged: (value) {
            if (value != null) setDialogState(() => level = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await DiscipleshipService().updateContactLevel(contact.id, level);
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                onSuccess();
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Update failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog to nominate a contact for deletion (requires zero activities and admin review).
void showRequestDeletionDialog(
  BuildContext context, {
  required DiscipleshipContact contact,
  required VoidCallback onSuccess,
}) async {
  final hasActivity = await DiscipleshipService().checkContactHasActivity(contact.id);
  if (!context.mounted) return;

  if (hasActivity) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 48),
        title: const Text('Cannot Delete Disciple'),
        content: Text(
          '${contact.fullName} has attached discipleship activities (interactions, Bible study sessions, prayers, or milestones).\n\nOnly disciples with zero attached activity can be nominated for deletion.',
          style: const TextStyle(height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
    return;
  }

  final reasonController = TextEditingController();
  String requesterRole = 'Coordinator';
  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red, size: 48),
        title: const Text('Request Disciple Deletion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nominate ${contact.fullName} for deletion. As a Coordinator/Director, this deletion request requires final approval by an Administrator.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: requesterRole,
                decoration: const InputDecoration(
                  labelText: 'Your Office / Role *',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Coordinator', child: Text('Coordinator')),
                  DropdownMenuItem(value: 'Director', child: Text('Director')),
                ],
                onChanged: (val) {
                  if (val != null) setDialogState(() => requesterRole = val);
                },
              ),
              const SizedBox(height: 14),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Reason for deletion *',
                  hintText: 'e.g. Created duplicate entry with 0 activity',
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
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Please enter a reason for deletion.')),
                );
                return;
              }
              final user = AuthService.instance.currentUser;
              try {
                await DiscipleshipService().requestContactDeletion(
                  contact: contact,
                  requesterId: user?.uid ?? '',
                  requesterName: user?.displayName ?? 'Officer',
                  requesterRole: requesterRole,
                  reason: reason,
                );
                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Deletion request queued for Admin approval.')),
                  );
                  onSuccess();
                }
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Request failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog to log a personal, phone, or digital interaction with a mentee.
void showAddInteractionDialog(
  BuildContext context, {
  required DiscipleshipContact contact,
  required VoidCallback onSuccess,
}) {
  final titleController = TextEditingController();
  final descriptionController = TextEditingController();
  var method = ContactMethod.inPerson;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Log interaction with ${contact.firstName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: descriptionController, decoration: const InputDecoration(labelText: 'Notes')),
            DropdownButton<ContactMethod>(
              value: method,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: ContactMethod.values
                  .map((m) => DropdownMenuItem(value: m, child: Text(TextFormatter.formatText(m.name))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setDialogState(() => method = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final user = AuthService.instance.currentUser;
              if (user == null) return;
              try {
                await DiscipleshipService().createInteraction(ContactInteraction(
                  id: '',
                  contactId: contact.id,
                  discipleMakerId: user.uid,
                  method: method,
                  title: titleController.text.trim(),
                  description: descriptionController.text.trim(),
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                ));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                onSuccess();
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Save failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Dialog to log a Bible study session with a mentee.
void showAddStudySessionDialog(
  BuildContext context, {
  required DiscipleshipContact contact,
  required VoidCallback onSuccess,
}) {
  final titleController = TextEditingController();
  final topicController = TextEditingController();
  var type = StudyType.bibleStudy;

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) => AlertDialog(
        title: Text('Study session with ${contact.firstName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: topicController, decoration: const InputDecoration(labelText: 'Topic')),
            DropdownButton<StudyType>(
              value: type,
              isExpanded: true,
              borderRadius: BorderRadius.circular(12),
              dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              icon: const Icon(Icons.arrow_drop_down_rounded),
              items: StudyType.values
                  .map((t) => DropdownMenuItem(value: t, child: Text(TextFormatter.formatText(t.name))))
                  .toList(),
              onChanged: (value) {
                if (value != null) setDialogState(() => type = value);
              },
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.trim().isEmpty) return;
              final user = AuthService.instance.currentUser;
              if (user == null) return;
              try {
                await DiscipleshipService().createStudySession(StudySession(
                  id: '',
                  contactId: contact.id,
                  discipleMakerId: user.uid,
                  type: type,
                  title: titleController.text.trim(),
                  topic: topicController.text.trim(),
                  date: DateTime.now(),
                  createdAt: DateTime.now(),
                ));
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                onSuccess();
              } catch (e) {
                if (dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Save failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}
