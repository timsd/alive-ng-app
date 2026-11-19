import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image/image.dart' as img;
import 'package:intl/intl.dart';

import '../models/board_models.dart';
import '../models/discipleship_models.dart';
import '../screens/discipleship/components/discipleship_officer_inbox.dart';

/// Structured row for the 4-column Attendance table in Official Minutes.
class MinutesAttendee {
  final String name;
  final String role;
  final String status; // e.g., 'Present', 'Absent', 'Excused'

  const MinutesAttendee({
    required this.name,
    required this.role,
    this.status = 'Present',
  });
}

/// Structured row for the 6-column Official Minutes & Action Matrix.
class MinutesAgendaRow {
  /// Leave empty (`''`) to vertically merge (`vMerge`) with the previous row's S/N & Agenda.
  final String sn;
  final String agenda;

  /// Chronological span from the transcript, e.g., "00:00 – 18:33" or "Audio 1 • 18:34"
  final String timestampRange;

  /// Used for strict chronological ordering from transcript timestamps.
  final int startSeconds;

  final String discussion;
  final String action;
  final String responsibility;
  final String deadline;

  const MinutesAgendaRow({
    this.sn = '',
    this.agenda = '',
    this.timestampRange = '',
    this.startSeconds = 0,
    required this.discussion,
    this.action = '',
    this.responsibility = '',
    this.deadline = '',
  });
}

/// Complete structured payload produced by ALIVE Scribe from a timestamped transcript.
class OfficialMeetingMinutesData {
  final String documentTitle; // e.g., 'ALIVE-NG NOVEMBER 2026 BOARD OF DIRECTORS MEETING'
  final String status; // e.g., 'Draft' or 'Final'
  final String date; // e.g., '16-11-2026'
  final String issuer;
  final String checker;
  final String approver;
  final String mode; // e.g., 'Zoom Conference call'
  final List<MinutesAttendee> attendance;
  final String startTime;
  final String openingPrayerAndRemark;
  final String devotionDetails;
  final List<String> agendaItems;
  final List<MinutesAgendaRow> minutesRows;
  final String closingRemarks;

  const OfficialMeetingMinutesData({
    required this.documentTitle,
    this.status = 'Draft',
    required this.date,
    this.issuer = '',
    this.checker = '',
    this.approver = '',
    this.mode = 'Zoom Conference call',
    this.attendance = const [],
    this.startTime = '',
    this.openingPrayerAndRemark = '',
    this.devotionDetails = '',
    this.agendaItems = const [],
    this.minutesRows = const [],
    this.closingRemarks = '',
  });

  factory OfficialMeetingMinutesData.fromJson(Map<String, dynamic> json) {
    final indexedRows = (json['minutes_rows'] as List<dynamic>? ?? [])
        .asMap()
        .entries
        .map((entry) => MapEntry(
              entry.key,
              Map<String, dynamic>.from(entry.value as Map),
            ))
        .toList();

    // Sort rows strictly by chronological transcript timestamp (`start_seconds`),
    // preserving original order when timestamps tie.
    indexedRows.sort((a, b) {
      final aSec = (a.value['start_seconds'] as num?)?.toInt() ?? 0;
      final bSec = (b.value['start_seconds'] as num?)?.toInt() ?? 0;
      final cmp = aSec.compareTo(bSec);
      return cmp != 0 ? cmp : a.key.compareTo(b.key);
    });

    final rawRows = indexedRows.map((entry) => entry.value).toList();

    return OfficialMeetingMinutesData(
      documentTitle: (json['document_title'] ??
              'ALIVE-NG BOARD OF DIRECTORS MEETING')
          .toString(),
      status: (json['status'] ?? 'Draft').toString(),
      date: (json['date'] ?? DateFormat('dd-MM-yyyy').format(DateTime.now()))
          .toString(),
      issuer: (json['issuer'] ?? '').toString(),
      checker: (json['checker'] ?? '').toString(),
      approver: (json['approver'] ?? '').toString(),
      mode: (json['mode'] ?? 'Zoom Conference call').toString(),
      attendance: (json['attendance'] as List<dynamic>? ?? [])
          .map((e) => MinutesAttendee(
                name: (e['name'] ?? '').toString(),
                role: (e['role'] ?? '').toString(),
                status: (e['status'] ?? 'Present').toString(),
              ))
          .toList(),
      startTime: (json['start_time'] ?? '').toString(),
      openingPrayerAndRemark:
          (json['opening_prayer_and_remark'] ?? '').toString(),
      devotionDetails: (json['devotion_details'] ?? '').toString(),
      agendaItems: (json['agenda_items'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      minutesRows: rawRows
          .map((e) => MinutesAgendaRow(
                sn: (e['sn'] ?? '').toString(),
                agenda: (e['agenda'] ?? '').toString(),
                timestampRange: (e['timestamp_range'] ?? '').toString(),
                startSeconds: (e['start_seconds'] as num?)?.toInt() ?? 0,
                discussion: (e['discussion'] ?? '').toString(),
                action: (e['action'] ?? '').toString(),
                responsibility: (e['responsibility'] ?? '').toString(),
                deadline: (e['deadline'] ?? '').toString(),
              ))
          .toList(),
      closingRemarks: (json['closing_remarks'] ?? '').toString(),
    );
  }
}

/// Resolved reporter / chapter / mission-field metadata attached to each
/// exported report so directors know exactly who sent it and from where.
class DocxSenderDetails {
  final String name;
  final String chapter;
  final String location;
  final String missionField;
  final String email;
  final String phone;

  const DocxSenderDetails({
    this.name = '',
    this.chapter = '',
    this.location = '',
    this.missionField = '',
    this.email = '',
    this.phone = '',
  });
}

/// Generates a formatted Microsoft Word (.docx) document for Discipleship
/// Officer Inbox reports using Office Open XML and `package:archive`.
class DocxReportGenerator {
  DocxReportGenerator._();

  static const String docxMimeType =
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document';

  static Uint8List generateDiscipleshipOfficeReport({
    required String officeTitle,
    required String officerName,
    required List<DiscipleshipReport> reports,
    Map<String, DocxSenderDetails> senderDetailsByUserId = const {},
    DateTime? generatedAt,
  }) {
    final now = generatedAt ?? DateTime.now();
    final generatedDate = DateFormat('MMMM dd, yyyy HH:mm').format(now);

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

    final body = StringBuffer();

    // Title Banner with ALIVE Logo at Top-Right
    body.writeln(_documentHeaderBanner(
      title: 'ALIVE NIGERIA EVANGELISM DEPARTMENT',
      subtitle: 'DISCIPLESHIP OFFICE REPORTS SUMMARY',
    ));
    body.writeln(_spacer(140));

    // Office Metadata Table
    body.writeln(_twoColumnTable(
      rows: [
        ['Holding Office', officeTitle],
        ['Officer In Charge', officerName],
        ['Generated Date', generatedDate],
        ['Total Reports Included', reports.length.toString()],
      ],
      labelShadeHex: 'F1F5F9',
    ));
    body.writeln(_spacer(180));

    // Executive Summary
    body.writeln(_sectionHeading('EXECUTIVE SUMMARY'));
    body.writeln(_twoColumnTable(
      headerLeft: 'Ministry Metric',
      headerRight: 'Total',
      rows: [
        ['Total Disciples', totalContacts.toString()],
        ['Active Disciples', totalActive.toString()],
        ['New Disciples', totalNew.toString()],
        ['Baptisms', totalBaptisms.toString()],
        ['Bible Study Sessions', totalStudies.toString()],
        ['Total Interactions', totalInteractions.toString()],
      ],
      labelShadeHex: 'F8FAFC',
    ));
    body.writeln(_spacer(220));

    // Detailed Breakdown
    body.writeln(_sectionHeading('DETAILED REPORTS BREAKDOWN'));

    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final periodStart = DateFormat.yMMMd().format(r.reportPeriodStart);
      final periodEnd = DateFormat.yMMMd().format(r.reportPeriodEnd);
      final statusLabel = r.status.toUpperCase();
      final sender = senderDetailsByUserId[r.discipleMakerId];
      final senderName = (sender != null && sender.name.trim().isNotEmpty)
          ? sender.name.trim()
          : r.discipleMakerId;
      final submittedDate = DateFormat('MMM d, yyyy HH:mm')
          .format((r.submittedAt ?? r.createdAt).toLocal());
      final contactParts = [
        if (sender != null && sender.email.trim().isNotEmpty) sender.email.trim(),
        if (sender != null && sender.phone.trim().isNotEmpty) sender.phone.trim(),
      ].join(' • ');

      body.writeln(_paragraph(
        'REPORT #${i + 1}: $senderName — $periodStart – $periodEnd  [$statusLabel]',
        bold: true,
        fontSizeHalfPt: 22,
        colorHex: '1B365D',
        shadingHex: 'E2E8F0',
        spacingBefore: 220,
        spacingAfter: 100,
      ));

      body.writeln(_twoColumnTable(
        rows: [
          ['Submitted By (Member)', senderName],
          if (sender != null && sender.chapter.trim().isNotEmpty)
            ['Chapter', sender.chapter.trim()],
          if (sender != null && sender.missionField.trim().isNotEmpty)
            ['Mission Field / Zone', sender.missionField.trim()],
          if (sender != null && sender.location.trim().isNotEmpty)
            ['Location / State', sender.location.trim()],
          if (contactParts.isNotEmpty) ['Member Contact', contactParts],
          ['Frequency & Submitted', '${r.frequency.name.toUpperCase()} • $submittedDate'],
          if (r.routedOfficeTitle != null && r.routedOfficeTitle!.trim().isNotEmpty)
            ['Routed Office', r.routedOfficeTitle!.trim()],
        ],
        labelShadeHex: 'F1F5F9',
      ));
      body.writeln(_spacer(80));

      body.writeln(_twoColumnTable(
        headerLeft: 'Metric',
        headerRight: 'Count',
        rows: [
          ['Total Disciples', r.totalContacts.toString()],
          ['Active Disciples', r.activeContacts.toString()],
          ['New Disciples', r.newContacts.toString()],
          ['Baptisms', r.baptisms.toString()],
          ['Study Sessions', r.studySessions.toString()],
          ['Interactions', r.interactions.toString()],
        ],
        labelShadeHex: 'F8FAFC',
      ));

      if (r.highlights != null && r.highlights!.trim().isNotEmpty) {
        body.writeln(_subHeading('Ministry Highlights'));
        body.writeln(_bodyText(r.highlights!.trim()));
      }
      if (r.challenges != null && r.challenges!.trim().isNotEmpty) {
        body.writeln(_subHeading('Challenges & Needs'));
        body.writeln(_bodyText(r.challenges!.trim()));
      }
      if (r.prayerRequests != null && r.prayerRequests!.trim().isNotEmpty) {
        body.writeln(_subHeading('Prayer Requests'));
        body.writeln(_bodyText(r.prayerRequests!.trim()));
      }
      if (r.goals != null && r.goals!.trim().isNotEmpty) {
        body.writeln(_subHeading('Next Goals'));
        body.writeln(_bodyText(r.goals!.trim()));
      }

      final thread = parseDiscipleshipFeedbackThread(
        r.feedback ?? '',
        officerName,
      );
      if (thread.isNotEmpty) {
        body.writeln(_subHeading(
          'Officer Feedback & Discussion (${thread.length} ${thread.length == 1 ? 'entry' : 'entries'})',
        ));
        for (final msg in thread) {
          final roleLabel =
              msg.isOfficer ? 'Officer Feedback' : 'Disciple Maker Response';
          final datePart = msg.date != null ? ' (${msg.date})' : '';
          body.writeln(_paragraph(
            '• [$roleLabel: ${msg.author}$datePart]',
            bold: true,
            fontSizeHalfPt: 19,
            colorHex: '334155',
            leftIndent: 240,
            spacingBefore: 60,
            spacingAfter: 30,
          ));
          body.writeln(_paragraph(
            msg.content.trim(),
            fontSizeHalfPt: 20,
            colorHex: '1E293B',
            leftIndent: 420,
            spacingBefore: 0,
            spacingAfter: 80,
          ));
        }
      }
    }

    body.writeln(_spacer(240));
    body.writeln(_paragraph(
      'ALIVE Nigeria Evangelism Department Report Management System • Confidential Office Record • Generated on $generatedDate',
      italic: true,
      fontSizeHalfPt: 18,
      colorHex: '64748B',
      topBorderColor: 'CBD5E1',
      spacingBefore: 160,
      spacingAfter: 0,
    ));

    return _buildDocxArchive(body.toString());
  }

  static Uint8List generateLeadershipReportsDocx({
    required String sectionTitle,
    required String exportedBy,
    required List<BoardReport> reports,
    Map<String, DocxSenderDetails> senderDetailsByUserId = const {},
    DateTime? generatedAt,
  }) {
    final now = generatedAt ?? DateTime.now();
    final generatedDate = DateFormat('MMMM dd, yyyy HH:mm').format(now);

    final statusCounts = <String, int>{};
    for (final r in reports) {
      final key = r.status.toUpperCase();
      statusCounts[key] = (statusCounts[key] ?? 0) + 1;
    }

    final body = StringBuffer();

    // Title Banner with ALIVE Logo at Top-Right
    body.writeln(_documentHeaderBanner(
      title: 'ALIVE NIGERIA MINISTRY',
      subtitle: 'LEADERSHIP REPORTS SUMMARY',
    ));
    body.writeln(_spacer(140));

    // Metadata Table
    body.writeln(_twoColumnTable(
      rows: [
        ['Section / Filter', sectionTitle],
        ['Exported By', exportedBy],
        ['Generated Date', generatedDate],
        ['Total Reports Included', reports.length.toString()],
      ],
      labelShadeHex: 'F1F5F9',
    ));
    body.writeln(_spacer(180));

    // Executive Summary
    body.writeln(_sectionHeading('EXECUTIVE SUMMARY'));
    body.writeln(_twoColumnTable(
      headerLeft: 'Status',
      headerRight: 'Count',
      rows: statusCounts.entries
          .map((e) => [e.key, e.value.toString()])
          .toList(),
      labelShadeHex: 'F8FAFC',
    ));
    body.writeln(_spacer(220));

    // Detailed Breakdown
    body.writeln(_sectionHeading('DETAILED REPORTS BREAKDOWN'));

    for (int i = 0; i < reports.length; i++) {
      final r = reports[i];
      final meta = r.metadata ?? const <String, dynamic>{};
      final level = (meta['hierarchy_level'] ?? meta['level'] ?? r.category)
          .toString()
          .toUpperCase();
      final sender = senderDetailsByUserId[r.authorId];
      final authorName = r.authorName.trim().isNotEmpty
          ? r.authorName.trim()
          : ((sender != null && sender.name.trim().isNotEmpty)
              ? sender.name.trim()
              : 'Unknown');
      final chapter = [
        (meta['chapter'] ?? meta['chapter_name'] ?? '').toString().trim(),
        sender?.chapter.trim() ?? '',
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final missionField = [
        (meta['mission_field'] ?? meta['zone'] ?? meta['region'] ?? '')
            .toString()
            .trim(),
        sender?.missionField.trim() ?? '',
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final location = [
        (meta['location'] ?? meta['state'] ?? meta['city'] ?? '')
            .toString()
            .trim(),
        sender?.location.trim() ?? '',
      ].firstWhere((v) => v.isNotEmpty, orElse: () => '');
      final contactParts = [
        if (sender != null && sender.email.trim().isNotEmpty) sender.email.trim(),
        if (sender != null && sender.phone.trim().isNotEmpty) sender.phone.trim(),
      ].join(' • ');
      final routedTo = (meta['routed_to_title'] ?? '').toString().trim();
      final dateStr = DateFormat('MMM d, yyyy').format(r.createdAt.toLocal());

      body.writeln(_paragraph(
        'REPORT #${i + 1}: ${r.title}  [${r.status.toUpperCase()}]',
        bold: true,
        fontSizeHalfPt: 22,
        colorHex: '1B365D',
        shadingHex: 'E2E8F0',
        spacingBefore: 220,
        spacingAfter: 120,
      ));

      body.writeln(_twoColumnTable(
        rows: [
          ['Submitted By (Member)', authorName],
          ['Date', dateStr],
          ['Level / Category', '$level (${r.category})'],
          if (chapter.isNotEmpty) ['Chapter', chapter],
          if (missionField.isNotEmpty) ['Mission Field / Zone', missionField],
          if (location.isNotEmpty) ['Location / State', location],
          if (contactParts.isNotEmpty) ['Member Contact', contactParts],
          if (routedTo.isNotEmpty) ['Routed To', routedTo],
        ],
        labelShadeHex: 'F8FAFC',
      ));

      if (r.description.trim().isNotEmpty) {
        body.writeln(_subHeading('Summary'));
        body.writeln(_bodyText(r.description.trim()));
      }
      if (r.content.trim().isNotEmpty) {
        body.writeln(_subHeading('Report Details'));
        body.writeln(_bodyText(r.content.trim()));
      }
      final feedback = (meta['review_feedback'] ?? '').toString().trim();
      if (feedback.isNotEmpty) {
        final reviewer =
            (meta['reviewed_by_name'] ?? 'Leadership Officer').toString();
        body.writeln(_subHeading('Leadership Review ($reviewer)'));
        body.writeln(_bodyText(feedback));
      }
    }

    body.writeln(_spacer(240));
    body.writeln(_paragraph(
      'ALIVE Nigeria Leadership Report Management System • Confidential Record • Generated on $generatedDate',
      italic: true,
      fontSizeHalfPt: 18,
      colorHex: '64748B',
      topBorderColor: 'CBD5E1',
      spacingBefore: 160,
      spacingAfter: 0,
    ));

    return _buildDocxArchive(body.toString());
  }

  static const String aliveLogoAssetPath = 'assets/images/alive_logo.svg';

  /// Loads `assets/images/alive_logo.svg` from Flutter assets and renders it to PNG bytes.
  /// Falls back to programmatic mosaic rendering if run outside a Flutter asset bundle.
  static Future<Uint8List> loadAliveLogoPngBytes({
    String assetPath = aliveLogoAssetPath,
    int maxDimensionPx = 200,
  }) async {
    try {
      final svgString = await rootBundle.loadString(assetPath);
      final pictureInfo =
          await vg.loadPicture(SvgStringLoader(svgString), null);

      final srcW = pictureInfo.size.width > 0 ? pictureInfo.size.width : 100.0;
      final srcH =
          pictureInfo.size.height > 0 ? pictureInfo.size.height : 100.0;
      final scale = maxDimensionPx / (srcW > srcH ? srcW : srcH);
      final outW = (srcW * scale).round().clamp(1, maxDimensionPx);
      final outH = (srcH * scale).round().clamp(1, maxDimensionPx);

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.scale(scale, scale);
      canvas.drawPicture(pictureInfo.picture);
      pictureInfo.picture.dispose();

      final image = await recorder.endRecording().toImage(outW, outH);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      if (byteData != null) {
        return byteData.buffer.asUint8List();
      }
    } catch (_) {
      // Fallback for pure-Dart unit tests without Flutter asset bundle
    }
    return _generateAliveLogoPngBytes();
  }

  /// Generates a formatted Word (`.docx`) document in the official ALIVE-NG
  /// Board of Directors Meeting Minutes format using timestamp-ordered data.
  static Future<Uint8List> generateOfficialMeetingMinutesDocx({
    required OfficialMeetingMinutesData data,
    String logoAssetPath = aliveLogoAssetPath,
  }) async {
    final logoBytes = await loadAliveLogoPngBytes(assetPath: logoAssetPath);
    final body = StringBuffer();

    // 1. Centered ALIVE Logo + Centered All-Caps Bold Title
    body.writeln(_centeredLogoAndTitle(
      title: data.documentTitle.toUpperCase(),
      logoWidthEmu: 762000, // ~60pt
      logoHeightEmu: 838200, // preserves natural vertical Africa emblem aspect ratio
    ));
    body.writeln(_spacer(120));

    // 2. 5-Column Document Control Table
    body.writeln(_styledGridTable(
      columnWidthsDxa: const [1500, 1800, 2260, 2260, 2260],
      headers: const ['Status', 'Date', 'Issuer', 'Checker', 'Approver'],
      rows: [
        [data.status, data.date, data.issuer, data.checker, data.approver],
      ],
    ));
    body.writeln(_spacer(160));

    // 3. INTRODUCTION & MODE
    body.writeln(_sectionHeading('INTRODUCTION'));
    body.writeln(_richParagraph('**MODE:** ${data.mode}', fontSizeHalfPt: 21));
    body.writeln(_spacer(80));

    // 4. 4-Column ATTENDANCE Table
    if (data.attendance.isNotEmpty) {
      body.writeln(_richParagraph(
        '**ATTENDANCE**',
        fontSizeHalfPt: 21,
        colorHex: '1B365D',
      ));
      body.writeln(_styledGridTable(
        columnWidthsDxa: const [800, 4380, 3100, 1800],
        headers: const ['S/N', 'Name', 'Role', 'Status'],
        rows: [
          for (int i = 0; i < data.attendance.length; i++)
            [
              '${i + 1}',
              data.attendance[i].name,
              data.attendance[i].role,
              data.attendance[i].status,
            ],
        ],
      ));
      body.writeln(_spacer(140));
    }

    // 5. OPENING DETAILS
    body.writeln(_richParagraph(
      '**OPENING DETAILS:**',
      fontSizeHalfPt: 21,
      colorHex: '1B365D',
    ));
    if (data.startTime.trim().isNotEmpty) {
      body.writeln(_richParagraph(
        '**Start time:** ${data.startTime.trim()}',
        fontSizeHalfPt: 20,
      ));
    }
    if (data.openingPrayerAndRemark.trim().isNotEmpty) {
      body.writeln(_richParagraph(
        '**Opening prayer and Remark:** ${data.openingPrayerAndRemark.trim()}',
        fontSizeHalfPt: 20,
      ));
    }
    if (data.devotionDetails.trim().isNotEmpty) {
      body.writeln(_richParagraph(
        data.devotionDetails.trim(),
        fontSizeHalfPt: 20,
      ));
    }
    body.writeln(_spacer(100));

    // 6. AGENDA LIST (Chronological Timestamp Order)
    if (data.agendaItems.isNotEmpty) {
      body.writeln(_sectionHeading('AGENDA'));
      for (final item in data.agendaItems) {
        body.writeln(_richParagraph(
          '• ${item.trim()}',
          fontSizeHalfPt: 20,
          colorHex: '1E293B',
          leftIndent: 240,
          spacingBefore: 20,
          spacingAfter: 30,
        ));
      }
      body.writeln(_spacer(140));
    }

    // 7. 6-Column Minutes & Action Matrix
    if (data.minutesRows.isNotEmpty) {
      body.writeln(_minutesActionMatrixTable(data.minutesRows));
      body.writeln(_spacer(160));
    }

    // 8. CLOSING
    body.writeln(_sectionHeading('CLOSING'));
    if (data.closingRemarks.trim().isNotEmpty) {
      body.writeln(_richParagraph(
        data.closingRemarks.trim(),
        fontSizeHalfPt: 20,
      ));
    }

    return _buildDocxArchive(body.toString(), customLogoBytes: logoBytes);
  }

  /// Backward-compatible wrapper: accepts either ALIVE Scribe JSON string
  /// (rendering the full official BoD format) or fallback markdown text.
  static Future<Uint8List> generateMeetingMinutesDocx({
    required String meetingTitle,
    required String meetingType,
    required String markdownContent,
    DateTime? generatedAt,
    String logoAssetPath = aliveLogoAssetPath,
  }) async {
    final trimmed = markdownContent.trim();
    if (trimmed.startsWith('{')) {
      try {
        final decoded = jsonDecode(trimmed) as Map<String, dynamic>;
        final data = OfficialMeetingMinutesData.fromJson(decoded);
        return await generateOfficialMeetingMinutesDocx(
          data: data,
          logoAssetPath: logoAssetPath,
        );
      } catch (_) {
        // Fall through to legacy markdown renderer if JSON parsing fails
      }
    }

    final logoBytes = await loadAliveLogoPngBytes(assetPath: logoAssetPath);
    final now = generatedAt ?? DateTime.now();
    final generatedDate = DateFormat('MMMM dd, yyyy HH:mm').format(now);
    final body = StringBuffer();

    body.writeln(_centeredLogoAndTitle(
      title: meetingTitle.trim().isNotEmpty
          ? meetingTitle.trim().toUpperCase()
          : 'ALIVE-NG MEETING MINUTES',
    ));
    body.writeln(_spacer(100));
    body.writeln(_twoColumnTable(
      rows: [
        ['Meeting Type', meetingType],
        ['Generated At', generatedDate],
      ],
    ));
    body.writeln(_spacer(120));

    for (final rawLine in markdownContent.split(RegExp(r'\r?\n'))) {
      final line = rawLine.trim();
      if (line.isEmpty) {
        body.writeln(_spacer(60));
        continue;
      }
      if (line.startsWith('# ')) {
        body.writeln(_sectionHeading(line.substring(2).replaceAll('**', '').trim()));
      } else if (line.startsWith('## ')) {
        body.writeln(_sectionHeading(line.substring(3).replaceAll('**', '').trim()));
      } else if (line.startsWith('### ')) {
        body.writeln(_subHeading(line.substring(4).replaceAll('**', '').trim()));
      } else if (line.startsWith('- ') || line.startsWith('* ')) {
        body.writeln(_richParagraph(
          '• ${line.substring(2).trim()}',
          fontSizeHalfPt: 20,
          colorHex: '1E293B',
          leftIndent: 240,
          spacingBefore: 20,
          spacingAfter: 40,
        ));
      } else if (line.startsWith('---')) {
        body.writeln(_spacer(80));
      } else {
        body.writeln(_richParagraph(line, fontSizeHalfPt: 20));
      }
    }

    return _buildDocxArchive(body.toString(), customLogoBytes: logoBytes);
  }

  static Uint8List _buildDocxArchive(
    String bodyXml, {
    Uint8List? customLogoBytes,
  }) {
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:wp="http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing" xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:pic="http://schemas.openxmlformats.org/drawingml/2006/picture">
  <w:body>
$bodyXml
    <w:sectPr>
      <w:pgSz w:w="12240" w:h="15840"/>
      <w:pgMar w:top="1080" w:right="1080" w:bottom="1080" w:left="1080" w:header="720" w:footer="720" w:gutter="0"/>
    </w:sectPr>
  </w:body>
</w:document>''';

    final archive = Archive();
    _addFile(archive, '[Content_Types].xml', _contentTypesXml);
    _addFile(archive, '_rels/.rels', _rootRelsXml);
    _addFile(archive, 'word/_rels/document.xml.rels', _documentRelsXml);
    _addFile(archive, 'word/styles.xml', _stylesXml);
    _addFile(archive, 'word/document.xml', documentXml);
    final logoBytes = customLogoBytes ?? _generateAliveLogoPngBytes();
    archive.addFile(
      ArchiveFile('word/media/alive_logo.png', logoBytes.length, logoBytes),
    );

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
  }

  static String _centeredLogoAndTitle({
    required String title,
    int logoWidthEmu = 762000,
    int logoHeightEmu = 838200,
  }) {
    return '''<w:p>
  <w:pPr><w:jc w:val="center"/><w:spacing w:before="0" w:after="100"/></w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$logoWidthEmu" cy="$logoHeightEmu"/>
        <wp:docPr id="1" name="ALIVE Logo"/>
        <wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="alive_logo.png"/>
                <pic:cNvPicPr/>
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="rId2"/>
                <a:stretch><a:fillRect/></a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm><a:off x="0" y="0"/><a:ext cx="$logoWidthEmu" cy="$logoHeightEmu"/></a:xfrm>
                <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
<w:p>
  <w:pPr>
    <w:jc w:val="center"/>
    <w:spacing w:before="40" w:after="140"/>
    <w:pBdr><w:bottom w:val="single" w:sz="12" w:space="8" w:color="1B365D"/></w:pBdr>
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
      <w:b/>
      <w:color w:val="1B365D"/>
      <w:sz w:val="28"/>
      <w:szCs w:val="28"/>
    </w:rPr>
    <w:t xml:space="preserve">${_xmlEscape(title)}</w:t>
  </w:r>
</w:p>''';
  }

  /// Parses `**bold**` markers into proper Word `<w:b/>` runs instead of stripping them.
  static String _richParagraph(
    String text, {
    int fontSizeHalfPt = 20,
    String colorHex = '0F172A',
    bool defaultBold = false,
    int leftIndent = 0,
    int spacingBefore = 30,
    int spacingAfter = 60,
  }) {
    final lines = text.split(RegExp(r'\r?\n'));
    return lines.map((line) {
      final runs = StringBuffer();
      final segments = line.split('**');
      for (int i = 0; i < segments.length; i++) {
        if (segments[i].isEmpty) continue;
        final isBold = defaultBold || (i % 2 == 1);
        runs.write('''<w:r>
  <w:rPr>
    <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
    ${isBold ? '<w:b/>' : ''}
    <w:color w:val="$colorHex"/>
    <w:sz w:val="$fontSizeHalfPt"/>
    <w:szCs w:val="$fontSizeHalfPt"/>
  </w:rPr>
  <w:t xml:space="preserve">${_xmlEscape(segments[i])}</w:t>
</w:r>''');
      }
      if (runs.isEmpty) {
        runs.write('<w:r><w:t xml:space="preserve"></w:t></w:r>');
      }
      final indXml = leftIndent > 0 ? '<w:ind w:left="$leftIndent"/>' : '';
      return '<w:p><w:pPr><w:spacing w:before="$spacingBefore" w:after="$spacingAfter"/>$indXml</w:pPr>$runs</w:p>';
    }).join('\n');
  }

  static String _styledGridTable({
    required List<int> columnWidthsDxa,
    required List<String> headers,
    required List<List<String>> rows,
    String headerShadeHex = '1B365D',
  }) {
    final totalW = columnWidthsDxa.fold<int>(0, (a, b) => a + b);
    final sb = StringBuffer();
    sb.writeln('''<w:tbl>
  <w:tblPr>
    <w:tblW w:w="$totalW" w:type="dxa"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:left w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:bottom w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:right w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
    </w:tblBorders>
  </w:tblPr>''');

    sb.writeln('  <w:tr><w:trPr><w:tblHeader/></w:trPr>');
    for (int c = 0; c < headers.length; c++) {
      sb.writeln('''    <w:tc>
      <w:tcPr>
        <w:tcW w:w="${columnWidthsDxa[c]}" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$headerShadeHex"/>
        <w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_richParagraph(headers[c], fontSizeHalfPt: 18, colorHex: 'FFFFFF', defaultBold: true, spacingBefore: 0, spacingAfter: 0)}
    </w:tc>''');
    }
    sb.writeln('  </w:tr>');

    for (int r = 0; r < rows.length; r++) {
      final shade = r.isEven ? 'FFFFFF' : 'F8FAFC';
      sb.writeln('  <w:tr>');
      for (int c = 0; c < headers.length; c++) {
        final val = c < rows[r].length ? rows[r][c] : '';
        sb.writeln('''    <w:tc>
      <w:tcPr>
        <w:tcW w:w="${columnWidthsDxa[c]}" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$shade"/>
        <w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="100" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="100" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_richParagraph(val, fontSizeHalfPt: 18, colorHex: '0F172A', spacingBefore: 0, spacingAfter: 0)}
    </w:tc>''');
      }
      sb.writeln('  </w:tr>');
    }
    sb.writeln('</w:tbl>');
    return sb.toString();
  }

  /// 6-column table: S/N (550) | AGENDA (1550) | DISCUSSION (3880) | ACTION (1800) | RESPONSIBILITY (1250) | DEADLINE (1050)
  static String _minutesActionMatrixTable(List<MinutesAgendaRow> rows) {
    const widths = [550, 1550, 3880, 1800, 1250, 1050];
    const headers = [
      'S/N',
      'AGENDA',
      'DISCUSSION',
      'ACTION',
      'RESPONSIBILITY',
      'DEADLINE',
    ];

    final sb = StringBuffer();
    sb.writeln('''<w:tbl>
  <w:tblPr>
    <w:tblW w:w="10080" w:type="dxa"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:left w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:bottom w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:right w:val="single" w:sz="6" w:space="0" w:color="94A3B8"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
    </w:tblBorders>
  </w:tblPr>''');

    sb.writeln('  <w:tr><w:trPr><w:tblHeader/></w:trPr>');
    for (int c = 0; c < headers.length; c++) {
      sb.writeln('''    <w:tc>
      <w:tcPr>
        <w:tcW w:w="${widths[c]}" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="1B365D"/>
        <w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="80" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_richParagraph(headers[c], fontSizeHalfPt: 17, colorHex: 'FFFFFF', defaultBold: true, spacingBefore: 0, spacingAfter: 0)}
    </w:tc>''');
    }
    sb.writeln('  </w:tr>');

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      final isNewAgenda =
          i == 0 || row.sn.trim().isNotEmpty || row.agenda.trim().isNotEmpty;
      final vMergeTag =
          isNewAgenda ? '<w:vMerge w:val="restart"/>' : '<w:vMerge/>';
      final trimmedAgenda = row.agenda.trim();
      final trimmedRange = row.timestampRange.trim();
      final agendaLabel = (isNewAgenda && trimmedRange.isNotEmpty)
          ? (trimmedAgenda.isNotEmpty
              ? '$trimmedAgenda\n[$trimmedRange]'
              : '[$trimmedRange]')
          : trimmedAgenda;

      sb.writeln('  <w:tr><w:trPr><w:cantSplit/></w:trPr>');
      sb.writeln('''    <w:tc>
      <w:tcPr>
        <w:tcW w:w="${widths[0]}" w:type="dxa"/>
        $vMergeTag
        <w:shd w:val="clear" w:color="auto" w:fill="F8FAFC"/>
        <w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="70" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="70" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_richParagraph(row.sn, fontSizeHalfPt: 18, defaultBold: true, spacingBefore: 0, spacingAfter: 0)}
    </w:tc>''');
      sb.writeln('''    <w:tc>
      <w:tcPr>
        <w:tcW w:w="${widths[1]}" w:type="dxa"/>
        $vMergeTag
        <w:shd w:val="clear" w:color="auto" w:fill="F8FAFC"/>
        <w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="80" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_richParagraph(agendaLabel, fontSizeHalfPt: 18, colorHex: '1B365D', defaultBold: true, spacingBefore: 0, spacingAfter: 0)}
    </w:tc>''');

      final trailing = [
        row.discussion,
        row.action,
        row.responsibility,
        row.deadline,
      ];
      for (int c = 0; c < trailing.length; c++) {
        sb.writeln('''    <w:tc>
      <w:tcPr>
        <w:tcW w:w="${widths[c + 2]}" w:type="dxa"/>
        <w:tcMar><w:top w:w="80" w:type="dxa"/><w:left w:w="80" w:type="dxa"/><w:bottom w:w="80" w:type="dxa"/><w:right w:w="80" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_richParagraph(trailing[c], fontSizeHalfPt: 18, spacingBefore: 20, spacingAfter: 40)}
    </w:tc>''');
      }
      sb.writeln('  </w:tr>');
    }

    sb.writeln('</w:tbl>');
    return sb.toString();
  }

  /// Renders a crisp transparent-background PNG of the ALIVE Africa mosaic
  /// emblem in brand green (#0F9A07) for the top-right DOCX header.
  static Uint8List _generateAliveLogoPngBytes() {
    const scale = 6;
    const width = 24 * scale;
    const height = 24 * scale;
    final canvas = img.Image(width: width, height: height, numChannels: 4);
    final green = img.ColorRgba8(0x0F, 0x9A, 0x07, 0xFF);

    const cells = <List<double>>[
      [7.575, 2.225], [8.875, 2.225], [10.175, 2.225], [11.475, 2.225],
      [6.275, 3.875], [7.575, 3.875], [8.875, 3.875], [10.175, 3.875], [11.475, 3.875], [12.775, 3.875], [14.075, 3.875],
      [4.975, 5.525], [6.275, 5.525], [7.575, 5.525], [8.875, 5.525], [10.175, 5.525], [11.475, 5.525], [12.775, 5.525], [14.075, 5.525], [15.375, 5.525],
      [4.975, 7.175], [6.275, 7.175], [7.575, 7.175], [8.875, 7.175], [10.175, 7.175], [11.475, 7.175], [12.775, 7.175], [14.075, 7.175], [15.375, 7.175],
      [4.975, 8.825], [6.275, 8.825], [7.575, 8.825], [8.875, 8.825], [10.175, 8.825], [11.475, 8.825], [12.775, 8.825], [15.375, 8.825], [16.675, 8.825],
      [8.875, 10.475], [10.175, 10.475], [11.475, 10.475], [16.675, 10.475], [17.975, 10.475],
      [11.475, 12.125], [12.775, 12.125], [15.375, 12.125], [16.675, 12.125],
      [11.475, 13.775], [12.775, 13.775], [15.375, 13.775],
      [11.475, 15.425], [12.775, 15.425], [15.375, 15.425],
      [11.475, 17.075], [12.775, 17.075], [14.075, 17.075], [15.375, 17.075], [17.975, 17.075],
      [11.475, 18.725], [12.775, 18.725], [14.075, 18.725], [15.375, 18.725], [17.975, 18.725],
      [12.775, 20.375], [14.075, 20.375],
    ];

    for (final c in cells) {
      final x1 = (c[0] * scale).round();
      final y1 = (c[1] * scale).round();
      final x2 = ((c[0] + 1.05) * scale).round();
      final y2 = ((c[1] + 1.4) * scale).round();
      img.fillRect(canvas, x1: x1, y1: y1, x2: x2, y2: y2, color: green);
    }
    return Uint8List.fromList(img.encodePng(canvas));
  }

  static String _documentHeaderBanner({
    required String title,
    required String subtitle,
  }) {
    const emuSize = 685800; // ~54pt square
    return '''<w:tbl>
  <w:tblPr>
    <w:tblW w:w="10080" w:type="dxa"/>
    <w:tblBorders>
      <w:top w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      <w:left w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      <w:bottom w:val="single" w:sz="12" w:space="0" w:color="1B365D"/>
      <w:right w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      <w:insideH w:val="none" w:sz="0" w:space="0" w:color="auto"/>
      <w:insideV w:val="none" w:sz="0" w:space="0" w:color="auto"/>
    </w:tblBorders>
  </w:tblPr>
  <w:tr>
    <w:tc>
      <w:tcPr><w:tcW w:w="8400" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
      ${_paragraph(title, bold: true, fontSizeHalfPt: 32, colorHex: '1B365D', spacingBefore: 0, spacingAfter: 40)}
      ${_paragraph(subtitle, bold: true, fontSizeHalfPt: 24, colorHex: '0F9A07', spacingBefore: 0, spacingAfter: 80)}
    </w:tc>
    <w:tc>
      <w:tcPr><w:tcW w:w="1680" w:type="dxa"/><w:vAlign w:val="center"/></w:tcPr>
      <w:p>
        <w:pPr><w:jc w:val="right"/><w:spacing w:before="0" w:after="60"/></w:pPr>
        <w:r>
          <w:drawing>
            <wp:inline distT="0" distB="0" distL="0" distR="0">
              <wp:extent cx="$emuSize" cy="$emuSize"/>
              <wp:docPr id="1" name="ALIVE Logo"/>
              <wp:cNvGraphicFramePr><a:graphicFrameLocks noChangeAspect="1"/></wp:cNvGraphicFramePr>
              <a:graphic>
                <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
                  <pic:pic>
                    <pic:nvPicPr>
                      <pic:cNvPr id="0" name="alive_logo.png"/>
                      <pic:cNvPicPr/>
                    </pic:nvPicPr>
                    <pic:blipFill>
                      <a:blip r:embed="rId2"/>
                      <a:stretch><a:fillRect/></a:stretch>
                    </pic:blipFill>
                    <pic:spPr>
                      <a:xfrm><a:off x="0" y="0"/><a:ext cx="$emuSize" cy="$emuSize"/></a:xfrm>
                      <a:prstGeom prst="rect"><a:avLst/></a:prstGeom>
                    </pic:spPr>
                  </pic:pic>
                </a:graphicData>
              </a:graphic>
            </wp:inline>
          </w:drawing>
        </w:r>
      </w:p>
    </w:tc>
  </w:tr>
</w:tbl>''';
  }

  static void _addFile(Archive archive, String name, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(name, bytes.length, bytes));
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }

  static String _sectionHeading(String text) {
    return _paragraph(
      text,
      bold: true,
      fontSizeHalfPt: 24,
      colorHex: '1B365D',
      spacingBefore: 160,
      spacingAfter: 100,
      bottomBorderColor: '94A3B8',
    );
  }

  static String _subHeading(String text) {
    return _paragraph(
      text,
      bold: true,
      fontSizeHalfPt: 20,
      colorHex: '0F172A',
      spacingBefore: 120,
      spacingAfter: 40,
    );
  }

  static String _bodyText(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    return lines
        .map((line) => _paragraph(
              line,
              fontSizeHalfPt: 20,
              colorHex: '1E293B',
              leftIndent: 200,
              spacingBefore: 0,
              spacingAfter: 60,
            ))
        .join('\n');
  }

  static String _spacer(int spacingAfter) {
    return '<w:p><w:pPr><w:spacing w:before="0" w:after="$spacingAfter"/></w:pPr></w:p>';
  }

  static String _paragraph(
    String text, {
    bool bold = false,
    bool italic = false,
    int fontSizeHalfPt = 21,
    String colorHex = '0F172A',
    String? shadingHex,
    String? bottomBorderColor,
    String? topBorderColor,
    int leftIndent = 0,
    int spacingBefore = 40,
    int spacingAfter = 80,
  }) {
    final pPr = StringBuffer();
    pPr.write('<w:spacing w:before="$spacingBefore" w:after="$spacingAfter"/>');
    if (leftIndent > 0) {
      pPr.write('<w:ind w:left="$leftIndent"/>');
    }
    if (shadingHex != null) {
      pPr.write('<w:shd w:val="clear" w:color="auto" w:fill="$shadingHex"/>');
    }
    if (bottomBorderColor != null || topBorderColor != null) {
      pPr.write('<w:pBdr>');
      if (topBorderColor != null) {
        pPr.write(
          '<w:top w:val="single" w:sz="6" w:space="6" w:color="$topBorderColor"/>',
        );
      }
      if (bottomBorderColor != null) {
        pPr.write(
          '<w:bottom w:val="single" w:sz="8" w:space="6" w:color="$bottomBorderColor"/>',
        );
      }
      pPr.write('</w:pBdr>');
    }

    final rPr = StringBuffer();
    rPr.write('<w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>');
    if (bold) rPr.write('<w:b/>');
    if (italic) rPr.write('<w:i/>');
    rPr.write('<w:color w:val="$colorHex"/>');
    rPr.write('<w:sz w:val="$fontSizeHalfPt"/>');
    rPr.write('<w:szCs w:val="$fontSizeHalfPt"/>');

    return '<w:p><w:pPr>$pPr</w:pPr><w:r><w:rPr>$rPr</w:rPr><w:t xml:space="preserve">${_xmlEscape(text)}</w:t></w:r></w:p>';
  }

  static String _twoColumnTable({
    String? headerLeft,
    String? headerRight,
    required List<List<String>> rows,
    String labelShadeHex = 'F8FAFC',
  }) {
    final sb = StringBuffer();
    sb.writeln('<w:tbl>');
    sb.writeln('''  <w:tblPr>
    <w:tblW w:w="10080" w:type="dxa"/>
    <w:tblBorders>
      <w:top w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
      <w:left w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
      <w:bottom w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
      <w:right w:val="single" w:sz="4" w:space="0" w:color="CBD5E1"/>
      <w:insideH w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
      <w:insideV w:val="single" w:sz="4" w:space="0" w:color="E2E8F0"/>
    </w:tblBorders>
  </w:tblPr>''');

    if (headerLeft != null && headerRight != null) {
      sb.writeln(_tableRow(
        headerLeft,
        headerRight,
        leftShadeHex: '1B365D',
        rightShadeHex: '1B365D',
        textColorHex: 'FFFFFF',
        boldLeft: true,
        boldRight: true,
      ));
    }

    for (final row in rows) {
      sb.writeln(_tableRow(
        row[0],
        row[1],
        leftShadeHex: labelShadeHex,
        rightShadeHex: 'FFFFFF',
        textColorHex: '0F172A',
        boldLeft: true,
        boldRight: false,
      ));
    }

    sb.writeln('</w:tbl>');
    return sb.toString();
  }

  static String _tableRow(
    String left,
    String right, {
    required String leftShadeHex,
    required String rightShadeHex,
    required String textColorHex,
    required bool boldLeft,
    required bool boldRight,
  }) {
    return '''  <w:tr>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="3600" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$leftShadeHex"/>
        <w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_paragraph(left, bold: boldLeft, fontSizeHalfPt: 20, colorHex: textColorHex, spacingBefore: 0, spacingAfter: 0)}
    </w:tc>
    <w:tc>
      <w:tcPr>
        <w:tcW w:w="6480" w:type="dxa"/>
        <w:shd w:val="clear" w:color="auto" w:fill="$rightShadeHex"/>
        <w:tcMar><w:top w:w="90" w:type="dxa"/><w:left w:w="140" w:type="dxa"/><w:bottom w:w="90" w:type="dxa"/><w:right w:w="140" w:type="dxa"/></w:tcMar>
      </w:tcPr>
      ${_paragraph(right, bold: boldRight, fontSizeHalfPt: 20, colorHex: textColorHex, spacingBefore: 0, spacingAfter: 0)}
    </w:tc>
  </w:tr>''';
  }

  static const String _contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Default Extension="png" ContentType="image/png"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const String _rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const String _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/image" Target="media/alive_logo.png"/>
</Relationships>''';

  static const String _stylesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:styles xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:docDefaults>
    <w:rPrDefault>
      <w:rPr>
        <w:rFonts w:ascii="Calibri" w:hAnsi="Calibri"/>
        <w:sz w:val="21"/>
        <w:szCs w:val="21"/>
      </w:rPr>
    </w:rPrDefault>
  </w:docDefaults>
</w:styles>''';
}
