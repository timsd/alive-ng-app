import 'dart:typed_data';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter/foundation.dart';

/// Service responsible for extracting text from files (PDF, TXT) locally
/// without needing to upload them to a server. This powers the Zero-Code CMS.
class PdfExtractorService {
  
  /// Extracts text from the provided file bytes.
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

  /// Parses a PDF file using syncfusion_flutter_pdf
  Future<String> _extractFromPdf(Uint8List bytes) async {
    // Load the PDF document
    final PdfDocument document = PdfDocument(inputBytes: bytes);
    
    // Create an instance of PdfTextExtractor
    final PdfTextExtractor extractor = PdfTextExtractor(document);
    
    // Extract everything
    final String text = extractor.extractText();
    
    // Dispose the document
    document.dispose();
    
    return text.trim();
  }

  /// Parses a plain text file natively
  String _extractFromTxt(Uint8List bytes) {
    return utf8.decode(bytes).trim();
  }
}
