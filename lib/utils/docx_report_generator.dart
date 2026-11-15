import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:intl/intl.dart';

import '../models/board_models.dart';
import '../models/discipleship_models.dart';
import '../screens/discipleship/components/discipleship_officer_inbox.dart';

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

    // Title Banner
    body.writeln(_paragraph(
      'ALIVE NIGERIA EVANGELISM DEPARTMENT',
      bold: true,
      fontSizeHalfPt: 32,
      colorHex: '1B365D',
      spacingBefore: 0,
      spacingAfter: 60,
    ));
    body.writeln(_paragraph(
      'OFFICE REPORTS SUMMARY',
      bold: true,
      fontSizeHalfPt: 26,
      colorHex: '334155',
      spacingBefore: 0,
      spacingAfter: 200,
      bottomBorderColor: '1B365D',
    ));

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

      body.writeln(_paragraph(
        'REPORT #${i + 1}: $periodStart – $periodEnd  [$statusLabel]',
        bold: true,
        fontSizeHalfPt: 22,
        colorHex: '1B365D',
        shadingHex: 'E2E8F0',
        spacingBefore: 220,
        spacingAfter: 120,
      ));

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

    // Title Banner
    body.writeln(_paragraph(
      'ALIVE NIGERIA MINISTRY',
      bold: true,
      fontSizeHalfPt: 32,
      colorHex: '1B365D',
      spacingBefore: 0,
      spacingAfter: 60,
    ));
    body.writeln(_paragraph(
      'LEADERSHIP REPORTS SUMMARY',
      bold: true,
      fontSizeHalfPt: 26,
      colorHex: '334155',
      spacingBefore: 0,
      spacingAfter: 200,
      bottomBorderColor: '1B365D',
    ));

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
      final chapter = (meta['chapter'] ?? meta['chapter_name'] ?? '').toString().trim();
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
          ['Author', r.authorName.isEmpty ? 'Unknown' : r.authorName],
          ['Date', dateStr],
          ['Level / Category', '$level (${r.category})'],
          if (chapter.isNotEmpty) ['Chapter', chapter],
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

  static Uint8List _buildDocxArchive(String bodyXml) {
    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
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

    final encoded = ZipEncoder().encode(archive);
    return Uint8List.fromList(encoded);
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
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
  <Override PartName="/word/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.styles+xml"/>
</Types>''';

  static const String _rootRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static const String _documentRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"/>''';

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
