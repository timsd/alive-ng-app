import 'package:flutter/material.dart';
import '../../services/bible_database_helper.dart';
import '../../constants/bible_data.dart';
import '../../models/bible_models.dart' as bible_models;
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
  final List<String> _availableVersions = ['NKJV', 'KJV', 'NIV', 'NLT', 'NASB', 'ASV'];
  final BibleDatabaseHelper _dbHelper = BibleDatabaseHelper();

  bool _isLoading = true;
  String _referenceTitle = '';
  List<bible_models.BibleVerse> _verses = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedVersion = widget.initialVersion;
    _referenceTitle = widget.reference;
    _loadVerseText();
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

      final book = parsed['book'] as String;
      final chapter = parsed['chapter'] as int;
      final startVerse = (parsed['verse'] as int?) ?? 1;

      // Extract range end verse if present (e.g. John 17:15-17 -> 17)
      int endVerse = startVerse;
      final rangeMatch = RegExp(r'[-–](\d+)').firstMatch(widget.reference);
      if (rangeMatch != null) {
        endVerse = int.tryParse(rangeMatch.group(1)!) ?? startVerse;
      }

      final chapterData = await _dbHelper.getChapter(
        book,
        chapter,
        _selectedVersion,
        'English',
      );

      if (chapterData != null && chapterData.verses.isNotEmpty) {
        final filtered = chapterData.verses
            .where((v) => v.number >= startVerse && v.number <= endVerse)
            .toList();

        setState(() {
          _verses = filtered.isNotEmpty ? filtered : chapterData.verses.take(3).toList();
          _isLoading = false;
        });
      } else {
        // Fallback: Try with KJV
        if (_selectedVersion != 'KJV') {
          final kjvChapter = await _dbHelper.getChapter(
            book,
            chapter,
            'KJV',
            'English',
          );
          if (kjvChapter != null && kjvChapter.verses.isNotEmpty) {
            final filtered = kjvChapter.verses
                .where((v) => v.number >= startVerse && v.number <= endVerse)
                .toList();
            setState(() {
              _verses = filtered.isNotEmpty ? filtered : kjvChapter.verses.take(3).toList();
              _selectedVersion = 'KJV';
              _isLoading = false;
            });
            return;
          }
        }
        throw 'Could not load verses for $book $chapter:$_selectedVersion';
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
    const darkBg = Color(0xFF1E1E1E);
    const cardBg = Color(0xFF252526);
    const borderCol = Color(0xFF333333);

    return Container(
      decoration: const BoxDecoration(
        color: darkBg,
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
                color: Colors.white24,
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
                icon: const Icon(Icons.close, color: Colors.white70, size: 22),
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
                  icon: const Icon(Icons.arrow_drop_down, color: Colors.white70),
                  style: const TextStyle(
                    color: Colors.white,
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 14),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                      ),
                    ),
                  )
                else if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  )
                else
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: Colors.white,
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
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white60,
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
              icon: const Icon(Icons.menu_book, color: Colors.greenAccent, size: 18),
              label: const Text(
                'Open in Bible Reader',
                style: TextStyle(
                  color: Colors.greenAccent,
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

