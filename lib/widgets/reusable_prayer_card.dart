import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Unified presentation model so [ReusablePrayerCard] can render prayer requests
/// originating from either:
/// 1. The general Prayer Wall & Private Rooms (`prayer_requests` collection)
/// 2. Discipleship Tracker (`discipleship_prayer_requests` collection)
class PrayerCardViewModel {
  final String id;
  final String title;
  final String description;
  final String authorName;
  final DateTime createdAt;
  final String? category;
  final int prayerCount;
  final bool isAnswered;
  final String? testimony;
  final DateTime? answeredAt;
  final String? roomName;
  final String? contactName;
  final bool isOwner;
  final bool isPublic;
  final String collectionSource; // 'prayer_requests' or 'discipleship_prayer_requests'

  const PrayerCardViewModel({
    required this.id,
    required this.title,
    required this.description,
    required this.authorName,
    required this.createdAt,
    this.category,
    this.prayerCount = 0,
    this.isAnswered = false,
    this.testimony,
    this.answeredAt,
    this.roomName,
    this.contactName,
    this.isOwner = false,
    this.isPublic = true,
    this.collectionSource = 'prayer_requests',
  });
}

/// Reusable and room/collection-aware Prayer Card for ALIVE Nigeria.
///
/// Handles general wall requests, room-specific intercessions, and discipleship prayers
/// with elegant celebratory styling for answered prayers and testimonies.
class ReusablePrayerCard extends StatelessWidget {
  final PrayerCardViewModel model;
  final VoidCallback? onPray;
  final VoidCallback? onShare;
  final VoidCallback? onMarkAnswered;
  final VoidCallback? onDelete;
  final VoidCallback? onViewHistory;

  const ReusablePrayerCard({
    super.key,
    required this.model,
    this.onPray,
    this.onShare,
    this.onMarkAnswered,
    this.onDelete,
    this.onViewHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final borderColor = model.isAnswered
        ? Colors.green.withValues(alpha: 0.6)
        : (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0));

    final backgroundColor = model.isAnswered
        ? (isDark ? const Color(0xFF0F291E) : const Color(0xFFF0FDF4))
        : (isDark ? const Color(0xFF1E293B) : Colors.white);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: model.isAnswered ? 1.5 : 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Avatar, Author/Mentee, Badges, and Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: model.isAnswered
                      ? Colors.green.withValues(alpha: 0.2)
                      : theme.colorScheme.primary.withValues(alpha: 0.12),
                  child: Icon(
                    model.isAnswered
                        ? Icons.check_circle_rounded
                        : (model.contactName != null
                            ? Icons.person_rounded
                            : Icons.favorite_rounded),
                    color: model.isAnswered
                        ? Colors.green
                        : theme.colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              model.contactName != null
                                  ? 'For: ${model.contactName}'
                                  : model.authorName,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (model.roomName != null && model.roomName!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.indigo.withValues(alpha: 0.3), width: 0.8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.meeting_room_rounded, size: 10, color: Colors.indigo),
                                  const SizedBox(width: 3),
                                  Text(
                                    model.roomName!,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.indigo,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          if (model.collectionSource == 'discipleship_prayer_requests') ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.teal.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: Colors.teal.withValues(alpha: 0.3), width: 0.8),
                              ),
                              child: const Text(
                                'DISCIPLESHIP',
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.teal,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            DateFormat('MMM dd, yyyy').format(model.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                            ),
                          ),
                          if (model.category != null && model.category!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Text(
                              '• ${model.category}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Answered badge or overflow
                if (model.isAnswered)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.5), width: 0.8),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 13, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'ANSWERED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (onDelete != null || onViewHistory != null || onMarkAnswered != null)
                  PopupMenuButton<String>(
                    icon: Icon(
                      Icons.more_vert_rounded,
                      size: 20,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                    itemBuilder: (context) => [
                      if (onMarkAnswered != null && !model.isAnswered)
                        const PopupMenuItem(
                          value: 'answer',
                          child: Row(
                            children: [
                              Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text('Mark as Answered'),
                            ],
                          ),
                        ),
                      if (onViewHistory != null)
                        const PopupMenuItem(
                          value: 'history',
                          child: Row(
                            children: [
                              Icon(Icons.history_rounded, size: 18),
                              SizedBox(width: 8),
                              Text('View History'),
                            ],
                          ),
                        ),
                      if (onDelete != null && model.isOwner)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline_rounded, color: Colors.red, size: 18),
                              SizedBox(width: 8),
                              Text('Delete Request', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                    onSelected: (val) {
                      if (val == 'answer' && onMarkAnswered != null) onMarkAnswered!();
                      if (val == 'history' && onViewHistory != null) onViewHistory!();
                      if (val == 'delete' && onDelete != null) onDelete!();
                    },
                  ),
              ],
            ),

            const SizedBox(height: 12),

            // Prayer Request Title (if distinct from description)
            if (model.title.isNotEmpty && model.title != model.description)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  model.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ),

            // Prayer Request Body / Description
            Text(
              model.description,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
                height: 1.45,
              ),
            ),

            // Answered Testimony / Praise Report Box
            if (model.isAnswered && model.testimony != null && model.testimony!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF093322) : const Color(0xFFE8F8EE),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.green.withValues(alpha: 0.35),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          'Testimony & Praise Report',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.green.shade300 : Colors.green.shade800,
                          ),
                        ),
                        if (model.answeredAt != null) ...[
                          const Spacer(),
                          Text(
                            DateFormat('MMM d, yyyy').format(model.answeredAt!),
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? Colors.green.shade400 : Colors.green.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      model.testimony!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.green.shade100 : const Color(0xFF1B4332),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Bottom Action Bar: Pray count, Share, Mark Answered quick action
            Row(
              children: [
                if (onPray != null)
                  FilledButton.tonalIcon(
                    onPressed: onPray,
                    icon: Icon(
                      Icons.volunteer_activism_rounded,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                    label: Text(
                      model.prayerCount > 0 ? '${model.prayerCount} Prayed' : 'Pray',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                const SizedBox(width: 8),
                if (onShare != null)
                  IconButton(
                    icon: const Icon(Icons.share_outlined, size: 18),
                    tooltip: 'Share prayer request',
                    onPressed: onShare,
                    visualDensity: VisualDensity.compact,
                  ),
                const Spacer(),
                if (!model.isAnswered && onMarkAnswered != null && model.isOwner)
                  OutlinedButton.icon(
                    onPressed: onMarkAnswered,
                    icon: const Icon(Icons.check_circle_outline, size: 15, color: Colors.green),
                    label: const Text(
                      'Mark Answered',
                      style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.green.withValues(alpha: 0.6)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

