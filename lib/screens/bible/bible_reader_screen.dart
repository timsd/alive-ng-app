import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/bible_source.dart';
import '../../models/bible_models.dart' as models;
import '../../constants/bible_data.dart';
import '../../services/offline_bible_service.dart';
import '../../utils/search_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../../config/app_config.dart';
import '../../services/tts_service.dart';
import '../../services/user_statistics_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/bible_database_helper.dart';

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

  String _selectedVersion = 'KJV';
  String _selectedBook = 'Genesis';
  int _selectedChapter = 1;
  final int _selectedVerse = 1;
  models.BibleVerse? _currentVerse;
  List<models.BibleVerse> _chapterVerses =
      OfflineBibleService.instantGenesis1Verses;
  bool _isLoading = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _formKey = GlobalKey();

  // Search-related state
  bool _isSpeaking = false;
  List<BibleTextHit> _fullTextResults = [];
  bool _isSearching = false;
  int _searchToken = 0;
  Timer? _searchDebounceTimer;
  int? _selectedVerseIndex;
  Set<String> _highlightedVerses = {};
  Map<String, Color> _verseHighlightColors = {};
  // Search-result jump: per-verse layout keys + flash highlight state.
  final Map<int, GlobalKey> _verseKeys = {};
  int? _flashVerseNumber;
  Timer? _flashTimer;
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
    _tabController = TabController(length: 2, vsync: this);
    _ttsService.initialize();
    _statisticsService.startReadingSession();
    _loadHighlights();
    _loadBooksAndInit();
    // Prewarm only the default KJV bundle; full search indexes are built
    // lazily per selected version on first search to keep startup fast.
    _offlineBible.prewarmBundle(language: 'en', version: 'KJV');
    // Auto-scroll to the form/search section after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToForm();
    });
  }

  /// Auto-scroll to the form section so users see the input immediately
  void _scrollToForm() {
    if (_scrollController.hasClients && _formKey.currentContext != null) {
      Scrollable.ensureVisible(
        _formKey.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  @override
  void dispose() {
    _flashTimer?.cancel();
    _searchDebounceTimer?.cancel();
    _scrollController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    _ttsService.dispose();
    _statisticsService.stopReadingSession();
    super.dispose();
  }

  Future<void> _loadHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final newHighlightColors = <String, Color>{};
      final newHighlightedVerses = <String>{};

      final savedBlob = prefs.getString('verse_highlights');
      if (savedBlob != null && savedBlob.isNotEmpty) {
        final decoded = json.decode(savedBlob);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            final colorValue =
                value is int ? value : int.tryParse(value?.toString() ?? '');
            if (colorValue != null) {
              final verseKey = key.toString();
              newHighlightColors[verseKey] = Color(colorValue);
              newHighlightedVerses.add(verseKey);
            }
          });
        }
      }

      final keys = prefs.getKeys().where((k) => k.startsWith('highlight_'));
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
    if (_chapterVerses.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final languageCode = _languageCodes[_selectedLanguage] ?? 'en';
      _versionsForLanguage = await _resolveVersionsForLanguage(languageCode);

      if (_versionsForLanguage.isNotEmpty &&
          !_versionsForLanguage.contains(_selectedVersion)) {
        if (_versionsForLanguage.contains('KJV')) {
          _selectedVersion = 'KJV';
        } else {
          _selectedVersion = _versionsForLanguage.first;
        }
      }

      final books = await _offlineBible.getBibleBooks(language: languageCode);
      if (books.isNotEmpty) {
        // Reorder books according to BibleData.allBooks
        final orderMap = {
          for (var i = 0; i < BibleData.allBooks.length; i++)
            BibleData.allBooks[i]: i
        };
        books.sort((a, b) {
          final orderA = orderMap[a.name];
          final orderB = orderMap[b.name];
          if (orderA != null && orderB != null) {
            return orderA.compareTo(orderB);
          }
          return a.order.compareTo(b.order);
        });
        _books = books;
        final bookIdx = _books.indexWhere(
            (b) => b.name.toLowerCase() == _selectedBook.toLowerCase());
        _currentBookIndex = bookIdx != -1 ? bookIdx : 0;
        _selectedBook = _books[_currentBookIndex].name;

        if (widget.initialReference != null && !_didApplyInitialReference) {
          final applied = await _openReference(widget.initialReference!);
          _didApplyInitialReference = true;
          if (!applied) {
            await _loadChapter();
          }
        } else if (_chapterVerses.isEmpty ||
            _selectedBook != 'Genesis' ||
            _selectedChapter != 1) {
          await _loadChapter();
        }
      } else {
        // Fallback: keep empty state when no local books available
        _selectedBook = '';
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<String>> _resolveVersionsForLanguage(String languageCode) async {
    if (languageCode == 'en') {
      // Start with NLT so users see it first, then verify which versions
      // actually have chapters on-device and prefer available ones.
      const preferredOrder = ['NLT', 'KJV', 'NIV', 'NKJV', 'NASB', 'ASV'];
      try {
        final available =
            await _offlineBible.getAvailableVersionCodesFromAssets('en');
        if (available.isNotEmpty) {
          final List<String> ordered = <String>[
            ...preferredOrder.where(available.contains),
            ...available.where((v) => !preferredOrder.contains(v)),
          ];
          return ordered;
        }
      } catch (_) {}
      return preferredOrder;
    }
    if (languageCode == 'ha') {
      // Filter against the database like English does. HAU is listed in
      // bible_versions but ships with zero chapters, so returning it
      // unconditionally gave an empty reader and made every Hausa search
      // return nothing.
      return await _resolveFromDatabase(['HAU']);
    }
    if (languageCode == 'ig') {
      return await _resolveFromDatabase(['IGBOB']);
    }
    if (languageCode == 'yo') {
      return await _resolveFromDatabase(['BM']);
    }

    final versions =
        await _offlineBible.getAvailableVersions(language: languageCode);
    return versions.map((v) => v.code).toList();
  }

  /// Keeps only the given version codes that actually have verse text.
  ///
  /// Falls back to the requested list if the database cannot be read, so a
  /// failure here degrades to the old behaviour rather than an empty reader.
  Future<List<String>> _resolveFromDatabase(List<String> codes) async {
    try {
      final present = await BibleDatabaseHelper().getLoadedVersionCodes();
      if (present.isEmpty) return codes;
      return codes.where(present.contains).toList();
    } catch (_) {
      return codes;
    }
  }

  Future<bool> _openReference(String reference) async {
    final parsed = BibleData.parseReference(reference);
    if (parsed['isValid'] != true) {
      await _loadVerse(reference);
      return false;
    }

    final parsedBook = parsed['book'] as String;
    final parsedChapter = parsed['chapter'] as int;
    final parsedVerse = (parsed['verse'] as int?) ??
        _parseVerseNumberFromReference(reference) ??
        1;
    final hasExactBook = _books.any((book) => book.name == parsedBook);

    // Search results / references use English book names. If the current
    // language cannot resolve the book, fall back to English — then CONTINUE
    // resolving so the user still lands on the verse (previously this left
    // them on Genesis 1).
    if (!hasExactBook && _selectedLanguage != 'English') {
      setState(() {
        _selectedLanguage = 'English';
      });
      await _loadBooksAndInit();
    }

    var targetIndex = _books.indexWhere(
        (book) => book.name.toLowerCase() == parsedBook.toLowerCase());
    if (targetIndex == -1) {
      targetIndex = _books.indexWhere((book) =>
          BibleData.canonicalBookName(book.name)?.toLowerCase() ==
          parsedBook.toLowerCase());
    }
    if (targetIndex == -1) {
      await _loadVerse(reference);
      return false;
    }

    setState(() {
      _currentBookIndex = targetIndex;
      _selectedBook = _books[targetIndex].name;
      _selectedChapter = parsedChapter;
    });

    await _loadChapter(targetVerseNumber: parsedVerse);
    if (!mounted) return true;

    // Standard bible-app behaviour: return to the Reader tab and auto-scroll
    // so the exact verse is in view, briefly flashing it.
    if (_tabController.index != 0) {
      _tabController.animateTo(0);
      await Future.delayed(const Duration(milliseconds: 320));
    }

    final matches =
        _chapterVerses.where((v) => v.number == parsedVerse).toList();
    if (matches.isNotEmpty) {
      setState(() {
        _currentVerse =
            models.BibleVerse(number: parsedVerse, text: matches.first.text);
      });
      await _scrollToVerse(parsedVerse);
    } else {
      // Verse not present in the loaded chapter (e.g. beyond chapter end) —
      // fall back to the single-verse loader.
      await _loadVerse(reference);
    }
    return true;
  }

  /// Scrolls the reader so [verseNumber] is in view and flashes it briefly —
  /// the same pattern YouVersion/Blue Letter Bible use for search jumps.
  Future<void> _scrollToVerse(int verseNumber) async {
    // Wait for frame rendering so widget context and layout keys are ready
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;

    BuildContext? ctx = _verseKeys[verseNumber]?.currentContext;
    if (ctx == null || !ctx.mounted) {
      await Future.delayed(const Duration(milliseconds: 120));
      if (!mounted) return;
      ctx = _verseKeys[verseNumber]?.currentContext;
    }

    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic,
        alignment: 0.12,
      );
    } else if (_scrollController.hasClients && _chapterVerses.isNotEmpty) {
      final verseIndex =
          _chapterVerses.indexWhere((v) => v.number == verseNumber);
      if (verseIndex >= 0) {
        final total = _chapterVerses.length;
        final targetOffset =
            (verseIndex / total) * _scrollController.position.maxScrollExtent;
        await _scrollController.animateTo(
          targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOutCubic,
        );
      }
    }
    if (!mounted) return;
    _flashTimer?.cancel();
    setState(() => _flashVerseNumber = verseNumber);
    _flashTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _flashVerseNumber = null);
    });
  }

  Future<void> _loadChapter({int? targetVerseNumber}) async {
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
          _chapterVerses = chapter.verses;
          // Rebuild per-verse keys for the new chapter and clear any
          // previous search-jump flash unless targeting a verse.
          _verseKeys.clear();
          if (targetVerseNumber == null) {
            _flashVerseNumber = null;
          }
        });
        // Chapter navigation should start at the top only when not jumping to verse
        if (targetVerseNumber == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(0);
            }
          });
        }
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
            content: const Text(
                'This chapter is not available in the selected Bible version. Try another version or language.'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
          .map((v) => 'Verse ${v.number}. ${v.text}')
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

  void _searchVerses(String query, {bool immediate = false}) {
    _searchDebounceTimer?.cancel();
    final trimmed = query.trim();
    _refreshClearButton();

    if (trimmed.isEmpty) {
      setState(() {
        _fullTextResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    if (immediate) {
      _executeSearch(trimmed);
    } else {
      _searchDebounceTimer = Timer(const Duration(milliseconds: 250), () {
        _executeSearch(trimmed);
      });
    }
  }

  Future<void> _executeSearch(String query) async {
    final token = ++_searchToken;
    final languageCode = _languageCodes[_selectedLanguage] ?? 'en';

    // Full ranked text search across ALL bundled chapters (~31,000 verses)
    // for the currently selected version.
    List<BibleTextHit> ranked = [];
    try {
      ranked = await _offlineBible.searchBibleText(
        query: query,
        version: _selectedVersion,
        language: languageCode,
        limit: 50,
      );
    } catch (_) {
      ranked = [];
    }

    if (token != _searchToken || !mounted) return;
    setState(() {
      _fullTextResults = ranked;
      _isSearching = false;
    });
  }

  bool _wasSearchEmpty = true;

  void _refreshClearButton() {
    final isEmpty = _searchController.text.isEmpty;
    if (isEmpty != _wasSearchEmpty && mounted) {
      _wasSearchEmpty = isEmpty;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final headerBgColor = isDark ? colorScheme.surface : colorScheme.primary;
    final headerTextColor =
        isDark ? colorScheme.onSurface : colorScheme.onPrimary;

    return Scaffold(
      backgroundColor: headerBgColor,
      appBar: CustomAppBar(
        showBackButton: true,
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
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReaderTab(),
          _buildSearchTab(),
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
    final headerTextColor =
        isDark ? colorScheme.onSurface : colorScheme.onPrimary;

    return Container(
      color: headerBgColor,
      child: Column(
        children: [
          // Chapter Title - Responsive
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 6 : 10,
            ),
            child: Text(
              _selectedBook.isEmpty 
                  ? 'Bible Reader' 
                  : '$_selectedBook $_selectedChapter',
              style: TextStyle(
                color: headerTextColor,
                fontSize: isSmallScreen ? 20 : (isMediumScreen ? 22 : 24),
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
              margin: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 12),
              padding: EdgeInsets.all(isSmallScreen ? 10 : 16),
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
                                      : 'No verses found for $_selectedBook $_selectedChapter yet. Try switching version or language.',
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
                          controller: _scrollController,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ..._chapterVerses.asMap().entries.map((entry) {
                                final index = entry.key;
                                final verse = entry.value;
                                final isSelected = _selectedVerseIndex == index;
                                final verseKey =
                                    '$_selectedBook:$_selectedChapter:${verse.number}';
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
                                        _showVerseActionSheet(verse, verseKey);
                                      }
                                    },
                                    onLongPress: () {
                                      setState(() {
                                        _selectedVerseIndex = index;
                                        _currentVerse = verse;
                                      });
                                      _showVerseActionSheet(verse, verseKey);
                                    },
                                    child: Container(
                                      key: _verseKeys.putIfAbsent(
                                          verse.number, () => GlobalKey()),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _flashVerseNumber == verse.number
                                            ? colorScheme.primary
                                                .withValues(alpha: 0.22)
                                            : highlightColor?.withValues(
                                                    alpha: 0.2) ??
                                                (isSelected
                                                    ? colorScheme.primary
                                                        .withValues(alpha: 0.1)
                                                    : null),
                                        borderRadius: BorderRadius.circular(8),
                                        border: _flashVerseNumber ==
                                                verse.number
                                            ? Border.all(
                                                color: colorScheme.primary,
                                                width: 1.5,
                                              )
                                            : isSelected
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
                                              text: '${verse.number} ',
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
                                            TextSpan(text: verse.text),
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
            padding: EdgeInsets.all(isSmallScreen ? 4 : 8),
            child: Container(
              padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 14,
                  vertical: isSmallScreen ? 6 : 8),
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.7 : 0.6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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

  void _showChapterSelector() {
    if (_books.isEmpty || _selectedBook.isEmpty) return;

    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    final currentBook = _books[_currentBookIndex];
    final maxChapters = currentBook.chapters;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.6 : 0.5),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
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
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.5 : 0.4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      isScrollControlled: true,
      builder: (context) => Container(
        height: screenHeight * (isSmallScreen ? 0.5 : 0.4),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
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
    final hasSearched = _searchController.text.trim().isNotEmpty;

    return Container(
      color: colorScheme.surface,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.7),
                ),
              ),
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                color: colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Search verses...',
                labelStyle: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                hintText: 'Type a verse, phrase, or keyword',
                hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                filled: true,
                fillColor: colorScheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 12),
                  borderSide:
                      BorderSide(color: colorScheme.primary, width: 1.4),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: isSmallScreen ? 20 : 24,
                  color: colorScheme.onSurfaceVariant,
                ),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        color: colorScheme.onSurfaceVariant,
                        onPressed: () {
                          _searchController.clear();
                          _searchVerses('');
                        },
                      ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 12 : 16,
                  vertical: isSmallScreen ? 8 : 12,
                ),
              ),
              onChanged: (val) => _searchVerses(val),
              onSubmitted: (value) {
                if (value.trim().isNotEmpty) _searchVerses(value, immediate: true);
              },
            ),
          ),
        Expanded(
          child: (_isSearching && _fullTextResults.isEmpty)
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Searching all ~31,000 verses in $_selectedVersion...',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 15,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                )
              : (_fullTextResults.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              size: isSmallScreen ? 48 : 64,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.5),
                            ),
                            SizedBox(height: isSmallScreen ? 12 : 16),
                            Text(
                              hasSearched
                                  ? 'No verses found for "${_searchController.text.trim()}" in $_selectedVersion ($_selectedLanguage).\nTry another keyword, phrase, or reference.'
                                  : 'Search across all verses in $_selectedVersion\n',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14 : 16,
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView(
                      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12, left: 4),
                          child: Text(
                            '${_fullTextResults.length} matches found in $_selectedVersion · $_selectedLanguage',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: isSmallScreen ? 13 : 14,
                              color: colorScheme.primary,
                            ),
                          ),
                        ),
                        ..._fullTextResults.map((hit) {
                          final hits = SearchUtils.highlightSpans(
                            hit.text,
                            _searchController.text,
                            TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: isSmallScreen ? 14 : 15,
                              height: 1.35,
                            ),
                            TextStyle(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              backgroundColor: colorScheme.primary
                                  .withValues(alpha: 0.15),
                            ),
                          );
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                hit.reference,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: colorScheme.primary,
                                ),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      color: colorScheme.onSurface,
                                      fontSize: isSmallScreen ? 14 : 15,
                                      height: 1.35,
                                    ),
                                    children: hits,
                                  ),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  softWrap: true,
                                ),
                              ),
                              trailing: Icon(
                                Icons.arrow_forward_ios,
                                size: 14,
                                color: colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.6),
                              ),
                              onTap: () {
                                _openReference(hit.reference);
                              },
                            ),
                          );
                        }),
                      ],
                    )),
        ),
      ],
      ),
    );
  }


  // TTS functionality

  /// Save highlights to SharedPreferences
  Future<void> _saveHighlights() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _verseHighlightColors
          .map((key, color) => MapEntry(key, color.toARGB32()));
      await prefs.setString('verse_highlights', json.encode(data));
      final oldKeys =
          prefs.getKeys().where((k) => k.startsWith('highlight_')).toList();
      for (final key in oldKeys) {
        await prefs.remove(key);
      }
      for (final entry in _verseHighlightColors.entries) {
        await prefs.setInt('highlight_${entry.key}', entry.value.toARGB32());
      }
    } catch (_) {}
  }

  /// Show a bottom sheet with verse actions: highlight colors, copy, bookmark, read aloud, notes
  void _showVerseActionSheet(models.BibleVerse verse, String verseKey) {
    final colorScheme = Theme.of(context).colorScheme;
    final reference = '$_selectedBook $_selectedChapter:${verse.number}';
    final verseText = verse.text;

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
                            color:
                                colorScheme.onSurface.withValues(alpha: 0.3)),
                      ),
                      child: Icon(Icons.close,
                          size: 16,
                          color: colorScheme.onSurface.withValues(alpha: 0.5)),
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
                          margin: const EdgeInsets.symmetric(horizontal: 6),
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                            border: _verseHighlightColors[verseKey] == color
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
                      Clipboard.setData(
                          ClipboardData(text: '$reference\n$verseText'));
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
                    icon: Icons.share_outlined,
                    label: 'Share',
                    onTap: () {
                      Navigator.pop(ctx);
                      SharePlus.instance.share(
                        ShareParams(text: '$reference\n$verseText'),
                      );
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.bookmark_outline,
                    label: 'Bookmark',
                    onTap: () async {
                      final prefs = await SharedPreferences.getInstance();
                      final bookmarks =
                          prefs.getStringList('bible_bookmarks') ?? [];
                      final entry =
                          '$reference|$verseText|${DateTime.now().toIso8601String()}';
                      if (!bookmarks.any((b) => b.startsWith(reference))) {
                        bookmarks.add(entry);
                        await prefs.setStringList('bible_bookmarks', bookmarks);
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
                        _currentVerse = verse;
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

    if (!mounted) return;
    final colorScheme = Theme.of(context).colorScheme;

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
            hintStyle:
                TextStyle(color: colorScheme.onSurface.withValues(alpha: 0.4)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child:
                Text('Cancel', style: TextStyle(color: colorScheme.onSurface)),
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
