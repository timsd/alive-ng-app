import 'package:flutter/material.dart';
import '../utils/app_theme.dart';
import '../services/bible_database_helper.dart';
import '../services/offline_bible_service.dart';
import '../constants/bible_data.dart';
import '../models/bible_models.dart' as bible_models;
import '../screens/bible/bible_reader_screen.dart';

/// Bottom sheet dialog matching the Bible reader aesthetic (dark theme, version selector, clean typography)
/// for previewing Scripture references immediately in interactive studies.
class BibleReferenceModalSheet extends StatefulWidget {
  final String reference;
  final String initialVersion;
  final String? initialQuote;

  const BibleReferenceModalSheet({
    super.key,
    required this.reference,
    this.initialVersion = 'KJV',
    this.initialQuote,
  });

  /// Displays the interactive Bible reference bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String reference,
    String initialVersion = 'KJV',
    String? initialQuote,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibleReferenceModalSheet(
        reference: reference,
        initialVersion: initialVersion,
        initialQuote: initialQuote,
      ),
    );
  }

  @override
  State<BibleReferenceModalSheet> createState() =>
      _BibleReferenceModalSheetState();
}

class _BibleReferenceModalSheetState extends State<BibleReferenceModalSheet> {
  late String _selectedVersion;
  List<String> _availableVersions = [
    'KJV',
    'NKJV',
    'ASV',
    'NIV',
    'NLT',
    'NASB',
    'BM',
    'HAU',
    'IGBOB'
  ];
  final BibleDatabaseHelper _dbHelper = BibleDatabaseHelper();
  final OfflineBibleService _offlineBible = OfflineBibleService();

  static final Map<String, List<bible_models.BibleVerse>> _modalVerseCache = {};
  static List<String>? _staticAvailableVersions;

  // Pre-compiled fast offline dictionary for instant 0 ms rendering
  static const Map<String, String> _commonStudyVerses = {
    'john 10:35':
        'If he called them gods, unto whom the word of God came, and the scripture cannot be broken;',
    '2 timothy 3:16':
        'All scripture is given by inspiration of God, and is profitable for doctrine, for reproof, for correction, for instruction in righteousness:',
    '2 timothy 3:15':
        'And that from a child thou hast known the holy scriptures, which are able to make thee wise unto salvation through faith which is in Christ Jesus.',
    '2 peter 1:21':
        'For the prophecy came not in old time by the will of man: but holy men of God spake as they were moved by the Holy Ghost.',
    '2 peter 1:20':
        'Knowing this first, that no prophecy of the scripture is of any private interpretation.',
    'psalms 119:105':
        'Thy word is a lamp unto my feet, and a light unto my path.',
    'psalm 119:105':
        'Thy word is a lamp unto my feet, and a light unto my path.',
    'psalms 119:160':
        'Thy word is true from the beginning: and every one of thy righteous judgments endureth for ever.',
    'psalm 119:160':
        'Thy word is true from the beginning: and every one of thy righteous judgments endureth for ever.',
    'psalms 119:100':
        'I understand more than the ancients, because I keep thy precepts.',
    'psalm 119:100':
        'I understand more than the ancients, because I keep thy precepts.',
    'isaiah 42:8, 9':
        'I am the LORD: that is my name: and my glory will I not give to another, neither my praise to graven images. Behold, the former things are come to pass, and new things do I declare: before they spring forth I tell you of them.',
    'isaiah 42:8-9':
        'I am the LORD: that is my name: and my glory will I not give to another, neither my praise to graven images. Behold, the former things are come to pass, and new things do I declare: before they spring forth I tell you of them.',
    'isaiah 46:9, 10':
        'Remember the former things of old: for I am God, and there is none else; I am God, and there is none like me, Declaring the end from the beginning, and from ancient times the things that are not yet done, saying, My counsel shall stand, and I will do all my pleasure:',
    'isaiah 46:9-10':
        'Remember the former things of old: for I am God, and there is none else; I am God, and there is none like me, Declaring the end from the beginning, and from ancient times the things that are not yet done, saying, My counsel shall stand, and I will do all my pleasure:',
    '2 corinthians 5:17':
        'Therefore if any man be in Christ, he is a new creature: old things are passed away; behold, all things are become new.',
    'luke 24:27':
        'And beginning at Moses and all the prophets, he expounded unto them in all the scriptures the things concerning himself.',
    'luke 24:44':
        'And he said unto them, These are the words which I spake unto you, while I was yet with you, that all things must be fulfilled, which were written in the law of Moses, and in the prophets, and in the psalms, concerning me.',
    'john 17:17': 'Sanctify them through thy truth: thy word is truth.',
    'isaiah 8:20':
        'To the law and to the testimony: if they speak not according to this word, it is because there is no light in them.',
    'hebrews 1:1, 2':
        'God, who at sundry times and in divers manners spake in time past unto the fathers by the prophets, Hath in these last days spoken unto us by his Son, whom he hath appointed heir of all things, by whom also he made the worlds;',
    'hebrews 1:1-2':
        'God, who at sundry times and in divers manners spake in time past unto the fathers by the prophets, Hath in these last days spoken unto us by his Son, whom he hath appointed heir of all things, by whom also he made the worlds;',
    'revelation 22:18, 19':
        'For I testify unto every man that heareth the words of the prophecy of this book, If any man shall add unto these things, God shall add unto him the plagues that are written in this book: And if any man shall take away from the words of the book of this prophecy, God shall take away his part out of the book of life, and out of the holy city, and from the things which are written in this book.',
    'revelation 22:18-19':
        'For I testify unto every man that heareth the words of the prophecy of this book, If any man shall add unto these things, God shall add unto him the plagues that are written in this book: And if any man shall take away from the words of the book of this prophecy, God shall take away his part out of the book of life, and out of the holy city, and from the things which are written in this book.',
    'micah 5:2':
        'But thou, Bethlehem Ephratah, though thou be little among the thousands of Judah, yet out of thee shall he come forth unto me that is to be ruler in Israel; whose goings forth have been from of old, from everlasting.',
    'matthew 2:1':
        'Now when Jesus was born in Bethlehem of Judaea in the days of Herod the king, behold, there came wise men from the east to Jerusalem,',
    'isaiah 7:14':
        'Therefore the Lord himself shall give you a sign; Behold, a virgin shall conceive, and bear a son, and shall call his name Immanuel.',
    'matthew 1:18-23':
        'Now the birth of Jesus Christ was on this wise: When as his mother Mary was espoused to Joseph, before they came together, she was found with child of the Holy Ghost... Behold, a virgin shall be with child, and shall bring forth a son, and they shall call his name Emmanuel.',
    'jeremiah 23:5':
        'Behold, the days come, saith the LORD, that I will raise unto David a righteous Branch, and a King shall reign and prosper, and shall execute judgment and justice in the earth.',
    'revelation 22:16':
        'I Jesus have sent mine angel to testify unto you these things in the churches. I am the root and the offspring of David, and the bright and morning star.',
    'jeremiah 31:15':
        'Thus saith the LORD; A voice was heard in Ramah, lamentation, and bitter weeping; Rahel weeping for her children refused to be comforted for her children, because they were not.',
    'matthew 2:16-18':
        'Then Herod, when he saw that he was mocked of the wise men, was exceeding wroth, and sent forth, and slew all the children that were in Bethlehem... Then was fulfilled that which was spoken by Jeremy the prophet...',
    'psalm 41:9':
        'Yea, mine own familiar friend, in whom I trusted, which did eat of my bread, hath lifted up his heel against me.',
    'psalms 41:9':
        'Yea, mine own familiar friend, in whom I trusted, which did eat of my bread, hath lifted up his heel against me.',
    'zechariah 11:12':
        'And I said unto them, If ye think good, give me my price; and if not, forbear. So they weighed for my price thirty pieces of silver.',
    'zechariah 12:10':
        'And I will pour upon the house of David, and upon the inhabitants of Jerusalem, the spirit of grace and of supplications: and they shall look upon me whom they have pierced, and they shall mourn for him...',
    'psalm 22:18':
        'They part my garments among them, and cast lots upon my vesture.',
    'psalms 22:18':
        'They part my garments among them, and cast lots upon my vesture.',
    'psalm 34:20':
        'He keepeth all his bones: not one of them is broken.',
    'psalms 34:20':
        'He keepeth all his bones: not one of them is broken.',
    'isaiah 53:9':
        'And he made his grave with the wicked, and with the rich in his death; because he had done no violence, neither was any deceit in his mouth.',
    'daniel 9:26':
        'And after threescore and two weeks shall Messiah be cut off, but not for himself: and the people of the prince that shall come shall destroy the city and the sanctuary...',
    'daniel 9:26, 27':
        'And after threescore and two weeks shall Messiah be cut off, but not for himself... And he shall confirm the covenant with many for one week...',
    'daniel 9:26-27':
        'And after threescore and two weeks shall Messiah be cut off, but not for himself... And he shall confirm the covenant with many for one week...',
    'hosea 6:2':
        'After two days will he revive us: in the third day he will raise us up, and we shall live in his sight.',
    'acts 10:38-40':
        'How God anointed Jesus of Nazareth with the Holy Ghost and with power: who went about doing good, and healing all that were oppressed of the devil; for God was with him. And we are witnesses of all things which he did... Him God raised up the third day, and shewed him openly;',
  };

  bool _isLoading = true;
  String _referenceTitle = '';
  List<bible_models.BibleVerse> _verses = [];
  String? _errorMessage;

  static String _normalizeRef(String ref) {
    return ref.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  int _parseStartVerse(String ref) {
    try {
      final parsed = BibleData.parseReference(ref);
      if (parsed['isValid'] == true && parsed['verse'] is int) {
        return parsed['verse'] as int;
      }
    } catch (_) {}
    final match = RegExp(r'[:\s](\d+)').firstMatch(ref);
    if (match != null) {
      return int.tryParse(match.group(1)!) ?? 1;
    }
    return 1;
  }

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion;
    _referenceTitle = widget.reference;

    // Use cached available versions if already discovered
    if (_staticAvailableVersions != null && _staticAvailableVersions!.isNotEmpty) {
      _availableVersions = _staticAvailableVersions!;
    }

    final normRef = _normalizeRef(widget.reference);
    final cacheKey = '$_selectedVersion:$normRef';

    // 1. FAST PATH: Check initialQuote, in-memory cache, or prebuilt dictionary for INSTANT 0 ms display
    final quote = widget.initialQuote?.trim();
    if (quote != null && quote.isNotEmpty) {
      _isLoading = false;
      _verses = [
        bible_models.BibleVerse(
          number: _parseStartVerse(widget.reference),
          text: quote,
        )
      ];
      _modalVerseCache[cacheKey] = _verses;
    } else if (_modalVerseCache.containsKey(cacheKey)) {
      _isLoading = false;
      _verses = _modalVerseCache[cacheKey]!;
    } else if (_selectedVersion == 'KJV' && _commonStudyVerses.containsKey(normRef)) {
      _isLoading = false;
      _verses = [
        bible_models.BibleVerse(
          number: _parseStartVerse(widget.reference),
          text: _commonStudyVerses[normRef]!,
        )
      ];
      _modalVerseCache[cacheKey] = _verses;
    }

    _initAvailableVersions();
    _loadVerseText();
  }

  Future<void> _initAvailableVersions() async {
    if (_staticAvailableVersions != null && _staticAvailableVersions!.isNotEmpty) {
      return;
    }
    try {
      final loaded = await _dbHelper.getLoadedVersionCodes();
      if (loaded.isNotEmpty && mounted) {
        final sorted = List<String>.from(loaded);
        sorted.sort((a, b) {
          if (a == 'KJV') return -1;
          if (b == 'KJV') return 1;
          if (a == 'NKJV') return -1;
          if (b == 'NKJV') return 1;
          return a.compareTo(b);
        });
        _staticAvailableVersions = sorted;
        setState(() {
          _availableVersions = sorted;
          if (!_availableVersions.contains(_selectedVersion)) {
            _selectedVersion = _availableVersions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVerseText() async {
    // Only set loading indicator if we don't already have text displayed!
    if (_verses.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final normRef = _normalizeRef(widget.reference);
      final cacheKey = '$_selectedVersion:$normRef';

      // Check cache again for newly selected version
      if (_modalVerseCache.containsKey(cacheKey)) {
        if (mounted) {
          setState(() {
            _verses = _modalVerseCache[cacheKey]!;
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      // Check common study verses for KJV
      if (_selectedVersion == 'KJV' && _commonStudyVerses.containsKey(normRef)) {
        final fastVerses = [
          bible_models.BibleVerse(
            number: _parseStartVerse(widget.reference),
            text: _commonStudyVerses[normRef]!,
          )
        ];
        _modalVerseCache[cacheKey] = fastVerses;
        if (mounted) {
          setState(() {
            _verses = fastVerses;
            _isLoading = false;
            _errorMessage = null;
          });
        }
        return;
      }

      final parsed = BibleData.parseReference(widget.reference);
      if (parsed['isValid'] != true) {
        throw 'Invalid Bible reference format';
      }

      final rawBook = parsed['book'] as String;
      final canonBook = BibleData.canonicalBookName(rawBook) ?? rawBook;
      final chapter = parsed['chapter'] as int;
      final startVerse = (parsed['verse'] as int?) ?? 1;

      // Extract target verses (ranges or comma-separated lists)
      final Set<int> targetVerses = {};
      final rangeMatch = RegExp(r'[-–](\d+)').firstMatch(widget.reference);
      if (rangeMatch != null) {
        final endVerse = int.tryParse(rangeMatch.group(1)!) ?? startVerse;
        for (int i = startVerse; i <= endVerse; i++) {
          targetVerses.add(i);
        }
      } else {
        final commaMatches = RegExp(r'[:,]\s*(\d+)').allMatches(widget.reference);
        if (commaMatches.length > 1) {
          for (final m in commaMatches) {
            final v = int.tryParse(m.group(1)!);
            if (v != null) targetVerses.add(v);
          }
        } else {
          targetVerses.add(startVerse);
        }
      }

      // Query offline Bible service with a safe 3-second timeout so UI never freezes
      bible_models.BibleChapter? chapterData;
      try {
        chapterData = await _offlineBible.getBibleChapter(
          book: canonBook,
          chapter: chapter,
          version: _selectedVersion,
          language: 'en',
        ).timeout(const Duration(seconds: 3));
      } catch (_) {}

      // Direct fallback to database helper
      chapterData ??= await _dbHelper.getChapter(
        canonBook,
        chapter,
        _selectedVersion,
        'English',
      ).timeout(const Duration(seconds: 2)).catchError((_) => null);

      // If version is missing this chapter, fallback seamlessly to KJV
      if ((chapterData == null || chapterData.verses.isEmpty) && _selectedVersion != 'KJV') {
        try {
          chapterData = await _offlineBible.getBibleChapter(
            book: canonBook,
            chapter: chapter,
            version: 'KJV',
            language: 'en',
          ).timeout(const Duration(seconds: 2));
        } catch (_) {}

        chapterData ??= await _dbHelper.getChapter(
          canonBook,
          chapter,
          'KJV',
          'English',
        ).timeout(const Duration(seconds: 2)).catchError((_) => null);

        if (chapterData != null && chapterData.verses.isNotEmpty && mounted) {
          setState(() {
            _selectedVersion = 'KJV';
          });
        }
      }

      if (chapterData != null && chapterData.verses.isNotEmpty) {
        final filtered = chapterData.verses
            .where((v) => targetVerses.contains(v.number))
            .toList();

        final resolvedVerses = filtered.isNotEmpty ? filtered : chapterData.verses.take(3).toList();
        _modalVerseCache[cacheKey] = resolvedVerses;

        if (mounted) {
          setState(() {
            _verses = resolvedVerses;
            _isLoading = false;
            _errorMessage = null;
          });
        }
      } else if (_verses.isEmpty) {
        // Only show error if we have no verses at all
        if (mounted) {
          setState(() {
            _errorMessage = 'Scripture reference preview currently unavailable offline.';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (_verses.isEmpty && mounted) {
        setState(() {
          _errorMessage = 'Scripture reference preview currently unavailable offline.';
          _isLoading = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF0D1520) : const Color(0xFFFCFAF5);
    final cardBg = isDark ? const Color(0xFF141F2D) : Colors.white;
    final borderCol = isDark ? const Color(0xFF2E3E50) : const Color(0xFFE2E8F0);
    final textColor = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textMuted = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final accentGold = isDark ? AppTheme.darkGold : const Color(0xFFB45309);
    final accentEmerald = isDark ? AppTheme.darkEmerald : AppTheme.lightEmerald;

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 16,
            spreadRadius: 4,
          )
        ],
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Header: Close icon and Version Dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.close, color: textMuted, size: 22),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => Navigator.of(context).pop(),
              ),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _availableVersions.contains(_selectedVersion)
                      ? _selectedVersion
                      : _availableVersions.first,
                  dropdownColor: cardBg,
                  icon: Icon(Icons.arrow_drop_down, color: textMuted),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  items: _availableVersions.map((v) {
                    return DropdownMenuItem<String>(
                      value: v,
                      child: Text(v),
                    );
                  }).toList(),
                  onChanged: (newVer) {
                    if (newVer != null && newVer != _selectedVersion) {
                      setState(() {
                        _selectedVersion = newVer;
                      });
                      _loadVerseText();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Reference Title and Verses Content Card
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderCol),
            ),
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _referenceTitle,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),

                if (_isLoading)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(accentEmerald),
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: textMuted,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  Text.rich(
                    TextSpan(
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                        height: 1.5,
                      ),
                      children: _verses.map((v) {
                        return TextSpan(
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.top,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 4.0),
                                child: Text(
                                  '${v.number}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: accentGold,
                                  ),
                                ),
                              ),
                            ),
                            TextSpan(text: '${v.text.trim()} '),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Open in full Bible reader button
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BibleReaderScreen(
                      initialReference: widget.reference,
                    ),
                  ),
                );
              },
              icon: Icon(Icons.menu_book, color: accentEmerald, size: 18),
              label: Text(
                'Open in Bible Reader',
                style: TextStyle(
                  color: isDark ? Colors.greenAccent : const Color(0xFF15803D),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
