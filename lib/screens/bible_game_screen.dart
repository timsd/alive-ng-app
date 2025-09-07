import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:math';
import '../data/bible_verses.dart' as bible_data;
import '../widgets/bible_reference_widget.dart';

// Game State Provider
final bibleGameProvider =
    StateNotifierProvider<BibleGameNotifier, BibleGameState>((ref) {
  return BibleGameNotifier();
});

class BibleGameState {
  final bible_data.BibleVerse? currentVerse;
  final String selectedVersion;
  final int currentLevel;
  final int score;
  final List<String> completedVerses;
  final GameMode gameMode;
  final bool isListening;
  final String userInput;
  final List<int> blankedWords;
  final bool showHint;

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
  });

  BibleGameState copyWith({
    bible_data.BibleVerse? currentVerse,
    String? selectedVersion,
    int? currentLevel,
    int? score,
    List<String>? completedVerses,
    GameMode? gameMode,
    bool? isListening,
    String? userInput,
    List<int>? blankedWords,
    bool? showHint,
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
    _loadNewVerse();
  }

  final Random _random = Random();

  void _loadNewVerse() {
    final verse =
        bible_data.dailyVerses[_random.nextInt(bible_data.dailyVerses.length)];
    final blankedWords =
        _generateBlankedWords(verse.text[state.selectedVersion] ?? '');

    state = state.copyWith(
      currentVerse: verse,
      blankedWords: blankedWords,
      userInput: '',
      showHint: false,
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

    if (isCorrect) {
      final newScore = state.score + (state.showHint ? 5 : 10);
      final newCompleted = [
        ...state.completedVerses,
        state.currentVerse!.reference
      ];

      state = state.copyWith(
        score: newScore,
        completedVerses: newCompleted,
      );

      _loadNewVerse();
    }
  }

  bool _isAnswerCorrect(String userAnswer, String correctAnswer) {
    // Simple similarity check - can be enhanced
    final userWords = userAnswer.toLowerCase().split(' ');
    final correctWords = correctAnswer.toLowerCase().split(' ');

    int matches = 0;
    for (final word in userWords) {
      if (correctWords.contains(word)) {
        matches++;
      }
    }

    return matches / correctWords.length >= 0.8; // 80% accuracy
  }

  void nextVerse() {
    _loadNewVerse();
  }

  void changeVersion(String version) {
    state = state.copyWith(selectedVersion: version);
    _loadNewVerse();
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
  bool _speechEnabled = false;

  @override
  void initState() {
    super.initState();
    _initializeSpeech();
    _initializeTts();
  }

  void _initializeSpeech() async {
    _speech = stt.SpeechToText();
    _speechEnabled = await _speech.initialize();
    setState(() {});
  }

  void _initializeTts() async {
    _tts = FlutterTts();
    await _tts.setLanguage('en-US');
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

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final gameState = ref.watch(bibleGameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bible Memorization Game'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (version) {
              ref.read(bibleGameProvider.notifier).changeVersion(version);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'NIV', child: Text('NIV')),
              const PopupMenuItem(value: 'KJV', child: Text('KJV')),
              const PopupMenuItem(value: 'NKJV', child: Text('NKJV')),
            ],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Chip(
                label: Text(gameState.selectedVersion),
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
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
                  _buildVerseCard(gameState),
                  const SizedBox(height: 20),
                  _buildGameContent(gameState),
                ],
              ),
            ),
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

  Widget _buildFillInTheGapText(BibleGameState gameState) {
    final text = gameState.currentVerse!.text[gameState.selectedVersion] ?? '';
    final words = text.split(' ');

    return Wrap(
      children: words.asMap().entries.map((entry) {
        final index = entry.key;
        final word = entry.value;
        final isBlank = gameState.blankedWords.contains(index);

        if (isBlank) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(4),
                color: Colors.blue.withValues(alpha: 0.1),
              ),
              child: Text(
                gameState.showHint ? word : '_' * word.length,
                style: TextStyle(
                  fontSize: 16,
                  color: gameState.showHint ? Colors.blue : Colors.transparent,
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
            const Text(
              'Fill in the missing words:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Type the complete verse here...',
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                ref.read(bibleGameProvider.notifier).updateUserInput(value);
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      ref.read(bibleGameProvider.notifier).checkAnswer();
                    },
                    child: const Text('Check Answer'),
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
                  child: const Text('Hint'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.read(bibleGameProvider.notifier).nextVerse();
                    _textController.clear();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                  ),
                  child: const Text('Skip'),
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
                  child: const Text('Check'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMultipleChoiceInput(BibleGameState gameState) {
    // TODO: Implement multiple choice mode
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text('Multiple choice mode coming soon!'),
      ),
    );
  }
}
