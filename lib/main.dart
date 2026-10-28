import 'dart:async';
import 'dart:math';
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';

// ============================================================
// 🖱️  DISABLE BROWSER RIGHT-CLICK CONTEXT MENU (Flutter Web)  🖱️
// ============================================================
// This conditional import picks the real dart:html-based
// implementation when compiled for web, and a harmless no-op
// version on mobile/desktop (dart:html isn't available there).
// See disable_context_menu_web.dart / disable_context_menu_stub.dart
// if you want to change how this works.
// ============================================================
import 'disable_context_menu_stub.dart'
    if (dart.library.js_interop) 'disable_context_menu_web.dart';

void main() {
  // Right click inside the game itself still works as "flag"
  // (see onSecondaryTap in _buildCell below) — this only stops
  // the browser's own native popup menu.
  if (kIsWeb) {
    disableRightClickMenu();
  }

  runApp(const MyApp());
}

// ===========================================================================
// AudioManager — Centralized audio playback for the Minesweeper app.
// ===========================================================================
// This singleton manages sound effects. It is wired into the Options dialog
// (SFX volume slider) and game events (dig, flag, mine hit, win, defeat).
//
// Audio assets live in `assets/audio/` and are registered in pubspec.yaml.
// To swap in your own sounds, simply replace the .wav files there — the code
// references them by name via AssetSource.
//
// All public methods are safe to call at any time; errors are caught and
// logged so they never crash the game.
// ===========================================================================
class AudioManager {
  // Private constructor — use [AudioManager.instance] to access the singleton.
  AudioManager._internal();
  static final AudioManager instance = AudioManager._internal();

  /// Current sound-effect volume (0.0 – 1.0), controlled by the Options slider.
  double sfxVolume = 0.5;

  /// Dedicated player for one-shot sound effects (dig, flag, explosion, win).
  final AudioPlayer _sfxPlayer = AudioPlayer();

  /// Dedicated player for the defeat jingle, so it can overlap the explosion
  /// instead of cutting it off by reusing [_sfxPlayer].
  final AudioPlayer _defeatPlayer = AudioPlayer();

  /// Updates the sound-effect volume for future SFX playback.
  ///
  /// Note: this only affects sounds played *after* the call; it does not
  /// change the volume of a sound that is already playing.
  Future<void> updateSfxVolume(double value) async {
    sfxVolume = value;
  }

  /// Plays the short "dig" sound effect at the current [sfxVolume].
  ///
  /// Triggered when the player successfully reveals a non-mine cell.
  /// The dig is played at half the general SFX volume (sfxVolume * 0.5)
  /// so it sits quieter than the other effects — tweak the 0.5 as needed.
  Future<void> playDigSound() async {
    try {
      await _sfxPlayer.play(
        AssetSource('audio/dig.wav'),
        volume: sfxVolume * 0.10,
      );
    } catch (e) {
      debugPrint('AudioManager: failed to play dig sound — $e');
    }
  }

  /// Plays the "flag placed" sound effect at the current [sfxVolume].
  ///
  /// Triggered when the player places or removes a flag on a cell.
  Future<void> playFlagSound() async {
    try {
      await _sfxPlayer.play(AssetSource('audio/flag.wav'), volume: sfxVolume);
    } catch (e) {
      debugPrint('AudioManager: failed to play flag sound — $e');
    }
  }

  /// Plays a cheerful victory jingle at the current [sfxVolume].
  ///
  /// Triggered when the player clears the whole board.
  Future<void> playWinSound() async {
    try {
      await _sfxPlayer.play(AssetSource('audio/win.wav'), volume: sfxVolume);
    } catch (e) {
      debugPrint('AudioManager: failed to play win sound — $e');
    }
  }

  /// Plays a sarcastic "sad trombone" defeat tone at half the current [sfxVolume].
  ///
  /// Triggered a moment after the player hits a mine.
  /// Uses its own [_defeatPlayer] so it can overlap safely with other sounds.
  Future<void> playDefeatSound() async {
    try {
      await _defeatPlayer.play(
        AssetSource('audio/defeat.wav'),
        volume: sfxVolume * 0.15,
      );
    } catch (e) {
      debugPrint('AudioManager: failed to play defeat sound — $e');
    }
  }

  /// Releases native audio resources held by the sound-effects players.
  ///
  /// Should be called when the app is shutting down to avoid resource leaks.
  Future<void> dispose() async {
    try {
      await _sfxPlayer.dispose();
      await _defeatPlayer.dispose();
    } catch (e) {
      debugPrint('AudioManager: failed to dispose players — $e');
    }
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Minesweeper',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF3E5C76),
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1B1F24),
      ),
      home: const DifficultyScreen(),
    );
  }
}

enum Difficulty { easy, medium, hard }

class DifficultyScreen extends StatefulWidget {
  const DifficultyScreen({super.key});

  @override
  State<DifficultyScreen> createState() => _DifficultyScreenState();
}

class _DifficultyScreenState extends State<DifficultyScreen> {
  double _sliderValue = 0;

  Difficulty get _selected => Difficulty.values[_sliderValue.round()];

  IconData get _face {
    switch (_selected) {
      case Difficulty.easy:
        return Icons.sentiment_satisfied;
      case Difficulty.medium:
        return Icons.sentiment_neutral;
      case Difficulty.hard:
        return Icons.sentiment_very_dissatisfied;
    }
  }

  Color get _faceColor {
    switch (_selected) {
      case Difficulty.easy:
        return Colors.greenAccent;
      case Difficulty.medium:
        return Colors.orangeAccent;
      case Difficulty.hard:
        return Colors.redAccent;
    }
  }

  String get _label {
    switch (_selected) {
      case Difficulty.easy:
        return 'Easy    9 x 9   10 mines';
      case Difficulty.medium:
        return 'Medium  13 x 13  30 mines';
      case Difficulty.hard:
        return 'Hard    16 x 16  55 mines';
    }
  }

  // ============================================================
  // ⚙️  OPTIONS MENU — SOUND EFFECT VOLUME (0% - 100%)  ⚙️
  // ============================================================
  void _showOptionsDialog() {
    double sfxVal = AudioManager.instance.sfxVolume * 100;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return AlertDialog(
              title: const Text('Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.volume_up),
                      const SizedBox(width: 8),
                      Text('Sound Effects: ${sfxVal.round()}%'),
                    ],
                  ),
                  Slider(
                    value: sfxVal,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: '${sfxVal.round()}%',
                    onChanged: (v) {
                      setDialogState(() => sfxVal = v);
                      AudioManager.instance.updateSfxVolume(v / 100);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // 🚪  EXIT — CLOSES THE GAME  🚪
  // ============================================================
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Exit Game'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              // Note: web browsers block pages from closing their own tab
              // for security reasons, so on web we just let the user know.
              // On Android / iOS / Desktop this actually closes the app.
              if (kIsWeb) {
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Close this browser tab to exit.'),
                  ),
                );
              } else {
                SystemNavigator.pop();
              }
            },
            child: const Text('Exit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        actions: [
          TextButton.icon(
            onPressed: _showOptionsDialog,
            icon: const Icon(Icons.settings),
            label: const Text('Options'),
          ),

          TextButton.icon(
            onPressed: _showExitDialog,
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Exit'),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'MINESWEEPER',
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'now with Radar Scan',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 40),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _face,
                key: ValueKey(_selected),
                size: 90,
                color: _faceColor,
              ),
            ),
            const SizedBox(height: 12),
            Text(_label, style: const TextStyle(fontSize: 15)),
            SizedBox(
              width: 280,
              child: Slider(
                value: _sliderValue,
                min: 0,
                max: 2,
                divisions: 2,
                activeColor: _faceColor,
                onChanged: (v) => setState(() => _sliderValue = v),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 200,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GameScreen(difficulty: _selected),
                    ),
                  );
                },
                child: const Text('Start'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class Cell {
  bool isMine = false;
  bool isRevealed = false;
  bool isFlagged = false;
  int adjacentMines = 0;
}

enum Tool { shovel, flag }

class GameScreen extends StatefulWidget {
  final Difficulty difficulty;
  const GameScreen({super.key, required this.difficulty});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late int rows, cols, mineCount;
  late List<List<Cell>> board;
  bool firstTapDone = false;
  bool gameOver = false;
  int flagsPlaced = 0;
  int secondsElapsed = 0;
  Timer? timer;

  Tool selectedTool = Tool.shovel;

  int radarUses = 3;
  bool radarActive = false;
  Point<int>? radarCell;
  int? radarResult;

  @override
  void initState() {
    super.initState();
    switch (widget.difficulty) {
      case Difficulty.easy:
        rows = 9;
        cols = 9;
        mineCount = 10;
        break;
      case Difficulty.medium:
        rows = 13;
        cols = 13;
        mineCount = 30;
        break;
      case Difficulty.hard:
        rows = 16;
        cols = 16;
        mineCount = 55;
        break;
    }
    _resetBoard();
  }

  void _resetBoard() {
    board = List.generate(rows, (_) => List.generate(cols, (_) => Cell()));
    firstTapDone = false;
    gameOver = false;
    flagsPlaced = 0;
    secondsElapsed = 0;
    selectedTool = Tool.shovel;
    radarUses = 3;
    radarActive = false;
    radarResult = null;
    radarCell = null;
    timer?.cancel();
    timer = null;
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!gameOver) setState(() => secondsElapsed++);
    });
  }

  void _placeMines(int excludeRow, int excludeCol) {
    final rand = Random();
    int placed = 0;
    while (placed < mineCount) {
      int r = rand.nextInt(rows);
      int c = rand.nextInt(cols);
      if ((r - excludeRow).abs() <= 1 && (c - excludeCol).abs() <= 1) continue;
      if (board[r][c].isMine) continue;
      board[r][c].isMine = true;
      placed++;
    }
    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        if (!board[r][c].isMine) {
          board[r][c].adjacentMines = _countAdjacentMines(r, c);
        }
      }
    }
  }

  int _countAdjacentMines(int r, int c) {
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        int nr = r + dr, nc = c + dc;
        if (nr >= 0 &&
            nr < rows &&
            nc >= 0 &&
            nc < cols &&
            board[nr][nc].isMine) {
          count++;
        }
      }
    }
    return count;
  }

  void _handleTap(int r, int c) {
    if (gameOver) return;

    if (radarActive) {
      _doRadarScan(r, c);
      return;
    }

    if (selectedTool == Tool.flag) {
      _toggleFlag(r, c);
    } else {
      _revealCell(r, c);
    }
  }

  void _revealCell(int r, int c) {
    final cell = board[r][c];
    if (cell.isRevealed || cell.isFlagged) return;

    if (!firstTapDone) {
      _placeMines(r, c);
      firstTapDone = true;
      _startTimer();
    }

    setState(() {
      if (cell.isMine) {
        _revealAllMines();
        gameOver = true;
        timer?.cancel();
        // Play defeat jingle after a short delay.
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) AudioManager.instance.playDefeatSound();
        });
        _showEndDialog(false);
      } else {
        _floodFill(r, c);
        // Successful dig — play dig sound (fire-and-forget).
        AudioManager.instance.playDigSound();
        if (_checkWin()) {
          gameOver = true;
          timer?.cancel();
          // Victory — play win jingle (fire-and-forget).
          AudioManager.instance.playWinSound();
          _showEndDialog(true);
        }
      }
    });
  }

  void _floodFill(int r, int c) {
    if (r < 0 || r >= rows || c < 0 || c >= cols) return;
    final cell = board[r][c];
    if (cell.isRevealed || cell.isFlagged) return;
    cell.isRevealed = true;
    if (cell.adjacentMines == 0) {
      for (int dr = -1; dr <= 1; dr++) {
        for (int dc = -1; dc <= 1; dc++) {
          if (dr == 0 && dc == 0) continue;
          _floodFill(r + dr, c + dc);
        }
      }
    }
  }

  void _revealAllMines() {
    for (var row in board) {
      for (var cell in row) {
        if (cell.isMine) cell.isRevealed = true;
      }
    }
  }

  bool _checkWin() {
    for (var row in board) {
      for (var cell in row) {
        if (!cell.isMine && !cell.isRevealed) return false;
      }
    }
    return true;
  }

  void _toggleFlag(int r, int c) {
    final cell = board[r][c];
    if (gameOver || cell.isRevealed) return;
    setState(() {
      cell.isFlagged = !cell.isFlagged;
      flagsPlaced += cell.isFlagged ? 1 : -1;
      // Play flag sound when a flag is placed (fire-and-forget).
      if (cell.isFlagged) {
        AudioManager.instance.playFlagSound();
      }
    });
  }

  void _doRadarScan(int r, int c) {
    if (radarUses <= 0 || board[r][c].isRevealed) return;
    if (!firstTapDone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reveal a cell first, then scan.'),
          duration: Duration(seconds: 2),
        ),
      );
      setState(() => radarActive = false);
      return;
    }
    int count = 0;
    for (int dr = -1; dr <= 1; dr++) {
      for (int dc = -1; dc <= 1; dc++) {
        int nr = r + dr, nc = c + dc;
        if (nr >= 0 &&
            nr < rows &&
            nc >= 0 &&
            nc < cols &&
            board[nr][nc].isMine) {
          count++;
        }
      }
    }
    setState(() {
      radarUses--;
      radarActive = false;
      radarCell = Point(r, c);
      radarResult = count;
    });
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          radarCell = null;
          radarResult = null;
        });
      }
    });
  }

  void _showEndDialog(bool didWin) {
    List<String> loseMessage = [
      'Did you even try?',
      'Skill issue :D',
      'Miscalculated.',
      'Git gud!',
      'Another bomb? Just quit.',
      'You might need an AI to solve this.',
      'You can do better, right?',
    ];
    final random = Random();

    // Random integer between 0 and 99
    int randomInt = random.nextInt(loseMessage.length);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(didWin ? 'You cleared the field!' : 'Boom!'),
          content: Text(
            didWin
                ? 'Finished in $secondsElapsed seconds.'
                : loseMessage[randomInt],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(_resetBoard);
              },
              child: const Text('Restart'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('Menu'),
            ),
          ],
        ),
      );
    });
  }

  Color _numberColor(int n) {
    switch (n) {
      case 1:
        return Colors.lightBlueAccent;
      case 2:
        return Colors.greenAccent;
      case 3:
        return Colors.redAccent;
      case 4:
        return Colors.purpleAccent;
      case 5:
        return Colors.orangeAccent;
      case 6:
        return Colors.tealAccent;
      case 7:
        return Colors.white;
      case 8:
        return Colors.grey;
      default:
        return Colors.black;
    }
  }

  // ============================================================
  // ❓  HELP DIALOG — EDIT THE RADAR SCAN INSTRUCTIONS BELOW  ❓
  // ============================================================
  // Feel free to rewrite the title / text here, or move this whole
  // method (and the IconButton that calls it, in the AppBar actions
  // below) somewhere else in the UI if you'd rather have the help
  // button in a different spot.
  // ============================================================
  void _showRadarHelpDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [Icon(Icons.radar), SizedBox(width: 8), Text('Radar Scan')],
        ),
        content: const Text(
          'Radar Scan lets you peek at a hidden cell without revealing it.\n\n'
          '1. Tap the "Radar Scan" button below the board to activate it.\n'
          '2. Tap any hidden cell you want to check.\n'
          '3. The number of mines touching that cell will show for a '
          'few seconds.\n\n'
          'You only get 3 scans per game, so use them wisely!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // PopScope guards the route: on Android, a mouse right-click can be
    // converted by the OS/emulator into the system "back" action, which would
    // instantly pop this screen back to the menu. canPop:false blocks that and
    // routes it through _confirmExitToMenu instead.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && mounted) _confirmExitToMenu();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag, size: 18, color: Colors.redAccent),
                  const SizedBox(width: 4),
                  Text('${mineCount - flagsPlaced}'),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.timer, size: 18),
                  const SizedBox(width: 4),
                  Text('$secondsElapsed s'),
                ],
              ),
            ],
          ),
          actions: [
            // ❓ Help button (see _showRadarHelpDialog above to edit the text).
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'How to use Radar Scan',
              onPressed: _showRadarHelpDialog,
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => setState(_resetBoard),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 8.0,
                  horizontal: 8.0,
                ),
                child: ElevatedButton.icon(
                  onPressed: radarUses > 0 && !gameOver
                      ? () => setState(() => radarActive = !radarActive)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: radarActive ? Colors.amber : null,
                    foregroundColor: radarActive ? Colors.black : null,
                  ),
                  icon: const Icon(Icons.radar),
                  label: Text('Radar Scan ($radarUses left)'),
                ),
              ),
              Expanded(
                child: Center(
                  child: AspectRatio(
                    aspectRatio: cols / rows,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: GridView.builder(
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: cols,
                        ),
                        itemCount: rows * cols,
                        itemBuilder: (context, index) {
                          int r = index ~/ cols;
                          int c = index % cols;
                          return _buildCell(r, c);
                        },
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12.0,
                  horizontal: 8.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _toolButton(Tool.shovel, Icons.construction, 'Shovel'),
                    const SizedBox(width: 12),
                    _toolButton(Tool.flag, Icons.flag, 'Flag'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Asks the player to confirm leaving to the menu, instead of letting an
  /// accidental back action (e.g. Android right-click -> back) kick them out.
  Future<void> _confirmExitToMenu() async {
    final bool? leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave game?'),
        content: const Text(
          'Your current game will be lost. Head back to the menu?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep playing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _toolButton(Tool tool, IconData icon, String label) {
    bool isSelected = selectedTool == tool && !radarActive;
    return ElevatedButton.icon(
      onPressed: () => setState(() {
        selectedTool = tool;
        radarActive = false;
      }),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected
            ? Theme.of(context).colorScheme.primary
            : null,
        foregroundColor: isSelected ? Colors.white : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }

  Widget _buildCell(int r, int c) {
    final cell = board[r][c];
    Widget content;
    Color bg;
    bool isScanned =
        radarCell != null && radarCell!.x == r && radarCell!.y == c;

    if (cell.isRevealed) {
      bg = cell.isMine ? Colors.red : const Color(0xFF2A2F36);
      if (cell.isMine) {
        content = const Icon(Icons.dangerous, color: Colors.black, size: 16);
      } else if (cell.adjacentMines > 0) {
        content = Text(
          '${cell.adjacentMines}',
          style: TextStyle(
            color: _numberColor(cell.adjacentMines),
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        content = const SizedBox.shrink();
      }
    } else {
      bg = (r + c) % 2 == 0 ? const Color(0xFF3E5C76) : const Color(0xFF4A6B8A);
      if (cell.isFlagged) {
        content = const Icon(Icons.flag, color: Colors.redAccent, size: 16);
      } else if (isScanned) {
        content = Text(
          '$radarResult',
          style: const TextStyle(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        );
      } else {
        content = const SizedBox.shrink();
      }
    }

    // Right-click is handled ONLY by the raw Listener below so each right-click
    // flags the tile exactly once. GestureDetector.onSecondaryTap is not used
    // because (a) it is unreliable on Windows desktop / Flutter web, and
    // (b) keeping it alongside the Listener would toggle the flag twice
    // (flag on, then immediately unflag) — a net no-op.
    return GestureDetector(
      onTap: () => _handleTap(r, c),
      onLongPress: () => _toggleFlag(r, c),
      child: Listener(
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons == kSecondaryMouseButton) {
            _toggleFlag(r, c);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: isScanned ? Colors.amber.withValues(alpha: 0.3) : bg,
            borderRadius: BorderRadius.circular(4),
            border: isScanned
                ? Border.all(color: Colors.amber, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );
  }
}
