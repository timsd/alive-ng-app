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

  const BibleReferenceModalSheet({
    super.key,
    required this.reference,
    this.initialVersion = 'NKJV',
  });

  /// Displays the interactive Bible reference bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String reference,
    String initialVersion = 'NKJV',
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BibleReferenceModalSheet(
        reference: reference,
        initialVersion: initialVersion,
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
    'NKJV',
    'KJV',
    'NIV',
    'NLT',
    'NASB',
    'ASV',
    'BM',
    'HAU',
    'IGBOB'
  ];
  final BibleDatabaseHelper _dbHelper = BibleDatabaseHelper();
  final OfflineBibleService _offlineBible = OfflineBibleService();

  bool _isLoading = true;
  String _referenceTitle = '';
  List<bible_models.BibleVerse> _verses = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion;
    _referenceTitle = widget.reference;
    _initAvailableVersions();
    _loadVerseText();
  }

  Future<void> _initAvailableVersions() async {
    try {
      final loaded = await _dbHelper.getLoadedVersionCodes();
      if (loaded.isNotEmpty && mounted) {
        setState(() {
          final sorted = List<String>.from(loaded);
          sorted.sort((a, b) {
            if (a == 'NKJV') return -1;
            if (b == 'NKJV') return 1;
            if (a == 'KJV') return -1;
            if (b == 'KJV') return 1;
            return a.compareTo(b);
          });
          _availableVersions = sorted;
          if (!_availableVersions.contains(_selectedVersion)) {
            _selectedVersion = _availableVersions.first;
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _loadVerseText() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
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

      // Query offline Bible service (checks in-memory cache, local prebuilt SQLite, and asset bundles)
      var chapterData = await _offlineBible.getBibleChapter(
        book: canonBook,
        chapter: chapter,
        version: _selectedVersion,
        language: 'en',
      );

      // Direct fallback to database helper
      chapterData ??= await _dbHelper.getChapter(
        canonBook,
        chapter,
        _selectedVersion,
        'English',
      );

      // If version is missing this chapter, fallback seamlessly to KJV
      if ((chapterData == null || chapterData.verses.isEmpty) && _selectedVersion != 'KJV') {
        chapterData = await _offlineBible.getBibleChapter(
          book: canonBook,
          chapter: chapter,
          version: 'KJV',
          language: 'en',
        );
        chapterData ??= await _dbHelper.getChapter(
          canonBook,
          chapter,
          'KJV',
          'English',
        );
        if (chapterData != null && chapterData.verses.isNotEmpty) {
          _selectedVersion = 'KJV';
        }
      }

      if (chapterData != null && chapterData.verses.isNotEmpty) {
        final filtered = chapterData.verses
            .where((v) => targetVerses.contains(v.number))
            .toList();

        setState(() {
          _verses = filtered.isNotEmpty ? filtered : chapterData!.verses.take(3).toList();
          _isLoading = false;
        });
      } else {
        throw 'No offline verses found for $canonBook $chapter';
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Scripture reference preview currently unavailable offline.';
        _isLoading = false;
      });
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
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

