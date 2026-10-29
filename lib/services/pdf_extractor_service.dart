import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';

/// Structured result containing WordPress-style organized tract content.
class ExtractedTractArticle {
  final String title;
  final String fullFormattedBody;
  final List<String> sections;
  final List<String> headings;
  final int totalWordCount;

  const ExtractedTractArticle({
    required this.title,
    required this.fullFormattedBody,
    required this.sections,
    required this.headings,
    required this.totalWordCount,
  });
}

/// Service responsible for extracting and structuring tract and lesson text from files (PDF, TXT)
/// locally without needing external APIs. Organizes raw PDF text into clean WordPress-style article layout.
class PdfExtractorService {
  
  /// Extracts raw text from the provided file bytes.
  /// Recognizes PDF and TXT formats based on the file extension.
  Future<String> extractTextFromBytes(Uint8List bytes, String fileName) async {
    final extension = fileName.split('.').last.toLowerCase();
    
    try {
      if (extension == 'pdf') {
        return await _extractFromPdf(bytes);
      } else if (extension == 'txt') {
        return _extractFromTxt(bytes);
      } else {
        throw Exception('Unsupported file format: .$extension. Please upload a PDF or TXT file.');
      }
    } catch (e) {
      debugPrint('Error extracting text: $e');
      throw Exception('Failed to parse document. Ensure the file is valid and readable.');
    }
  }

  /// Extracts and formats text into a structured, readable WordPress-style article
  /// with distinct headings, flowing paragraphs, and clean typography.
  Future<ExtractedTractArticle> extractAndFormatArticle(
    Uint8List bytes,
    String fileName, {
    String? fallbackTitle,
  }) async {
    final rawText = await extractTextFromBytes(bytes, fileName);
    return structureAsWordPressContent(
      rawText,
      fallbackTitle: fallbackTitle ?? fileName.replaceAll(RegExp(r'\.[^.]+$'), ''),
    );
  }

  /// Transforms raw unformatted PDF string into clean, publication-ready WordPress content
  ExtractedTractArticle structureAsWordPressContent(String rawText, {String? fallbackTitle}) {
    if (rawText.trim().isEmpty) {
      return ExtractedTractArticle(
        title: fallbackTitle ?? 'Untitled Tract',
        fullFormattedBody: '',
        sections: [],
        headings: [],
        totalWordCount: 0,
      );
    }

    // 1. Normalize line endings and fix broken PDF hyphenated line-wraps
    var text = rawText.replaceAll(RegExp(r'\r\n?'), '\n');
    text = text.replaceAll(RegExp(r'(\w+)-\n(\w+)'), r'$1$2');

    final rawLines = text.split('\n');
    final cleanedParagraphs = <String>[];
    final headings = <String>[];
    String? detectedTitle = fallbackTitle;

    StringBuffer currentParagraph = StringBuffer();

    for (int i = 0; i < rawLines.length; i++) {
      final line = rawLines[i].trim();
      if (line.isEmpty) {
        if (currentParagraph.isNotEmpty) {
          cleanedParagraphs.add(currentParagraph.toString().trim());
          currentParagraph = StringBuffer();
        }
        continue;
      }

      // Check if line is a potential heading (short, all-caps, or starts with Chapter/Section/Number)
      final isShort = line.length < 65;
      final isAllUpper = line.length > 3 && line == line.toUpperCase() && RegExp(r'[A-Z]').hasMatch(line);
      final isHeaderPrefix = RegExp(r'^(Chapter|Section|Part|Lesson|\d+\.)\s+', caseSensitive: false).hasMatch(line);

      if (isShort && (isAllUpper || isHeaderPrefix)) {
        if (currentParagraph.isNotEmpty) {
          cleanedParagraphs.add(currentParagraph.toString().trim());
          currentParagraph = StringBuffer();
        }
        if (detectedTitle == null || (detectedTitle == fallbackTitle && i < 3)) {
          detectedTitle = _capitalizeWords(line);
        }
        final formattedHeading = '## ${_capitalizeWords(line)}';
        cleanedParagraphs.add(formattedHeading);
        headings.add(line);
      } else {
        if (currentParagraph.isNotEmpty) {
          currentParagraph.write(' ');
        }
        currentParagraph.write(line);
      }
    }

    if (currentParagraph.isNotEmpty) {
      cleanedParagraphs.add(currentParagraph.toString().trim());
    }

    // Split into readable multi-page sections (around 1800 characters per section)
    final sections = <String>[];
    StringBuffer sectionBuffer = StringBuffer();

    for (final p in cleanedParagraphs) {
      if (sectionBuffer.length + p.length > 1800 && sectionBuffer.isNotEmpty) {
        sections.add(sectionBuffer.toString().trim());
        sectionBuffer = StringBuffer();
      }
      if (sectionBuffer.isNotEmpty) {
        sectionBuffer.write('\n\n');
      }
      sectionBuffer.write(p);
    }
    if (sectionBuffer.isNotEmpty) {
      sections.add(sectionBuffer.toString().trim());
    }

    final fullBody = cleanedParagraphs.join('\n\n');
    final wordCount = fullBody.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

    return ExtractedTractArticle(
      title: detectedTitle ?? fallbackTitle ?? 'Gospel Tract',
      fullFormattedBody: fullBody,
      sections: sections,
      headings: headings,
      totalWordCount: wordCount,
    );
  }

  static String _capitalizeWords(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Parses a PDF file using syncfusion_flutter_pdf
  Future<String> _extractFromPdf(Uint8List bytes) async {
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    final String text = extractor.extractText();
    document.dispose();
    return text.trim();
  }

  /// Parses a plain text file natively
  String _extractFromTxt(Uint8List bytes) {
    return utf8.decode(bytes).trim();
  }
}
