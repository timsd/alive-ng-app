import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../models/bible_models.dart';
import 'firebase_database_service.dart';

/// Helper to publish Bible chapter data to Firebase (Firestore + Storage).
class BibleDataUploader {
  BibleDataUploader._();
  static final BibleDataUploader instance = BibleDataUploader._();

  final FirebaseDatabaseService _db = FirebaseDatabaseService.instance;

  /// Upload a chapter JSON to Storage and index metadata/verses in Firestore.
  Future<void> uploadChapter(BibleChapter chapter) async {
    try {
      // Prepare JSON structure
      final payload = {
        'book': chapter.book,
        'chapter': chapter.chapter,
        'version': chapter.version,
        'language': chapter.language,
        'verses': chapter.verses
            .map((v) => {
                  'verse': v.number,
                  'text': v.text,
                  if (v.footnotes != null) 'footnotes': v.footnotes,
                  if (v.crossReferences != null)
                    'crossReferences': v.crossReferences,
                })
            .toList(),
        'metadata': chapter.metadata,
        'lastUpdated': (chapter.lastUpdated ?? DateTime.now()).toIso8601String(),
      };

      // Upload to Storage under a predictable path
      final storagePath =
          'bible/${chapter.language}/${chapter.version}/${chapter.book.toLowerCase()}_${chapter.chapter}.json';

      // Write to a temp file then upload
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/bible_${chapter.book}_${chapter.chapter}_${chapter.version}.json');
      await tempFile.writeAsString(jsonEncode(payload));

      final ref = _db.storage.ref().child(storagePath);
      await ref.putFile(tempFile);

      // Index metadata in Firestore and verses in subcollection
      final chapters = _db.firestore.collection('bible_chapters');
      final chapterDoc = await chapters.add({
        'book': chapter.book,
        'chapter': chapter.chapter,
        'version': chapter.version,
        'language': chapter.language,
        'metadata': chapter.metadata,
        'lastUpdated': chapter.lastUpdated ?? DateTime.now(),
        'storagePath': storagePath,
      });

      final versesCol = chapterDoc.collection('verses');
      for (final v in chapter.verses) {
        await versesCol.add({
          'number': v.number,
          'text': v.text,
          if (v.footnotes != null) 'footnotes': v.footnotes,
          if (v.crossReferences != null) 'crossReferences': v.crossReferences,
        });
      }

      // Clean up temp file
      await tempFile.delete();
    } catch (e) {
      // Best-effort; errors should not crash caller
      // Consider logging via your app logger
    }
  }
}
