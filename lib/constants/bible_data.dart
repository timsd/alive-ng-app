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

  static String _normalizeAliasKey(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .replaceAll(RegExp(r'^1st'), '1')
        .replaceAll(RegExp(r'^first'), '1')
        .replaceAll(RegExp(r'^2nd'), '2')
        .replaceAll(RegExp(r'^second'), '2')
        .replaceAll(RegExp(r'^3rd'), '3')
        .replaceAll(RegExp(r'^third'), '3');
  }

  static const Map<String, String> _rawAliases = {
    // Old Testament
    'gen': 'Genesis', 'ge': 'Genesis', 'gn': 'Genesis', 'genesis': 'Genesis',
    'ex': 'Exodus', 'exo': 'Exodus', 'exod': 'Exodus', 'exodus': 'Exodus',
    'lev': 'Leviticus', 'le': 'Leviticus', 'lv': 'Leviticus', 'leviticus': 'Leviticus',
    'num': 'Numbers', 'nu': 'Numbers', 'nm': 'Numbers', 'nb': 'Numbers', 'numbers': 'Numbers',
    'deut': 'Deuteronomy', 'dt': 'Deuteronomy', 'de': 'Deuteronomy', 'deuteronomy': 'Deuteronomy',
    'josh': 'Joshua', 'jos': 'Joshua', 'jsh': 'Joshua', 'joshua': 'Joshua',
    'judg': 'Judges', 'jdg': 'Judges', 'jg': 'Judges', 'jdgs': 'Judges', 'judges': 'Judges',
    'rut': 'Ruth', 'rth': 'Ruth', 'ru': 'Ruth', 'ruth': 'Ruth',
    '1sam': '1 Samuel', '1sa': '1 Samuel', '1s': '1 Samuel', '1samuel': '1 Samuel',
    '2sam': '2 Samuel', '2sa': '2 Samuel', '2s': '2 Samuel', '2samuel': '2 Samuel',
    '1kings': '1 Kings', '1kgs': '1 Kings', '1ki': '1 Kings', '1k': '1 Kings',
    '2kings': '2 Kings', '2kgs': '2 Kings', '2ki': '2 Kings', '2k': '2 Kings',
    '1chron': '1 Chronicles', '1chr': '1 Chronicles', '1ch': '1 Chronicles', '1chronicles': '1 Chronicles',
    '2chron': '2 Chronicles', '2chr': '2 Chronicles', '2ch': '2 Chronicles', '2chronicles': '2 Chronicles',
    'ezr': 'Ezra', 'ez': 'Ezra', 'ezra': 'Ezra',
    'neh': 'Nehemiah', 'ne': 'Nehemiah', 'nehemiah': 'Nehemiah',
    'esth': 'Esther', 'est': 'Esther', 'es': 'Esther', 'esther': 'Esther',
    'job': 'Job', 'jb': 'Job',
    'psalm': 'Psalms', 'psalms': 'Psalms', 'ps': 'Psalms', 'psa': 'Psalms', 'psm': 'Psalms', 'pss': 'Psalms',
    'prov': 'Proverbs', 'pro': 'Proverbs', 'prv': 'Proverbs', 'pr': 'Proverbs', 'proverbs': 'Proverbs',
    'eccl': 'Ecclesiastes', 'ecc': 'Ecclesiastes', 'ec': 'Ecclesiastes', 'qoh': 'Ecclesiastes', 'qoheleth': 'Ecclesiastes', 'ecclesiastes': 'Ecclesiastes',
    'song': 'Song of Solomon', 'songs': 'Song of Solomon', 'songofsongs': 'Song of Solomon', 'sos': 'Song of Solomon',
    'canticle': 'Song of Solomon', 'canticles': 'Song of Solomon', 'songofsolomon': 'Song of Solomon',
    'isa': 'Isaiah', 'is': 'Isaiah', 'isaiah': 'Isaiah',
    'jer': 'Jeremiah', 'je': 'Jeremiah', 'jr': 'Jeremiah', 'jeremiah': 'Jeremiah',
    'lam': 'Lamentations', 'la': 'Lamentations', 'lamentations': 'Lamentations',
    'ezek': 'Ezekiel', 'eze': 'Ezekiel', 'ezk': 'Ezekiel', 'ezekiel': 'Ezekiel',
    'dan': 'Daniel', 'da': 'Daniel', 'dn': 'Daniel', 'daniel': 'Daniel',
    'hos': 'Hosea', 'ho': 'Hosea', 'hosea': 'Hosea',
    'joe': 'Joel', 'jl': 'Joel', 'joel': 'Joel',
    'am': 'Amos', 'amo': 'Amos', 'amos': 'Amos',
    'obad': 'Obadiah', 'oba': 'Obadiah', 'ob': 'Obadiah', 'obadiah': 'Obadiah',
    'jon': 'Jonah', 'jnh': 'Jonah', 'jonah': 'Jonah',
    'mic': 'Micah', 'mc': 'Micah', 'micah': 'Micah',
    'nah': 'Nahum', 'na': 'Nahum', 'nahum': 'Nahum',
    'hab': 'Habakkuk', 'hb': 'Habakkuk', 'habakkuk': 'Habakkuk',
    'zeph': 'Zephaniah', 'zep': 'Zephaniah', 'zp': 'Zephaniah', 'zephaniah': 'Zephaniah',
    'hag': 'Haggai', 'hg': 'Haggai', 'haggai': 'Haggai',
    'zech': 'Zechariah', 'zec': 'Zechariah', 'zc': 'Zechariah', 'zechariah': 'Zechariah',
    'mal': 'Malachi', 'ml': 'Malachi', 'malachi': 'Malachi',

    // New Testament
    'matt': 'Matthew', 'mt': 'Matthew', 'mat': 'Matthew', 'matthew': 'Matthew',
    'mk': 'Mark', 'mrk': 'Mark', 'mar': 'Mark', 'mark': 'Mark',
    'lk': 'Luke', 'luk': 'Luke', 'lu': 'Luke', 'luke': 'Luke',
    'jn': 'John', 'jhn': 'John', 'joh': 'John', 'john': 'John',
    'act': 'Acts', 'ac': 'Acts', 'acts': 'Acts',
    'rom': 'Romans', 'ro': 'Romans', 'rm': 'Romans', 'roman': 'Romans', 'romans': 'Romans',
    '1cor': '1 Corinthians', '1co': '1 Corinthians', '1corinthians': '1 Corinthians',
    '2cor': '2 Corinthians', '2co': '2 Corinthians', '2corinthians': '2 Corinthians',
    'gal': 'Galatians', 'ga': 'Galatians', 'galatians': 'Galatians',
    'eph': 'Ephesians', 'ep': 'Ephesians', 'ephesians': 'Ephesians',
    'phil': 'Philippians', 'php': 'Philippians', 'pp': 'Philippians', 'philippians': 'Philippians',
    'col': 'Colossians', 'co': 'Colossians', 'colossians': 'Colossians',
    '1thess': '1 Thessalonians', '1th': '1 Thessalonians', '1thes': '1 Thessalonians', '1thessalonians': '1 Thessalonians',
    '2thess': '2 Thessalonians', '2th': '2 Thessalonians', '2thes': '2 Thessalonians', '2thessalonians': '2 Thessalonians',
    '1tim': '1 Timothy', '1ti': '1 Timothy', '1timothy': '1 Timothy',
    '2tim': '2 Timothy', '2ti': '2 Timothy', '2timothy': '2 Timothy',
    'tit': 'Titus', 'ti': 'Titus', 'titus': 'Titus',
    'philem': 'Philemon', 'phm': 'Philemon', 'pm': 'Philemon', 'philemon': 'Philemon',
    'heb': 'Hebrews', 'he': 'Hebrews', 'hebrews': 'Hebrews',
    'jas': 'James', 'jm': 'James', 'jam': 'James', 'james': 'James',
    '1pet': '1 Peter', '1pe': '1 Peter', '1pt': '1 Peter', '1p': '1 Peter', '1peter': '1 Peter',
    '2pet': '2 Peter', '2pe': '2 Peter', '2pt': '2 Peter', '2p': '2 Peter', '2peter': '2 Peter',
    '1jn': '1 John', '1joh': '1 John', '1j': '1 John', '1john': '1 John',
    '2jn': '2 John', '2joh': '2 John', '2j': '2 John', '2john': '2 John',
    '3jn': '3 John', '3joh': '3 John', '3j': '3 John', '3john': '3 John',
    'rev': 'Revelation', 'revelation': 'Revelation', 'revelations': 'Revelation', 'rv': 'Revelation', 'apoc': 'Revelation',

    // Hausa Bible Book Aliases
    'farawa': 'Genesis',
    'fitowa': 'Exodus',
    'littafin firistoci': 'Leviticus',
    'littafin kidaya': 'Numbers',
    'maimaitawar shari\'a': 'Deuteronomy',
    'maimaita': 'Deuteronomy',
    'joshuwa': 'Joshua',
    'littafin mahukunta': 'Judges',
    'rut': 'Ruth',
    '1 sama\'ila': '1 Samuel',
    '1samaila': '1 Samuel',
    '2 sama\'ila': '2 Samuel',
    '2samaila': '2 Samuel',
    '1 sarakuna': '1 Kings',
    '1sarakun': '1 Kings',
    '2 sarakuna': '2 Kings',
    '2sarakun': '2 Kings',
    '1 tarihi': '1 Chronicles',
    '1tarihi': '1 Chronicles',
    '2 tarihi': '2 Chronicles',
    '2tarihi': '2 Chronicles',
    'ezra': 'Ezra',
    'nehemiya': 'Nehemiah',
    'esta': 'Esther',
    'ayuba': 'Job',
    'zabura': 'Psalms',
    'karin magana': 'Proverbs',
    'karinmag': 'Proverbs',
    'mai hadishi': 'Ecclesiastes',
    'maihadis': 'Ecclesiastes',
    'wakar wakoki': 'Song of Solomon',
    'wakarwak': 'Song of Solomon',
    'ishaya': 'Isaiah',
    'irmiya': 'Jeremiah',
    'makoki': 'Lamentations',
    'ezekiyel': 'Ezekiel',
    'daniyel': 'Daniel',
    'yusha\'u': 'Hosea',
    'yushau': 'Hosea',
    'yowel': 'Joel',
    'amos': 'Amos',
    'obadiya': 'Obadiah',
    'yunusa': 'Jonah',
    'mika': 'Micah',
    'nahum': 'Nahum',
    'habakuk': 'Habakkuk',
    'zafaniya': 'Zephaniah',
    'haggai': 'Haggai',
    'zakariya': 'Zechariah',
    'malakai': 'Malachi',
    'matiyu': 'Matthew',
    'markus': 'Mark',
    'luka': 'Luke',
    'yahaya': 'John',
    'ayyukan manzanni': 'Acts',
    'ayyukanm': 'Acts',
    'romawa': 'Romans',
    '1 korantiyawa': '1 Corinthians',
    '1koranti': '1 Corinthians',
    '2 korantiyawa': '2 Corinthians',
    '2koranti': '2 Corinthians',
    'galatiyawa': 'Galatians',
    'galatiya': 'Galatians',
    'afisawa': 'Ephesians',
    'filibiyawa': 'Philippians',
    'filibiya': 'Philippians',
    'kolosiyawa': 'Colossians',
    'kolosiya': 'Colossians',
    '1 tasalonikawa': '1 Thessalonians',
    '1tasalon': '1 Thessalonians',
    '2 tasalonikawa': '2 Thessalonians',
    '2tasalon': '2 Thessalonians',
    '1 timoti': '1 Timothy',
    '1timoti': '1 Timothy',
    '2 timoti': '2 Timothy',
    '2timoti': '2 Timothy',
    'titus': 'Titus',
    'filiman': 'Philemon',
    'ibraniyawa': 'Hebrews',
    'ibraniya': 'Hebrews',
    'yakubu': 'James',
    '1 bitrus': '1 Peter',
    '1bitrus': '1 Peter',
    '2 bitrus': '2 Peter',
    '2bitrus': '2 Peter',
    '1 yahaya': '1 John',
    '1yahaya': '1 John',
    '2 yahaya': '2 John',
    '2yahaya': '2 John',
    '3 yahaya': '3 John',
    '3yahaya': '3 John',
    'yahuza': 'Jude',
    'wahayin yahaya': 'Revelation',
    'wahayiny': 'Revelation',
  };

  /// Map of normalized alias keys to canonical English book names.
  static final Map<String, String> _aliasMap = () {
    final map = <String, String>{};
    for (final book in allBooks) {
      map[_normalizeAliasKey(book)] = book;
    }
    for (final entry in _rawAliases.entries) {
      map[_normalizeAliasKey(entry.key)] = entry.value;
    }
    return map;
  }();

  /// Resolves any book name, abbreviation, or alias to canonical English book name.
  /// E.g. "Psalm" -> "Psalms", "1cor" -> "1 Corinthians", "Gen" -> "Genesis", "Song of Songs" -> "Song of Solomon".
  static String? canonicalBookName(String input) {
    if (input.trim().isEmpty) return null;
    final key = _normalizeAliasKey(input);
    return _aliasMap[key];
  }

  /// Returns all recognized aliases/tokens for a given canonical book name.
  static Set<String> aliasesForBook(String canonicalName) {
    final canon = canonicalBookName(canonicalName) ?? canonicalName;
    final results = <String>{};
    for (final entry in _rawAliases.entries) {
      if (entry.value.toLowerCase() == canon.toLowerCase()) {
        results.add(entry.key);
      }
    }
    results.add(canon.toLowerCase());
    return results;
  }

  static bool isValidBook(String book) {
    return canonicalBookName(book) != null;
  }

  static bool isValidChapter(String book, int chapter) {
    final canon = canonicalBookName(book) ?? book;
    final maxChapter = bibleBooks[canon];
    return maxChapter != null && chapter >= 1 && chapter <= maxChapter;
  }

  static String? getNextChapter(String book, int chapter) {
    final canon = canonicalBookName(book) ?? book;
    final maxChapter = bibleBooks[canon];
    if (maxChapter == null) return null;
    
    if (chapter < maxChapter) {
      return '$canon ${chapter + 1}';
    } else {
      // Move to next book
      final currentIndex = allBooks.indexOf(canon);
      if (currentIndex != -1 && currentIndex < allBooks.length - 1) {
        final nextBook = allBooks[currentIndex + 1];
        return '$nextBook 1';
      }
    }
    return null;
  }

  static String? getPreviousChapter(String book, int chapter) {
    final canon = canonicalBookName(book) ?? book;
    if (chapter > 1) {
      return '$canon ${chapter - 1}';
    } else {
      // Move to previous book
      final currentIndex = allBooks.indexOf(canon);
      if (currentIndex > 0) {
        final previousBook = allBooks[currentIndex - 1];
        final lastChapter = bibleBooks[previousBook] ?? 1;
        return '$previousBook $lastChapter';
      }
    }
    return null;
  }

  /// Parses reference strings such as:
  /// "John 3:16", "John 3 16", "1 Corinthians 13:4-7", "1Cor 13:4", "Psalm 23", "Genesis 1", "Revelation"
  static Map<String, dynamic> parseReference(String reference) {
    final trimmed = reference.trim();
    if (trimmed.isEmpty) {
      return {
        'book': '',
        'chapter': 1,
        'startVerse': 1,
        'endVerse': 1,
        'hasChapter': false,
        'hasVerse': false,
        'isValid': false,
      };
    }

    // Pattern matching:
    // Group 1: Book name with optional leading digit (e.g. "1 Corinthians", "Song of Solomon", "John", "1Cor", "Psalm")
    // Group 2: Chapter number
    // Group 3: Verse number (after colon or dot)
    // Group 4: End verse (after dash)
    // Group 5: Verse number (space-separated after chapter e.g. "John 3 16")
    final refRegex = RegExp(
      r'^((?:[1-3]\s*)?[a-zA-Z]+(?:\s+[a-zA-Z]+)*)\s*(\d+)?(?:\s*[:.]\s*(\d+)(?:\s*-\s*(\d+))?|\s+(\d+))?$',
    );
    final match = refRegex.firstMatch(trimmed);
    if (match != null) {
      final rawBook = match.group(1)?.trim() ?? '';
      final canonicalBook = canonicalBookName(rawBook);
      if (canonicalBook != null) {
        final chapterStr = match.group(2);
        final chapter = chapterStr != null ? (int.tryParse(chapterStr) ?? 1) : 1;
        final startVerseStr = match.group(3) ?? match.group(5);
        final startVerse = startVerseStr != null ? (int.tryParse(startVerseStr) ?? 1) : 1;
        final endVerseStr = match.group(4);
        final endVerse = endVerseStr != null ? (int.tryParse(endVerseStr) ?? startVerse) : startVerse;

        return {
          'book': canonicalBook,
          'chapter': chapter,
          'verse': startVerse,
          'startVerse': startVerse,
          'endVerse': endVerse,
          'hasChapter': chapterStr != null,
          'hasVerse': startVerseStr != null,
          'isValid': isValidChapter(canonicalBook, chapter),
        };
      }
    }

    // Direct check for book name only (e.g., "Genesis", "Revelation", "psalm")
    final directCanon = canonicalBookName(trimmed);
    if (directCanon != null) {
      return {
        'book': directCanon,
        'chapter': 1,
        'verse': 1,
        'startVerse': 1,
        'endVerse': 1,
        'hasChapter': false,
        'hasVerse': false,
        'isValid': true,
      };
    }

    return {
      'book': '',
      'chapter': 1,
      'verse': 1,
      'startVerse': 1,
      'endVerse': 1,
      'hasChapter': false,
      'hasVerse': false,
      'isValid': false,
    };
  }

  static String formatReference(String book, int chapter, {int? verse, int? endVerse}) {
    final canon = canonicalBookName(book) ?? book;
    if (verse != null) {
      if (endVerse != null && endVerse != verse) {
        return '$canon $chapter:$verse-$endVerse';
      } else {
        return '$canon $chapter:$verse';
      }
    } else {
      return '$canon $chapter';
    }
  }
}
