// Bible Data for Navigation and Reference
class BibleData {
  static const Map<String, int> bibleBooks = {
    // Old Testament
    'Genesis': 50,
    'Exodus': 40,
    'Leviticus': 27,
    'Numbers': 36,
    'Deuteronomy': 34,
    'Joshua': 24,
    'Judges': 21,
    'Ruth': 4,
    '1 Samuel': 31,
    '2 Samuel': 24,
    '1 Kings': 22,
    '2 Kings': 25,
    '1 Chronicles': 29,
    '2 Chronicles': 36,
    'Ezra': 10,
    'Nehemiah': 13,
    'Esther': 10,
    'Job': 42,
    'Psalms': 150,
    'Proverbs': 31,
    'Ecclesiastes': 12,
    'Song of Solomon': 8,
    'Isaiah': 66,
    'Jeremiah': 52,
    'Lamentations': 5,
    'Ezekiel': 48,
    'Daniel': 12,
    'Hosea': 14,
    'Joel': 3,
    'Amos': 9,
    'Obadiah': 1,
    'Jonah': 4,
    'Micah': 7,
    'Nahum': 3,
    'Habakkuk': 3,
    'Zephaniah': 3,
    'Haggai': 2,
    'Zechariah': 14,
    'Malachi': 4,
    
    // New Testament
    'Matthew': 28,
    'Mark': 16,
    'Luke': 24,
    'John': 21,
    'Acts': 28,
    'Romans': 16,
    '1 Corinthians': 16,
    '2 Corinthians': 13,
    'Galatians': 6,
    'Ephesians': 6,
    'Philippians': 4,
    'Colossians': 4,
    '1 Thessalonians': 5,
    '2 Thessalonians': 3,
    '1 Timothy': 6,
    '2 Timothy': 4,
    'Titus': 3,
    'Philemon': 1,
    'Hebrews': 13,
    'James': 5,
    '1 Peter': 5,
    '2 Peter': 3,
    '1 John': 5,
    '2 John': 1,
    '3 John': 1,
    'Jude': 1,
    'Revelation': 22,
  };

  static const List<String> oldTestamentBooks = [
    'Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy',
    'Joshua', 'Judges', 'Ruth', '1 Samuel', '2 Samuel',
    '1 Kings', '2 Kings', '1 Chronicles', '2 Chronicles', 'Ezra',
    'Nehemiah', 'Esther', 'Job', 'Psalms', 'Proverbs',
    'Ecclesiastes', 'Song of Solomon', 'Isaiah', 'Jeremiah', 'Lamentations',
    'Ezekiel', 'Daniel', 'Hosea', 'Joel', 'Amos',
    'Obadiah', 'Jonah', 'Micah', 'Nahum', 'Habakkuk',
    'Zephaniah', 'Haggai', 'Zechariah', 'Malachi',
  ];

  static const List<String> newTestamentBooks = [
    'Matthew', 'Mark', 'Luke', 'John', 'Acts',
    'Romans', '1 Corinthians', '2 Corinthians', 'Galatians', 'Ephesians',
    'Philippians', 'Colossians', '1 Thessalonians', '2 Thessalonians', '1 Timothy',
    '2 Timothy', 'Titus', 'Philemon', 'Hebrews', 'James',
    '1 Peter', '2 Peter', '1 John', '2 John', '3 John',
    'Jude', 'Revelation',
  ];

  static List<String> get allBooks => [...oldTestamentBooks, ...newTestamentBooks];

  static int getChapterCount(String book) {
    return bibleBooks[book] ?? 1;
  }

  static bool isValidBook(String book) {
    return bibleBooks.containsKey(book);
  }

  static bool isValidChapter(String book, int chapter) {
    final maxChapter = bibleBooks[book];
    return maxChapter != null && chapter >= 1 && chapter <= maxChapter;
  }

  static String? getNextChapter(String book, int chapter) {
    final maxChapter = bibleBooks[book];
    if (maxChapter == null) return null;
    
    if (chapter < maxChapter) {
      return '$book ${chapter + 1}';
    } else {
      // Move to next book
      final currentIndex = allBooks.indexOf(book);
      if (currentIndex != -1 && currentIndex < allBooks.length - 1) {
        final nextBook = allBooks[currentIndex + 1];
        return '$nextBook 1';
      }
    }
    return null;
  }

  static String? getPreviousChapter(String book, int chapter) {
    if (chapter > 1) {
      return '$book ${chapter - 1}';
    } else {
      // Move to previous book
      final currentIndex = allBooks.indexOf(book);
      if (currentIndex > 0) {
        final previousBook = allBooks[currentIndex - 1];
        final lastChapter = bibleBooks[previousBook] ?? 1;
        return '$previousBook $lastChapter';
      }
    }
    return null;
  }

  static Map<String, dynamic> parseReference(String reference) {
    // Parse references like "John 3:16", "1 Corinthians 13:4-7", "Genesis 1"
    final regex = RegExp(r'^(\d*\s*\w+)\s*(\d+)?(?::(\d+)(?:-(\d+))?)?$');
    final match = regex.firstMatch(reference.trim());
    
    if (match != null) {
      final book = match.group(1)?.trim() ?? '';
      final chapter = int.tryParse(match.group(2) ?? '1') ?? 1;
      final startVerse = int.tryParse(match.group(3) ?? '1') ?? 1;
      final endVerse = int.tryParse(match.group(4) ?? match.group(3) ?? '1') ?? startVerse;
      
      return {
        'book': book,
        'chapter': chapter,
        'startVerse': startVerse,
        'endVerse': endVerse,
        'isValid': isValidBook(book) && isValidChapter(book, chapter),
      };
    }
    
    return {
      'book': '',
      'chapter': 1,
      'startVerse': 1,
      'endVerse': 1,
      'isValid': false,
    };
  }

  static String formatReference(String book, int chapter, {int? verse, int? endVerse}) {
    if (verse != null) {
      if (endVerse != null && endVerse != verse) {
        return '$book $chapter:$verse-$endVerse';
      } else {
        return '$book $chapter:$verse';
      }
    } else {
      return '$book $chapter';
    }
  }
}
