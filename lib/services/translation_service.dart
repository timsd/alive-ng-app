import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/app_exception.dart';
import '../utils/logger.dart';

/// Service for handling automatic translation of content
class TranslationService {
  static const String _baseUrl = 'https://api.mymemory.translated.net/get';
  static final Logger _logger = Logger('TranslationService');

  /// Translate text from one language to another
  /// Uses MyMemory Translation API (free tier)
  static Future<String?> translateText(
      String text, String fromLanguage, String toLanguage) async {
    if (text.isEmpty || fromLanguage == toLanguage) {
      return text;
    }

    try {
      final encodedText = Uri.encodeComponent(text);
      final url = '$_baseUrl?q=$encodedText&langpair=$fromLanguage|$toLanguage';

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['responseStatus'] == 200) {
          return data['responseData']['translatedText'];
        }
      }

      throw NetworkException('Translation failed: ${response.statusCode}');
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('Translation error', e);
      throw NetworkException('Failed to translate text', originalError: e);
    }
  }

  /// Translate HTML content while preserving HTML tags
  static Future<String?> translateHtmlContent(
      String htmlContent, String fromLanguage, String toLanguage) async {
    if (htmlContent.isEmpty || fromLanguage == toLanguage) {
      return htmlContent;
    }

    try {
      // Extract text content from HTML while preserving structure
      final textParts = _extractTextFromHtml(htmlContent);
      final translatedParts = <String>[];

      for (final textPart in textParts) {
        if (textPart.trim().isNotEmpty) {
          final translated =
              await translateText(textPart, fromLanguage, toLanguage);
          translatedParts.add(translated ?? textPart);
        } else {
          translatedParts.add(textPart);
        }
      }

      // Reconstruct HTML with translated text
      return _reconstructHtml(htmlContent, textParts, translatedParts);
    } catch (e) {
      if (e is AppException) rethrow;
      _logger.error('HTML translation error', e);
      throw NetworkException('Failed to translate HTML content',
          originalError: e);
    }
  }

  /// Extract text content from HTML
  static List<String> _extractTextFromHtml(String html) {
    final textParts = <String>[];
    final regex = RegExp(r'>([^<]+)<');
    final matches = regex.allMatches(html);

    for (final match in matches) {
      final text = match.group(1);
      if (text != null && text.trim().isNotEmpty) {
        textParts.add(text);
      }
    }

    return textParts;
  }

  /// Reconstruct HTML with translated text
  static String _reconstructHtml(String originalHtml,
      List<String> originalTexts, List<String> translatedTexts) {
    String result = originalHtml;

    for (int i = 0;
        i < originalTexts.length && i < translatedTexts.length;
        i++) {
      result = result.replaceFirst(originalTexts[i], translatedTexts[i]);
    }

    return result;
  }

  /// Get language code mapping for translation API
  static String _getApiLanguageCode(String appLanguageCode) {
    switch (appLanguageCode) {
      case 'yo':
        return 'yo'; // Yoruba
      case 'ig':
        return 'ig'; // Igbo
      case 'ha':
        return 'ha'; // Hausa
      case 'en':
      default:
        return 'en'; // English
    }
  }

  /// Translate content with proper language code mapping
  static Future<String?> translateContentForApp(
      String content, String targetLanguageCode,
      {String sourceLanguageCode = 'en'}) async {
    final fromLang = _getApiLanguageCode(sourceLanguageCode);
    final toLang = _getApiLanguageCode(targetLanguageCode);

    // Check if content contains HTML
    if (content.contains('<') && content.contains('>')) {
      return await translateHtmlContent(content, fromLang, toLang);
    } else {
      return await translateText(content, fromLang, toLang);
    }
  }

  /// Cache translated content to avoid repeated API calls
  static final Map<String, Map<String, String>> _translationCache = {};

  static Future<String?> translateWithCache(
      String content, String targetLanguageCode,
      {String sourceLanguageCode = 'en'}) async {
    final cacheKey = '$sourceLanguageCode-$targetLanguageCode';
    final contentHash = content.hashCode.toString();

    // Check cache first
    if (_translationCache[cacheKey]?.containsKey(contentHash) == true) {
      return _translationCache[cacheKey]![contentHash];
    }

    // Translate and cache
    final translated = await translateContentForApp(content, targetLanguageCode,
        sourceLanguageCode: sourceLanguageCode);

    if (translated != null) {
      _translationCache[cacheKey] ??= {};
      _translationCache[cacheKey]![contentHash] = translated;
    }

    return translated;
  }
}
