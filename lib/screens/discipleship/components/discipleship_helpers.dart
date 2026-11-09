import 'package:flutter/material.dart';
import '../../../models/discipleship_models.dart';

/// Helper methods and presentation utilities for discipleship tracking.
class DiscipleshipHelpers {
  static String getLevelDisplayName(DiscipleshipLevel level) {
    return level.name
        .split('')
        .map((c) => c == level.name[0] ? c.toUpperCase() : c)
        .join('');
  }

  static Color getLevelColor(DiscipleshipLevel level) {
    switch (level) {
      case DiscipleshipLevel.prospect:
        return Colors.grey;
      case DiscipleshipLevel.studying:
        return Colors.orange;
      case DiscipleshipLevel.convinced:
        return Colors.purple;
      case DiscipleshipLevel.committed:
        return Colors.red;
      case DiscipleshipLevel.baptized:
        return Colors.green;
      case DiscipleshipLevel.disciple:
        return Colors.teal;
    }
  }

  static IconData getMethodIcon(ContactMethod method) {
    switch (method) {
      case ContactMethod.inPerson:
        return Icons.person;
      case ContactMethod.phone:
        return Icons.phone;
      case ContactMethod.video:
        return Icons.video_call;
      case ContactMethod.email:
        return Icons.email;
      case ContactMethod.text:
        return Icons.message;
      case ContactMethod.socialMedia:
        return Icons.share;
      case ContactMethod.other:
        return Icons.more_horiz;
    }
  }

  static Color getStudyTypeColor(StudyType type) {
    switch (type) {
      case StudyType.bibleStudy:
        return Colors.blue;
      case StudyType.prophecySeminar:
        return Colors.deepPurple;
      case StudyType.healthSeminar:
        return Colors.green;
      case StudyType.evangelisticSeries:
        return Colors.red;
      case StudyType.personalStudy:
        return Colors.amber;
      case StudyType.smallGroup:
        return Colors.teal;
      case StudyType.other:
        return Colors.grey;
    }
  }

  static String getStudyTypeDisplayName(StudyType type) {
    switch (type) {
      case StudyType.bibleStudy:
        return 'Bible Study';
      case StudyType.prophecySeminar:
        return 'Prophecy Seminar';
      case StudyType.healthSeminar:
        return 'Health Seminar';
      case StudyType.evangelisticSeries:
        return 'Evangelistic Series';
      case StudyType.personalStudy:
        return 'Personal Study';
      case StudyType.smallGroup:
        return 'Small Group';
      case StudyType.other:
        return 'Other';
    }
  }

  static Widget buildMetricChip(
    BuildContext context,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

