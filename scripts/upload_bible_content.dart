import 'dart:convert';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:alive_flutter_app/services/firebase_database_service.dart';
import 'package:alive_flutter_app/models/bible_models.dart';

/// This script helps upload Bible content to Firebase
/// It can be used to populate the database with Bible books, chapters, and verses
///
/// Usage: dart upload_bible_content.dart [command] [options]
/// Commands:
///   - upload_book: Upload a Bible book
///   - upload_chapter: Upload a Bible chapter
///   - upload_json: Upload Bible content from a JSON file

void main(List<String> arguments) async {
  // Initialize Firebase
  await Firebase.initializeApp();

  if (arguments.isEmpty) {
    printUsage();
    return;
  }

  final command = arguments[0];
  final service = FirebaseDatabaseService.instance;

  switch (command) {
    case 'upload_book':
      if (arguments.length < 3) {
        stderr.writeln('Error: Missing required arguments for upload_book');
        printUsage();
        return;
      }
      final jsonPath = arguments[1];
      final language = arguments[2];
      await uploadBookFromJson(service, jsonPath, language);
      break;

    case 'upload_chapter':
      if (arguments.length < 3) {
        stderr.writeln('Error: Missing required arguments for upload_chapter');
        printUsage();
        return;
      }
      final jsonPath = arguments[1];
      final language = arguments[2];
      final version = arguments.length > 3 ? arguments[3] : 'KJV';
      await uploadChapterFromJson(service, jsonPath, language, version);
      break;

    case 'upload_json':
      if (arguments.length < 2) {
        stderr.writeln('Error: Missing required arguments for upload_json');
        printUsage();
        return;
      }
      final jsonPath = arguments[1];
      await uploadFromJson(service, jsonPath);
      break;

    default:
      stderr.writeln('Unknown command: $command');
      printUsage();
  }
}

void printUsage() {
  stdout.writeln('''
Usage: dart upload_bible_content.dart [command] [options]

Commands:
  upload_book [json_file_path] [language]
    Upload a Bible book from a JSON file
    
  upload_chapter [json_file_path] [language] [version=KJV]
    Upload a Bible chapter from a JSON file
    
  upload_json [json_file_path]
    Upload Bible content from a structured JSON file
''');
}

Future<void> uploadBookFromJson(
    FirebaseDatabaseService service, String jsonPath, String language) async {
  try {
    final file = File(jsonPath);
    if (!await file.exists()) {
      stderr.writeln('Error: File not found: $jsonPath');
      return;
    }

    final jsonContent = await file.readAsString();
    final Map<String, dynamic> bookData = json.decode(jsonContent);

    final book = BibleBook(
      name: bookData['name'],
      abbreviation:
          bookData['abbreviation'] ?? bookData['name'].substring(0, 3),
      chapters: bookData['chapters'],
      testament: bookData['testament'],
      order: bookData['order'],
      translations: bookData['translations'] != null
          ? Map<String, String>.from(bookData['translations'])
          : null,
    );

    await service.addBibleBook(book, language);
    stdout.writeln('Successfully uploaded book: ${book.name}');
  } catch (e) {
    stderr.writeln('Error uploading book: $e');
  }
}

Future<void> uploadChapterFromJson(FirebaseDatabaseService service,
    String jsonPath, String language, String version) async {
  try {
    final file = File(jsonPath);
    if (!await file.exists()) {
      stderr.writeln('Error: File not found: $jsonPath');
      return;
    }

    final jsonContent = await file.readAsString();
    final Map<String, dynamic> chapterData = json.decode(jsonContent);

    final verses = (chapterData['verses'] as List<dynamic>)
        .map((v) => BibleVerse(
              number: v['verse'],
              text: v['text'],
              footnotes: v['footnotes'] != null
                  ? Map<String, String>.from(v['footnotes'])
                  : null,
              crossReferences: v['crossReferences'] != null
                  ? List<String>.from(v['crossReferences'])
                  : null,
            ))
        .toList();

    final chapter = BibleChapter(
      book: chapterData['book'],
      chapter: chapterData['chapter'],
      version: version,
      language: language,
      verses: verses,
      metadata: chapterData['metadata'],
      lastUpdated: DateTime.now(),
    );

    await service.addBibleChapter(chapter);
    stdout.writeln(
        'Successfully uploaded chapter: ${chapter.book} ${chapter.chapter}');
  } catch (e) {
    stderr.writeln('Error uploading chapter: $e');
  }
}

Future<void> uploadFromJson(
    FirebaseDatabaseService service, String jsonPath) async {
  try {
    final file = File(jsonPath);
    if (!await file.exists()) {
      stderr.writeln('Error: File not found: $jsonPath');
      return;
    }

    final jsonContent = await file.readAsString();
    final Map<String, dynamic> data = json.decode(jsonContent);

    // Check if the JSON contains books
    if (data.containsKey('books')) {
      final language = data['language'] ?? 'en';
      final books = data['books'] as List<dynamic>;

      for (final bookData in books) {
        final book = BibleBook(
          name: bookData['name'],
          abbreviation:
              bookData['abbreviation'] ?? bookData['name'].substring(0, 3),
          chapters: bookData['chapters'],
          testament: bookData['testament'],
          order: bookData['order'],
          translations: bookData['translations'] != null
              ? Map<String, String>.from(bookData['translations'])
              : null,
        );

        await service.addBibleBook(book, language);
        stdout.writeln('Successfully uploaded book: ${book.name}');
      }
    }

    // Check if the JSON contains chapters
    if (data.containsKey('chapters')) {
      final language = data['language'] ?? 'en';
      final version = data['version'] ?? 'KJV';
      final chapters = data['chapters'] as List<dynamic>;

      for (final chapterData in chapters) {
        final verses = (chapterData['verses'] as List<dynamic>)
            .map((v) => BibleVerse(
                  number: v['verse'],
                  text: v['text'],
                  footnotes: v['footnotes'] != null
                      ? Map<String, String>.from(v['footnotes'])
                      : null,
                  crossReferences: v['crossReferences'] != null
                      ? List<String>.from(v['crossReferences'])
                      : null,
                ))
            .toList();

        final chapter = BibleChapter(
          book: chapterData['book'],
          chapter: chapterData['chapter'],
          version: version,
          language: language,
          verses: verses,
          metadata: chapterData['metadata'],
          lastUpdated: DateTime.now(),
        );

        await service.addBibleChapter(chapter);
        stdout.writeln(
            'Successfully uploaded chapter: ${chapter.book} ${chapter.chapter}');
      }
    }

    stdout.writeln('Upload completed successfully');
  } catch (e) {
    stderr.writeln('Error uploading from JSON: $e');
  }
}
