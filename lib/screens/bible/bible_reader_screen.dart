import 'package:flutter/material.dart';
import '../../widgets/custom_app_bar.dart';
import '../../services/bible_source.dart';
import '../../models/bible_models.dart' as models;
import '../../data/bible_verses.dart' as data_bible;
import '../../data/bible_data.dart';
import '../../services/offline_bible_service.dart';

import '../../config/app_config.dart';
import '../../services/tts_service.dart';
import '../../services/user_statistics_service.dart';

class BibleReaderScreen extends StatefulWidget {
  final String? initialReference;

  const BibleReaderScreen({super.key, this.initialReference});

  @override
  State<BibleReaderScreen> createState() => _BibleReaderScreenState();
}

class _BibleReaderScreenState extends State<BibleReaderScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final TTSService _ttsService = TTSService();
  final UserStatisticsService _statisticsService = UserStatisticsService.instance;
  
  String _selectedVersion = 'BM';
  String _selectedBook = '';
  int _selectedChapter = 1;
  final int _selectedVerse = 1;
  models.BibleVerse? _currentVerse;
  List<Map<String, dynamic>> _chapterVerses = [];
  bool _isLoading = false;
  bool _isSpeaking = false;
  List<data_bible.BibleVerse> _searchResults = [];
  // Available versions for the current language, loaded from service
  List<String> _versionsForLanguage = [];
  
  final OfflineBibleService _offlineBible = OfflineBibleService();
  String _selectedLanguage = 'Yoruba';
  final Map<String, String> _languageCodes = {
    'English': 'en',
    'Yoruba': 'yo',
    'Igbo': 'ig',
    'Hausa': 'ha',
  };
  List<models.BibleBook> _books = [];
  int _currentBookIndex = 0;
  List<String> get _availableVersions => _versionsForLanguage.isNotEmpty ? _versionsForLanguage : ['BM'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _ttsService.initialize();
    _statisticsService.startReadingSession();
    
    _loadBooksAndInit();
  }

  Future<void> _loadBooksAndInit() async {
    setState(() => _isLoading = true);
    try {
      final languageCode = _languageCodes[_selectedLanguage] ?? 'en';
      // Load available versions for the selected language
      final versions = await _offlineBible.getAvailableVersions(language: languageCode);
      _versionsForLanguage = versions.map((v) => v.code).toList();
      if (_versionsForLanguage.isNotEmpty) {
        _selectedVersion = _versionsForLanguage.first;
      }
      final books = await _offlineBible.getBibleBooks(language: languageCode);
      if (books.isNotEmpty) {
        _books = books..sort((a, b) => a.order.compareTo(b.order));
        _currentBookIndex = 0;
        _selectedBook = _books[_currentBookIndex].name;
        _selectedChapter = 1;
        await _loadChapter();
      } else {
        // Fallback: keep empty state when no local books available
        _selectedBook = '';
      }
    } finally {
      setState(() => _isLoading = false);
    }
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
    setState(() { _isSpeaking = true; });
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
        setState(() { _isSpeaking = false; });
      }
    }
  }

  Future<void> _stopSpeaking() async {
    await _ttsService.stop();
    if (mounted) {
      setState(() { _isSpeaking = false; });
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
              text: 'Verse not available in local corpus. Please try another verse.',
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
    final verseNum = _parseVerseNumberFromReference(v.reference) ?? _selectedVerse;
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
    
    return Scaffold(
      backgroundColor: colorScheme.primary,
      appBar: CustomAppBar(
        title: 'Bible Reader',
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        showThemeToggle: true,
        showLanguageToggle: true,
        showDonationButton: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: colorScheme.onPrimary,
          labelColor: colorScheme.onPrimary,
          unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.7),
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
    
    return Column(
      children: [
        // Chapter Title - Responsive
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Text(
            _selectedBook.isEmpty
                ? 'Bible Reader'
                : '$_selectedBook ${_selectedChapter.toString()}',
            style: TextStyle(
              color: colorScheme.onPrimary,
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
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ..._chapterVerses.map((verse) => Padding(
                          padding: EdgeInsets.only(bottom: isSmallScreen ? 12 : 16),
                          child: GestureDetector(
                            onLongPress: () {
                              setState(() {
                                _currentVerse = models.BibleVerse(
                                  number: verse['verse'],
                                  text: verse['text'],
                                );
                              });
                              _speakVerse();
                            },
                            child: RichText(
                            text: TextSpan(
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: isSmallScreen ? 16 : (isMediumScreen ? 17 : 18),
                                height: 1.6,
                                fontFamily: 'Georgia',
                              ),
                              children: [
                                TextSpan(
                                  text: '${verse['verse']} ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: isSmallScreen ? 14 : (isMediumScreen ? 15 : 16),
                                    color: colorScheme.primary,
                                  ),
                                ),
                                TextSpan(text: verse['text']),
                              ],
                            ),
                          ),
                        ),
                        )),
                      ],
                    ),
                  ),
          ),
        ),
        
        // Bottom Navigation Bar - Responsive
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 20),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 20, 
              vertical: isSmallScreen ? 12 : 15
            ),
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(50),
              border: Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.1),
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
        
        // Book/Chapter Selector
        Expanded(
          child: GestureDetector(
            onTap: _showBookSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                '$_selectedBook $_selectedChapter',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        
        // Language Selector
        GestureDetector(
          onTap: _showLanguageSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              _selectedLanguage,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Version Selector
        GestureDetector(
          onTap: _showVersionSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Text(
              _selectedVersion,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        // Speak/Stop Chapter (TTS)
        GestureDetector(
          onTap: () {
            if (_isSpeaking) {
              _stopSpeaking();
            } else {
              _speakChapter();
            }
          },
          child: Icon(
            _isSpeaking ? Icons.stop : Icons.volume_up,
            color: colorScheme.onPrimary,
            size: 20,
          ),
        ),
        
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
        
        const SizedBox(width: 20),
        
        // Book Selector
        Expanded(
          child: GestureDetector(
            onTap: _showBookSelector,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                '$_selectedBook $_selectedChapter',
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 20),
        
        // Language Selector
        GestureDetector(
          onTap: _showLanguageSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _selectedLanguage,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        // Version Selector
        GestureDetector(
          onTap: _showVersionSelector,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              _selectedVersion,
              style: TextStyle(
                color: colorScheme.onPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        
        const SizedBox(width: 20),
        // Speak/Stop Chapter (TTS)
        GestureDetector(
          onTap: () {
            if (_isSpeaking) {
              _stopSpeaking();
            } else {
              _speakChapter();
            }
          },
          child: Icon(
            _isSpeaking ? Icons.stop : Icons.volume_up,
            color: colorScheme.onPrimary,
            size: 20,
          ),
        ),
        const SizedBox(width: 20),
        
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
          color: colorScheme.onPrimary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Icon(
          icon,
          color: colorScheme.onPrimary,
          size: 20,
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: isSelected 
                        ? Icon(
                            Icons.check, 
                            color: Theme.of(context).colorScheme.primary,
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: isSelected 
                        ? Icon(
                            Icons.check, 
                            color: Theme.of(context).colorScheme.primary,
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

    void _showLanguageSelector() {
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
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                            ? Theme.of(context).colorScheme.primary 
                            : Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      trailing: isSelected 
                        ? Icon(
                            Icons.check, 
                            color: Theme.of(context).colorScheme.primary,
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
                          color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.5),
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
                              color: colorScheme.primary,
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
                            final parsed = BibleData.parseReference(verse.reference);
                            if (parsed['isValid']) {
                              setState(() {
                                _selectedBook = parsed['book'];
                                _selectedChapter = parsed['chapter'];
                              });
                              _loadChapter();
                              _loadVerse(verse.reference);
                            }
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
                                    content: Text('Opening ${book['title']} reader...'),
                                    backgroundColor: colorScheme.primary,
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




