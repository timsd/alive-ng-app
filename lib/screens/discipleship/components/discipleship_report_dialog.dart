import 'package:flutter/material.dart';
import '../../../widgets/modern_dropdown.dart';
import 'package:intl/intl.dart';
import '../../../models/discipleship_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/discipleship_service.dart';
import '../../../utils/error_handler.dart';
import '../../../utils/text_formatter.dart';
import 'discipleship_helpers.dart';
import 'discipleship_officer_inbox.dart';

/// The Discipleship Reports tab widget showing dispatched reports and interactive feedback threads.
class DiscipleshipReportsTab extends StatefulWidget {
  final List<DiscipleshipReport> reports;
  final bool canAccessOfficerInbox;
  final VoidCallback onGenerateReport;
  final Future<void> Function() onRefresh;

  const DiscipleshipReportsTab({
    super.key,
    required this.reports,
    required this.canAccessOfficerInbox,
    required this.onGenerateReport,
    required this.onRefresh,
  });

  @override
  State<DiscipleshipReportsTab> createState() => _DiscipleshipReportsTabState();
}

class _DiscipleshipReportsTabState extends State<DiscipleshipReportsTab> {
  String? _expandedReportId;

  List<DiscipleshipReport> get reports => widget.reports;
  bool get canAccessOfficerInbox => widget.canAccessOfficerInbox;
  VoidCallback get onGenerateReport => widget.onGenerateReport;
  Future<void> Function() get onRefresh => widget.onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Modern Reports Header Card matching Officer Inbox
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? theme.colorScheme.surfaceContainerHigh
                  : theme.colorScheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.assessment_rounded,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'My Reports (${reports.length})',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            'Send progress updates & track officer feedback',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: onGenerateReport,
                  icon: const Icon(Icons.send_rounded, size: 17),
                  label: const Text(
                    'Generate Report',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (reports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.assessment_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'No reports dispatched yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Generate a report to send progress updates and prayer needs to your officer.',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            ...reports.map((report) {
              final isReviewed = report.status.toLowerCase() == 'reviewed';
              final isExpanded = _expandedReportId == report.id;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      borderRadius: isExpanded
                          ? const BorderRadius.vertical(top: Radius.circular(14))
                          : BorderRadius.circular(14),
                      onTap: () {
                        setState(() {
                          _expandedReportId = isExpanded ? null : report.id;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Period: ${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
                                style: theme.textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isReviewed
                                    ? Colors.green.withValues(alpha: 0.15)
                                    : Colors.orange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                report.status.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: isReviewed
                                      ? Colors.green[800]
                                      : Colors.orange[800],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              isExpanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 20,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 10,
                              runSpacing: 6,
                              children: [
                                DiscipleshipHelpers.buildMetricChip(
                                    context,
                                    'Total Disciples',
                                    report.totalContacts.toString()),
                                DiscipleshipHelpers.buildMetricChip(
                                    context,
                                    'Active',
                                    report.activeContacts.toString()),
                                DiscipleshipHelpers.buildMetricChip(
                                    context, 'New', report.newContacts.toString()),
                                DiscipleshipHelpers.buildMetricChip(
                                    context, 'Baptisms', report.baptisms.toString()),
                                DiscipleshipHelpers.buildMetricChip(
                                    context,
                                    'Studies',
                                    report.studySessions.toString()),
                                DiscipleshipHelpers.buildMetricChip(
                                    context,
                                    'Interactions',
                                    report.interactions.toString()),
                              ],
                            ),
                            if (report.highlights != null &&
                                report.highlights!.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text('Highlights: ${report.highlights}',
                                  style: theme.textTheme.bodySmall),
                            ],
                            if (report.challenges != null &&
                                report.challenges!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Challenges: ${report.challenges}',
                                  style: theme.textTheme.bodySmall),
                            ],
                            if (report.goals != null &&
                                report.goals!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text('Goals: ${report.goals}',
                                  style: theme.textTheme.bodySmall),
                            ],

                            // Conversation thread (Replies and Responses)
                            if (report.feedback != null &&
                                report.feedback!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              DiscipleshipFeedbackThreadView(
                                report: report,
                                canOfficerReply: canAccessOfficerInbox,
                                onRefresh: () => onRefresh(),
                              ),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// Dialog to compile discipleship statistics and dispatch an executive report to a designated officer.
void showGenerateReportDialog(
  BuildContext context, {
  required List<OfficerOfficeAssignment> officerAssignments,
  required VoidCallback onSuccess,
}) {
  var frequency = ReportFrequency.monthly;
  DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime endDate = DateTime.now();
  OfficerOfficeAssignment? routedOfficer =
      officerAssignments.isNotEmpty ? officerAssignments.first : null;
  final highlightsController = TextEditingController();
  final challengesController = TextEditingController();
  final goalsController = TextEditingController();
  final prayerRequestsController = TextEditingController();

  showDialog(
    context: context,
    builder: (dialogContext) {
      bool isSubmitting = false;
      return StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Generate & Dispatch Report'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ModernDropdownFormField<ReportFrequency>(
                  initialValue: frequency,
                  borderRadius: BorderRadius.circular(12),
                  dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  icon: const Icon(Icons.arrow_drop_down_rounded),
                  decoration: const InputDecoration(labelText: 'Report Frequency', border: OutlineInputBorder()),
                  items: ReportFrequency.values
                      .map((f) => DropdownMenuItem(value: f, child: Text(TextFormatter.formatText(f.name))))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setDialogState(() => frequency = val);
                  },
                ),
                const SizedBox(height: 14),
                if (officerAssignments.isNotEmpty)
                  ModernDropdownFormField<OfficerOfficeAssignment>(
                    initialValue: routedOfficer,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Dispatch To Officer / Office *',
                      border: OutlineInputBorder(),
                    ),
                    items: officerAssignments
                        .map((a) => DropdownMenuItem(
                              value: a,
                              child: Text('${a.officeTitle} (${a.officerName})', overflow: TextOverflow.ellipsis),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => routedOfficer = val);
                    },
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setDialogState(() => startDate = picked);
                              },
                        child: Text('Start: ${DateFormat.MMMd().format(startDate)}'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: endDate,
                                  firstDate: startDate,
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setDialogState(() => endDate = picked);
                              },
                        child: Text('End: ${DateFormat.MMMd().format(endDate)}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: highlightsController,
                  enabled: !isSubmitting,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Highlights / Victories', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: challengesController,
                  enabled: !isSubmitting,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Challenges / Needs', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: goalsController,
                  enabled: !isSubmitting,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Goals for Next Period', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: prayerRequestsController,
                  enabled: !isSubmitting,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Prayer Requests for Mission', border: OutlineInputBorder()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              icon: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(isSubmitting ? 'Dispatching...' : 'Dispatch Report'),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final user = AuthService.instance.currentUser;
                      if (user == null) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        final submittedReport =
                            await DiscipleshipService().generateAndSubmitReport(
                          discipleMakerId: user.uid,
                          routedOfficerId: routedOfficer?.officerId,
                          routedOfficeTitle: routedOfficer?.officeTitle,
                          routedOfficerName: routedOfficer?.officerName,
                          startDate: startDate,
                          endDate: endDate,
                          frequency: frequency,
                          highlights: highlightsController.text.trim().isEmpty ? null : highlightsController.text.trim(),
                          challenges: challengesController.text.trim().isEmpty ? null : challengesController.text.trim(),
                          goals: goalsController.text.trim().isEmpty ? null : goalsController.text.trim(),
                          prayerRequests: prayerRequestsController.text.trim().isEmpty ? null : prayerRequestsController.text.trim(),
                        );
                        if (dialogContext.mounted) {
                          Navigator.pop(dialogContext);
                        }
                        if (context.mounted) {
                          final messenger = ScaffoldMessenger.of(context);
                          messenger.clearSnackBars();
                          messenger.showSnackBar(
                            SnackBar(
                              duration: const Duration(seconds: 15),
                              content: Text(
                                'Report dispatched to ${routedOfficer?.officeTitle ?? 'Office'}! (Undo within 15s)',
                              ),
                              action: SnackBarAction(
                                label: 'UNDO',
                                onPressed: () async {
                                  try {
                                    await DiscipleshipService()
                                        .deleteReport(submittedReport.id);
                                    onSuccess();
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Discipleship report dispatch undone.'),
                                      ),
                                    );
                                  } catch (e) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Could not undo: ${ErrorHandler.getUserFriendlyMessage(e)}',
                                        ),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ),
                          );
                          onSuccess();
                        }
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() => isSubmitting = false);
                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                            SnackBar(content: Text('Failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      );
    },
  );
}

