import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Uploads Bible content JSON into Appwrite.
///
/// Required environment values can come from the shell or local `.env`:
/// - APPWRITE_ENDPOINT
/// - APPWRITE_PROJECT_ID
/// - APPWRITE_DATABASE_ID
/// - APPWRITE_API_KEY
///
/// Usage:
///   dart scripts/upload_bible_content.dart upload_book data/genesis.json en
///   dart scripts/upload_bible_content.dart upload_chapter data/john_3.json en KJV
///   dart scripts/upload_bible_content.dart upload_json data/bible.json

Future<void> main(List<String> arguments) async {
  final env = await _loadEnvironment();
  final client = _AppwriteRestClient(
    endpoint: env.value('APPWRITE_ENDPOINT'),
    projectId: env.value('APPWRITE_PROJECT_ID'),
    databaseId: env.value('APPWRITE_DATABASE_ID'),
    apiKey: env.value('APPWRITE_API_KEY'),
  );

  if (arguments.isEmpty) {
    printUsage();
    return;
  }

  final command = arguments[0];

  switch (command) {
    case 'upload_book':
      if (arguments.length < 3) {
        stderr.writeln('Error: Missing required arguments for upload_book');
        printUsage();
        return;
      }
      await _uploadBookFromJson(client, arguments[1], arguments[2]);
      break;

    case 'upload_chapter':
      if (arguments.length < 3) {
        stderr.writeln('Error: Missing required arguments for upload_chapter');
        printUsage();
        return;
      }
      final version = arguments.length > 3 ? arguments[3] : 'KJV';
      await _uploadChapterFromJson(client, arguments[1], arguments[2], version);
      break;

    case 'upload_json':
      if (arguments.length < 2) {
        stderr.writeln('Error: Missing required arguments for upload_json');
        printUsage();
        return;
      }
      await _uploadFromJson(client, arguments[1]);
      break;

    default:
      stderr.writeln('Unknown command: $command');
      printUsage();
  }

  client.close();
}

void printUsage() {
  stdout.writeln('''
Usage: dart scripts/upload_bible_content.dart [command] [options]

Commands:
  upload_book [json_file_path] [language]
    Upload a Bible book from a JSON file

  upload_chapter [json_file_path] [language] [version=KJV]
    Upload a Bible chapter from a JSON file

  upload_json [json_file_path]
    Upload Bible content from a structured JSON file
''');
}

Future<void> _uploadBookFromJson(
  _AppwriteRestClient client,
  String jsonPath,
  String language,
) async {
  final bookData = await _readJsonObject(jsonPath);
  await _uploadBook(client, bookData, language);
}

Future<void> _uploadChapterFromJson(
  _AppwriteRestClient client,
  String jsonPath,
  String language,
  String version,
) async {
  final chapterData = await _readJsonObject(jsonPath);
  await _uploadChapter(client, chapterData, language, version);
}

Future<void> _uploadFromJson(_AppwriteRestClient client, String jsonPath) async {
  final data = await _readJsonObject(jsonPath);

  if (data.containsKey('books')) {
    final language = data['language']?.toString() ?? 'en';
    for (final item in data['books'] as List<dynamic>) {
      await _uploadBook(client, Map<String, dynamic>.from(item as Map), language);
    }
  }

  if (data.containsKey('chapters')) {
    final language = data['language']?.toString() ?? 'en';
    final version = data['version']?.toString() ?? 'KJV';
    for (final item in data['chapters'] as List<dynamic>) {
      await _uploadChapter(
        client,
        Map<String, dynamic>.from(item as Map),
        language,
        version,
      );
    }
  }

  stdout.writeln('Upload completed successfully');
}

Future<void> _uploadBook(
  _AppwriteRestClient client,
  Map<String, dynamic> bookData,
  String language,
) async {
  final name = bookData['name']?.toString();
  if (name == null || name.trim().isEmpty) {
    throw const FormatException('Book JSON is missing "name"');
  }

  final abbreviation =
      bookData['abbreviation']?.toString() ?? name.substring(0, 3);
  final version = bookData['version']?.toString() ?? 'KJV';
  final id = _stableId('bb', '$language:$version:$name');

  await client.upsertDocument(
    collectionId: 'bible_books',
    documentId: id,
    data: _withoutNulls({
      'name': name,
      'abbreviation': abbreviation,
      'chapters': _asInt(bookData['chapters']),
      'testament': bookData['testament']?.toString(),
      'language': language,
      'version': version,
      'order': _asInt(bookData['order']),
      'translations': bookData['translations'] == null
          ? null
          : jsonEncode(bookData['translations']),
    }),
  );

  stdout.writeln('Uploaded book: $name [$language/$version]');
}

Future<void> _uploadChapter(
  _AppwriteRestClient client,
  Map<String, dynamic> chapterData,
  String language,
  String version,
) async {
  final book = chapterData['book']?.toString();
  final chapter = _asInt(chapterData['chapter']);
  if (book == null || book.trim().isEmpty || chapter == null) {
    throw const FormatException(
      'Chapter JSON must include "book" and "chapter"',
    );
  }

  final verses = (chapterData['verses'] as List<dynamic>? ?? [])
      .map((item) => Map<String, dynamic>.from(item as Map))
      .toList();
  final chapterId = _stableId('bc', '$language:$version:$book:$chapter');
  final now = DateTime.now().toIso8601String();

  await client.upsertDocument(
    collectionId: 'bible_chapters',
    documentId: chapterId,
    data: _withoutNulls({
      'book_id': _stableId('bb', '$language:$version:$book'),
      'book': book,
      'chapter': chapter,
      'language': language,
      'version': version,
      'content': jsonEncode({
        'metadata': chapterData['metadata'],
        'lastUpdated': now,
        'verses': verses,
      }),
    }),
  );

  for (final verseData in verses) {
    final verseNumber = _asInt(verseData['verse'] ?? verseData['number']);
    final text = verseData['text']?.toString();
    if (verseNumber == null || text == null || text.trim().isEmpty) continue;

    await client.upsertDocument(
      collectionId: 'bible_verses',
      documentId:
          _stableId('bv', '$language:$version:$book:$chapter:$verseNumber'),
      data: {
        'book': book,
        'chapter': chapter,
        'verse': verseNumber,
        'text': text,
        'language': language,
        'version': version,
        'reference': '$book $chapter:$verseNumber',
      },
    );
  }

  stdout.writeln('Uploaded chapter: $book $chapter [$language/$version]');
}

Future<Map<String, dynamic>> _readJsonObject(String path) async {
  final file = File(path);
  if (!await file.exists()) {
    throw FileSystemException('File not found', path);
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map) {
    throw FormatException('Expected JSON object in $path');
  }
  return Map<String, dynamic>.from(decoded);
}

Map<String, dynamic> _withoutNulls(Map<String, dynamic> data) {
  return Map.fromEntries(data.entries.where((entry) => entry.value != null));
}

int? _asInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

String _stableId(String prefix, String seed) {
  final digest = md5.convert(utf8.encode(seed.toLowerCase())).toString();
  return '${prefix}_$digest'.substring(0, 35);
}

Future<_Environment> _loadEnvironment() async {
  final values = <String, String>{...Platform.environment};
  final file = File('.env');
  if (await file.exists()) {
    for (final raw in await file.readAsLines()) {
      final line = raw.trim();
      if (line.isEmpty || line.startsWith('#') || !line.contains('=')) continue;
      final separator = line.indexOf('=');
      final key = line.substring(0, separator).trim();
      final value = line.substring(separator + 1).trim();
      values.putIfAbsent(key, () => _stripWrappingQuotes(value));
    }
  }
  return _Environment(values);
}

String _stripWrappingQuotes(String value) {
  if (value.length < 2) return value;
  final first = value[0];
  final last = value[value.length - 1];
  if ((first == '"' && last == '"') || (first == "'" && last == "'")) {
    return value.substring(1, value.length - 1);
  }
  return value;
}

class _Environment {
  const _Environment(this._values);

  final Map<String, String> _values;

  String value(String key) {
    final value = _values[key];
    if (value == null || value.isEmpty) {
      throw StateError('Missing required environment variable: $key');
    }
    return value;
  }
}

class _AppwriteRestClient {
  _AppwriteRestClient({
    required String endpoint,
    required this.projectId,
    required this.databaseId,
    required this.apiKey,
  })  : endpoint = endpoint.replaceFirst(RegExp(r'/$'), ''),
        _client = HttpClient();

  final String endpoint;
  final String projectId;
  final String databaseId;
  final String apiKey;
  final HttpClient _client;

  Future<void> upsertDocument({
    required String collectionId,
    required String documentId,
    required Map<String, dynamic> data,
  }) async {
    final created = await _send(
      'POST',
      '/databases/$databaseId/collections/$collectionId/documents',
      {
        'documentId': documentId,
        'data': data,
      },
      allowConflict: true,
    );
    if (created == 409) {
      await _send(
        'PATCH',
        '/databases/$databaseId/collections/$collectionId/documents/$documentId',
        {'data': data},
      );
    }
  }

  Future<int> _send(
    String method,
    String path,
    Map<String, dynamic> body, {
    bool allowConflict = false,
  }) async {
    final request = await _client.openUrl(method, Uri.parse('$endpoint$path'));
    request.headers
      ..contentType = ContentType.json
      ..set('X-Appwrite-Project', projectId)
      ..set('X-Appwrite-Key', apiKey);
    request.write(jsonEncode(body));

    final response = await request.close();
    final text = await response.transform(utf8.decoder).join();
    if (allowConflict && response.statusCode == 409) return 409;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Appwrite request failed (${response.statusCode}): $text',
        uri: Uri.parse('$endpoint$path'),
      );
    }
    return response.statusCode;
  }

  void close() {
    _client.close(force: true);
  }
}
