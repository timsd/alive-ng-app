import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import '../../services/bible_source.dart';
import '../../data/bible_verses.dart';
import '../../widgets/bible_reference_widget.dart';
import '../../widgets/star_animation_widget.dart';
import '../../providers/language_provider.dart';

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
  final bool showAnswer;

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
    this.showAnswer = false,
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
    bool? showAnswer,
  }) {
    return BibleGameState(
      currentVerse: currentVerse ?? this.currentVerse,
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
      selectedChoiceIndex: selectedChoiceIndex ?? this.selectedChoiceIndex,
      showAnswer: showAnswer ?? this.showAnswer,
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

  void loadNewVerse() {
    final corpus = BibleSource.instance.dailyCorpus;
    final verse = corpus[_random.nextInt(corpus.length)];
    final blankedWords =
        _generateBlankedWords(verse.text[state.selectedVersion] ?? '');

    state = state.copyWith(
      currentVerse: verse,
      blankedWords: blankedWords,
      userInput: '',
      showHint: false,
      hasCheckedAnswer: false,
      selectedChoiceIndex: null,
      showAnswer: false,
    );
  }

  List<int> _generateBlankedWords(String text) {
    final words = text.split(' ');
    final numBlanks = (words.length * 0.2).ceil(); // 20% of words
    final blankedIndices = <int>[];

    while (blankedIndices.length < numBlanks) {
      final index = _random.nextInt(words.length);
      if (!blankedIndices.contains(index)) {
        blankedIndices.add(index);
      }
    }

    return blankedIndices..sort();
  }

  void setGameMode(GameMode mode) {
    state = state.copyWith(gameMode: mode);
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

    final correctText = state.currentVerse!.text[state.selectedVersion] ?? '';
    final isCorrect = _isAnswerCorrect(state.userInput, correctText);

    // Mark that answer has been checked
    state = state.copyWith(hasCheckedAnswer: true);

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
      );

      // Hide animation after 3 seconds and load new verse
      Future.delayed(const Duration(seconds: 3), () {
        state = state.copyWith(showStarAnimation: false);
        loadNewVerse();
      });
    } else {
      // Show "Try Again" message for incorrect answers
      state = state.copyWith(showAnswer: false);
      // Reset user input to allow retry
      state = state.copyWith(userInput: '');
    }
  }

  void hideStarAnimation() {
    state = state.copyWith(showStarAnimation: false);
  }

  bool _isAnswerCorrect(String userAnswer, String correctAnswer) {
    final normalizedUser = _normalizeText(userAnswer);
    final normalizedCorrect = _normalizeText(correctAnswer);
    // Word-perfect means exact normalized match only.
    return normalizedUser == normalizedCorrect;
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
    if (state.selectedChoiceIndex == null) return;
    
    final isCorrect = state.selectedChoiceIndex == 0; // First option is always correct
    
    if (isCorrect) {
      state = state.copyWith(
        score: state.score + 10,
        showStarAnimation: true,
        showAnswer: true,
      );
      
      // Show star animation and move to next verse after delay
      Future.delayed(const Duration(seconds: 2), () {
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

class _BibleGameScreenState extends ConsumerState<BibleGameScreen> {
  late stt.SpeechToText _speech;
  late FlutterTts _tts;
  final TextEditingController _textController = TextEditingController();
  final Map<int, TextEditingController> _blankControllers = {};
  String _blankControllerKey = '';
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    _speechEnabled = await _speech.initialize(
      onError: (error) => debugPrint('Speech recognition error: $error'),
      onStatus: (status) => debugPrint('Speech recognition status: $status'),
    );
    setState(() {});
  }

  void _initializeTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-NG'); // Nigerian English
    await _tts.setSpeechRate(0.5);
  }

  void _startListening() async {
    if (_speechEnabled) {
      ref.read(bibleGameProvider.notifier).setListening(true);
      await _speech.listen(
        onResult: (result) {
          ref
              .read(bibleGameProvider.notifier)
              .updateUserInput(result.recognizedWords);
          _textController.text = result.recognizedWords;
        },
        localeId: 'en-NG', // Nigerian English locale
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
        onSoundLevelChange: (level) => debugPrint('Sound level: $level'),
        listenOptions: stt.SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenMode: stt.ListenMode.confirmation,
        ),
      );
    }
  }

  void _stopListening() async {
    await _speech.stop();
    ref.read(bibleGameProvider.notifier).setListening(false);
  }

  void _speakVerse(String text) async {
    await _tts.speak(text);
  }

  void _playSuccessSound() async {
    // Play a celebratory sound using TTS
    await _tts.speak('Word Perfect! Well Done!');
  }

  @override
  void dispose() {
    _textController.dispose();
    for (final controller in _blankControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(bibleGameProvider);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: Text(ref.watch(translationProvider)('bible_memorization_game')),
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
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
            _playSuccessSound();
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
                const Icon(Icons.star, color: Colors.amber, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Score: ${gameState.score}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Completed: ${gameState.completedVerses.length}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Column(
              children: [
                const Icon(Icons.trending_up, color: Colors.blue, size: 30),
                const SizedBox(height: 4),
                Text(
                  'Level: ${gameState.currentLevel}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
            const Text(
              'Game Mode',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    return ElevatedButton.icon(
      onPressed: () => ref.read(bibleGameProvider.notifier).setGameMode(mode),
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? Theme.of(context).primaryColor : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black87,
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
                BibleReferenceWidget(
                  text: gameState.currentVerse!.reference,
                  textStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                IconButton(
                  onPressed: () => _speakVerse(
                    gameState.currentVerse!.text[gameState.selectedVersion] ??
                        '',
                  ),
                  icon: const Icon(Icons.volume_up),
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

  Widget _buildFlipCard(BibleGameState gameState) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(opacity: animation, child: child);
      },
      child: gameState.hasCheckedAnswer
          ? _buildVerseBackCard(gameState)
          : _buildVersePromptCard(),
    );
  }

  Widget _buildVersePromptCard() {
    return Container(
      key: const ValueKey('prompt'),
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade50,
            Colors.blue.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.mic_rounded,
            size: 48,
            color: Colors.blue.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Recite the verse from memory',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.blue.shade800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Click "Check" to reveal the verse',
            style: TextStyle(
              fontSize: 14,
              fontStyle: FontStyle.italic,
              color: Colors.blue.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flip_to_back,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
                const SizedBox(width: 8),
                Text(
                  'Tap to flip and see verse',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerseBackCard(BibleGameState gameState) {
    return Container(
      key: const ValueKey('verse'),
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.green.shade50,
            Colors.green.shade100,
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
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
                color: Colors.green.shade600,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                'Bible Verse',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Text(
              gameState.currentVerse!.text[gameState.selectedVersion] ?? '',
              style: const TextStyle(
                fontSize: 16,
                height: 1.6,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: 16,
                      color: Colors.green.shade600,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Verse Revealed',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFillInTheGapText(BibleGameState gameState) {
    final text = gameState.currentVerse!.text[gameState.selectedVersion] ?? '';
    final words = text.split(' ');

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
                      minWidth: word.length * 12.0 + 16, // Minimum width based on word length
                      maxWidth: 120,
                    ),
                    child: TextField(
                      controller: _blankControllers[index],
                      decoration: InputDecoration(
                        hintText: gameState.showHint ? word : '_' * word.length,
                        hintStyle: TextStyle(
                          color: gameState.showHint ? Colors.blue : Colors.grey.withValues(alpha: 0.5),
                          fontSize: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: const BorderSide(color: Colors.blue, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.blue.withValues(alpha: 0.1),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        isDense: true,
                      ),
                      style: const TextStyle(fontSize: 16),
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
                  style: const TextStyle(fontSize: 16),
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
            const Text(
              'Fill in the missing words:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(bibleGameProvider.notifier).checkAnswer();
                    },
                    child: Text(ref.watch(translationProvider)('check_answer')),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.read(bibleGameProvider.notifier).showHint();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                  ),
                  child: Text(ref.watch(translationProvider)('hint')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceRecitationInput(BibleGameState gameState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recite the verse aloud:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Container(
              height: 120,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      gameState.isListening ? Icons.mic : Icons.mic_none,
                      size: 40,
                      color: gameState.isListening ? Colors.red : Colors.grey,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      gameState.isListening
                          ? 'Listening...'
                          : 'Tap to start recording',
                      style: TextStyle(
                        color: gameState.isListening ? Colors.red : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (gameState.userInput.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'You said: "${gameState.userInput}"',
                  style: const TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _speechEnabled
                        ? (gameState.isListening
                            ? _stopListening
                            : _startListening)
                        : null,
                    icon: Icon(gameState.isListening ? Icons.stop : Icons.mic),
                    label: Text(gameState.isListening ? 'Stop' : 'Record'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          gameState.isListening ? Colors.red : Colors.blue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: gameState.userInput.isNotEmpty
                      ? () => ref.read(bibleGameProvider.notifier).checkAnswer()
                      : null,
                  child: Text(ref.watch(translationProvider)('check')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceInput(BibleGameState gameState) {
    final currentVerse = gameState.currentVerse;
    if (currentVerse == null) return const SizedBox.shrink();
    
    // Generate multiple choice options
    final correctAnswer = currentVerse.text[gameState.selectedVersion] ?? currentVerse.text.values.first;
    final options = _generateMultipleChoiceOptions(correctAnswer);
    
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
                  backgroundColor = Colors.green.withValues(alpha: 0.2);
                  textColor = Colors.green[700];
                } else if (isSelected && !isCorrect) {
                  backgroundColor = Colors.red.withValues(alpha: 0.2);
                  textColor = Colors.red[700];
                }
              } else if (isSelected) {
                backgroundColor = Theme.of(context).colorScheme.primary.withValues(alpha: 0.2);
                textColor = Theme.of(context).colorScheme.primary;
              }
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: showResult ? null : () {
                    ref.read(bibleGameProvider.notifier).selectChoice(index);
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      border: Border.all(
                        color: isSelected 
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${String.fromCharCode(65 + index)}. $option',
                      style: TextStyle(
                        color: textColor,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
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
                     ? () => ref.read(bibleGameProvider.notifier).checkMultipleChoiceAnswer()
                     : null,
                 child: const Text('Check'),
               )
             else
               ElevatedButton(
                  onPressed: () => ref.read(bibleGameProvider.notifier).loadNewVerse(),
                  child: const Text('Next'),
                ),
          ],
        ),
      ),
    );
  }
  
  List<String> _generateMultipleChoiceOptions(String correctAnswer) {
    // This is a simplified implementation
    // In a real app, you'd want more sophisticated wrong answers
    final options = <String>[correctAnswer];
    
    // Add some generic wrong answers
    final wrongAnswers = [
      'For God so loved the world that he gave his one and only Son.',
      'The Lord is my shepherd, I lack nothing.',
      'Trust in the Lord with all your heart and lean not on your own understanding.',
      'I can do all this through him who gives me strength.',
      'Be strong and courageous. Do not be afraid; do not be discouraged.',
    ];
    
    // Remove the correct answer if it's in wrong answers
    wrongAnswers.removeWhere((answer) => answer == correctAnswer);
    
    // Add 3 wrong answers
    for (int i = 0; i < 3 && i < wrongAnswers.length; i++) {
      options.add(wrongAnswers[i]);
    }
    
    // Shuffle the options
    options.shuffle();
    
    return options;
  }
}




