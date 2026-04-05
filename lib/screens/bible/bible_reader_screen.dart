import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/bible_source.dart';
import '../../models/bible_models.dart' as models;
import '../../constants/bible_verses.dart' as data_bible;
import '../../constants/bible_data.dart';
import '../../services/offline_bible_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../../config/app_config.dart';
import '../../services/tts_service.dart';
import '../../services/user_statistics_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String? initialReference;

  const BibleReaderScreen({super.key, this.initialReference});

  @override
  ConsumerState<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends ConsumerState<BibleReaderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TTSService _ttsService = TTSService();
  final UserStatisticsService _statisticsService =
      UserStatisticsService.instance;

  String _selectedVersion = '';
  String _selectedBook = '';
  int _selectedChapter = 1;
  final int _selectedVerse = 1;
  models.BibleVerse? _currentVerse;
  List<Map<String, dynamic>> _chapterVerses = [];
  bool _isLoading = false;
  bool _isSpeaking = false;
  List<data_bible.BibleVerse> _searchResults = [];
  int? _selectedVerseIndex;
  Set<String> _highlightedVerses = {};
  Map<String, Color> _verseHighlightColors = {};
  // Available versions for the current language, loaded from service
  List<String> _versionsForLanguage = [];

  final OfflineBibleService _offlineBible = OfflineBibleService();
  String _selectedLanguage = 'English';
  bool _didApplyInitialReference = false;
  final Map<String, String> _languageCodes = {
    'English': 'en',
    'Yoruba': 'yo',
    'Igbo': 'ig',
    'Hausa': 'ha',
  };
  List<models.BibleBook> _books = [];
  int _currentBookIndex = 0;
  List<String> get _availableVersions =>
      _versionsForLanguage.isNotEmpty ? _versionsForLanguage : ['BM'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ttsService.initialize();
    _statisticsService.startReadingSession();
    _loadHighlights(); // Now implemented
    _loadBooksAndInit();
  }

  Future<void> _loadHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('highlight_'));
      final newHighlightColors = <String, Color>{};
      final newHighlightedVerses = <String>{};
      
      for (final key in keys) {
        final verseKey = key.replaceFirst('highlight_', '');
        final colorValue = prefs.getInt(key);
        if (colorValue != null) {
          newHighlightColors[verseKey] = Color(colorValue);
          newHighlightedVerses.add(verseKey);
        }
      }
      
      if (mounted) {
        setState(() {
          _verseHighlightColors = newHighlightColors;
          _highlightedVerses = newHighlightedVerses;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadBooksAndInit() async {
    setState(() => _isLoading = true);
    try {
      final languageCode = _languageCodes[_selectedLanguage] ?? 'en';
      _versionsForLanguage = await _resolveVersionsForLanguage(languageCode);

      if (_versionsForLanguage.isNotEmpty && !_versionsForLanguage.contains(_selectedVersion)) {
        _selectedVersion = _versionsForLanguage.first;
      }
      
      final books = await _offlineBible.getBibleBooks(language: languageCode);
      if (books.isNotEmpty) {
        // Reorder books according to BibleData.allBooks
        final orderMap = {for (var i = 0; i < BibleData.allBooks.length; i++) BibleData.allBooks[i]: i};
        books.sort((a, b) {
          final orderA = orderMap[a.name];
          final orderB = orderMap[b.name];
          if (orderA != null && orderB != null) {
            return orderA.compareTo(orderB);
          }
          return a.order.compareTo(b.order);
        });
        _books = books;
        _currentBookIndex = 0;
        _selectedBook = _books[_currentBookIndex].name;
        _selectedChapter = 1;
        if (widget.initialReference != null && !_didApplyInitialReference) {
          final applied = await _openReference(widget.initialReference!);
          _didApplyInitialReference = true;
          if (!applied) {
            await _loadChapter();
          }
        } else {
          await _loadChapter();
        }
      } else {
        // Fallback: keep empty state when no local books available
        _selectedBook = '';
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<List<String>> _resolveVersionsForLanguage(String languageCode) async {
    if (languageCode == 'en') {
      return ['ASV', 'KJV', 'NASB', 'NIV', 'NKJV', 'NLT'];
    }
    if (languageCode == 'ha') {
      return ['HAU'];
    }
    if (languageCode == 'ig') {
      return ['IGBOB'];
    }
    if (languageCode == 'yo') {
      return ['BM'];
    }

    final versions = await _offlineBible.getAvailableVersions(language: languageCode);
    return versions.map((v) => v.code).toList();
  }

  Future<bool> _openReference(String reference) async {
    final parsed = BibleData.parseReference(reference);
    if (parsed['isValid'] != true) {
      await _loadVerse(reference);
      return false;
    }

    final parsedBook = parsed['book'] as String;
    final parsedChapter = parsed['chapter'] as int;
    final hasExactBook = _books.any((book) => book.name == parsedBook);

    if (!hasExactBook && _selectedLanguage != 'English') {
      setState(() {
        _selectedLanguage = 'English';
      });
      await _loadBooksAndInit();
      return true;
    }

    final targetIndex =
        _books.indexWhere((book) => book.name.toLowerCase() == parsedBook.toLowerCase());
    if (targetIndex == -1) {
      await _loadVerse(reference);
      return false;
    }

    setState(() {
      _currentBookIndex = targetIndex;
      _selectedBook = _books[targetIndex].name;
      _selectedChapter = parsedChapter;
    });

    await _loadChapter();
    await _loadVerse(reference);
    return true;
  }

  Future<void> _loadChapter() async {
    setState(() => _isLoading = true);

    try {
      final languageCode = _languageCodes[_selectedLanguage] ?? 'en';
      final chapter = await _offlineBible.getBibleChapter(
        book: _selectedBook,
        chapter: _selectedChapter,
        version: _selectedVersion,
        language: languageCode,
      );

      if (chapter != null) {
        setState(() {
          _chapterVerses = chapter.verses
              .map((v) => {'verse': v.number, 'text': v.text})
              .toList();
        });
        _statisticsService.recordChapterRead(_selectedBook, _selectedChapter);
        _statisticsService.recordVersesRead(
            chapter.reference, chapter.verses.length);
      } else {
        setState(() {
          _chapterVerses = [];
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading chapter: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadFullBook() async {
    setState(() => _isLoading = true);
    try {
      final languageCode = _languageCodes[_selectedLanguage] ?? 'en';
      final currentBook = _books[_currentBookIndex];
      
      final List<Map<String, dynamic>> allVerses = [];
      final chapters = await _offlineBible.getBibleBookFull(
        book: _selectedBook,
        totalChapters: currentBook.chapters,
        version: _selectedVersion,
        language: languageCode,
      );

      for (var chapter in chapters) {
        for (var v in chapter.verses) {
          allVerses.add({
            'verse': v.number,
            'text': v.text,
            'chapter': chapter.chapter,
          });
        }
      }

      setState(() {
        _chapterVerses = allVerses;
        _selectedChapter = 1; // Default to start
      });
      
      _statisticsService.recordChapterRead(_selectedBook, 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading book: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateToPreviousChapter() {
    if (_books.isEmpty) return;
    if (_selectedChapter > 1) {
      setState(() => _selectedChapter -= 1);
      _loadChapter();
      return;
    }
    if (_currentBookIndex > 0) {
      setState(() {
        _currentBookIndex -= 1;
        _selectedBook = _books[_currentBookIndex].name;
        _selectedChapter = _books[_currentBookIndex].chapters;
      });
      _loadChapter();
    }
  }

  void _navigateToNextChapter() {
    if (_books.isEmpty) return;
    final maxChapter = _books[_currentBookIndex].chapters;
    if (_selectedChapter < maxChapter) {
      setState(() => _selectedChapter += 1);
      _loadChapter();
      return;
    }
    if (_currentBookIndex < _books.length - 1) {
      setState(() {
        _currentBookIndex += 1;
        _selectedBook = _books[_currentBookIndex].name;
        _selectedChapter = 1;
      });
      _loadChapter();
    }
  }

  Future<void> _speakChapter() async {
    if (_chapterVerses.isEmpty) return;
    setState(() {
      _isSpeaking = true;
    });
    try {
      final chapterText = _chapterVerses
          .map((v) => 'Verse ${v['verse']}. ${v['text']}')
          .join(' ');

      await _ttsService.speak(chapterText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error speaking chapter: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _ttsService.stop();
    if (mounted) {
      setState(() {
        _isSpeaking = false;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _ttsService.dispose();
    _statisticsService.stopReadingSession();
    super.dispose();
  }

  Future<void> _loadVerse(String reference) async {
    setState(() => _isLoading = true);

    try {
      // First check local data
      final verse = _findVerseInLocalData(reference);

      if (verse != null) {
        setState(() {
          _currentVerse = verse;
        });

        // Track verse reading
        _statisticsService.recordVersesRead(reference, 1);
        _statisticsService.recordChapterRead(_selectedBook, _selectedChapter);
      } else {
        // If configured to use local Bible only, skip remote API calls
        if (AppConfig.useLocalBibleOnly) {
          setState(() {
            _currentVerse = models.BibleVerse(
              number: _selectedVerse,
              text: 'Verse not available in local corpus.',
            );
          });
          // Track verse reading from fallback
          _statisticsService.recordVersesRead(reference, 1);
          _statisticsService.recordChapterRead(_selectedBook, _selectedChapter);
        } else {
          // Use local fallback message when verse not found locally
          setState(() {
            _currentVerse = models.BibleVerse(
              number: _selectedVerse,
              text: 'Verse not available. Please try another verse.',
            );
          });
          // Still track the attempt
          _statisticsService.recordVersesRead(reference, 1);
          _statisticsService.recordChapterRead(_selectedBook, _selectedChapter);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading verse: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  models.BibleVerse? _findVerseInLocalData(String reference) {
    final v = BibleSource.instance.findByReference(reference);
    if (v == null) return null;
    final selectedText = v.text[_selectedVersion] ?? v.text.values.first;
    final verseNum =
        _parseVerseNumberFromReference(v.reference) ?? _selectedVerse;
    return models.BibleVerse(number: verseNum, text: selectedText);
  }

  int? _parseVerseNumberFromReference(String reference) {
    try {
      final match = RegExp(r":\s*(\d+)").firstMatch(reference);
      if (match != null) {
        return int.tryParse(match.group(1)!);
      }
      // Fallback: take first number in the reference
      final any = RegExp(r"(\d+)").firstMatch(reference);
      if (any != null) {
        return int.tryParse(any.group(1)!);
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  void _searchVerses(String query) {
    if (query.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() {
      _searchResults = BibleSource.instance.search(query);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    final headerBgColor = isDark ? colorScheme.surface : colorScheme.primary;
    final headerTextColor = isDark ? colorScheme.onSurface : colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: headerBgColor,
      appBar: CustomAppBar(
        title: 'Bible Reader',
        backgroundColor: headerBgColor,
        foregroundColor: headerTextColor,
        elevation: 0,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
        actions: [
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop : Icons.volume_up),
            onPressed: () {
              if (_isSpeaking) {
                _stopSpeaking();
              } else {
                _speakChapter();
              }
            },
            tooltip: _isSpeaking ? 'Stop Reading' : 'Listen to Chapter',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: headerTextColor,
          labelColor: headerTextColor,
          unselectedLabelColor: headerTextColor.withValues(alpha: 0.7),
          tabs: const [
            Tab(text: 'Reader'),
            Tab(text: 'Search'),
            Tab(text: 'E.G. White'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReaderTab(),
          _buildSearchTab(),
          _buildEGWhiteTab(),
        ],
      ),
    );
  }

  Widget _buildReaderTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final isMediumScreen = screenWidth >= 600 && screenWidth < 900;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    
    // In light mode we use the brand primary color for the background, in dark mode we use the surface color.
    final headerBgColor = isDark ? colorScheme.surface : colorScheme.primary;
    final headerTextColor = isDark ? colorScheme.onSurface : colorScheme.onPrimary;

    return Container(
      color: headerBgColor,
      child: Column(
        children: [
          // Chapter Title - Responsive
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Text(
              _selectedBook.isEmpty
                  ? 'Bible Reader'
                  : _selectedBook,
              style: TextStyle(
                color: headerTextColor,
                fontSize: isSmallScreen ? 24 : (isMediumScreen ? 26 : 28),
                fontWeight: FontWeight.bold,
                fontStyle: FontStyle.italic,
                shadows: [
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 2,
                    color: colorScheme.shadow.withValues(alpha: 0.3),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Bible Content - Responsive
          Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 20),
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.shadow.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _chapterVerses.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.menu_book_outlined,
                                  size: 48,
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _selectedBook.isEmpty
                                    ? 'Select a book to begin reading'
                                    : 'No verses found for $_selectedBook $_selectedChapter',
                                style: TextStyle(
                                  color: colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                  fontSize: 16,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ..._chapterVerses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final verse = entry.value;
                              final isSelected =
                                  _selectedVerseIndex == index;
                              final verseKey =
                                  '$_selectedBook:$_selectedChapter:${verse['verse']}';
                              final highlightColor =
                                  _verseHighlightColors[verseKey];

                              return Padding(
                                padding: EdgeInsets.only(
                                    bottom: isSmallScreen ? 4 : 6),
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _selectedVerseIndex =
                                          isSelected ? null : index;
                                    });
                                    if (!isSelected) {
                                      _showVerseActionSheet(
                                          verse, verseKey);
                                    }
                                  },
                                  onLongPress: () {
                                    setState(() {
                                      _selectedVerseIndex = index;
                                      _currentVerse = models.BibleVerse(
                                        number: verse['verse'],
                                        text: verse['text'],
                                      );
                                    });
                                    _showVerseActionSheet(verse, verseKey);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: highlightColor
                                              ?.withValues(alpha: 0.2) ??
                                          (isSelected
                                              ? colorScheme.primary
                                                  .withValues(alpha: 0.1)
                                              : null),
                                      borderRadius:
                                          BorderRadius.circular(8),
                                      border: isSelected
                                          ? Border.all(
                                              color: colorScheme.primary
                                                  .withValues(alpha: 0.3),
                                              width: 1)
                                          : null,
                                    ),
                                    child: RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          color: colorScheme.onSurface,
                                          fontSize: isSmallScreen
                                              ? 16
                                              : (isMediumScreen ? 17 : 18),
                                          height: 1.6,
                                          fontFamily: 'Georgia',
                                        ),
                                        children: [
                                          TextSpan(
                                            text:
                                                '${verse['verse']} ',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: isSmallScreen
                                                  ? 14
                                                  : (isMediumScreen
                                                      ? 15
                                                      : 16),
                                              color: colorScheme.secondary,
                                            ),
                                          ),
                                          TextSpan(
                                              text: verse['text']),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
          ),
        ),

        // Bottom Navigation Bar - Responsive
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 16),
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 16,
                vertical: isSmallScreen ? 8 : 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(50),
              border: Border.all(
                  color: colorScheme.outline.withValues(alpha: 0.2)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSmallScreen
                ? _buildCompactNavigation()
                : _buildFullNavigation(),
          ),
        ),
      ],
    ),
  );
  }

  Widget _buildCompactNavigation() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Previous Chapter Button
        _buildNavButton(
          icon: Icons.arrow_back_ios,
          onTap: _navigateToPreviousChapter,
        ),

        // Book Selector
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _showBookSelector,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _selectedBook.isEmpty ? 'Book' : _selectedBook,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),

        // Chapter Selector
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: _showChapterSelector,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedChapter.toString(),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),

        // Version Chip
        _buildNavChip(
          label: _selectedVersion,
          onTap: _showVersionSelector,
        ),

        const SizedBox(width: 4),

        // Language Dropdown Equivalent
        _buildNavChip(
          label: _selectedLanguage,
          onTap: () => _showLanguageSelector(context),
        ),

        const SizedBox(width: 4),
 
         // Next Chapter Button
        _buildNavButton(
          icon: Icons.arrow_forward_ios,
          onTap: _navigateToNextChapter,
        ),
      ],
    );
  }

  Widget _buildFullNavigation() {
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        // Previous Chapter Button
        _buildNavButton(
          icon: Icons.arrow_back_ios,
          onTap: _navigateToPreviousChapter,
        ),

        const SizedBox(width: 12),

        // Book Selector
        Expanded(
          flex: 2,
          child: GestureDetector(
            onTap: _showBookSelector,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    _selectedBook.isEmpty ? 'Select Book' : _selectedBook,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),

        // Chapter Selector
        Expanded(
          flex: 1,
          child: GestureDetector(
            onTap: _showChapterSelector,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _selectedChapter.toString(),
                  style: TextStyle(
                    color: colorScheme.onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                Icon(
                  Icons.expand_more,
                  size: 18,
                  color: colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(width: 12),

        const SizedBox(width: 12),

        // Version Chip
        _buildNavChip(
          label: _selectedVersion,
          onTap: _showVersionSelector,
        ),

        const SizedBox(width: 8),

        // Language Chip
        _buildNavChip(
          label: _selectedLanguage,
          onTap: () => _showLanguageSelector(context),
        ),

        const SizedBox(width: 12),
 
         // Next Chapter Button
        _buildNavButton(
          icon: Icons.arrow_forward_ios,
          onTap: _navigateToNextChapter,
        ),
      ],
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: colorScheme.secondary,
          size: 18,
        ),
      ),
    );
  }

  /// Chip-styled pill for version/language selectors
  Widget _buildNavChip({
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: colorScheme.secondary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: colorScheme.secondary.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: colorScheme.secondary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 2),
            Icon(
              Icons.arrow_drop_down,
              color: colorScheme.secondary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  void _showBookSelector() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.7 : 0.6),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              child: Text(
                'Select Book',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _books.length,
                itemBuilder: (context, index) {
                  final book = _books[index];
                  final isSelected = book.name == _selectedBook;

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 4 : 8,
                    ),
                    title: Text(
                      book.name,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.secondary,
                            size: isSmallScreen ? 20 : 24,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedBook = book.name;
                        _currentBookIndex = index;
                        _selectedChapter = 1; // Reset to chapter 1
                      });
                      Navigator.pop(context);
                      _loadFullBook();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showChapterSelector() {
    if (_books.isEmpty || _selectedBook.isEmpty) return;
    
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    
    final currentBook = _books[_currentBookIndex];
    final maxChapters = currentBook.chapters;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.6 : 0.5),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              child: Text(
                'Select Chapter',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 5,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: maxChapters,
                itemBuilder: (context, index) {
                  final chapter = index + 1;
                  final isSelected = chapter == _selectedChapter;
                  return InkWell(
                    onTap: () {
                      setState(() {
                        _selectedChapter = chapter;
                      });
                      Navigator.pop(context);
                      _loadChapter();
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.secondary 
                            : Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected
                              ? Theme.of(context).colorScheme.secondary
                              : Theme.of(context).dividerColor,
                        ),
                      ),
                      child: Text(
                        chapter.toString(),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.onSecondary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVersionSelector() {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.5 : 0.4),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              child: Text(
                'Select Bible Version',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _availableVersions.length,
                itemBuilder: (context, index) {
                  final version = _availableVersions[index];
                  final isSelected = version == _selectedVersion;

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 4 : 8,
                    ),
                    title: Text(
                      version,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.secondary,
                            size: isSmallScreen ? 20 : 24,
                          )
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedVersion = version;
                      });
                      Navigator.pop(context);
                      _loadChapter();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    final languages = _languageCodes.keys.toList();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.5 : 0.4),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              child: Text(
                'Select Language',
                style: TextStyle(
                  fontSize: isSmallScreen ? 18 : 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).textTheme.titleLarge?.color,
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: languages.length,
                itemBuilder: (context, index) {
                  final language = languages[index];
                  final isSelected = language == _selectedLanguage;
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                      vertical: isSmallScreen ? 4 : 8,
                    ),
                    title: Text(
                      language,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 14 : 16,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check,
                            color: Theme.of(context).colorScheme.secondary,
                            size: isSmallScreen ? 20 : 24,
                          )
                        : null,
                    onTap: () async {
                      setState(() {
                        _selectedLanguage = language;
                      });
                      Navigator.pop(context);
                      await _loadBooksAndInit();
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchTab() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          color: colorScheme.primary.withValues(alpha: 0.1),
          child: TextField(
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            decoration: InputDecoration(
              labelText: 'Search verses...',
              labelStyle: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
              ),
              prefixIcon: Icon(
                Icons.search,
                size: isSmallScreen ? 20 : 24,
                color: Theme.of(context).iconTheme.color,
              ),
              contentPadding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 12 : 16,
                vertical: isSmallScreen ? 8 : 12,
              ),
            ),
            onChanged: _searchVerses,
          ),
        ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search,
                        size: isSmallScreen ? 48 : 64,
                        color: Theme.of(context)
                            .iconTheme
                            .color
                            ?.withValues(alpha: 0.5),
                      ),
                      SizedBox(height: isSmallScreen ? 12 : 16),
                      Text(
                        'Search for Bible verses',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  itemCount: _searchResults.length,
                  itemBuilder: (context, index) {
                    final verse = _searchResults[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        title: Text(
                          verse.reference,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.secondary,
                          ),
                        ),
                        subtitle: Text(
                          verse.text[_selectedVersion] ??
                              verse.text.values.first,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          _tabController.animateTo(0);
                          _searchController.text = verse.reference;
                          _openReference(verse.reference);
                        },
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildEGWhiteTab() {
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ellen G. White Library',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: colorScheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Access to Ellen G. White writings and commentary on Bible passages.',
            style: TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 24),

          // Popular Books
          const Text(
            'Popular Books:',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ..._getEGWhiteBooks().map((book) => Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.library_books,
                    color: colorScheme.primary,
                  ),
                  title: Text(
                    book['title']!,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(book['description']!),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(book['title']!),
                        content: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                book['description']!,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'This book contains inspiring spiritual content to strengthen your faith and understanding.',
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Close'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      'Opening ${book['title']} reader...'),
                                  backgroundColor: colorScheme.secondary,
                                ),
                              );
                            },
                            child: const Text('Read Book'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              )),

          const SizedBox(height: 24),

          // Search E.G. White
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Search E.G. White Writings',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Search topic or Bible reference...',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.search),
                    ),
                    onSubmitted: (query) {
                      if (query.trim().isEmpty) return;

                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: Text('Search Results for "$query"'),
                          content: const SizedBox(
                            width: double.maxFinite,
                            height: 200,
                            child: Center(
                              child: Text(
                                'E.G. White search functionality will be implemented with API integration.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 16),
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, String>> _getEGWhiteBooks() {
    return [
      {
        'title': 'Steps to Christ',
        'description': 'A guide to finding peace and joy in Jesus Christ.',
      },
      {
        'title': 'The Desire of Ages',
        'description': 'The life and ministry of Jesus Christ.',
      },
      {
        'title': 'The Great Controversy',
        'description': 'The cosmic conflict between good and evil.',
      },
      {
        'title': 'Patriarchs and Prophets',
        'description': 'Stories from the Old Testament.',
      },
      {
        'title': 'The Acts of the Apostles',
        'description': 'The early Christian church and its mission.',
      },
    ];
  }

  // TTS functionality

  /// Save highlights to SharedPreferences
  Future<void> _saveHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _verseHighlightColors.map((key, color) =>
          MapEntry(key, color.toARGB32()));
      await prefs.setString('verse_highlights', json.encode(data));
    } catch (_) {}
  }

  /// Show a bottom sheet with verse actions: highlight colors, copy, bookmark, read aloud, notes
  void _showVerseActionSheet(Map<String, dynamic> verse, String verseKey) {
    final colorScheme = Theme.of(context).colorScheme;
    final reference =
        '$_selectedBook $_selectedChapter:${verse['verse']}';
    final verseText = verse['text'] ?? '';

    final highlightColors = [
      const Color(0xFFFDE68A), // yellow
      const Color(0xFF93C5FD), // blue
      const Color(0xFF6EE7B7), // teal
      const Color(0xFFF9A8D4), // pink
      const Color(0xFFFCA5A5), // red
      const Color(0xFFA5B4FC), // navy/indigo
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Verse reference
              Text(
                reference,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _selectedVersion,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 16),
              // Highlight color circles
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clear highlight button
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _verseHighlightColors.remove(verseKey);
                        _highlightedVerses.remove(verseKey);
                      });
                      _saveHighlights();
                      Navigator.pop(ctx);
                    },
                    child: Container(
                      width: 32,
                      height: 32,
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: colorScheme.onSurface
                                .withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.close,
                          size: 16,
                          color: colorScheme.onSurface
                              .withValues(alpha: 0.5)),
                    ),
                  ),
                  ...highlightColors.map((color) => GestureDetector(
                        onTap: () {
                          setState(() {
                            _verseHighlightColors[verseKey] = color;
                            _highlightedVerses.add(verseKey);
                          });
                          _saveHighlights();
                          Navigator.pop(ctx);
                        },
                        child: Container(
                          width: 32,
                          height: 32,
                          margin:
                              const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _verseHighlightColors[verseKey] ==
                                    color
                                ? Border.all(
                                    color: colorScheme.primary, width: 2)
                                : null,
                          ),
                        ),
                      )),
                ],
              ),
              const SizedBox(height: 20),
              const Divider(height: 1),
              const SizedBox(height: 8),
              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: Icons.copy_outlined,
                    label: 'Copy',
                    onTap: () {
                      Clipboard.setData(ClipboardData(
                          text: '$reference\n$verseText'));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Verse copied!'),
                          backgroundColor: colorScheme.primary,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.bookmark_outline,
                    label: 'Bookmark',
                    onTap: () async {
                      final prefs =
                          await SharedPreferences.getInstance();
                      final bookmarks = prefs.getStringList(
                              'bible_bookmarks') ??
                          [];
                      final entry =
                          '$reference|$verseText|${DateTime.now().toIso8601String()}';
                      if (!bookmarks
                          .any((b) => b.startsWith(reference))) {
                        bookmarks.add(entry);
                        await prefs.setStringList(
                            'bible_bookmarks', bookmarks);
                      }
                      if (ctx.mounted) Navigator.pop(ctx);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Bookmarked!'),
                            backgroundColor: colorScheme.primary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.volume_up_outlined,
                    label: 'Read',
                    onTap: () {
                      setState(() {
                        _currentVerse = models.BibleVerse(
                          number: verse['verse'],
                          text: verseText,
                        );
                      });
                      Navigator.pop(ctx);
                      _speakVerse();
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.note_add_outlined,
                    label: 'Notes',
                    onTap: () {
                      Navigator.pop(ctx);
                      _showNotesDialog(reference, verseText);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: colorScheme.primary, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  void _showNotesDialog(String reference, String verseText) async {
    final prefs = await SharedPreferences.getInstance();
    final existingNote = prefs.getString('note_$reference') ?? '';
    final controller = TextEditingController(text: existingNote);
    final colorScheme = Theme.of(context).colorScheme;

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text('Notes — $reference',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface)),
        content: TextField(
          controller: controller,
          maxLines: 5,
          style: TextStyle(color: colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Write your thoughts...',
            hintStyle: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.4)),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel',
                style: TextStyle(color: colorScheme.onSurface)),
          ),
          ElevatedButton(
            onPressed: () async {
              await prefs.setString('note_$reference', controller.text);
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Note saved!'),
                    backgroundColor: colorScheme.primary,
                  ),
                );
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _speakVerse() async {
    if (_currentVerse == null) return;

    setState(() {
      _isSpeaking = true;
    });

    try {
      final text = _currentVerse!.text;
      await _ttsService.speak(text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error speaking verse: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
      }
    }
  }

}
