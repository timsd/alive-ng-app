import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/interactive_lessons_service.dart';
import '../../services/pdf_extractor_service.dart';

class InteractiveLessonReaderScreen extends StatefulWidget {
  final InteractiveLessonItem? lesson;
  final String? lessonId;
  final String? title;
  final Map<String, dynamic>? lessonData;

  const InteractiveLessonReaderScreen({
    super.key,
    this.lesson,
    this.lessonId,
    this.title,
    this.lessonData,
  });

  @override
  State<InteractiveLessonReaderScreen> createState() =>
      _InteractiveLessonReaderScreenState();
}

class _InteractiveLessonReaderScreenState
    extends State<InteractiveLessonReaderScreen> {
  // Brand Emerald & Gold Design System Colors (from Lesson HTML / Design System)
  static const Color _brandDeep = Color(0xFF032B20);
  static const Color _brand900 = Color(0xFF064E3B);
  static const Color _brand800 = Color(0xFF14532D);
  static const Color _brand700 = Color(0xFF166534);
  static const Color _brand50 = Color(0xFFF0FDF4);
  static const Color _gold500 = Color(0xFFEAB308);
  static const Color _gold400 = Color(0xFFFACC15);
  static const Color _bgSurface = Color(0xFFF5F7F5);

  late InteractiveLessonItem _resolvedLesson;
  late List<ExtractedLessonSection> _sections;
  late Map<String, dynamic> _lessonJson;
  late String _enquiryPhone;
  late String _heroVerse;
  late String _heroVerseRef;
  late String _introHeading;
  late String _introText;
  late String _introHighlight;
  late List<Map<String, String>> _decisionQuestions;
  late String _decisionQuote;
  late String _commitmentTitle;
  late String _commitmentText;

  // Interactive User State (Persisted to SharedPreferences)
  final Map<String, TextEditingController> _textControllers = {};
  final Map<String, bool> _checkboxStates = {};
  final Map<String, bool?> _decisionStates = {};
  final Map<int, String> _tableSearchQueries = {};
  bool _commitmentChecked = false;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  double _completionRatio = 0.0;
  bool _showSavedBanner = false;

  String get _storageKey => 'alive_nigeria_notes_${_resolvedLesson.id}';

  @override
  void initState() {
    super.initState();
    _resolveLessonItem();
    _initializeLessonStructure();
    _loadSavedUserNotes();
  }

  void _resolveLessonItem() {
    if (widget.lesson != null) {
      _resolvedLesson = widget.lesson!;
    } else if (widget.lessonData != null) {
      _resolvedLesson = InteractiveLessonItem.fromJson(widget.lessonData!);
    } else {
      final serviceLessons = InteractiveLessonsService.instance.lessons;
      final found = serviceLessons.firstWhere(
        (l) => l.id == widget.lessonId,
        orElse: () => InteractiveLessonItem(
          id: widget.lessonId ?? 'lesson_something_we_can_trust',
          title: widget.title ?? 'Lesson 1: Something We Can Trust',
          description: '',
          category: 'Bible Study',
          level: 'Beginner',
          duration: '30 min',
          content: '',
        ),
      );
      _resolvedLesson = found;
    }
  }

  @override
  void dispose() {
    for (final c in _textControllers.values) {
      c.dispose();
    }
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _initializeLessonStructure() {
    // 1. Load pre-parsed interactiveSections if available; otherwise parse on the fly
    if (_resolvedLesson.interactiveSections.isNotEmpty) {
      _sections = _resolvedLesson.interactiveSections
          .map((m) => ExtractedLessonSection.fromJson(m))
          .toList();
    } else {
      final extracted = PdfExtractorService().structureAsWordPressContent(
        _resolvedLesson.content,
        fallbackTitle: _resolvedLesson.title,
      );
      _sections = extracted.interactiveSections;
      _lessonJson = extracted.lessonJson;
    }

    _lessonJson = _resolvedLesson.lessonJson ??
        PdfExtractorService()
            .structureAsWordPressContent(
              _resolvedLesson.content,
              fallbackTitle: _resolvedLesson.title,
            )
            .lessonJson;

    _enquiryPhone = (_lessonJson['phone'] ?? '07014331481').toString();

    final heroMap = _lessonJson['hero'] is Map
        ? Map<String, dynamic>.from(_lessonJson['hero'] as Map)
        : <String, dynamic>{};
    _heroVerse = (heroMap['verse'] ??
            (_sections.isNotEmpty && _sections.first.verseQuotes.isNotEmpty
                ? _sections.first.verseQuotes.first['quote']
                : 'Thy word is a lamp unto my feet, and a light unto my path.'))
        .toString();
    _heroVerseRef = (heroMap['verse_ref'] ??
            (_sections.isNotEmpty && _sections.first.verseQuotes.isNotEmpty
                ? _sections.first.verseQuotes.first['reference']
                : 'Psalms 119:105'))
        .toString();

    final introMap = _lessonJson['intro'] is Map
        ? Map<String, dynamic>.from(_lessonJson['intro'] as Map)
        : <String, dynamic>{};
    _introHeading =
        (introMap['heading'] ?? 'The Great Question of Our Age').toString();
    _introText = (introMap['text'] ?? _resolvedLesson.description).toString();
    _introHighlight = (introMap['highlight'] ?? '').toString();

    final decisionMap = _lessonJson['decision'] is Map
        ? Map<String, dynamic>.from(_lessonJson['decision'] as Map)
        : <String, dynamic>{};
    _decisionQuote = (decisionMap['quote'] ??
            'We have seen that the Bible is no ordinary book. It is inspired. It can change lives for it has changed my life and yours can be changed right now if you believe.')
        .toString();

    final rawDecQuestions = decisionMap['questions'];
    if (rawDecQuestions is List && rawDecQuestions.isNotEmpty) {
      _decisionQuestions = rawDecQuestions.whereType<Map>().map((q) {
        return {
          'id': (q['id'] ?? 'dec_1').toString(),
          'text': (q['text'] ?? '').toString(),
        };
      }).toList();
    } else {
      _decisionQuestions = [
        {'id': 'haveBible', 'text': 'Do you have a Bible?'},
        {'id': 'studyBible', 'text': 'Do you study the Bible?'},
        {'id': 'believeBible', 'text': 'Do you believe the Bible?'},
      ];
    }

    for (final q in _decisionQuestions) {
      _decisionStates[q['id']!] = null;
    }

    final commitMap = decisionMap['commitment'] is Map
        ? Map<String, dynamic>.from(decisionMap['commitment'] as Map)
        : <String, dynamic>{};
    _commitmentTitle =
        (commitMap['title'] ?? 'My Study Commitment:').toString();
    _commitmentText = (commitMap['text'] ??
            'You can commit to the study of the Bible from today. Would you like to ask God for power and enabling strength for a prayerful study of the Bible?')
        .toString();

    // Initialize controllers for all section reflections and QA sub-questions
    for (final s in _sections) {
      if (s.hasInputTarget) {
        final ctrl = TextEditingController();
        ctrl.addListener(_recalculateProgress);
        _textControllers['q_${s.number}'] = ctrl;
      }
      for (final qa in s.qaItems) {
        final letter = qa['letter'] ?? 'A';
        final key = 'q_${s.number}_${letter.toLowerCase()}';
        final ctrl = TextEditingController();
        ctrl.addListener(_recalculateProgress);
        _textControllers[key] = ctrl;
      }
      for (int i = 0; i < s.checklistItems.length; i++) {
        _checkboxStates['chk_${s.number}_$i'] = false;
      }
      for (int i = 0; i < s.steps.length; i++) {
        _checkboxStates['step_${s.number}_$i'] = false;
      }
      if (s.tableData != null) {
        final rows = (s.tableData!['rows'] as List?) ?? const [];
        for (int r = 0; r < rows.length; r++) {
          _checkboxStates['tbl_${s.number}_$r'] = false;
        }
      }
    }
  }

  Future<void> _loadSavedUserNotes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw == null || raw.isEmpty) {
        _recalculateProgress();
        return;
      }
      final data = jsonDecode(raw) as Map<String, dynamic>;

      final fields = data['fields'] as Map<String, dynamic>? ?? {};
      fields.forEach((key, val) {
        if (_textControllers.containsKey(key)) {
          _textControllers[key]!.text = val?.toString() ?? '';
        }
      });

      final checks = data['checkboxes'] as Map<String, dynamic>? ?? {};
      checks.forEach((key, val) {
        if (_checkboxStates.containsKey(key)) {
          _checkboxStates[key] = val == true;
        }
      });

      final decisions = data['decisions'] as Map<String, dynamic>? ?? {};
      decisions.forEach((key, val) {
        if (_decisionStates.containsKey(key) && val is bool) {
          _decisionStates[key] = val;
        }
      });

      _commitmentChecked = data['commitment'] == true;
      _nameController.text = (data['userName'] ?? '').toString();
      _phoneController.text = (data['userPhone'] ?? '').toString();

      if (mounted) {
        setState(() {});
        _recalculateProgress();
      }
    } catch (e) {
      debugPrint('Could not load saved lesson notes: $e');
    }
  }

  void _recalculateProgress() {
    int totalItems = _textControllers.length + _decisionStates.length + 1;
    int completedItems = 0;

    for (final c in _textControllers.values) {
      if (c.text.trim().isNotEmpty) completedItems++;
    }
    for (final d in _decisionStates.values) {
      if (d != null) completedItems++;
    }
    if (_commitmentChecked) completedItems++;

    if (_checkboxStates.isNotEmpty) {
      totalItems += 3;
      final checkedCount =
          _checkboxStates.values.where((v) => v == true).length;
      completedItems += checkedCount.clamp(0, 3);
    }

    final ratio =
        totalItems > 0 ? (completedItems / totalItems).clamp(0.0, 1.0) : 0.0;
    if ((ratio - _completionRatio).abs() > 0.005 && mounted) {
      setState(() {
        _completionRatio = ratio;
      });
      InteractiveLessonsService.instance
          .updateLessonProgress(_resolvedLesson.id, ratio);
    }
  }

  Future<void> _saveProgressLocally() async {
    final payload = {
      'lessonId': _resolvedLesson.id,
      'lessonTitle': _resolvedLesson.title,
      'fields': {
        for (final entry in _textControllers.entries)
          entry.key: entry.value.text.trim(),
      },
      'checkboxes': _checkboxStates,
      'decisions': _decisionStates,
      'commitment': _commitmentChecked,
      'userName': _nameController.text.trim(),
      'userPhone': _phoneController.text.trim(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(payload));
    await InteractiveLessonsService.instance
        .updateLessonProgress(_resolvedLesson.id, _completionRatio);

    if (!mounted) return;
    setState(() {
      _showSavedBanner = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showSavedBanner = false;
        });
      }
    });
  }

  Future<void> _exportStudySummary() async {
    await _saveProgressLocally();
    final buf = StringBuffer();
    buf.writeln('==================================================');
    buf.writeln('ALIVE NIGERIA SERIES • WHAT THE BIBLE SAYS');
    buf.writeln(_resolvedLesson.title.toUpperCase());
    buf.writeln('==================================================\n');

    for (final s in _sections) {
      buf.writeln('${s.number}. ${s.title}');
      for (final v in s.verseQuotes) {
        buf.writeln('   "${v['quote']}" — ${v['reference']}');
      }
      final note = _textControllers['q_${s.number}']?.text.trim() ?? '';
      if (note.isNotEmpty) {
        buf.writeln('   My Reflection: $note');
      }
      for (final qa in s.qaItems) {
        final letter = qa['letter'] ?? 'A';
        final qaNote =
            _textControllers['q_${s.number}_${letter.toLowerCase()}']
                    ?.text
                    .trim() ??
                '';
        if (qaNote.isNotEmpty) {
          buf.writeln('   [$letter] ${qa['question']}: $qaNote');
        }
      }
      buf.writeln();
    }

    buf.writeln('--- PERSONAL COMMITMENT ---');
    for (final q in _decisionQuestions) {
      final ans = _decisionStates[q['id']!];
      final ansLabel = ans == null ? 'Not answered' : (ans ? 'YES' : 'NO');
      buf.writeln('${q['text']} -> $ansLabel');
    }
    buf.writeln('Prayer Commitment Checked: ${_commitmentChecked ? "YES" : "NO"}');
    if (_nameController.text.trim().isNotEmpty) {
      buf.writeln('Name: ${_nameController.text.trim()}');
    }
    if (_phoneController.text.trim().isNotEmpty) {
      buf.writeln('Phone: ${_phoneController.text.trim()}');
    }

    await Clipboard.setData(ClipboardData(text: buf.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Study Summary copied to clipboard & saved to your device!',
        ),
        backgroundColor: _brand700,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pct = (_completionRatio * 100).round();

    return Scaffold(
      backgroundColor: _bgSurface,
      body: SafeArea(
        child: Column(
          children: [
            // 1. Sticky Top Header Banner + Dynamic Progress Bar
            _buildStickyHeader(pct),

            // 2. Main Scrollable Tract Content
            Expanded(
              child: ListView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 860),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildHeroAndIntroSection(pct),
                          const SizedBox(height: 24),
                          for (final section in _sections) ...[
                            _buildSectionCard(section),
                            const SizedBox(height: 20),
                          ],
                          _buildDecisionAndCommitmentCard(),
                          const SizedBox(height: 28),
                          _buildFooter(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sticky Top Header (Matches Emerald & Gold Design System)
  // ---------------------------------------------------------------------------
  Widget _buildStickyHeader(int pct) {
    return Container(
      decoration: const BoxDecoration(
        color: _brandDeep,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Back',
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _gold500,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ALIVE NIGERIA',
                    style: TextStyle(
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w900,
                      fontSize: 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _resolvedLesson.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _brand800,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone, color: _gold400, size: 13),
                      const SizedBox(width: 4),
                      Text(
                        _enquiryPhone,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Gradient Progress Indicator Bar
          SizedBox(
            height: 6,
            width: double.infinity,
            child: Stack(
              children: [
                Container(color: const Color(0xFF022C22)),
                FractionallySizedBox(
                  widthFactor: _completionRatio.clamp(0.0, 1.0),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF34D399), _gold400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Banner & Intro Hook Card
  // ---------------------------------------------------------------------------
  Widget _buildHeroAndIntroSection(int pct) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top Emerald Gradient Hero
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_brand900, Color(0xFF065F46), Color(0xFF134E4A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 560;
                final leftCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: const Color(0xFF6EE7B7).withValues(alpha: 0.35)),
                      ),
                      child: const Text(
                        'INTERACTIVE SCRIPTURE TRACT GUIDE',
                        style: TextStyle(
                          color: Color(0xFFA7F3D0),
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _resolvedLesson.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.2,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '"$_heroVerse" — $_heroVerseRef',
                      style: const TextStyle(
                        color: Color(0xFFD1FAE5),
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        height: 1.5,
                        fontFamily: 'Georgia',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Icon(Icons.schedule,
                            color: Color(0xFFA7F3D0), size: 15),
                        Text(
                          'Estimated Study Time: ${_resolvedLesson.duration}',
                          style: const TextStyle(
                            color: Color(0xFFA7F3D0),
                            fontSize: 12,
                          ),
                        ),
                        const Text('•',
                            style: TextStyle(color: Color(0xFFA7F3D0))),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _brand800,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '$pct% Complete',
                            style: const TextStyle(
                              color: Color(0xFFA7F3D0),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );

                final rightCard = Container(
                  width: 165,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF022C22),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF6EE7B7).withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF059669).withValues(alpha: 0.25),
                          border: Border.all(
                            color: const Color(0xFF34D399).withValues(alpha: 0.5),
                          ),
                        ),
                        child: const Icon(
                          Icons.menu_book_rounded,
                          color: Color(0xFFA7F3D0),
                          size: 26,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _resolvedLesson.category.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFA7F3D0),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        '"Search the Scriptures daily, whether those things were so."',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFFCBD5E1),
                          fontSize: 11,
                          fontStyle: FontStyle.italic,
                          fontFamily: 'Georgia',
                        ),
                      ),
                    ],
                  ),
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(child: leftCol),
                      const SizedBox(width: 24),
                      rightCard,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    leftCol,
                    const SizedBox(height: 16),
                    Center(child: rightCard),
                  ],
                );
              },
            ),
          ),

          // Bottom Parchment Intro Hook
          if (_introText.trim().isNotEmpty)
            Container(
              padding: const EdgeInsets.all(22),
              decoration: const BoxDecoration(
                color: Color(0xFFFFFBEB),
                border: Border(
                  top: BorderSide(color: Color(0xFFFEF3C7)),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.explore, color: _brand700, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _introHeading,
                          style: const TextStyle(
                            color: Color(0xFF0F172A),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _buildFormattedText(
                    _introText,
                    baseStyle: const TextStyle(
                      color: Color(0xFF334155),
                      fontSize: 14.5,
                      height: 1.6,
                      fontFamily: 'Georgia',
                    ),
                  ),
                  if (_introHighlight.trim().isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5).withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFA7F3D0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.check_circle,
                              color: _brand700, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _introHighlight,
                              style: const TextStyle(
                                color: Color(0xFF022C22),
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Numbered Section Card
  // ---------------------------------------------------------------------------
  Widget _buildSectionCard(ExtractedLessonSection s) {
    final isTips = s.title.toLowerCase().contains('practical tips') ||
        s.title.toLowerCase().contains('helpful tips');

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Number Badge + Question Title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: _brand700,
                  shape: BoxShape.circle,
                ),
                child: isTips
                    ? const Icon(Icons.volunteer_activism,
                        color: Colors.white, size: 16)
                    : Text(
                        '${s.number}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  s.title,
                  style: const TextStyle(
                    color: Color(0xFF0F172A),
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.3,
                    fontFamily: 'Georgia',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 1. Scripture Verse Cards
          if (s.verseQuotes.isNotEmpty) ...[
            _buildVerseCard(s.verseQuotes),
            const SizedBox(height: 14),
          ],

          // 2. Explanatory Commentary Text
          if (s.bodyText.trim().isNotEmpty) ...[
            for (final para in s.bodyText
                .split('\n\n')
                .map((p) => p.trim())
                .where((p) => p.isNotEmpty)) ...[
              _buildFormattedText(
                para,
                baseStyle: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],

          // 3. Highlight Box
          if (s.highlightNote != null && s.highlightNote!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD1FAE5).withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.check_circle, color: _brand700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildFormattedText(
                      s.highlightNote!,
                      baseStyle: const TextStyle(
                        color: Color(0xFF022C22),
                        fontSize: 13.5,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // 4. Interactive Fulfilled Prophecies Checklist
          if (s.checklistItems.isNotEmpty) ...[
            _buildChecklistBlock(s),
            const SizedBox(height: 14),
          ],

          // 5. Scientific Facts Grid
          if (s.factItems.isNotEmpty) ...[
            _buildFactsGrid(s.factItems),
            const SizedBox(height: 14),
          ],

          // 6. Dark Atomic Mystery Callout
          if (s.darkCallout != null) ...[
            _buildDarkCallout(s.darkCallout!),
            const SizedBox(height: 14),
          ],

          // 7. True Life Testimony Card
          if (s.testimony != null) ...[
            _buildTestimonyCard(s.testimony!),
            const SizedBox(height: 14),
          ],

          // 8. Filterable Messianic Prophecies Table
          if (s.tableData != null) ...[
            _buildFilterableTable(s.number, s.tableData!),
            const SizedBox(height: 14),
          ],

          // 9. Numbered Steps / Practical Tips
          if (s.steps.isNotEmpty) ...[
            _buildStepsBlock(s, checkable: s.checkableSteps),
            const SizedBox(height: 14),
          ],

          // 10. Principle Note Callout
          if (s.principleNote != null && s.principleNote!.isNotEmpty) ...[
            _buildPrincipleNote(s.principleNote!),
            const SizedBox(height: 14),
          ],

          // 11. Interactive A/B/C Q&A Cards
          if (s.qaItems.isNotEmpty) ...[
            _buildQaCards(s),
            const SizedBox(height: 6),
          ],

          // 12. Personal Reflection Input Box
          if (s.hasInputTarget) _buildReflectionInput(s),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Block Renderers
  // ---------------------------------------------------------------------------
  Widget _buildVerseCard(List<Map<String, String>> verses) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brand50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: const Border(
          left: BorderSide(color: _brand700, width: 4),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (int i = 0; i < verses.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            _buildFormattedText(
              '${verses[i]['lead'] != null && verses[i]['lead']!.isNotEmpty ? "${verses[i]['lead']} " : ""}"${verses[i]['quote'] ?? ''}"',
              baseStyle: const TextStyle(
                color: Color(0xFF1E293B),
                fontSize: 15,
                height: 1.55,
                fontFamily: 'Georgia',
              ),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                '— ${verses[i]['reference'] ?? ''}',
                style: const TextStyle(
                  color: _brand700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChecklistBlock(ExtractedLessonSection s) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.fact_check_outlined, color: _brand700, size: 16),
                  SizedBox(width: 6),
                  Text(
                    'EXAMPLES OF FULFILLED BIBLE PROPHECIES:',
                    style: TextStyle(
                      color: _brand900,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
              Text(
                'Tap to check studied',
                style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < s.checklistItems.length; i++) ...[
            Builder(builder: (context) {
              final key = 'chk_${s.number}_$i';
              final checked = _checkboxStates[key] ?? false;
              final item = s.checklistItems[i];
              return InkWell(
                onTap: () {
                  setState(() {
                    _checkboxStates[key] = !checked;
                  });
                  _recalculateProgress();
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: checked
                          ? _brand700
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: Checkbox(
                          value: checked,
                          activeColor: _brand700,
                          onChanged: (v) {
                            setState(() {
                              _checkboxStates[key] = v ?? false;
                            });
                            _recalculateProgress();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              color: Color(0xFF334155),
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(
                                text: '${item['label']} ',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              TextSpan(text: item['text'] ?? ''),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildFactsGrid(List<Map<String, String>> facts) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: facts.map((f) {
        return Container(
          width: 360,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _brand50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFD1FAE5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _brand800,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  (f['tag'] ?? 'FACT').toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                f['title'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                f['quote'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontStyle: FontStyle.italic,
                  fontSize: 13,
                  fontFamily: 'Georgia',
                ),
              ),
              if ((f['text'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  f['text']!,
                  style: const TextStyle(
                    color: Color(0xFF475569),
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDarkCallout(Map<String, String> callout) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF083344),
              border: Border.all(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.4)),
            ),
            child: const Icon(
              Icons.hub_outlined,
              color: Color(0xFF67E8F9),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  callout['title'] ?? 'The Riddle of Nuclear Physics',
                  style: const TextStyle(
                    color: Color(0xFF67E8F9),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                _buildFormattedText(
                  callout['text'] ?? '',
                  baseStyle: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTestimonyCard(Map<String, String> testimony) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFBEB), _brand50],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA7F3D0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.format_quote, color: _brand700, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  testimony['title'] ?? 'True Life Testimony',
                  style: const TextStyle(
                    color: _brand900,
                    fontWeight: FontWeight.bold,
                    fontSize: 13.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '"${testimony['text'] ?? ''}"',
            style: const TextStyle(
              color: Color(0xFF1E293B),
              fontSize: 13,
              fontStyle: FontStyle.italic,
              height: 1.55,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterableTable(int sectionNum, Map<String, dynamic> tableData) {
    final title = (tableData['title'] ?? 'Fulfilled Prophecies').toString();
    final columns = (tableData['columns'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['Prophecy Subject', 'OT Prediction', 'NT Fulfillment'];
    final rawRows = (tableData['rows'] as List?) ?? const [];
    final query = (_tableSearchQueries[sectionNum] ?? '').toLowerCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: _brand900,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
              SizedBox(
                width: 210,
                height: 34,
                child: TextField(
                  onChanged: (val) {
                    setState(() {
                      _tableSearchQueries[sectionNum] = val;
                    });
                  },
                  style: const TextStyle(fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Filter prophecy...',
                    prefixIcon: const Icon(Icons.search, size: 16),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_brand900),
              headingTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
              dataRowMinHeight: 38,
              dataRowMaxHeight: 48,
              columns: [
                for (final col in columns) DataColumn(label: Text(col)),
                const DataColumn(label: Text('Studied')),
              ],
              rows: [
                for (int r = 0; r < rawRows.length; r++)
                  if (query.isEmpty ||
                      rawRows[r]
                          .toString()
                          .toLowerCase()
                          .contains(query))
                    DataRow(
                      cells: [
                        for (int c = 0; c < columns.length; c++)
                          DataCell(
                            Text(
                              c < (rawRows[r] as List).length
                                  ? rawRows[r][c].toString()
                                  : '',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: c == 0
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                                color: c == 1
                                    ? _brand700
                                    : const Color(0xFF334155),
                              ),
                            ),
                          ),
                        DataCell(
                          Checkbox(
                            value: _checkboxStates['tbl_${sectionNum}_$r'] ??
                                false,
                            activeColor: _brand700,
                            onChanged: (v) {
                              setState(() {
                                _checkboxStates['tbl_${sectionNum}_$r'] =
                                    v ?? false;
                              });
                              _recalculateProgress();
                            },
                          ),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsBlock(ExtractedLessonSection s, {required bool checkable}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checkable) ...[
            const Text(
              'Tick each one you will practise:',
              style: TextStyle(
                color: Color(0xFF64748B),
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
          ],
          for (int i = 0; i < s.steps.length; i++) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFA7F3D0),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: _brand900,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: Color(0xFF334155),
                          fontSize: 13.5,
                          height: 1.45,
                        ),
                        children: [
                          TextSpan(
                            text: '${s.steps[i]['title']} ',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: s.steps[i]['text'] ?? ''),
                        ],
                      ),
                    ),
                  ),
                  if (checkable)
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value:
                            _checkboxStates['step_${s.number}_$i'] ?? false,
                        activeColor: _brand700,
                        onChanged: (v) {
                          setState(() {
                            _checkboxStates['step_${s.number}_$i'] =
                                v ?? false;
                          });
                          _recalculateProgress();
                        },
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPrincipleNote(String noteText) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: Color(0xFFD97706), size: 16),
              SizedBox(width: 6),
              Text(
                'The Principle of "Apparent Age":',
                style: TextStyle(
                  color: Color(0xFF78350F),
                  fontWeight: FontWeight.bold,
                  fontSize: 12.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            noteText,
            style: const TextStyle(
              color: Color(0xFF78350F),
              fontSize: 12.5,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQaCards(ExtractedLessonSection s) {
    return Column(
      children: s.qaItems.map((qa) {
        final letter = qa['letter'] ?? 'A';
        final key = 'q_${s.number}_${letter.toLowerCase()}';
        final ctrl = _textControllers[key];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: _brand800,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      letter,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      qa['question'] ?? '',
                      style: const TextStyle(
                        color: _brand900,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                qa['text'] ?? '',
                style: const TextStyle(
                  color: Color(0xFF334155),
                  fontSize: 13.5,
                  height: 1.5,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: qa['placeholder'] ?? 'Enter your response...',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: _brand700, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildReflectionInput(ExtractedLessonSection s) {
    final ctrl = _textControllers['q_${s.number}'];
    final isMultiline = s.number == 1 || s.number == 5 || s.number == 13;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(top: 12),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: _brand700, size: 17),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  s.reflectionPrompt.toUpperCase(),
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: ctrl,
            maxLines: isMultiline ? 3 : 1,
            style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
            decoration: InputDecoration(
              hintText: s.reflectionPlaceholder,
              hintStyle:
                  const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _brand700, width: 1.8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Personal Response & Commitment Section
  // ---------------------------------------------------------------------------
  Widget _buildDecisionAndCommitmentCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brandDeep, _brand900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: const Color(0xFF059669).withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'PERSONAL RESPONSE & COMMITMENT',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _gold400,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Making God's Word Your Foundation",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$_decisionQuote"',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFD1FAE5),
              fontSize: 13,
              height: 1.5,
              fontFamily: 'Georgia',
            ),
          ),
          const SizedBox(height: 20),

          // YES / NO Decision Toggle Cards
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: _decisionQuestions.map((q) {
              final qId = q['id']!;
              final currentVal = _decisionStates[qId];
              return Container(
                width: _decisionQuestions.length == 1 ? 520 : 250,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24),
                ),
                child: Column(
                  children: [
                    Text(
                      q['text'] ?? '',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildYesNoButton(
                          label: 'YES',
                          isSelected: currentVal == true,
                          activeColor: const Color(0xFF10B981),
                          onTap: () {
                            setState(() {
                              _decisionStates[qId] = true;
                            });
                            _recalculateProgress();
                          },
                        ),
                        const SizedBox(width: 10),
                        _buildYesNoButton(
                          label: 'NO',
                          isSelected: currentVal == false,
                          activeColor: const Color(0xFFDC2626),
                          onTap: () {
                            setState(() {
                              _decisionStates[qId] = false;
                            });
                            _recalculateProgress();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Prayer Commitment & Contact Box
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF022C22).withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _gold400.withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                InkWell(
                  onTap: () {
                    setState(() {
                      _commitmentChecked = !_commitmentChecked;
                    });
                    _recalculateProgress();
                  },
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: _commitmentChecked,
                        activeColor: _gold400,
                        checkColor: Colors.black,
                        onChanged: (v) {
                          setState(() {
                            _commitmentChecked = v ?? false;
                          });
                          _recalculateProgress();
                        },
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _commitmentTitle,
                              style: const TextStyle(
                                color: _gold400,
                                fontWeight: FontWeight.bold,
                                fontSize: 13.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '"$_commitmentText"',
                              style: const TextStyle(
                                color: Color(0xFFD1FAE5),
                                fontSize: 13,
                                height: 1.45,
                                fontFamily: 'Georgia',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Your Name',
                          hintStyle: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        style:
                            const TextStyle(color: Colors.white, fontSize: 12.5),
                        decoration: InputDecoration(
                          hintText: 'Phone Number / WhatsApp',
                          hintStyle: const TextStyle(
                              color: Colors.white54, fontSize: 12),
                          filled: true,
                          fillColor: Colors.white.withValues(alpha: 0.1),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // Save & Export Action Buttons
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              ElevatedButton.icon(
                onPressed: _saveProgressLocally,
                icon: const Icon(Icons.save, size: 16),
                label: const Text('SAVE MY ANSWERS LOCALLY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _gold500,
                  foregroundColor: const Color(0xFF0F172A),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
              OutlinedButton.icon(
                onPressed: _exportStudySummary,
                icon: const Icon(Icons.download, size: 16),
                label: const Text('COPY / EXPORT STUDY SUMMARY'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFF34D399)),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    letterSpacing: 0.6,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),

          if (_showSavedBanner) ...[
            const SizedBox(height: 12),
            const Text(
              '✓ Your study notes and responses have been saved successfully to your device!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _gold400,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildYesNoButton({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor
              : Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        const Divider(color: Color(0xFFCBD5E1)),
        const SizedBox(height: 12),
        const Text(
          'ALIVE NIGERIA SERIES  •  WHAT THE BIBLE SAYS',
          style: TextStyle(
            color: _brand900,
            fontWeight: FontWeight.bold,
            fontSize: 13,
            letterSpacing: 0.8,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '"$_heroVerse" — $_heroVerseRef',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF475569),
            fontSize: 12,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'For Enquiry, Study Guides & Prayer: $_enquiryPhone',
          style: const TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  /// Renders inline markup (__underlined__, **bold**, *italic*).
  Widget _buildFormattedText(String input, {required TextStyle baseStyle}) {
    final spans = <InlineSpan>[];
    final tokenRegex = RegExp(r'__(.+?)__|\*\*(.+?)\*\*|\*(.+?)\*');
    int lastIdx = 0;

    for (final match in tokenRegex.allMatches(input)) {
      if (match.start > lastIdx) {
        spans.add(TextSpan(text: input.substring(lastIdx, match.start)));
      }
      if (match.group(1) != null) {
        spans.add(
          TextSpan(
            text: match.group(1),
            style: baseStyle.copyWith(
              fontWeight: FontWeight.bold,
              color: _brand900,
              decoration: TextDecoration.underline,
              decorationColor: _gold500,
              decorationThickness: 2,
            ),
          ),
        );
      } else if (match.group(2) != null) {
        spans.add(
          TextSpan(
            text: match.group(2),
            style: baseStyle.copyWith(fontWeight: FontWeight.bold),
          ),
        );
      } else if (match.group(3) != null) {
        spans.add(
          TextSpan(
            text: match.group(3),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastIdx = match.end;
    }

    if (lastIdx < input.length) {
      spans.add(TextSpan(text: input.substring(lastIdx)));
    }

    return RichText(
      text: TextSpan(style: baseStyle, children: spans),
    );
  }
}
