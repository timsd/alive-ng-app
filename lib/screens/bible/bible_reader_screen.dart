import 'package:flutter/material.dart';
import '../../utils/error_handler.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
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

class BibleReaderScreen extends ConsumerStatefulWidget {
  final String? initialReference;

  /// Initial tab index: 0 = Reader, 1 = Search, 2 = My Study.
  final int initialTab;

  const BibleReaderScreen({super.key, this.initialReference, this.initialTab = 0});

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

  // My Study State (Notes, Highlights, Bookmarks)
  int _studySubTabIndex = 0; // 0 = Notes, 1 = Highlights, 2 = Bookmarks
  List<Map<String, dynamic>> _userNotes = [];
  List<Map<String, dynamic>> _userHighlights = [];
  List<Map<String, dynamic>> _userBookmarks = [];
  bool _isLoadingStudy = false;
  final TextEditingController _studySearchController = TextEditingController();
  String _studySearchQuery = '';

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
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 2),
    );
    _tabController.addListener(() {
      if (_tabController.index == 2 && !_tabController.indexIsChanging) {
        _loadStudyItems();
      }
    });
    _ttsService.initialize();
    _ttsService.addCompletionListener(_onTtsComplete);
    _statisticsService.startReadingSession();
    _loadHighlights();
    _loadStudyItems();
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
    _studySearchController.dispose();
    _ttsService.removeCompletionListener(_onTtsComplete);
    _ttsService.dispose();
    _statisticsService.stopReadingSession();
    super.dispose();
  }

  void _onTtsComplete() {
    if (mounted && _isSpeaking) {
      setState(() {
        _isSpeaking = false;
      });
    }
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

  Future<void> _loadBooksAndInit({String? targetLanguage, String? targetVersion}) async {
    if (_chapterVerses.isEmpty) {
      setState(() => _isLoading = true);
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (targetLanguage != null && _languageCodes.containsKey(targetLanguage)) {
        _selectedLanguage = targetLanguage;
        await prefs.setString('last_read_bible_language', targetLanguage);
      } else {
        final savedLang = prefs.getString('last_read_bible_language');
        if (savedLang != null && _languageCodes.containsKey(savedLang)) {
          _selectedLanguage = savedLang;
        }
      }

      final languageCode = _languageCodes[_selectedLanguage] ?? 'en';
      _versionsForLanguage = await _resolveVersionsForLanguage(languageCode);

      if (targetVersion != null && _versionsForLanguage.contains(targetVersion)) {
        _selectedVersion = targetVersion;
        await prefs.setString('last_read_bible_version', targetVersion);
      } else {
        final savedVersion = prefs.getString('last_read_bible_version');
        if (savedVersion != null && _versionsForLanguage.contains(savedVersion)) {
          _selectedVersion = savedVersion;
        } else if (!_versionsForLanguage.contains(_selectedVersion)) {
          if (languageCode == 'yo') {
            _selectedVersion = 'BM';
          } else if (languageCode == 'ha') {
            _selectedVersion = 'HAU';
          } else if (languageCode == 'ig') {
            _selectedVersion = 'IGBOB';
          } else if (_versionsForLanguage.contains('KJV')) {
            _selectedVersion = 'KJV';
          } else {
            _selectedVersion = _versionsForLanguage.first;
          }
          await prefs.setString('last_read_bible_version', _selectedVersion);
        }
      }

      final savedBook = prefs.getString('last_read_bible_book');
      final savedChapter = prefs.getInt('last_read_bible_chapter');
      if (savedBook != null && savedBook.isNotEmpty) {
        _selectedBook = savedBook;
      }
      if (savedChapter != null && savedChapter > 0) {
        _selectedChapter = savedChapter;
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
        final canonSelected = BibleData.canonicalBookName(_selectedBook) ?? _selectedBook;
        var bookIdx = _books.indexWhere(
            (b) => b.name.toLowerCase() == _selectedBook.toLowerCase());
        if (bookIdx == -1) {
          bookIdx = _books.indexWhere(
              (b) => (BibleData.canonicalBookName(b.name) ?? b.name).toLowerCase() == canonSelected.toLowerCase());
        }
        _currentBookIndex = bookIdx != -1 ? bookIdx : 0;
        _selectedBook = _books[_currentBookIndex].name;

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
        // Fallback: keep safe default
        _selectedBook = 'Genesis';
        await _loadChapter();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<List<String>> _resolveVersionsForLanguage(String languageCode) async {
    if (languageCode == 'en') {
      return const ['NKJV', 'KJV', 'NIV', 'NLT', 'NASB', 'ASV'];
    }
    if (languageCode == 'ha') {
      return const ['HAU'];
    }
    if (languageCode == 'ig') {
      return const ['IGBOB'];
    }
    if (languageCode == 'yo') {
      return const ['BM'];
    }
    return const ['KJV'];
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

        unawaited(SharedPreferences.getInstance().then((prefs) {
          prefs.setString('last_read_bible_language', _selectedLanguage);
          prefs.setString('last_read_bible_version', _selectedVersion);
          prefs.setString('last_read_bible_book', _selectedBook);
          prefs.setInt('last_read_bible_chapter', _selectedChapter);
        }).catchError((_) {}));
      } else {
        if (_chapterVerses.isEmpty) {
          setState(() {
            _chapterVerses = OfflineBibleService.instantGenesis1Verses;
          });
        }
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

      await _ttsService.speak(
        chapterText,
        languageCode: _selectedLanguage,
        onComplete: _onTtsComplete,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error speaking chapter: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
            content: Text('Error loading verse: ${ErrorHandler.getUserFriendlyMessage(e)}'),
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
        title: 'Bible',
        backgroundColor: headerBgColor,
        foregroundColor: headerTextColor,
        elevation: 0,
        showThemeToggle: false,
        showLanguageToggle: false,
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
            Tab(text: 'My Study'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildReaderTab(),
          _buildSearchTab(),
          _buildMyStudyTab(),
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
                    onTap: () async {
                      setState(() {
                        _selectedVersion = version;
                      });
                      Navigator.pop(context);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setString('last_read_bible_version', version);
                      await _loadChapter();
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

  Future<void> _selectLanguage(String language) async {
    if (_selectedLanguage == language && _chapterVerses.isNotEmpty) return;
    setState(() {
      _selectedLanguage = language;
      _isLoading = true;
    });

    final languageCode = _languageCodes[language] ?? 'en';
    final versions = await _resolveVersionsForLanguage(languageCode);
    _versionsForLanguage = versions;

    String nextVersion = versions.first;
    if (languageCode == 'yo') {
      nextVersion = 'BM';
    } else if (languageCode == 'ha') {
      nextVersion = 'HAU';
    } else if (languageCode == 'ig') {
      nextVersion = 'IGBOB';
    } else if (versions.contains('KJV')) {
      nextVersion = 'KJV';
    }
    _selectedVersion = nextVersion;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_read_bible_language', language);
    await prefs.setString('last_read_bible_version', nextVersion);

    await _loadBooksAndInit(targetLanguage: language, targetVersion: nextVersion);
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
                      Navigator.pop(context);
                      await _selectLanguage(language);
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
                      SharedPreferences.getInstance().then((prefs) {
                        prefs.remove('highlight_$verseKey');
                        prefs.remove('highlight_text_$verseKey');
                        _loadStudyItems();
                      });
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
                          SharedPreferences.getInstance().then((prefs) {
                            prefs.setString('highlight_text_$verseKey', verseText);
                            _loadStudyItems();
                          });
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
                        await _loadStudyItems();
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
              final text = controller.text.trim();
              if (text.isEmpty) {
                await prefs.remove('note_$reference');
                await prefs.remove('note_verse_$reference');
              } else {
                await prefs.setString('note_$reference', text);
                if (verseText.isNotEmpty) {
                  await prefs.setString('note_verse_$reference', verseText);
                }
              }
              await _loadStudyItems();
              if (ctx.mounted) Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(text.isEmpty ? 'Note removed' : 'Note saved!'),
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
      await _ttsService.speak(
        text,
        languageCode: _selectedLanguage,
        onComplete: _onTtsComplete,
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSpeaking = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error speaking verse: ${ErrorHandler.getUserFriendlyMessage(e)}'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  // ==========================================
  // MY STUDY (Notes, Highlights & Bookmarks)
  // ==========================================

  Future<void> _loadStudyItems() async {
    setState(() => _isLoadingStudy = true);
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Bookmarks from 'bible_bookmarks'
      final rawBookmarks = prefs.getStringList('bible_bookmarks') ?? [];
      final parsedBookmarks = <Map<String, dynamic>>[];
      for (final raw in rawBookmarks) {
        final parts = raw.split('|');
        if (parts.isNotEmpty && parts[0].trim().isNotEmpty) {
          final ref = parts[0].trim();
          final text = parts.length > 1 ? parts[1].trim() : '';
          final dateStr = parts.length > 2 ? parts[2].trim() : '';
          DateTime? date;
          if (dateStr.isNotEmpty) {
            date = DateTime.tryParse(dateStr);
          }
          parsedBookmarks.add({
            'reference': ref,
            'text': text.isNotEmpty ? text : (_findVerseInLocalData(ref)?.text ?? 'Bookmarked Scripture'),
            'date': date ?? DateTime.now(),
            'raw': raw,
          });
        }
      }

      // 2. Highlights from _verseHighlightColors & SharedPreferences
      final parsedHighlights = <Map<String, dynamic>>[];
      for (final entry in _verseHighlightColors.entries) {
        final ref = entry.key;
        final color = entry.value;
        final savedText = prefs.getString('highlight_text_$ref');
        final text = (savedText != null && savedText.isNotEmpty)
            ? savedText
            : (_findVerseInLocalData(ref)?.text ?? 'Highlighted Scripture');
        parsedHighlights.add({
          'reference': ref,
          'color': color,
          'text': text,
        });
      }

      // 3. Notes from keys starting with 'note_'
      final noteKeys = prefs
          .getKeys()
          .where((k) => k.startsWith('note_') && !k.startsWith('note_verse_'))
          .toList();
      final parsedNotes = <Map<String, dynamic>>[];
      for (final k in noteKeys) {
        final ref = k.replaceFirst('note_', '');
        final noteText = prefs.getString(k) ?? '';
        if (noteText.trim().isNotEmpty) {
          final verseText = prefs.getString('note_verse_$ref') ??
              _findVerseInLocalData(ref)?.text ??
              '';
          parsedNotes.add({
            'reference': ref,
            'note': noteText,
            'verseText': verseText,
          });
        }
      }

      if (mounted) {
        setState(() {
          _userBookmarks = parsedBookmarks;
          _userHighlights = parsedHighlights;
          _userNotes = parsedNotes;
          _isLoadingStudy = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingStudy = false);
    }
  }

  Future<void> _deleteBookmark(String raw) async {
    final prefs = await SharedPreferences.getInstance();
    final bookmarks = prefs.getStringList('bible_bookmarks') ?? [];
    bookmarks.remove(raw);
    await prefs.setStringList('bible_bookmarks', bookmarks);
    await _loadStudyItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bookmark removed'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteHighlight(String verseKey) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _verseHighlightColors.remove(verseKey);
      _highlightedVerses.remove(verseKey);
    });
    await _saveHighlights();
    await prefs.remove('highlight_$verseKey');
    await prefs.remove('highlight_text_$verseKey');
    await _loadStudyItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Highlight cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _deleteNote(String reference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('note_$reference');
    await prefs.remove('note_verse_$reference');
    await _loadStudyItems();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Note deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildMyStudyTab() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 600;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Column(
        children: [
          // 1. Sub-Tabs Segmented Bar: Notes, Highlights, Bookmarks
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? colorScheme.surface
                  : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              border: Border(
                bottom: BorderSide(
                  color: colorScheme.outlineVariant.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildStudyPill(
                    index: 0,
                    icon: Icons.note_alt_outlined,
                    label: 'Notes',
                    count: _userNotes.length,
                  ),
                  const SizedBox(width: 8),
                  _buildStudyPill(
                    index: 1,
                    icon: Icons.border_color_outlined,
                    label: 'Highlights',
                    count: _userHighlights.length,
                  ),
                  const SizedBox(width: 8),
                  _buildStudyPill(
                    index: 2,
                    icon: Icons.bookmark_border_rounded,
                    label: 'Bookmarks',
                    count: _userBookmarks.length,
                  ),
                ],
              ),
            ),
          ),

          // 2. Search / Filter Field
          Padding(
            padding: EdgeInsets.fromLTRB(
              isSmallScreen ? 12 : 16,
              10,
              isSmallScreen ? 12 : 16,
              6,
            ),
            child: TextField(
              controller: _studySearchController,
              onChanged: (val) {
                setState(() {
                  _studySearchQuery = val.trim().toLowerCase();
                });
              },
              decoration: InputDecoration(
                hintText: _studySubTabIndex == 0
                    ? 'Search notes & reflections...'
                    : _studySubTabIndex == 1
                        ? 'Search highlighted verses...'
                        : 'Search bookmarked scriptures...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _studySearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _studySearchController.clear();
                          setState(() {
                            _studySearchQuery = '';
                          });
                        },
                      )
                    : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.25)
                    : colorScheme.surface,
              ),
            ),
          ),

          // 3. Tab Body
          Expanded(
            child: _isLoadingStudy
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadStudyItems,
                    child: _buildStudyContent(isSmallScreen),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStudyPill({
    required int index,
    required IconData icon,
    required String label,
    required int count,
  }) {
    final isSelected = _studySubTabIndex == index;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: () {
        setState(() {
          _studySubTabIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
                color:
                    isSelected ? colorScheme.onPrimary : colorScheme.onSurface,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? colorScheme.onPrimary.withValues(alpha: 0.25)
                    : colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyContent(bool isSmallScreen) {
    switch (_studySubTabIndex) {
      case 0:
        return _buildNotesList(isSmallScreen);
      case 1:
        return _buildHighlightsList(isSmallScreen);
      case 2:
      default:
        return _buildBookmarksList(isSmallScreen);
    }
  }

  Widget _buildNotesList(bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _studySearchQuery.isEmpty
        ? _userNotes
        : _userNotes.where((item) {
            final ref = (item['reference'] ?? '').toString().toLowerCase();
            final note = (item['note'] ?? '').toString().toLowerCase();
            final verse = (item['verseText'] ?? '').toString().toLowerCase();
            return ref.contains(_studySearchQuery) ||
                note.contains(_studySearchQuery) ||
                verse.contains(_studySearchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyStudyState(
        icon: Icons.note_alt_outlined,
        title: _studySearchQuery.isEmpty
            ? 'No Notes Saved'
            : 'No matching notes found',
        description: _studySearchQuery.isEmpty
            ? 'Tap any verse while reading the Bible and select "Notes" to record personal revelations, insights, and study notes.'
            : 'Try a different search term or book reference.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final reference = item['reference'] as String;
        final note = item['note'] as String;
        final verseText = item['verseText'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openReference(reference),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          reference,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit Note',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _showNotesDialog(reference, verseText),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Delete Note',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteNote(reference),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                      border: Border(
                        left: BorderSide(
                          color: colorScheme.primary,
                          width: 3.5,
                        ),
                      ),
                    ),
                    child: Text(
                      note,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.5 : 14.5,
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                  if (verseText.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“$verseText”',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontSize: 12.5,
                        color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightsList(bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _studySearchQuery.isEmpty
        ? _userHighlights
        : _userHighlights.where((item) {
            final ref = (item['reference'] ?? '').toString().toLowerCase();
            final text = (item['text'] ?? '').toString().toLowerCase();
            return ref.contains(_studySearchQuery) ||
                text.contains(_studySearchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyStudyState(
        icon: Icons.border_color_outlined,
        title: _studySearchQuery.isEmpty
            ? 'No Highlights Yet'
            : 'No matching highlights found',
        description: _studySearchQuery.isEmpty
            ? 'Highlight meaningful verses by tapping any verse in the reader and choosing a color.'
            : 'Try searching for another book or verse.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final reference = item['reference'] as String;
        final color = item['color'] as Color;
        final text = item['text'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openReference(reference),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        reference,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share Highlight',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(text: '$reference\n$text'),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Clear Highlight',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteHighlight(reference),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13.5 : 14.5,
                        height: 1.4,
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBookmarksList(bool isSmallScreen) {
    final colorScheme = Theme.of(context).colorScheme;
    final filtered = _studySearchQuery.isEmpty
        ? _userBookmarks
        : _userBookmarks.where((item) {
            final ref = (item['reference'] ?? '').toString().toLowerCase();
            final text = (item['text'] ?? '').toString().toLowerCase();
            return ref.contains(_studySearchQuery) ||
                text.contains(_studySearchQuery);
          }).toList();

    if (filtered.isEmpty) {
      return _buildEmptyStudyState(
        icon: Icons.bookmark_border_rounded,
        title: _studySearchQuery.isEmpty
            ? 'No Bookmarks Saved'
            : 'No matching bookmarks found',
        description: _studySearchQuery.isEmpty
            ? 'Save verses for fast reference by tapping any verse in the reader and selecting "Bookmark".'
            : 'Try a different search term or book reference.',
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final item = filtered[index];
        final reference = item['reference'] as String;
        final text = item['text'] as String;
        final date = item['date'] as DateTime;
        final raw = item['raw'] as String;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(
              color: colorScheme.outlineVariant.withValues(alpha: 0.45),
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _openReference(reference),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.bookmark_added,
                          size: 18, color: colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        reference,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: colorScheme.primary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('MMM d, y').format(date),
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.65),
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        tooltip: 'Share',
                        visualDensity: VisualDensity.compact,
                        onPressed: () {
                          SharePlus.instance.share(
                            ShareParams(text: '$reference\n$text'),
                          );
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        tooltip: 'Remove Bookmark',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _deleteBookmark(raw),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13.5 : 14.5,
                      height: 1.4,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyStudyState({
    required IconData icon,
    required String title,
    required String description,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: colorScheme.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              icon: const Icon(Icons.auto_stories, size: 18),
              label: const Text('Open Bible Reader'),
              onPressed: () => _tabController.animateTo(0),
            ),
          ],
        ),
      ),
    );
  }
}
