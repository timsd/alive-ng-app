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

// ─────────────────────────────────────────────────────────────────────────────
// Modern Feedback Thread View — Chat-bubble timeline
// ─────────────────────────────────────────────────────────────────────────────

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
    final isDark = theme.brightness == Brightness.dark;
    final rawFeedback = report.feedback ?? '';
    final defaultOfficerName = report.feedbackOfficerName ?? 'Officer';
    final messages = parseDiscipleshipFeedbackThread(rawFeedback, defaultOfficerName);

    if (messages.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Thread header
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Icon(Icons.forum_rounded, size: 16,
                  color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Conversation Thread',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${messages.length}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Chat bubbles
        for (int i = 0; i < messages.length; i++) ...[
          _ChatBubble(
            message: messages[i],
            isLast: i == messages.length - 1,
          ),
        ],

        const SizedBox(height: 8),

        // Action buttons row
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            _ModernSmallButton(
              icon: Icons.reply_rounded,
              label: 'Reply',
              onTap: () => showDiscipleMakerReplyDialog(context, report, onRefresh),
              color: theme.colorScheme.primary,
              isDark: isDark,
            ),
            if (canOfficerReply) ...[
              const SizedBox(width: 8),
              _ModernSmallButton(
                icon: Icons.rate_review_rounded,
                label: 'Follow-up',
                onTap: () => showSendOfficerFeedbackDialog(
                  context,
                  report: report,
                  officerName: defaultOfficerName,
                  onSuccess: onRefresh,
                ),
                color: Colors.amber.shade700,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// A single chat-style bubble in the feedback thread.
class _ChatBubble extends StatelessWidget {
  final DiscipleshipThreadMessage message;
  final bool isLast;

  const _ChatBubble({required this.message, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOfficer = message.isOfficer;

    final bubbleColor = isOfficer
        ? (isDark
            ? Colors.amber.withValues(alpha: 0.10)
            : Colors.amber.withValues(alpha: 0.08))
        : (isDark
            ? theme.colorScheme.primary.withValues(alpha: 0.10)
            : theme.colorScheme.primary.withValues(alpha: 0.06));

    final accentColor = isOfficer ? Colors.amber.shade700 : theme.colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 14,
            backgroundColor: accentColor.withValues(alpha: 0.15),
            child: Icon(
              isOfficer ? Icons.shield_rounded : Icons.person_rounded,
              size: 14,
              color: accentColor,
            ),
          ),
          const SizedBox(width: 8),
          // Bubble
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(4),
                  topRight: const Radius.circular(14),
                  bottomLeft: const Radius.circular(14),
                  bottomRight: const Radius.circular(14),
                ),
                border: Border(
                  left: BorderSide(color: accentColor, width: 2.5),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        message.author,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: accentColor,
                        ),
                      ),
                      if (isOfficer) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'OFFICER',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      if (message.date != null && message.date!.isNotEmpty)
                        Text(
                          message.date!,
                          style: TextStyle(
                            fontSize: 10,
                            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message.content,
                    style: theme.textTheme.bodySmall?.copyWith(
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact modern button used inside cards.
class _ModernSmallButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color color;
  final bool isDark;

  const _ModernSmallButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: isDark ? 0.15 : 0.10),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dialogs
// ─────────────────────────────────────────────────────────────────────────────

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
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.rate_review_rounded, size: 20, color: Colors.amber.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    thread.isEmpty ? 'Send Feedback' : 'Follow-up',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (thread.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 14,
                        color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      '${thread.length} previous message(s) in thread',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: feedbackController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Your Feedback',
                hintText: 'Write guidance, encouragement, or follow-up...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
            label: const Text('Send'),
          ),
        ],
      );
    },
  );
}

/// Dialog for a Disciple Maker to reply to officer feedback.
void showDiscipleMakerReplyDialog(
  BuildContext context,
  DiscipleshipReport report,
  VoidCallback onSuccess,
) {
  final controller = TextEditingController();
  final officerName = report.feedbackOfficerName ?? 'Officer';

  showDialog(
    context: context,
    builder: (ctx) {
      final theme = Theme.of(ctx);
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.reply_rounded, size: 20,
                  color: theme.colorScheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Reply to $officerName',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Acknowledge feedback or provide an update.',
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
                hintText: 'e.g. Thank you! We have followed up on the active contacts...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
            label: const Text('Send'),
          ),
        ],
      );
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Metric Tile — Icon-based mini card for report KPIs
// ─────────────────────────────────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MetricTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.20 : 0.15),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: theme.colorScheme.onSurface,
                  height: 1.1,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Expandable Info Section for Highlights, Challenges, Goals
// ─────────────────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 12, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  content,
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Modern Officer Inbox View
// ─────────────────────────────────────────────────────────────────────────────

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
    final isDark = theme.brightness == Brightness.dark;
    final roleService = RoleAccessService.instance;

    // Access gate
    if (!roleService.hasRole('coordinator') &&
        !roleService.canAccessAdmin() &&
        !roleService.hasRole('director') &&
        !roleService.hasRole('bod')) {
      return _buildAccessDenied(context, theme, isDark);
    }

    // Count stats for summary bar
    final reviewed = reports.where((r) => r.status.toLowerCase() == 'reviewed').length;
    final pending = reports.length - reviewed;

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Header card with office selector ──
          _buildHeaderCard(context, theme, isDark),

          const SizedBox(height: 14),

          // ── Summary bar ──
          if (reports.isNotEmpty) ...[
            _buildSummaryBar(theme, isDark, reviewed, pending),
            const SizedBox(height: 14),
          ],

          // ── Report list header ──
          _buildReportListHeader(context, theme, isDark),

          const SizedBox(height: 10),

          // ── Reports or empty state ──
          if (reports.isEmpty)
            _buildEmptyState(theme, isDark)
          else
            ...reports.map((report) => _buildReportCard(context, report, theme, isDark)),
        ],
      ),
    );
  }

  // ─── Access Denied ───
  Widget _buildAccessDenied(BuildContext context, ThemeData theme, bool isDark) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.lock_outline_rounded,
                  size: 40,
                  color: theme.colorScheme.error,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Officer Access Required',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Only coordinators, directors, and administrators can review dispatched reports and provide feedback.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header Card ───
  Widget _buildHeaderCard(BuildContext context, ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1A2332),
                  const Color(0xFF0F1923),
                ]
              : [
                  theme.colorScheme.primary.withValues(alpha: 0.06),
                  theme.colorScheme.primary.withValues(alpha: 0.02),
                ],
        ),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.10),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
                    Icons.inbox_rounded,
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
                        'Officer Inbox',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Review dispatched reports & exchange feedback',
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
            if (officerAssignments.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline_rounded, size: 16,
                        color: theme.colorScheme.error),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'No officer assignments found. Contact the Administrator.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              )
            else
              DropdownButtonFormField<OfficerOfficeAssignment>(
                value: selectedOffice,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Select Office',
                  prefixIcon: Icon(Icons.business_center_rounded,
                      size: 18, color: theme.colorScheme.primary),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: theme.colorScheme.primary,
                      width: 1.5,
                    ),
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
                items: officerAssignments.map((a) {
                  return DropdownMenuItem(
                    value: a,
                    child: Text(
                      '${a.officeTitle} (${a.officerName})',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  );
                }).toList(),
                onChanged: onOfficeChanged,
              ),
          ],
        ),
      ),
    );
  }

  // ─── Summary Bar ───
  Widget _buildSummaryBar(ThemeData theme, bool isDark, int reviewed, int pending) {
    return Row(
      children: [
        Expanded(
          child: _SummaryChip(
            icon: Icons.schedule_rounded,
            label: 'Pending',
            value: pending.toString(),
            color: Colors.orange,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryChip(
            icon: Icons.check_circle_rounded,
            label: 'Reviewed',
            value: reviewed.toString(),
            color: Colors.green,
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryChip(
            icon: Icons.summarize_rounded,
            label: 'Total',
            value: reports.length.toString(),
            color: theme.colorScheme.primary,
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  // ─── Report List Header ───
  Widget _buildReportListHeader(BuildContext context, ThemeData theme, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Reports for ${selectedOffice?.officeTitle ?? 'Office'}',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (reports.isNotEmpty)
          Material(
            color: theme.colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.10),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _exportReportsToDoc(context, selectedOffice, reports),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.ios_share_rounded, size: 14,
                        color: theme.colorScheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      'Export',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ─── Empty State ───
  Widget _buildEmptyState(ThemeData theme, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.inbox_rounded,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No reports yet',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Reports dispatched to this office will appear here.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Report Card ───
  Widget _buildReportCard(BuildContext context, DiscipleshipReport report, ThemeData theme, bool isDark) {
    final isReviewed = report.status.toLowerCase() == 'reviewed';
    final officerName = selectedOffice?.officerName ?? report.feedbackOfficerName ?? 'Officer';

    final statusColor = isReviewed ? Colors.green : Colors.orange;
    final statusIcon = isReviewed ? Icons.check_circle_rounded : Icons.schedule_rounded;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: theme.colorScheme.surfaceContainerLow,
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: isDark ? 0.06 : 0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_month_rounded, size: 16,
                    color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${DateFormat.yMMMd().format(report.reportPeriodStart)} – ${DateFormat.yMMMd().format(report.reportPeriodEnd)}',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        report.status.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: statusColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Metrics grid
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetricTile(
                  icon: Icons.people_rounded,
                  value: report.totalContacts.toString(),
                  label: 'Disciples',
                  color: Colors.blue,
                ),
                _MetricTile(
                  icon: Icons.trending_up_rounded,
                  value: report.activeContacts.toString(),
                  label: 'Active',
                  color: Colors.teal,
                ),
                _MetricTile(
                  icon: Icons.person_add_rounded,
                  value: report.newContacts.toString(),
                  label: 'New',
                  color: Colors.purple,
                ),
                _MetricTile(
                  icon: Icons.water_drop_rounded,
                  value: report.baptisms.toString(),
                  label: 'Baptisms',
                  color: Colors.indigo,
                ),
                _MetricTile(
                  icon: Icons.menu_book_rounded,
                  value: report.studySessions.toString(),
                  label: 'Studies',
                  color: Colors.orange,
                ),
                _MetricTile(
                  icon: Icons.connect_without_contact_rounded,
                  value: report.interactions.toString(),
                  label: 'Interactions',
                  color: Colors.pink,
                ),
              ],
            ),
          ),

          // Highlights, Challenges, Goals
          if (_hasInfoSections(report))
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    if (report.highlights != null && report.highlights!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.star_rounded,
                        title: 'HIGHLIGHTS',
                        content: report.highlights!,
                        color: Colors.amber.shade700,
                      ),
                    if (report.challenges != null && report.challenges!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.warning_amber_rounded,
                        title: 'CHALLENGES',
                        content: report.challenges!,
                        color: Colors.red.shade400,
                      ),
                    if (report.goals != null && report.goals!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.flag_rounded,
                        title: 'GOALS',
                        content: report.goals!,
                        color: Colors.green,
                      ),
                  ],
                ),
              ),
            ),

          // Feedback thread
          if (report.feedback != null && report.feedback!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: DiscipleshipFeedbackThreadView(
                report: report,
                canOfficerReply: true,
                onRefresh: () => onRefresh(),
              ),
            ),

          // Bottom action bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _ModernSmallButton(
                  icon: Icons.rate_review_rounded,
                  label: report.feedback != null ? 'Add Feedback' : 'Send Feedback',
                  onTap: () => showSendOfficerFeedbackDialog(
                    context,
                    report: report,
                    officerName: officerName,
                    onSuccess: () => onRefresh(),
                  ),
                  color: Colors.amber.shade700,
                  isDark: isDark,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _hasInfoSections(DiscipleshipReport report) {
    return (report.highlights != null && report.highlights!.isNotEmpty) ||
        (report.challenges != null && report.challenges!.isNotEmpty) ||
        (report.goals != null && report.goals!.isNotEmpty);
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
    buffer.writeln('======================================================================');
    buffer.writeln('ALIVE NIGERIA EVANGELISM DEPARTMENT');
    buffer.writeln('OFFICE REPORTS SUMMARY');
    buffer.writeln('======================================================================');
    buffer.writeln('Holding Office    : $officeTitle');
    buffer.writeln('Officer In Charge : $officerName');
    buffer.writeln('Generated Date    : $generatedDate');
    buffer.writeln('Total Reports     : ${reports.length}');
    buffer.writeln('');
    buffer.writeln('----------------------------------------------------------------------');
    buffer.writeln('EXECUTIVE SUMMARY');
    buffer.writeln('----------------------------------------------------------------------');
    buffer.writeln('• Total Disciples      : $totalContacts');
    buffer.writeln('• Active Disciples     : $totalActive');
    buffer.writeln('• New Disciples        : $totalNew');
    buffer.writeln('• Baptisms             : $totalBaptisms');
    buffer.writeln('• Bible Study Sessions : $totalStudies');
    buffer.writeln('• Total Interactions   : $totalInteractions');
    buffer.writeln('');
    buffer.writeln('======================================================================');
    buffer.writeln('DETAILED REPORTS BREAKDOWN');
    buffer.writeln('======================================================================');

    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final periodStart = DateFormat.yMMMd().format(r.reportPeriodStart);
      final periodEnd = DateFormat.yMMMd().format(r.reportPeriodEnd);

      buffer.writeln('');
      buffer.writeln('----------------------------------------------------------------------');
      buffer.writeln('REPORT #${i + 1}: $periodStart – $periodEnd [${r.status.toUpperCase()}]');
      buffer.writeln('----------------------------------------------------------------------');
      buffer.writeln('Metrics:');
      buffer.writeln('  - Total Disciples      : ${r.totalContacts}');
      buffer.writeln('  - Active Disciples     : ${r.activeContacts}');
      buffer.writeln('  - New Disciples        : ${r.newContacts}');
      buffer.writeln('  - Baptisms             : ${r.baptisms}');
      buffer.writeln('  - Study Sessions       : ${r.studySessions}');
      buffer.writeln('  - Interactions         : ${r.interactions}');

      if (r.highlights != null && r.highlights!.trim().isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('Ministry Highlights:');
        buffer.writeln('  ${r.highlights!.trim()}');
      }
      if (r.challenges != null && r.challenges!.trim().isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('Challenges & Needs:');
        buffer.writeln('  ${r.challenges!.trim()}');
      }
      if (r.goals != null && r.goals!.trim().isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('Next Goals:');
        buffer.writeln('  ${r.goals!.trim()}');
      }

      final thread = parseDiscipleshipFeedbackThread(r.feedback ?? '', officerName);
      if (thread.isNotEmpty) {
        buffer.writeln('');
        buffer.writeln('Officer Feedback & Discussion (${thread.length} entries):');
        for (final msg in thread) {
          final roleLabel = msg.isOfficer ? 'Officer Feedback' : 'Disciple Maker Response';
          buffer.writeln('  • [$roleLabel: ${msg.author}${msg.date != null ? " (${msg.date})" : ""}]');
          buffer.writeln('    ${msg.content.trim()}');
        }
      }
    }

    buffer.writeln('');
    buffer.writeln('======================================================================');
    buffer.writeln('ALIVE Nigeria Evangelism Department Report Management System');
    buffer.writeln('Confidential Office Record • Generated on $generatedDate');
    buffer.writeln('======================================================================');

    final cleanTitle = officeTitle.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    final fileName = 'discipleship_reports_${cleanTitle}_${DateFormat('yyyyMMdd').format(DateTime.now())}.txt';
    final reportContent = buffer.toString();

    try {
      await SharePlus.instance.share(
        ShareParams(
          text: reportContent,
          files: [
            XFile.fromData(
              Uint8List.fromList(utf8.encode(reportContent)),
              name: fileName,
              mimeType: 'text/plain',
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

// ─────────────────────────────────────────────────────────────────────────────
// Summary Chip — used in the stats bar
// ─────────────────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final bool isDark;

  const _SummaryChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.20 : 0.12),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: theme.colorScheme.onSurface,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
