import 'package:intl/intl.dart';

import '../screens/admin/leader_meeting_transcription_screen.dart';

/// Result structure generated entirely on-device by [OnDeviceMeetingSynthesizer].
class SynthesizedMeetingMinutes {
  final String executiveSummary;
  final List<String> keyDecisions;
  final List<MeetingActionItem> actionItems;
  final Map<String, int> speakerContributions;
  final List<String> discussionThemes;
  final bool quorumAchieved;

  const SynthesizedMeetingMinutes({
    required this.executiveSummary,
    required this.keyDecisions,
    required this.actionItems,
    required this.speakerContributions,
    required this.discussionThemes,
    required this.quorumAchieved,
  });
}

/// Advanced 100% on-device Natural Language heuristic synthesizer.
///
/// Completely private and offline. Eliminates reliance on cloud LLMs (Gemini/OpenAI)
/// while producing executive council summaries, key decisions, and assigned action
/// items with target deadlines.
class OnDeviceMeetingSynthesizer {
  const OnDeviceMeetingSynthesizer();

  /// Synthesizes complete council minutes from transcript entries and meeting metadata.
  SynthesizedMeetingMinutes synthesize({
    required String meetingTitle,
    required String meetingType,
    required DateTime meetingDate,
    required List<MeetingAttendee> attendees,
    required List<MeetingTranscriptEntry> entries,
    List<String> existingDecisions = const [],
    List<MeetingActionItem> existingActionItems = const [],
  }) {
    final speakerContributions = <String, int>{};
    for (final entry in entries) {
      speakerContributions[entry.speakerName] =
          (speakerContributions[entry.speakerName] ?? 0) + 1;
    }

    final keyDecisions = extractDecisions(
      entries: entries,
      existingDecisions: existingDecisions,
    );

    final actionItems = extractActionItems(
      entries: entries,
      attendees: attendees,
      meetingDate: meetingDate,
      existingActionItems: existingActionItems,
    );

    final discussionThemes = extractThemes(entries);

    // Quorum: considered achieved if at least 2 attendees are present or entries exist
    final quorumAchieved = attendees.length >= 2 || entries.length >= 3;

    final executiveSummary = generateExecutiveSummary(
      meetingTitle: meetingTitle,
      meetingType: meetingType,
      meetingDate: meetingDate,
      attendees: attendees,
      entries: entries,
      speakerContributions: speakerContributions,
      decisionsCount: keyDecisions.length,
      actionsCount: actionItems.length,
      discussionThemes: discussionThemes,
      quorumAchieved: quorumAchieved,
    );

    return SynthesizedMeetingMinutes(
      executiveSummary: executiveSummary,
      keyDecisions: keyDecisions,
      actionItems: actionItems,
      speakerContributions: speakerContributions,
      discussionThemes: discussionThemes,
      quorumAchieved: quorumAchieved,
    );
  }

  /// Extracts key decisions and formal resolutions adopted by the council.
  List<String> extractDecisions({
    required List<MeetingTranscriptEntry> entries,
    List<String> existingDecisions = const [],
  }) {
    final decisions = <String>[];

    // Seed with existing decisions
    for (final dec in existingDecisions) {
      final clean = _cleanDecisionText(dec);
      if (clean.isNotEmpty && !_containsSimilar(decisions, clean)) {
        decisions.add(clean);
      }
    }

    final decisionPatterns = [
      RegExp(r'^(?:decision|resolution):\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:it is decided that|it was decided that)\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:council resolved that|resolved that|resolved:)\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:approved unanimously|unanimously approved)\s*(?:that|to)?\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:agreed that|it was agreed that|agreed to)\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:board approved|council approved|approved:)\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:motion (?:passed|carried|adopted))\s*(?:that|to)?\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:duly adopted:?)\s*(.+)$', caseSensitive: false),
    ];

    for (final entry in entries) {
      final content = entry.content.trim();
      if (content.isEmpty) continue;

      // Direct entry tag
      if (entry.type == TranscriptEntryType.decision) {
        final clean = _cleanDecisionText(content);
        if (clean.isNotEmpty && !_containsSimilar(decisions, clean)) {
          decisions.add(clean);
        }
        continue;
      }

      // Check regex heuristics
      for (final pattern in decisionPatterns) {
        final match = pattern.firstMatch(content);
        if (match != null && match.groupCount >= 1) {
          final matchedText = match.group(1)?.trim() ?? '';
          final clean = _cleanDecisionText(matchedText);
          if (clean.length > 5 && !_containsSimilar(decisions, clean)) {
            decisions.add(clean);
            break;
          }
        }
      }

      // Fallback keyword scanning for formal clauses
      final lower = content.toLowerCase();
      if (lower.contains('approved unanimously') ||
          lower.contains('motion carried') ||
          lower.contains('unanimously resolved')) {
        final clean = _cleanDecisionText(content);
        if (clean.length > 5 && !_containsSimilar(decisions, clean)) {
          decisions.add(clean);
        }
      }
    }

    return decisions;
  }

  /// Extracts actionable tasks, assignees, and computed target deadlines.
  List<MeetingActionItem> extractActionItems({
    required List<MeetingTranscriptEntry> entries,
    required List<MeetingAttendee> attendees,
    required DateTime meetingDate,
    List<MeetingActionItem> existingActionItems = const [],
  }) {
    final actionItems = <MeetingActionItem>[...existingActionItems];

    final actionPatterns = [
      RegExp(r'^(?:action item|action):\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:task for|assigned to)\s+([A-Za-z\s]+?):\s*(.+)$', caseSensitive: false),
      RegExp(r'^([A-Za-z\s]+?)\s+(?:will|shall|to)\s+(?:coordinate|follow up on|prepare|submit|finalize|organize|contact|deliver|review)\s*(.+)$', caseSensitive: false),
      RegExp(r'^(?:assigned to)\s+([A-Za-z\s]+?)\s+to\s+(.+)$', caseSensitive: false),
    ];

    for (final entry in entries) {
      final content = entry.content.trim();
      if (content.isEmpty) continue;

      if (entry.type == TranscriptEntryType.actionItem) {
        final parsed = _parseActionItemFromText(
          content,
          defaultAssignee: entry.speakerName,
          attendees: attendees,
          baseDate: entry.timestamp,
        );
        if (!_containsSimilarTask(actionItems, parsed.task)) {
          actionItems.add(parsed);
        }
        continue;
      }

      for (final pattern in actionPatterns) {
        final match = pattern.firstMatch(content);
        if (match != null) {
          final parsed = _parseActionItemFromText(
            content,
            defaultAssignee: entry.speakerName,
            attendees: attendees,
            baseDate: entry.timestamp,
          );
          if (parsed.task.length > 5 && !_containsSimilarTask(actionItems, parsed.task)) {
            actionItems.add(parsed);
            break;
          }
        }
      }
    }

    return actionItems;
  }

  /// Extracts core meeting discussion themes based on keyword frequencies.
  List<String> extractThemes(List<MeetingTranscriptEntry> entries) {
    final allText = entries.map((e) => e.content.toLowerCase()).join(' ');
    final themes = <String>[];

    final themeKeywords = {
      'Budget & Financial Stewardship': ['budget', 'financial', 'funds', 'treasury', 'naira', 'account', 'surplus', 'expense', 'auditing'],
      'Evangelism & Literature Outreach': ['evangelism', 'tracts', 'mission', 'outreach', 'literature', 'souls', 'gospel', 'distribution'],
      'Leadership & Council Governance': ['trustees', 'board', 'constitution', 'policy', 'council', 'resolution', 'governance', 'election'],
      'Youth & Student Ministry': ['youth', 'students', 'campus', 'fellowship', 'retreat', 'young', 'university'],
      'Welfare & Member Support': ['welfare', 'assistance', 'support', 'benevolence', 'care', 'visit'],
      'Facilities & Technical Infrastructure': ['equipment', 'hall', 'media', 'sound', 'zoom', 'livekit', 'stream', 'app', 'online'],
    };

    themeKeywords.forEach((theme, keywords) {
      final matchCount = keywords.where((kw) => allText.contains(kw)).length;
      if (matchCount >= 1) {
        themes.add(theme);
      }
    });

    if (themes.isEmpty) {
      themes.add('Council Deliberations & Ministry Operations');
    }

    return themes;
  }

  /// Generates a synthesized professional executive summary paragraph.
  String generateExecutiveSummary({
    required String meetingTitle,
    required String meetingType,
    required DateTime meetingDate,
    required List<MeetingAttendee> attendees,
    required List<MeetingTranscriptEntry> entries,
    required Map<String, int> speakerContributions,
    required int decisionsCount,
    required int actionsCount,
    required List<String> discussionThemes,
    required bool quorumAchieved,
  }) {
    final buffer = StringBuffer();
    final formattedDate = DateFormat('MMMM d, yyyy').format(meetingDate);

    // Opening Paragraph
    buffer.writeln(
        'The $meetingType convened on $formattedDate for "$meetingTitle". '
        'Quorum was ${quorumAchieved ? 'duly constituted' : 'informally observed'} '
        'with ${attendees.length} council members in attendance, represented by leadership delegates.');

    // Deliberation and floor participation
    if (entries.isNotEmpty) {
      final totalContributions = entries.length;
      final topSpeakers = speakerContributions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final primaryVoices = topSpeakers.take(3).map((e) => '${e.key} (${e.value})').join(', ');

      buffer.writeln(
          '\nA total of $totalContributions floor contributions were recorded during proceedings. '
          'Key deliberative interventions were led by: $primaryVoices.');
    } else {
      buffer.writeln(
          '\nNo formal floor speech contributions have been registered for this session.');
    }

    // Core Agenda Themes
    buffer.writeln(
        '\nCore agenda themes deliberated upon centered on: ${discussionThemes.join(", ")}.');

    // Executive Outcome / Closing Synthesis
    buffer.writeln(
        '\nIn summary, the council adopted $decisionsCount formal resolution${decisionsCount == 1 ? '' : 's'} '
        'and assigned $actionsCount actionable follow-up task${actionsCount == 1 ? '' : 's'}. '
        'Council adjourned with unity of purpose in service to the Lord’s work.');

    return buffer.toString().trim();
  }

  // ── Helper parsing methods ──────────────────────────────────────────

  String _cleanDecisionText(String text) {
    return text
        .replaceAll(
            RegExp(
                r'^(?:decision:|resolution:|it is decided that|it was decided that|council resolved that|resolved that|resolved:|approved unanimously\s*(?:that|to)?|unanimously approved\s*(?:that|to)?|agreed that|it was agreed that|agreed to|board approved|council approved|approved:|motion (?:passed|carried|adopted)\s*(?:that|to)?)\s*',
                caseSensitive: false),
            '')
        .trim();
  }

  MeetingActionItem _parseActionItemFromText(
    String rawText, {
    required String defaultAssignee,
    required List<MeetingAttendee> attendees,
    required DateTime baseDate,
  }) {
    String text = rawText
        .replaceAll(RegExp(r'^(?:action item:|action:)\s*', caseSensitive: false), '')
        .trim();

    String detectedAssignee = defaultAssignee;

    // Check if an attendee is explicitly named at the beginning or after "assigned to"
    final assignedToMatch = RegExp(r'(?:assigned to|task for)\s+([A-Za-z\s]+?)(?:\s+to|\s*:|\s*$)', caseSensitive: false).firstMatch(text);
    if (assignedToMatch != null) {
      final candidate = assignedToMatch.group(1)?.trim() ?? '';
      final matchedAttendee = _findAttendee(candidate, attendees);
      if (matchedAttendee != null) {
        detectedAssignee = matchedAttendee.name;
        text = text.replaceFirst(assignedToMatch.group(0)!, '').trim();
      }
    } else {
      for (final attendee in attendees) {
        final firstName = attendee.name.split(' ').first.toLowerCase();
        if (text.toLowerCase().startsWith(firstName) ||
            text.toLowerCase().startsWith(attendee.name.toLowerCase())) {
          detectedAssignee = attendee.name;
          text = text
              .replaceFirst(RegExp('^${RegExp.escape(attendee.name)}', caseSensitive: false), '')
              .replaceFirst(RegExp('^${RegExp.escape(firstName)}', caseSensitive: false), '')
              .replaceFirst(RegExp(r'^(?:\s*will|\s*to|\s*:)\s*', caseSensitive: false), '')
              .trim();
          break;
        }
      }
    }

    // Extract due date from text if present
    final (cleanedTask, dueDate) = _extractDueDate(text, baseDate);

    // Final clean
    var finalTask = cleanedTask.trim();
    if (finalTask.isEmpty) finalTask = rawText;
    // Capitalize first character
    if (finalTask.isNotEmpty) {
      finalTask = finalTask[0].toUpperCase() + finalTask.substring(1);
    }

    return MeetingActionItem(
      id: 'action_${DateTime.now().microsecondsSinceEpoch}_${finalTask.hashCode.abs()}',
      task: finalTask,
      assignee: detectedAssignee,
      dueDate: dueDate,
      isCompleted: false,
    );
  }

  (String task, DateTime dueDate) _extractDueDate(String text, DateTime baseDate) {
    DateTime calculatedDue = baseDate.add(const Duration(days: 7)); // default 1 week
    String cleaned = text;

    final tomorrowReg = RegExp(r'\b(?:by|before)?\s*tomorrow\b', caseSensitive: false);
    if (tomorrowReg.hasMatch(text)) {
      calculatedDue = baseDate.add(const Duration(days: 1));
      cleaned = cleaned.replaceAll(tomorrowReg, '');
      return (cleaned.trim(), calculatedDue);
    }

    final twoWeeksReg = RegExp(r'\b(?:within|in)\s*(?:2|two)\s*weeks?\b', caseSensitive: false);
    if (twoWeeksReg.hasMatch(text)) {
      calculatedDue = baseDate.add(const Duration(days: 14));
      cleaned = cleaned.replaceAll(twoWeeksReg, '');
      return (cleaned.trim(), calculatedDue);
    }

    final nextWeekReg = RegExp(r'\b(?:by|before)?\s*next\s*week\b', caseSensitive: false);
    if (nextWeekReg.hasMatch(text)) {
      calculatedDue = baseDate.add(const Duration(days: 7));
      cleaned = cleaned.replaceAll(nextWeekReg, '');
      return (cleaned.trim(), calculatedDue);
    }

    // Days of week: e.g. "by Friday", "before Sabbath", "by next Monday"
    final dayMap = {
      'monday': DateTime.monday,
      'tuesday': DateTime.tuesday,
      'wednesday': DateTime.wednesday,
      'thursday': DateTime.thursday,
      'friday': DateTime.friday,
      'saturday': DateTime.saturday,
      'sabbath': DateTime.saturday,
      'sunday': DateTime.sunday,
    };

    for (final entry in dayMap.entries) {
      final dayPattern = RegExp('\\b(?:by|before|on)?\\s*(?:next)?\\s*${entry.key}\\b', caseSensitive: false);
      if (dayPattern.hasMatch(text)) {
        int diff = entry.value - baseDate.weekday;
        if (diff <= 0) diff += 7;
        calculatedDue = baseDate.add(Duration(days: diff));
        cleaned = cleaned.replaceAll(dayPattern, '');
        return (cleaned.trim(), calculatedDue);
      }
    }

    return (cleaned.trim(), calculatedDue);
  }

  MeetingAttendee? _findAttendee(String nameQuery, List<MeetingAttendee> attendees) {
    final q = nameQuery.toLowerCase().trim();
    if (q.isEmpty) return null;
    for (final a in attendees) {
      if (a.name.toLowerCase() == q || a.name.toLowerCase().contains(q) || q.contains(a.name.toLowerCase())) {
        return a;
      }
    }
    return null;
  }

  bool _containsSimilar(List<String> list, String candidate) {
    final c = candidate.toLowerCase().trim();
    for (final item in list) {
      final it = item.toLowerCase().trim();
      if (it == c || it.contains(c) || c.contains(it)) return true;
    }
    return false;
  }

  bool _containsSimilarTask(List<MeetingActionItem> list, String task) {
    final t = task.toLowerCase().trim();
    for (final item in list) {
      final it = item.task.toLowerCase().trim();
      if (it == t || it.contains(t) || t.contains(it)) return true;
    }
    return false;
  }
}
