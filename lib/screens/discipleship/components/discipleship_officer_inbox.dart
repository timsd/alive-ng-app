import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../models/discipleship_models.dart';
import '../../../services/auth_service.dart';
import '../../../services/discipleship_service.dart';
import '../../../services/role_access_service.dart';
import '../../../utils/error_handler.dart';
import 'discipleship_helpers.dart';

/// Parses raw feedback text containing threaded officer feedback and disciple maker responses.
List<DiscipleshipThreadMessage> parseDiscipleshipFeedbackThread(
  String rawFeedback,
  String defaultOfficerName,
) {
  final messages = <DiscipleshipThreadMessage>[];
  if (rawFeedback.trim().isEmpty) return messages;

  final regExp = RegExp(
    r'---\s*(Officer Feedback|Disciple Maker Response)(?:\s*\(([^)]+)\))?(?:\s*by\s*([^-]+))?---\n',
    caseSensitive: false,
  );

  final matches = regExp.allMatches(rawFeedback).toList();
  if (matches.isEmpty) {
    messages.add(DiscipleshipThreadMessage(
      isOfficer: true,
      author: defaultOfficerName,
      date: null,
      content: rawFeedback.trim(),
    ));
    return messages;
  }

  if (matches.first.start > 0) {
    final preText = rawFeedback.substring(0, matches.first.start).trim();
    if (preText.isNotEmpty) {
      messages.add(DiscipleshipThreadMessage(
        isOfficer: true,
        author: defaultOfficerName,
        date: null,
        content: preText,
      ));
    }
  }

  for (int i = 0; i < matches.length; i++) {
    final m = matches[i];
    final headerType = m.group(1) ?? '';
    final isOfficer = headerType.toLowerCase().contains('officer');
    final date = m.group(2)?.trim();
    final byName = m.group(3)?.trim();
    final author = byName != null && byName.isNotEmpty
        ? byName
        : (isOfficer ? defaultOfficerName : 'Disciple Maker');

    final contentStart = m.end;
    final contentEnd =
        (i + 1 < matches.length) ? matches[i + 1].start : rawFeedback.length;
    final content = rawFeedback.substring(contentStart, contentEnd).trim();

    if (content.isNotEmpty) {
      messages.add(DiscipleshipThreadMessage(
        isOfficer: isOfficer,
        author: author,
        date: date,
        content: content,
      ));
    }
  }

  return messages;
}

/// A threaded conversation timeline widget showing alternating Officer feedback
/// and Disciple Maker responses.
class DiscipleshipFeedbackThreadView extends StatelessWidget {
  final DiscipleshipReport report;
  final bool canOfficerReply;
  final VoidCallback onRefresh;

  const DiscipleshipFeedbackThreadView({
    super.key,
    required this.report,
    required this.canOfficerReply,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rawFeedback = report.feedback ?? '';
    final defaultOfficerName = report.feedbackOfficerName ?? 'Officer';
    final messages = parseDiscipleshipFeedbackThread(rawFeedback, defaultOfficerName);

    if (messages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final msg in messages) ...[
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: msg.isOfficer
                  ? Colors.amber.withValues(alpha: 0.12)
                  : theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: msg.isOfficer
                    ? Colors.amber.withValues(alpha: 0.4)
                    : theme.colorScheme.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      msg.isOfficer ? Icons.rate_review_rounded : Icons.reply_rounded,
                      size: 16,
                      color: msg.isOfficer ? Colors.amber.shade800 : theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        msg.isOfficer
                            ? 'Feedback from ${msg.author}${msg.date != null && msg.date!.isNotEmpty ? ' (${msg.date})' : ''}:'
                            : 'Response from ${msg.author}${msg.date != null && msg.date!.isNotEmpty ? ' (${msg.date})' : ''}:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: msg.isOfficer ? Colors.amber.shade900 : theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(msg.content, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => showDiscipleMakerReplyDialog(context, report, onRefresh),
              icon: const Icon(Icons.reply_rounded, size: 16),
              label: const Text(
                'Reply to Conversation',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            if (canOfficerReply)
              TextButton.icon(
                onPressed: () => showSendOfficerFeedbackDialog(
                  context,
                  report: report,
                  officerName: defaultOfficerName,
                  onSuccess: onRefresh,
                ),
                icon: const Icon(Icons.rate_review_rounded, size: 16),
                label: const Text(
                  'Send Follow-up Feedback',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Dialog for an Officer to send feedback or follow-up guidance.
void showSendOfficerFeedbackDialog(
  BuildContext context, {
  required DiscipleshipReport report,
  required String officerName,
  required VoidCallback onSuccess,
}) {
  final feedbackController = TextEditingController();
  final thread = parseDiscipleshipFeedbackThread(report.feedback ?? '', officerName);

  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(thread.isEmpty ? 'Send Officer Feedback' : 'Send Follow-up Feedback'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Report Period: ${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          if (thread.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Conversation history has ${thread.length} message(s). Your new response will be appended to the thread.',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: feedbackController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Officer Feedback & Guidance *',
              hintText: 'Write feedback, instruction, or follow-up words of encouragement...',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.send_rounded, size: 16),
          onPressed: () async {
            final text = feedbackController.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(content: Text('Please enter feedback.')),
              );
              return;
            }
            try {
              await DiscipleshipService().submitReportFeedback(
                reportId: report.id,
                feedback: text,
                officerName: officerName,
              );
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(dialogContext).showSnackBar(
                  const SnackBar(content: Text('Feedback sent to disciple maker!')),
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
          label: const Text('Send Feedback'),
        ),
      ],
    ),
  );
}

/// Dialog for a Disciple Maker to reply to officer feedback.
void showDiscipleMakerReplyDialog(
  BuildContext context,
  DiscipleshipReport report,
  VoidCallback onSuccess,
) {
  final controller = TextEditingController();
  final theme = Theme.of(context);
  final officerName = report.feedbackOfficerName ?? 'Officer';

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.reply_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Reply to $officerName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Acknowledge feedback or provide an update on this report.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: controller,
            maxLines: 4,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Your Response',
              hintText: 'e.g. Thank you! We have followed up on the active contacts and scheduled the next study.',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () async {
            final text = controller.text.trim();
            if (text.isEmpty) return;
            Navigator.pop(ctx);
            try {
              final user = AuthService.instance.currentUser;
              final userName = user?.displayName ?? 'Disciple Maker';
              await DiscipleshipService().submitUserReplyToFeedback(
                reportId: report.id,
                userReply: text,
                userName: userName,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Response submitted successfully!')),
                );
              }
              onSuccess();
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(ErrorHandler.getUserFriendlyMessage(e))),
                );
              }
            }
          },
          icon: const Icon(Icons.send_rounded, size: 16),
          label: const Text('Send Response'),
        ),
      ],
    ),
  );
}

/// The Officer Inbox Tab widget.
class DiscipleshipOfficerInboxView extends StatelessWidget {
  final List<OfficerOfficeAssignment> officerAssignments;
  final OfficerOfficeAssignment? selectedOffice;
  final List<DiscipleshipReport> reports;
  final ValueChanged<OfficerOfficeAssignment?> onOfficeChanged;
  final Future<void> Function() onRefresh;

  const DiscipleshipOfficerInboxView({
    super.key,
    required this.officerAssignments,
    required this.selectedOffice,
    required this.reports,
    required this.onOfficeChanged,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roleService = RoleAccessService.instance;

    if (!roleService.hasRole('coordinator') &&
        !roleService.canAccessAdmin() &&
        !roleService.hasRole('director') &&
        !roleService.hasRole('bod')) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 48,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  'Officer inbox',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'Only coordinators, directors and administrators can review and respond to dispatched reports.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Officer Office / Inbox View',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Select your designated office to review dispatched reports and exchange threaded feedback.',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  if (officerAssignments.isEmpty)
                    const Text('No officer assignments found. Contact the Administrator.')
                  else
                    DropdownButtonFormField<OfficerOfficeAssignment>(
                      initialValue: selectedOffice,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Holding Office',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      items: officerAssignments.map((a) {
                        return DropdownMenuItem(
                          value: a,
                          child: Text('${a.officeTitle} (${a.officerName})', overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: onOfficeChanged,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Received Reports for ${selectedOffice?.officeTitle ?? 'Office'} (${reports.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              if (reports.isNotEmpty)
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.description_rounded, size: 16),
                  label: const Text('Export All (.doc)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: FilledButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  ),
                  onPressed: () => _exportReportsToDoc(context, selectedOffice, reports),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (reports.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.inbox_outlined, size: 56, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(height: 12),
                    Text(
                      'No reports dispatched to this office yet.',
                      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            ...reports.map((report) {
              final isReviewed = report.status.toLowerCase() == 'reviewed';
              final officerName = selectedOffice?.officerName ?? report.feedbackOfficerName ?? 'Officer';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Period: ${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
                            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                                color: isReviewed ? Colors.green[800] : Colors.orange[800],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 6,
                        children: [
                          DiscipleshipHelpers.buildMetricChip(context, 'Total Disciples', report.totalContacts.toString()),
                          DiscipleshipHelpers.buildMetricChip(context, 'Active', report.activeContacts.toString()),
                          DiscipleshipHelpers.buildMetricChip(context, 'New', report.newContacts.toString()),
                          DiscipleshipHelpers.buildMetricChip(context, 'Baptisms', report.baptisms.toString()),
                          DiscipleshipHelpers.buildMetricChip(context, 'Studies', report.studySessions.toString()),
                          DiscipleshipHelpers.buildMetricChip(context, 'Interactions', report.interactions.toString()),
                        ],
                      ),
                      if (report.highlights != null && report.highlights!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('Highlights: ${report.highlights}', style: theme.textTheme.bodySmall),
                      ],
                      if (report.challenges != null && report.challenges!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Challenges: ${report.challenges}', style: theme.textTheme.bodySmall),
                      ],
                      if (report.goals != null && report.goals!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('Goals: ${report.goals}', style: theme.textTheme.bodySmall),
                      ],

                      // Unified Threaded Feedback & Response Stream
                      if (report.feedback != null && report.feedback!.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        DiscipleshipFeedbackThreadView(
                          report: report,
                          canOfficerReply: true,
                          onRefresh: () => onRefresh(),
                        ),
                      ],

                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => showSendOfficerFeedbackDialog(
                          context,
                          report: report,
                          officerName: officerName,
                          onSuccess: () => onRefresh(),
                        ),
                        icon: const Icon(Icons.rate_review_outlined),
                        label: Text(report.feedback != null ? 'Add Officer Feedback' : 'Send Feedback'),
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _exportReportsToDoc(
    BuildContext context,
    OfficerOfficeAssignment? office,
    List<DiscipleshipReport> reports,
  ) async {
    if (reports.isEmpty) return;

    final officeTitle = office?.officeTitle ?? 'General Office';
    final officerName = office?.officerName ?? 'Officer';
    final generatedDate = DateFormat('MMMM dd, yyyy HH:mm').format(DateTime.now());

    int totalContacts = 0;
    int totalActive = 0;
    int totalNew = 0;
    int totalBaptisms = 0;
    int totalStudies = 0;
    int totalInteractions = 0;

    for (final r in reports) {
      totalContacts += r.totalContacts;
      totalActive += r.activeContacts;
      totalNew += r.newContacts;
      totalBaptisms += r.baptisms;
      totalStudies += r.studySessions;
      totalInteractions += r.interactions;
    }

    final buffer = StringBuffer();
    buffer.writeln('''<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset="utf-8">
<title>ALIVE Nigeria Discipleship Office Reports - $officeTitle</title>
<!--[if gte mso 9]>
<xml>
<w:WordDocument>
<w:View>Print</w:View>
<w:Zoom>100</w:Zoom>
<w:DoNotOptimizeForBrowser/>
</w:WordDocument>
</xml>
<![endif]-->
<style>
  body { font-family: 'Calibri', 'Segoe UI', Arial, sans-serif; font-size: 11pt; color: #1e293b; line-height: 1.6; margin: 30pt; }
  h1 { color: #1B365D; font-size: 20pt; border-bottom: 2pt solid #1B365D; padding-bottom: 6pt; margin-bottom: 4pt; }
  .subtitle { color: #64748b; font-size: 11pt; margin-bottom: 18pt; }
  h2 { color: #0D9488; font-size: 14pt; margin-top: 20pt; margin-bottom: 8pt; border-bottom: 1pt solid #cbd5e1; padding-bottom: 4pt; }
  h3 { color: #1e293b; font-size: 12pt; margin-top: 14pt; margin-bottom: 6pt; }
  table { border-collapse: collapse; width: 100%; margin: 10pt 0 16pt 0; }
  th, td { border: 1pt solid #cbd5e1; padding: 7pt 10pt; text-align: left; font-size: 10pt; }
  th { background-color: #f1f5f9; color: #1B365D; font-weight: bold; }
  .summary-card { background-color: #f8fafc; border: 1pt solid #e2e8f0; border-radius: 6pt; padding: 12pt; margin-bottom: 18pt; }
  .report-card { border: 1pt solid #cbd5e1; border-radius: 6pt; padding: 14pt; margin-bottom: 18pt; }
  .badge { display: inline-block; padding: 3pt 8pt; border-radius: 4pt; font-size: 9pt; font-weight: bold; text-transform: uppercase; }
  .badge-reviewed { background-color: #dcfce7; color: #166534; }
  .badge-submitted { background-color: #ffedd5; color: #9a3412; }
  .thread-msg { border-left: 3pt solid #0D9488; background-color: #f0fdf4; padding: 8pt 12pt; margin: 6pt 0; border-radius: 0 4pt 4pt 0; }
  .thread-msg-officer { border-left-color: #f59e0b; background-color: #fffbeb; }
  .thread-meta { font-size: 9pt; font-weight: bold; margin-bottom: 3pt; color: #0f766e; }
  .thread-meta-officer { color: #b45309; }
  .footer { margin-top: 30pt; border-top: 1pt solid #cbd5e1; padding-top: 8pt; font-size: 9pt; color: #94a3b8; text-align: center; }
</style>
</head>
<body>
<h1>ALIVE Nigeria Discipleship Office Reports</h1>
<div class="subtitle">Holding Office: <b>$officeTitle</b> • Officer: <b>$officerName</b> • Generated: <b>$generatedDate</b></div>

<div class="summary-card">
  <h3>Executive Summary of Received Reports (${reports.length} Total)</h3>
  <table>
    <tr>
      <th>Total Disciples</th>
      <th>Active Disciples</th>
      <th>New Disciples</th>
      <th>Baptisms</th>
      <th>Bible Studies</th>
      <th>Interactions</th>
    </tr>
    <tr style="font-weight: bold; font-size: 11pt; background-color: #ffffff;">
      <td>$totalContacts</td>
      <td>$totalActive</td>
      <td>$totalNew</td>
      <td>$totalBaptisms</td>
      <td>$totalStudies</td>
      <td>$totalInteractions</td>
    </tr>
  </table>
</div>
''');

    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final periodStart = DateFormat.yMMMd().format(r.reportPeriodStart);
      final periodEnd = DateFormat.yMMMd().format(r.reportPeriodEnd);
      final isReviewed = r.status.toLowerCase() == 'reviewed';

      buffer.writeln('''
<div class="report-card">
  <h2>Report #${i + 1}: $periodStart – $periodEnd
    <span class="badge ${isReviewed ? 'badge-reviewed' : 'badge-submitted'}">${r.status.toUpperCase()}</span>
  </h2>
  <table>
    <tr>
      <th>Total Disciples</th>
      <th>Active</th>
      <th>New</th>
      <th>Baptisms</th>
      <th>Study Sessions</th>
      <th>Interactions</th>
    </tr>
    <tr>
      <td>${r.totalContacts}</td>
      <td>${r.activeContacts}</td>
      <td>${r.newContacts}</td>
      <td>${r.baptisms}</td>
      <td>${r.studySessions}</td>
      <td>${r.interactions}</td>
    </tr>
  </table>
''');

      if (r.highlights != null && r.highlights!.isNotEmpty) {
        buffer.writeln('<p><b>Ministry Highlights:</b> ${r.highlights}</p>');
      }
      if (r.challenges != null && r.challenges!.isNotEmpty) {
        buffer.writeln('<p><b>Challenges & Needs:</b> ${r.challenges}</p>');
      }
      if (r.goals != null && r.goals!.isNotEmpty) {
        buffer.writeln('<p><b>Next Goals:</b> ${r.goals}</p>');
      }

      final thread = parseDiscipleshipFeedbackThread(r.feedback ?? '', officerName);
      if (thread.isNotEmpty) {
        buffer.writeln('<h3>Officer Feedback & Discussion (${thread.length} entries)</h3>');
        for (final msg in thread) {
          final isOfficer = msg.isOfficer;
          buffer.writeln('''
<div class="thread-msg ${isOfficer ? 'thread-msg-officer' : ''}">
  <div class="thread-meta ${isOfficer ? 'thread-meta-officer' : ''}">
    ${isOfficer ? 'Officer Feedback' : 'Disciple Maker Response'} by ${msg.author}${msg.date != null ? ' (${msg.date})' : ''}:
  </div>
  <div>${msg.content}</div>
</div>
''');
        }
      }

      buffer.writeln('</div>');
    }

    buffer.writeln('''
<div class="footer">
  ALIVE Nigeria Discipleship Ministry Management System • Confidential Office Record
</div>
</body>
</html>
''');

    final cleanTitle = officeTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final fileName = 'discipleship_reports_${cleanTitle}_${DateFormat('yyyyMMdd').format(DateTime.now())}.doc';

    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(buffer.toString())),
              name: fileName,
              mimeType: 'application/msword',
            ),
          ],
          subject: 'ALIVE Nigeria Discipleship Reports - $officeTitle',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: ${ErrorHandler.getUserFriendlyMessage(e)}')),
        );
      }
    }
  }
}

