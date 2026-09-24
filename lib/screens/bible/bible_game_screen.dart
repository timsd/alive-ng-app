import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../services/bible_source.dart';
import '../../constants/bible_verses.dart';
import '../../widgets/star_animation_widget.dart';
import '../../widgets/custom_app_bar.dart';

// Game State Provider
final bibleGameProvider =
    StateNotifierProvider<BibleGameNotifier, BibleGameState>((ref) {
  return BibleGameNotifier();
});

class BibleGameState {
  final BibleVerse? currentVerse;
  final String selectedVersion;
  final int currentLevel;
  final int score;
  final List<String> completedVerses;
  final GameMode gameMode;
  final bool isListening;
  final String userInput;
  final List<int> blankedWords;
  final bool showHint;
  final bool showStarAnimation;
  final bool hasCheckedAnswer;
  final int? selectedChoiceIndex;
  final List<String> multipleChoiceOptions;
  final bool showAnswer;
  final int attemptCount;
  final bool showHintButton;

  BibleGameState({
    this.currentVerse,
    this.selectedVersion = 'NIV',
    this.currentLevel = 1,
    this.score = 0,
    this.completedVerses = const [],
    this.gameMode = GameMode.fillInTheGap,
    this.isListening = false,
    this.userInput = '',
    this.blankedWords = const [],
    this.showHint = false,
    this.showStarAnimation = false,
    this.hasCheckedAnswer = false,
    this.selectedChoiceIndex,
    this.multipleChoiceOptions = const [],
    this.showAnswer = false,
    this.attemptCount = 0,
    this.showHintButton = false,
  });

  BibleGameState copyWith({
    BibleVerse? currentVerse,
    String? selectedVersion,
    int? currentLevel,
    int? score,
    List<String>? completedVerses,
    GameMode? gameMode,
    bool? isListening,
    String? userInput,
    List<int>? blankedWords,
    bool? showHint,
    bool? showStarAnimation,
    bool? hasCheckedAnswer,
    int? selectedChoiceIndex,
    List<String>? multipleChoiceOptions,
    bool? showAnswer,
    int? attemptCount,
    bool? showHintButton,
    bool clearCurrentVerse = false,
    bool clearSelectedChoiceIndex = false,
  }) {
    return BibleGameState(
      currentVerse:
          clearCurrentVerse ? null : currentVerse ?? this.currentVerse,
      selectedVersion: selectedVersion ?? this.selectedVersion,
      currentLevel: currentLevel ?? this.currentLevel,
      score: score ?? this.score,
      completedVerses: completedVerses ?? this.completedVerses,
      gameMode: gameMode ?? this.gameMode,
      isListening: isListening ?? this.isListening,
      userInput: userInput ?? this.userInput,
      blankedWords: blankedWords ?? this.blankedWords,
      showHint: showHint ?? this.showHint,
      showStarAnimation: showStarAnimation ?? this.showStarAnimation,
      hasCheckedAnswer: hasCheckedAnswer ?? this.hasCheckedAnswer,
      selectedChoiceIndex: clearSelectedChoiceIndex
          ? null
          : selectedChoiceIndex ?? this.selectedChoiceIndex,
      multipleChoiceOptions:
          multipleChoiceOptions ?? this.multipleChoiceOptions,
      showAnswer: showAnswer ?? this.showAnswer,
      attemptCount: attemptCount ?? this.attemptCount,
      showHintButton: showHintButton ?? this.showHintButton,
    );
  }
}

enum GameMode {
  fillInTheGap,
  voiceRecitation,
  multipleChoice,
}

class BibleGameNotifier extends StateNotifier<BibleGameState> {
  BibleGameNotifier() : super(BibleGameState()) {
    loadNewVerse();
  }

  final Random _random = Random();
  List<String> _remainingVerseReferences = <String>[];

  /// Incremented every time a new verse is loaded so pending delayed callbacks
  /// from a previous verse can detect that they are now stale and bail.
  int _verseGeneration = 0;

  /// Returns the verse text for the currently selected version, falling back
  /// to the first available translation if the requested one is missing.
  String _verseText(BibleVerse verse) =>
      verse.text[state.selectedVersion] ?? verse.text.values.first;

  void _rebuildVersePool({String? avoidReference}) {
    final references = BibleSource.instance.nonGenealogyCorpus
        .map((verse) => verse.reference)
        .where((reference) => reference != avoidReference)
        .toList();
    references.shuffle(_random);
    _remainingVerseReferences = references;
  }

  Future<void> loadNewVerse() async {
    // Invalidate any in-flight delayed callbacks tied to the previous verse.
    _verseGeneration++;

    final previousReference = state.currentVerse?.reference;

    // Show loading state implicitly by clearing out the current verse briefly
    state = state.copyWith(
      clearCurrentVerse: true,
      clearSelectedChoiceIndex: true,
    );

    if (_remainingVerseReferences.isEmpty) {
      _rebuildVersePool(avoidReference: previousReference);
    }
    if (_remainingVerseReferences.isEmpty) {
      _rebuildVersePool();
    }

    final nextReference = _remainingVerseReferences.isNotEmpty
        ? _remainingVerseReferences.removeAt(0)
        : null;
    final verse = nextReference != null
        ? BibleSource.instance.findByReference(nextReference)
        : BibleSource.instance.randomVerse(excludeGenealogy: true);
    if (verse == null) return;

    // Pick the version based on current selection (or fallback to KJV if not found)
    final textForVersion = _verseText(verse);
    final blankedWords = _generateBlankedWords(textForVersion);
    final multipleChoiceOptions =
        _generateMultipleChoiceOptions(verse, state.selectedVersion);

    state = state.copyWith(
      currentVerse: verse,
      blankedWords: blankedWords,
      multipleChoiceOptions: multipleChoiceOptions,
      userInput: '',
      showHint: false,
      hasCheckedAnswer: false,
      clearSelectedChoiceIndex: true,
      showAnswer: false,
      attemptCount: 0,
      showHintButton: false,
    );
  }

  List<int> _generateBlankedWords(String text) {
    final words =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return const [];

    final candidates = words
        .asMap()
        .entries
        .where((entry) {
          final normalized = _normalizeText(entry.value);
          return normalized.length > 2;
        })
        .map((entry) => entry.key)
        .toList()
      ..shuffle(_random);

    if (candidates.isEmpty) return const [];

    final numBlanks =
        max(1, min((words.length * 0.2).ceil(), candidates.length));
    final blankedIndices = candidates.take(numBlanks).toList();

    return blankedIndices..sort();
  }

  List<String> _generateMultipleChoiceOptions(
    BibleVerse verse,
    String selectedVersion,
  ) {
    final correctAnswer =
        verse.text[selectedVersion] ?? verse.text.values.first;
    final normalizedCorrect = _normalizeText(correctAnswer);

    final wrongAnswers = BibleSource.instance.nonGenealogyCorpus
        .where((candidate) => candidate.reference != verse.reference)
        .map((candidate) =>
            candidate.text[selectedVersion] ?? candidate.text.values.first)
        .where((answer) => _normalizeText(answer) != normalizedCorrect)
        .toList()
      ..shuffle(_random);

    final options = <String>[correctAnswer];
    for (final answer in wrongAnswers) {
      if (options.length == 4) break;
      if (!options.contains(answer)) {
        options.add(answer);
      }
    }

    options.shuffle(_random);
    return options;
  }

  void setGameMode(GameMode mode) {
    state = state.copyWith(
      gameMode: mode,
      attemptCount: 0,
      showHintButton: false,
      hasCheckedAnswer: false,
      showHint: false,
      showAnswer: false,
      clearSelectedChoiceIndex: true,
    );
  }

  void deductPoints(int points) {
    final newScore = max(0, state.score - points);
    state = state.copyWith(score: newScore);
  }

  void flipCardWithDeduction() {
    if (state.hasCheckedAnswer) return;
    deductPoints(2);
    state = state.copyWith(hasCheckedAnswer: true, showAnswer: true);
  }

  void flipCardBack() {
    state = state.copyWith(hasCheckedAnswer: false, showAnswer: false);
  }

  void restartGame() {
    state = BibleGameState(
      selectedVersion: state.selectedVersion,
      gameMode: state.gameMode,
      score: 0,
    );
    loadNewVerse();
  }

  void setListening(bool listening) {
    state = state.copyWith(isListening: listening);
  }

  void updateUserInput(String input) {
    state = state.copyWith(userInput: input);
  }

  void showHint() {
    state = state.copyWith(showHint: true);
  }

  void checkAnswer() {
    if (state.currentVerse == null) return;

    final correctText = _verseText(state.currentVerse!);
    final isCorrect = state.gameMode == GameMode.fillInTheGap
        ? _areFillInGapWordsCorrect(state.userInput, correctText)
        : _isAnswerCorrect(state.userInput, correctText);

    if (isCorrect) {
      final newScore = state.score + (state.showHint ? 5 : 10);
      final newCompleted = [
        ...state.completedVerses,
        state.currentVerse!.reference
      ];

      // Show star animation for correct answer
      state = state.copyWith(
        score: newScore,
        completedVerses: newCompleted,
        showStarAnimation: true,
        hasCheckedAnswer: true,
        attemptCount: 0,
        showHintButton: false,
      );

      // Keep the celebration brief so the feedback feels immediate.
      final generation = _verseGeneration;
      Future.delayed(const Duration(milliseconds: 1400), () {
        // Skip if the verse changed or the notifier was disposed meanwhile.
        if (generation != _verseGeneration || !mounted) return;
        state = state.copyWith(showStarAnimation: false);
        loadNewVerse();
      });
    } else {
      final attempts = state.attemptCount + 1;
      final isVoice = state.gameMode == GameMode.voiceRecitation;
      final autoShowHint = attempts >= 3 && !isVoice;

      state = state.copyWith(
        showAnswer: autoShowHint,
        hasCheckedAnswer: autoShowHint,
        // Offer the hint (so the Submit button surfaces the 2-pt deduction
        // popup on its next press) WITHOUT auto-revealing the blanks yet.
        // `showHint` only becomes true when the player confirms the popup,
        // which is what actually fills the blanks and arms the advance timer.
        showHint: false,
        attemptCount: attempts,
        showHintButton: attempts >= 3 && !isVoice,
      );
      if (isVoice) {
        // Keep transcript visible so users can compare and retry.
        return;
      }
      state = state.copyWith(userInput: '');
    }
  }

  void checkPartialMatch(String input) {
    if (state.currentVerse == null ||
        state.gameMode != GameMode.voiceRecitation) {
      return;
    }

    final correctText = _verseText(state.currentVerse!);

    // We only auto-verify if the user actually matched it perfectly
    if (_isAnswerCorrect(input, correctText)) {
      checkAnswer();
    }
  }

  bool _areFillInGapWordsCorrect(String userAnswer, String correctAnswer) {
    if (userAnswer.contains('__blank__')) {
      return false;
    }
    return _isAnswerCorrect(userAnswer, correctAnswer);
  }

  void hideStarAnimation() {
    state = state.copyWith(showStarAnimation: false);
  }

  void showVoiceHint() {
    state = state.copyWith(
      showHint: true,
      hasCheckedAnswer: true,
      showHintButton: true,
    );
  }

  void resetVoicePrompt() {
    state = state.copyWith(showHint: false, hasCheckedAnswer: false);
  }

  bool _isAnswerCorrect(String userAnswer, String correctAnswer) {
    final normalizedUser = _normalizeText(userAnswer);
    final normalizedCorrect = _normalizeText(correctAnswer);
    // Exact match (typed answers in fill-gap mode are exact)
    if (normalizedUser == normalizedCorrect) return true;
    // For voice recitation: use fuzzy word-similarity to accommodate
    // non-English accents/intonation. Require >=80% word matches.
    return _fuzzyMatch(normalizedUser, normalizedCorrect);
  }

  /// Checks if at least [threshold] fraction of words in [correct] appear
  /// in [user] (order-insensitive, handles accent-caused substitutions).
  bool _fuzzyMatch(String user, String correct, {double threshold = 0.80}) {
    final correctWords = correct.split(' ');
    if (correctWords.isEmpty) return false;
    final userWords = user.split(' ').toSet();
    int matches = 0;
    for (final word in correctWords) {
      if (userWords.contains(word)) {
        matches++;
      } else {
        // Allow 1-character edit distance for small words to handle accent errors
        for (final uw in userWords) {
          if (_editDistance(word, uw) <= 1) {
            matches++;
            break;
          }
        }
      }
    }
    return matches / correctWords.length >= threshold;
  }

  /// Levenshtein edit distance between two strings.
  int _editDistance(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(a.length + 1, (i) => List.filled(b.length + 1, 0));
    for (int i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (int j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (int i = 1; i <= a.length; i++) {
      for (int j = 1; j <= b.length; j++) {
        dp[i][j] = a[i - 1] == b[j - 1]
            ? dp[i - 1][j - 1]
            : 1 +
                [dp[i - 1][j], dp[i][j - 1], dp[i - 1][j - 1]]
                    .reduce((x, y) => x < y ? x : y);
      }
    }
    return dp[a.length][b.length];
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  void nextVerse() {
    loadNewVerse();
  }

  void changeVersion(String version) {
    state = state.copyWith(selectedVersion: version);
    loadNewVerse();
  }

  void selectChoice(int index) {
    state = state.copyWith(selectedChoiceIndex: index);
  }

  void checkMultipleChoiceAnswer() {
    final selectedIndex = state.selectedChoiceIndex;
    if (selectedIndex == null ||
        selectedIndex < 0 ||
        selectedIndex >= state.multipleChoiceOptions.length ||
        state.currentVerse == null) {
      return;
    }

    final correctAnswer = _verseText(state.currentVerse!);
    final selectedAnswer = state.multipleChoiceOptions[selectedIndex];
    final isCorrect =
        _normalizeText(selectedAnswer) == _normalizeText(correctAnswer);

    if (isCorrect) {
      final newCompleted = [
        ...state.completedVerses,
        state.currentVerse!.reference
      ];
      state = state.copyWith(
        score: state.score + 10,
        completedVerses: newCompleted,
        showStarAnimation: true,
        showAnswer: true,
      );

      // Show star animation and move to next verse after delay
      final generation = _verseGeneration;
      Future.delayed(const Duration(seconds: 2), () {
        // Skip if the verse changed or the notifier was disposed meanwhile.
        if (generation != _verseGeneration || !mounted) return;
        loadNewVerse();
      });
    } else {
      state = state.copyWith(showAnswer: true);
    }
  }
}

class BibleGameScreen extends ConsumerStatefulWidget {
  const BibleGameScreen({super.key});

  @override
  ConsumerState<BibleGameScreen> createState() => _BibleGameScreenState();
}

class _BibleGameScreenState extends ConsumerState<BibleGameScreen>
    with WidgetsBindingObserver {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  final TextEditingController _textController = TextEditingController();
  final Map<int, TextEditingController> _blankControllers = {};
  String _blankControllerKey = '';
  bool _speechEnabled = false;
  bool _speechReady = false;
  bool _ttsReady = false;
  Timer? _hintAutoAdvanceTimer;
  bool _isGameOverShowing = false;

  /// The best available STT locale resolved at init (en-NG → en-GB → en-US).
  String _resolvedSttLocale = 'en-NG';

  /// Ordered locale fallback chain: Nigerian English → British English → US English.
  static const _localeFallbackChain = [
    'en-NG',
    'en_NG',
    'en-GB',
    'en_GB',
    'en-US',
    'en_US'
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeSpeech();
    _initializeTts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Anti-cheat: user minimized or switched app, rotate verse
      if (mounted) {
        _hintAutoAdvanceTimer?.cancel();
        _hintAutoAdvanceTimer = null;
        ref.read(bibleGameProvider.notifier).loadNewVerse();
      }
    }
  }

  void _checkGameOver() {
    final gameState = ref.read(bibleGameProvider);
    if (_isGameOverShowing || !mounted) return;
    if (gameState.score <= 0 &&
        (gameState.attemptCount > 0 || gameState.completedVerses.isNotEmpty)) {
      _isGameOverShowing = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 8),
              Text('Game Over'),
            ],
          ),
          content: const Text(
            'Your score reached 0 points! Would you like to restart the challenge?',
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                _isGameOverShowing = false;
                Navigator.of(ctx).pop();
                ref.read(bibleGameProvider.notifier).restartGame();
              },
              child: const Text('Restart Game'),
            ),
          ],
        ),
      ).then((_) => _isGameOverShowing = false);
    }
  }

  Future<void> _confirmFlipCard(BuildContext context) async {
        final currentScore = ref.read(bibleGameProvider).score;
    if (currentScore <= 0) {
      final gs = ref.read(bibleGameProvider);
      // No score has been earned yet on this verse: rather than blocking the
      // child or triggering game-over, treat it as "start over" and deal a
      // fresh verse. Deductions are only valid against an existing score.
      if (gs.completedVerses.isEmpty && gs.attemptCount == 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No score yet — here’s a new verse to try!'),
            ),
          );
          ref.read(bibleGameProvider.notifier).loadNewVerse();
        }
      } else {
        _checkGameOver();
      }
      return;
    }
    if (currentScore < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need at least 2 points to reveal this verse.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Flip Card?'),
        content: const Text(
          'Flipping this card to reveal the verse will deduct 2 points from your score.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade600,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Flip (-2 pts)'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(bibleGameProvider.notifier).flipCardWithDeduction();
      final updatedScore = ref.read(bibleGameProvider).score;
      if (updatedScore <= 0) {
        _checkGameOver();
      }
    }
  }

  void _onNextAfterAutofill() {
    _hintAutoAdvanceTimer?.cancel();
    _hintAutoAdvanceTimer = null;
    ref.read(bibleGameProvider.notifier).loadNewVerse();
  }

  Future<void> _confirmFillGapsHint(
      BuildContext context, BibleGameState gameState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Use Hint?'),
        content: const Text(
          'Using a hint will deduct 2 points and auto-fill the missing words.\n\nDo you want to continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Auto-Fill (-2 pts)'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      ref.read(bibleGameProvider.notifier).deductPoints(2);
      ref.read(bibleGameProvider.notifier).showHint();
      if (gameState.currentVerse != null) {
        final text =
            gameState.currentVerse!.text[gameState.selectedVersion] ?? '';
        final words = text
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toList();
        for (final index in gameState.blankedWords) {
          if (_blankControllers.containsKey(index) && index < words.length) {
            _blankControllers[index]!.text = words[index];
          }
        }
        _updateFillInTheGapInput(gameState, words);
      }
      _checkGameOver();
      _hintAutoAdvanceTimer?.cancel();
      // Increased duration (8 seconds) giving users ample time to read and master the verse,
      // while the dual-function Submit/Next button allows manual advance whenever ready.
      _hintAutoAdvanceTimer = Timer(const Duration(seconds: 8), () {
        if (mounted) {
          ref.read(bibleGameProvider.notifier).loadNewVerse();
        }
      });
    }
  }

  void _submitFillGaps() {
    _hintAutoAdvanceTimer?.cancel();
    _hintAutoAdvanceTimer = null;
    ref.read(bibleGameProvider.notifier).checkAnswer();
    final gs = ref.read(bibleGameProvider);
    if (!gs.showStarAnimation) {
      // Clear inputs for retry
      for (final controller in _blankControllers.values) {
        controller.clear();
      }
      final words = (gs.currentVerse?.text[gs.selectedVersion] ?? '')
          .split(RegExp(r'\s+'))
          .where((w) => w.isNotEmpty)
          .toList();
      _updateFillInTheGapInput(gs, words);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            gs.attemptCount < 3
                ? 'Incorrect word(s). Try again! (Attempt ${gs.attemptCount} of 3)'
                : '3 failed attempts. You can now use Hint (-2 pts).',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _initializeSpeech() async {
    try {
      _speech = stt.SpeechToText();
      _speechEnabled = await _speech.initialize(
        onError: (error) => debugPrint('Speech recognition error: $error'),
        onStatus: (status) => debugPrint('Speech recognition status: $status'),
      );
      _speechReady = true;

      // Resolve the best available STT locale from the fallback chain
      if (_speechEnabled) {
        final locales = await _speech.locales();
        final availableIds = locales.map((l) => l.localeId).toSet();
        for (final candidate in _localeFallbackChain) {
          if (availableIds.contains(candidate)) {
            _resolvedSttLocale = candidate;
            debugPrint('STT locale resolved: $candidate');
            break;
          }
        }
        // If none of the preferred locales are available, try any 'en' locale
        if (!_localeFallbackChain.contains(_resolvedSttLocale) ||
            !availableIds.contains(_resolvedSttLocale)) {
          final fallback = availableIds.firstWhere(
            (id) => id.startsWith('en'),
            orElse: () => 'en-US',
          );
          _resolvedSttLocale = fallback;
          debugPrint('STT locale fallback to: $fallback');
        }
      }

      if (mounted) {
        setState(() {});
      }
    } catch (error) {
      debugPrint('Speech recognition initialization failed: $error');
    }
  }

  void _initializeTts() async {
    try {
      _tts = FlutterTts();

      // Try locale fallback chain for TTS: en-NG → en-GB → en-US
      final languages = await _tts.getLanguages;
      final availableLangs =
          (languages as List?)?.map((l) => l.toString()).toSet() ?? <String>{};

      String resolvedTtsLang = 'en-US'; // ultimate fallback
      for (final candidate in _localeFallbackChain) {
        if (availableLangs.contains(candidate)) {
          resolvedTtsLang = candidate;
          break;
        }
      }
      // Also check with dash-to-underscore variants
      if (resolvedTtsLang == 'en-US' && !availableLangs.contains('en-US')) {
        final fallback = availableLangs.firstWhere(
          (l) => l.startsWith('en'),
          orElse: () => 'en-US',
        );
        resolvedTtsLang = fallback;
      }

      await _tts.setLanguage(resolvedTtsLang);
      debugPrint('TTS locale resolved: $resolvedTtsLang');

      await _tts.setSpeechRate(0.58);
      await _tts.setQueueMode(0);
      await _tts.awaitSpeakCompletion(true);
      _ttsReady = true;
    } catch (error) {
      debugPrint('TTS initialization failed: $error');
    }
  }

  void _startListening() async {
    if (_speechEnabled && _speechReady) {
      ref.read(bibleGameProvider.notifier).resetVoicePrompt();
      ref.read(bibleGameProvider.notifier).setListening(true);
      if (_ttsReady) {
        await _tts.stop();
      }
      await _speech.listen(
        onResult: (result) {
          final transcript = result.recognizedWords.trim();
          if (transcript.isEmpty) return;

          // Always update live recognized words so user sees real-time transcription
          ref.read(bibleGameProvider.notifier).updateUserInput(transcript);
          _textController.value = TextEditingValue(
            text: transcript,
            selection: TextSelection.collapsed(offset: transcript.length),
          );
          ref.read(bibleGameProvider.notifier).checkPartialMatch(transcript);

          final gameState = ref.read(bibleGameProvider);
          if (gameState.showStarAnimation) {
            _speech.cancel();
            ref.read(bibleGameProvider.notifier).setListening(false);
          }
        },
        // Uses best available: en-NG → en-GB → en-US
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: false,
          listenMode: stt.ListenMode.dictation,
          listenFor: const Duration(seconds: 30),
          pauseFor: const Duration(seconds: 3),
          localeId: _resolvedSttLocale,
        ),
      );
    }
  }

  void _stopListening() async {
    if (_speechReady) {
      await _speech.stop();
    }
    ref.read(bibleGameProvider.notifier).setListening(false);
    final gameState = ref.read(bibleGameProvider);
    if (gameState.gameMode == GameMode.voiceRecitation &&
        gameState.userInput.trim().isNotEmpty) {
      ref.read(bibleGameProvider.notifier).checkAnswer();
      final updated = ref.read(bibleGameProvider);
      if (!updated.showStarAnimation) {
        if (!mounted) return;
        if (updated.attemptCount < 3) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Incorrect recitation. Try again! (Attempt ${updated.attemptCount} of 3)',
              ),
              duration: const Duration(seconds: 2),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '3 failed attempts. "Flip (-2 pts)" is now unlocked above!',
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        if (updated.score <= 0 && updated.attemptCount >= 3) {
          _checkGameOver();
        }
      }
    }
  }

  void _speakVerse(String text) async {
    if (_ttsReady) {
      await _tts.speak(text);
    }
  }

  void _playSuccessSound() async {
    if (_ttsReady) {
      await _tts.stop();
      await _tts.speak('Word Perfect! Well Done!');
    }
  }

  @override
  void dispose() {
    _hintAutoAdvanceTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_speechReady) {
      _speech.stop();
    }
    if (_ttsReady) {
      _tts.stop();
    }
    _textController.dispose();
    for (final controller in _blankControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<BibleGameState>(bibleGameProvider, (previous, next) {
      if (next.showStarAnimation && !(previous?.showStarAnimation ?? false)) {
        _playSuccessSound();
      }
    });

    final gameState = ref.watch(bibleGameProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: CustomAppBar(
            title: 'Bible Game',
            showBackButton: true,
            actions: [
              IconButton(
                onPressed: () =>
                    ref.read(bibleGameProvider.notifier).loadNewVerse(),
                icon: const Icon(Icons.refresh),
                tooltip: 'New Verse',
              ),
            ],
          ),
          body: gameState.currentVerse == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildScoreCard(gameState),
                      const SizedBox(height: 20),
                      _buildGameModeSelector(gameState),
                      const SizedBox(height: 20),
                      _buildVersionSelector(gameState),
                      const SizedBox(height: 20),
                      _buildVerseCard(gameState),
                      const SizedBox(height: 20),
                      _buildGameContent(gameState),
                    ],
                  ),
                ),
        ),
        // Star animation overlay
        CelebrationOverlay(
          show: gameState.showStarAnimation,
          message: 'Word Perfect!\nWell Done!',
          onComplete: () {
            ref.read(bibleGameProvider.notifier).hideStarAnimation();
          },
        ),
      ],
    );
  }

  Widget _buildScoreCard(BibleGameState gameState) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Icon(Icons.star,
                    color: Theme.of(context).colorScheme.secondary, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Score: ${gameState.score}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Column(
              children: [
                Icon(Icons.check_circle,
                    color: Theme.of(context).colorScheme.tertiary, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Completed: ${gameState.completedVerses.length}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            Column(
              children: [
                Icon(Icons.trending_up,
                    color: Theme.of(context).colorScheme.primary, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Level: ${gameState.currentLevel}',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameModeSelector(BibleGameState gameState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Game Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModeButton(
                    'Fill Gaps',
                    Icons.edit,
                    GameMode.fillInTheGap,
                    gameState.gameMode == GameMode.fillInTheGap,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildModeButton(
                    'Voice',
                    Icons.mic,
                    GameMode.voiceRecitation,
                    gameState.gameMode == GameMode.voiceRecitation,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
      String label, IconData icon, GameMode mode, bool isSelected) {
    final cs = Theme.of(context).colorScheme;
    return ElevatedButton.icon(
      onPressed: () => ref.read(bibleGameProvider.notifier).setGameMode(mode),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? cs.primary : cs.surfaceContainerHighest,
        foregroundColor: isSelected ? cs.onPrimary : cs.onSurface,
        side: isSelected
            ? BorderSide(color: cs.primary, width: 2)
            : BorderSide(color: cs.outline.withValues(alpha: 0.4)),
      ),
    );
  }

  Widget _buildVerseCard(BibleGameState gameState) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  gameState.currentVerse!.reference,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
                if (gameState.gameMode != GameMode.voiceRecitation ||
                    gameState.hasCheckedAnswer)
                  IconButton(
                    onPressed: () => _speakVerse(
                      gameState.currentVerse!.text[gameState.selectedVersion] ??
                          '',
                    ),
                    icon: const Icon(Icons.volume_up),
                    tooltip: 'Listen to verse',
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (gameState.gameMode == GameMode.fillInTheGap)
              _buildFillInTheGapText(gameState)
            else if (gameState.gameMode == GameMode.voiceRecitation)
              _buildFlipCard(gameState)
            else
              Text(
                gameState.currentVerse!.text[gameState.selectedVersion] ?? '',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVersionSelector(BibleGameState gameState) {
    const supportedVersions = ['KJV', 'NKJV', 'NIV'];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.menu_book),
            const SizedBox(width: 12),
            Text(
              'Bible Version',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: gameState.selectedVersion,
                items: supportedVersions
                    .map((v) => DropdownMenuItem<String>(
                          value: v,
                          child: Text(v),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(bibleGameProvider.notifier).changeVersion(value);
                  }
                },
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlipCard(BibleGameState gameState) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: gameState.hasCheckedAnswer
          ? _buildVerseBackCardReal(gameState)
          : _buildVersePromptCard(gameState),
    );
  }

  Widget _buildVersePromptCard(BibleGameState gameState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reference = gameState.currentVerse?.reference ?? '';
        final canFlip = gameState.attemptCount >= 3;
    final isListening = gameState.isListening;

    return InkWell(
      onTap: canFlip ? () => _confirmFlipCard(context) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        key: const ValueKey('prompt'),
        width: double.infinity,
        height: 200,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                    Theme.of(context).colorScheme.surface,
                  ]
                : [
                    Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.1),
                    Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withValues(alpha: 0.2),
                  ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark
                  ? Theme.of(context).colorScheme.outline
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.3),
              width: 2),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3)
                  : Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
              Text(
                'Recite the verse aloud (word-perfect)',
                textAlign: TextAlign.justify,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              const SizedBox(height: 8),
              // Bible reference kept here (removed from the top-left of card).
              Text(
                reference,
                textAlign: TextAlign.justify,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              // Clickable mic that captures the recitation.
              if (_speechEnabled) _buildVoiceMicButton(isListening: isListening),
              if (_speechEnabled) const SizedBox(height: 16),
              // Note: the card only flips once 3 attempts have been used.
              if (!canFlip)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Flip the card after 3 attempts to reveal the verse',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: canFlip ? () => _confirmFlipCard(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: canFlip
                          ? Colors.green.shade600
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest
                              .withValues(alpha: 0.5),
                      foregroundColor: canFlip
                          ? Colors.white
                          : Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5),
                      disabledBackgroundColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      disabledForegroundColor: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    icon: const Icon(Icons.flip_to_back),
                    label: Text(
                      canFlip
                          ? 'Flip (-2 pts)'
                          : 'Flip (${3 - gameState.attemptCount} attempts left)',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /* Widget _buildVerseBackCard_BLANK
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            } // end REMOVED_BLOCK */

    /// Circular mic button on the prompt-card face in Voice mode to capture
  /// the recitation.
  /// Wires into the same `_startListening` / `_stopListening` handlers.
  Widget _buildVoiceMicButton({required bool isListening}) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: GestureDetector(
        onTap: _speechEnabled
            ? (isListening ? _stopListening : _startListening)
            : null,
        child: Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isListening ? cs.error : cs.primary,
            boxShadow: [
              BoxShadow(
                color: (isListening ? cs.error : cs.primary)
                    .withValues(alpha: 0.35),
                blurRadius: isListening ? 24 : 10,
                spreadRadius: isListening ? 6 : 0,
              ),
            ],
          ),
          child: Icon(
            isListening ? Icons.stop : Icons.mic,
            color: cs.onPrimary,
            size: 38,
          ),
        ),
      ),
    );
  }

  Widget _buildVerseBackCardReal(BibleGameState gameState) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      key: const ValueKey('verse'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  Theme.of(context).colorScheme.surfaceContainerHighest,
                  Theme.of(context).colorScheme.surface,
                ]
              : [
                  Theme.of(context)
                      .colorScheme
                      .tertiaryContainer
                      .withValues(alpha: 0.1),
                  Theme.of(context)
                      .colorScheme
                      .tertiaryContainer
                      .withValues(alpha: 0.2),
                ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark
                ? Theme.of(context).colorScheme.outline
                : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
            width: 2),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Theme.of(context).colorScheme.shadow.withValues(alpha: 0.3)
                : Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.menu_book_rounded,
                color: Theme.of(context).colorScheme.tertiary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Bible Verse',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.tertiary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Text(
              gameState.currentVerse!.text[gameState.selectedVersion] ?? '',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.6,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(bibleGameProvider.notifier).flipCardBack();
                  final currentScore = ref.read(bibleGameProvider).score;
                  if (currentScore <= 0) {
                    _checkGameOver();
                  } else {
                    ref.read(bibleGameProvider.notifier).loadNewVerse();
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Flip Back & Next'),
              ),
              IconButton.filledTonal(
                onPressed: () => _speakVerse(
                  gameState.currentVerse!.text[gameState.selectedVersion] ?? '',
                ),
                icon: const Icon(Icons.volume_up),
                tooltip: 'Listen to verse',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFillInTheGapText(BibleGameState gameState) {
    final text = gameState.currentVerse!.text[gameState.selectedVersion] ?? '';
    final words =
        text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();

    final controllerKey =
        '${gameState.currentVerse!.reference}|${gameState.selectedVersion}|${gameState.blankedWords.join(',')}';
    if (_blankControllerKey != controllerKey) {
      for (final controller in _blankControllers.values) {
        controller.dispose();
      }
      _blankControllers.clear();
      for (final index in gameState.blankedWords) {
        _blankControllers[index] = TextEditingController();
      }
      _blankControllerKey = controllerKey;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          children: words.asMap().entries.map((entry) {
            final index = entry.key;
            final word = entry.value;
            final isBlank = gameState.blankedWords.contains(index);

            if (isBlank) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: IntrinsicWidth(
                  child: Container(
                    constraints: BoxConstraints(
                      minWidth: min(word.length * 12.0 + 16, 200),
                      maxWidth: 200,
                    ),
                    child: TextField(
                      controller: _blankControllers[index],
                      decoration: InputDecoration(
                        hintText: gameState.showHint ? word : '_' * word.length,
                        hintStyle:
                            Theme.of(context).textTheme.bodyLarge?.copyWith(
                                  color: gameState.showHint
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant
                                          .withValues(alpha: 0.5),
                                ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.outline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        isDense: true,
                      ),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                      textAlign: TextAlign.center,
                      onChanged: (value) {
                        // Update the user input with all filled blanks
                        _updateFillInTheGapInput(gameState, words);
                      },
                    ),
                  ),
                ),
              );
            } else {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
                child: Text(
                  '$word ',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                ),
              );
            }
          }).toList(),
        ),
      ],
    );
  }

  void _updateFillInTheGapInput(BibleGameState gameState, List<String> words) {
    final reconstructedText = words.asMap().entries.map((entry) {
      final index = entry.key;
      final word = entry.value;
      final isBlank = gameState.blankedWords.contains(index);

      if (isBlank && _blankControllers.containsKey(index)) {
        final typed = _blankControllers[index]!.text.trim();
        return typed.isEmpty ? '__blank__' : typed;
      }
      return word;
    }).join(' ');

    ref.read(bibleGameProvider.notifier).updateUserInput(reconstructedText);
  }

  /// Strip punctuation and lowercase text for easy comparison
  String _normalizeText(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '').trim();
  }

  /// Deduplicate repeated sentence fragments from STT partial results.
  /// e.g. "the Lord is good the Lord is good" → "the Lord is good"
  String _deduplicateTranscript(String text) {
    final words = text.split(RegExp(r'\s+'));
    if (words.length < 4) return text;

    // Try progressively larger prefix lengths to find a repeated block
    for (int prefixLen = (words.length ~/ 2); prefixLen >= 3; prefixLen--) {
      final prefix = words.sublist(0, prefixLen).join(' ').toLowerCase();
      final rest =
          words.sublist(prefixLen).join(' ').toLowerCase().trimLeft();
      if (rest.startsWith(prefix)) {
        // The first half repeated — return only the first occurrence
        return words.sublist(0, prefixLen).join(' ');
      }
    }
    return text;
  }

  /// Compact voice transcript box: shows max 2 lines + a similarity score
  /// so users (especially non-English speakers) know how close they are.
  Widget _buildVoiceTranscriptBox(BibleGameState gameState) {
    final correctText =
        gameState.currentVerse?.text[gameState.selectedVersion] ?? '';
    final userText = _deduplicateTranscript(gameState.userInput);

    // Calculate similarity 0-100%
    final normalizedUser = _normalizeText(userText);
    final normalizedCorrect = _normalizeText(correctText);
    final correctWords = normalizedCorrect.split(' ');
    final userWords = normalizedUser.split(' ').toSet();
    int matchCount = 0;
    for (final word in correctWords) {
      if (userWords.contains(word)) matchCount++;
    }
    final similarity = correctWords.isEmpty
        ? 0
        : ((matchCount / correctWords.length) * 100).round();

    Color simColor;
    if (similarity >= 80) {
      simColor = Theme.of(context).colorScheme.tertiary;
    } else if (similarity >= 50) {
      simColor = Theme.of(context).colorScheme.secondary;
    } else {
      simColor = Theme.of(context).colorScheme.error;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: simColor.withValues(alpha: 0.4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'You said:',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: simColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$similarity% match',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: simColor,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            userText,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildGameContent(BibleGameState gameState) {
    switch (gameState.gameMode) {
      case GameMode.fillInTheGap:
        return _buildFillInTheGapInput(gameState);
      case GameMode.voiceRecitation:
        return _buildVoiceRecitationInput(gameState);
      case GameMode.multipleChoice:
        return _buildMultipleChoiceInput(gameState);
    }
  }

  Widget _buildFillInTheGapInput(BibleGameState gameState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Fill in the missing words:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
            ),
            const SizedBox(height: 16),
            const Text(
              'A hint or auto-fill appears after 3 attempts (-2 pts).',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () {
                        if (gameState.showHint) {
                          _onNextAfterAutofill();
                        } else if (!gameState.showHint &&
                            gameState.showHintButton) {
                          _confirmFillGapsHint(context, gameState);
                        } else {
                          _submitFillGaps();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gameState.showHint
                            ? Theme.of(context).colorScheme.tertiary
                            : Theme.of(context).colorScheme.primary,
                        foregroundColor: gameState.showHint
                            ? Theme.of(context).colorScheme.onTertiary
                            : Theme.of(context).colorScheme.onPrimary,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            gameState.showHint ? 'Next' : 'Submit',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          if (gameState.showHint) ...[
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRecitationInput(BibleGameState gameState) {
    final cs = Theme.of(context).colorScheme;
    final isListening = gameState.isListening;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Recite the verse aloud (word-perfect):',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            // Recording box — tap to start/stop recording
            InkWell(
              onTap: _speechEnabled
                  ? (isListening ? _stopListening : _startListening)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isListening
                        ? cs.error
                        : cs.primary.withValues(alpha: 0.4),
                    width: isListening ? 2 : 1.5,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isListening
                      ? cs.error.withValues(alpha: 0.06)
                      : cs.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Mic / Stop icon inside the box
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                        key: ValueKey(isListening),
                        size: 40,
                        color: isListening ? cs.error : cs.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isListening ? 'Listening… Tap to stop' : 'Tap to start recording',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isListening ? cs.error : cs.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            if (gameState.userInput.isNotEmpty) ...[
              const SizedBox(height: 12),
              _buildVoiceTranscriptBox(gameState),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceInput(BibleGameState gameState) {
    final currentVerse = gameState.currentVerse;
    if (currentVerse == null) return const SizedBox.shrink();

    final correctAnswer = currentVerse.text[gameState.selectedVersion] ??
        currentVerse.text.values.first;
    final options = gameState.multipleChoiceOptions.isEmpty
        ? <String>[correctAnswer]
        : gameState.multipleChoiceOptions;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Select the correct verse:',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...options.asMap().entries.map((entry) {
              final index = entry.key;
              final option = entry.value;
              final isSelected = gameState.selectedChoiceIndex == index;
              final isCorrect = option == correctAnswer;
              final showResult = gameState.showAnswer;

              Color? backgroundColor;
              Color? textColor;

              if (showResult) {
                if (isCorrect) {
                  backgroundColor = Theme.of(context)
                      .colorScheme
                      .tertiary
                      .withValues(alpha: 0.2);
                  textColor = Theme.of(context).colorScheme.tertiary;
                } else if (isSelected && !isCorrect) {
                  backgroundColor = Theme.of(context)
                      .colorScheme
                      .error
                      .withValues(alpha: 0.2);
                  textColor = Theme.of(context).colorScheme.error;
                }
              } else if (isSelected) {
                backgroundColor = Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.2);
                textColor = Theme.of(context).colorScheme.primary;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: showResult
                      ? null
                      : () {
                          ref
                              .read(bibleGameProvider.notifier)
                              .selectChoice(index);
                        },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .outline
                                .withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${String.fromCharCode(65 + index)}. $option',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: textColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            if (!gameState.showAnswer)
              ElevatedButton(
                onPressed: gameState.selectedChoiceIndex != null
                    ? () => ref
                        .read(bibleGameProvider.notifier)
                        .checkMultipleChoiceAnswer()
                    : null,
                child: const Text('Check'),
              )
            else
              ElevatedButton(
                onPressed: () =>
                    ref.read(bibleGameProvider.notifier).loadNewVerse(),
                child: const Text('Next'),
              ),
          ],
        ),
      ),
    );
  }
}

