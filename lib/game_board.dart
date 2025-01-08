import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' show Point, Random, sqrt;
import 'package:flutter/foundation.dart';
import 'game_state.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  _GameBoardState createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> with TickerProviderStateMixin {
  late GameState gameState;
  final Random random = Random();
  late AnimationController _controller;
  late AnimationController _winAnimationController;
  List<List<AnimationController>> tileControllers = [];
  bool _showUndo = false;
  final FocusNode _focusNode = FocusNode();
  Offset? _panStartPosition;
  Offset? _lastUpdatePosition;
  DateTime? _panStartTime;
  final double _minSwipeDistance = 10.0;
  final double _minSwipeVelocity = 200.0;

  @override
  void initState() {
    super.initState();

    // Initialize gameState first
    gameState = GameState(
      board: List.generate(4, (_) => List.generate(4, (_) => 0)),
      score: 0,
      highScore: 0,
      isGameOver: false,
    );

    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _winAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    tileControllers = List.generate(
      4,
          (_) => List.generate(
        4,
            (_) => AnimationController(
          duration: const Duration(milliseconds: 200),
          vsync: this,
        ),
      ),
    );

    // Load high score after initialization
    GameState.loadHighScore().then((value) {
      setState(() {
        gameState.highScore = value;
      });
    });

    resetGame();
  }

  void resetGame() {
    setState(() {
      gameState = GameState(
        board: List.generate(4, (_) => List.generate(4, (_) => 0)),
        score: 0,
        highScore: gameState.highScore, // Now this will work because gameState is initialized
        isGameOver: false,
      );
      addNewTile();
      addNewTile();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    _winAnimationController.dispose();
    for (var row in tileControllers) {
      for (var controller in row) {
        controller.dispose();
      }
    }
    super.dispose();
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent && !gameState.isGameOver) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        moveTiles(Direction.up);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        moveTiles(Direction.down);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        moveTiles(Direction.left);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        moveTiles(Direction.right);
      } else if (event.logicalKey == LogicalKeyboardKey.space) {
        resetGame();
      }
    }
  }

  void handlePanStart(DragStartDetails details) {
    _panStartPosition = details.localPosition;
    _lastUpdatePosition = details.localPosition;
    _panStartTime = DateTime.now();
  }

  void handlePanUpdate(DragUpdateDetails details) {
    _lastUpdatePosition = details.localPosition;
  }

  void handlePanEnd(DragEndDetails details) {
    if (_panStartPosition == null || _lastUpdatePosition == null ||
        _panStartTime == null || gameState.isGameOver) return;

    final dx = _lastUpdatePosition!.dx - _panStartPosition!.dx;
    final dy = _lastUpdatePosition!.dy - _panStartPosition!.dy;
    final distance = sqrt(dx * dx + dy * dy);

    final duration = DateTime.now().difference(_panStartTime!).inMilliseconds;
    final velocity = distance / (duration / 1000); // pixels per second

    if (distance < _minSwipeDistance || velocity < _minSwipeVelocity) return;

    if (dx.abs() > dy.abs()) {
      // Horizontal swipe
      if (dx > 0) {
        moveTiles(Direction.right);
      } else {
        moveTiles(Direction.left);
      }
    } else {
      // Vertical swipe
      if (dy > 0) {
        moveTiles(Direction.down);
      } else {
        moveTiles(Direction.up);
      }
    }

    _panStartPosition = null;
    _lastUpdatePosition = null;
    _panStartTime = null;
  }

  Future<void> moveTiles(Direction direction) async {
    if (_controller.isAnimating) return;

    gameState.saveMoveState();
    _showUndo = true;

    bool moved = false;
    List<List<int>> rotated = rotateBoard(gameState.board, direction);

    for (int i = 0; i < 4; i++) {
      List<int> row = rotated[i].where((x) => x != 0).toList();
      for (int j = 0; j < row.length - 1; j++) {
        if (row[j] == row[j + 1]) {
          row[j] *= 2;
          gameState.score += row[j];
          row[j + 1] = 0;
          moved = true;
        }
      }
      row = row.where((x) => x != 0).toList();
      while (row.length < 4) {
        row.add(0);
      }
      if (!listEquals(rotated[i], row)) {
        moved = true;
      }
      rotated[i] = row;
    }

    if (moved) {
      _controller.forward(from: 0);

      setState(() {
        gameState.board = rotateBoard(rotated, direction);
      });

      await _controller.forward(from: 0);

      setState(() {
        addNewTile();
        if (gameState.score > gameState.highScore) {
          gameState.highScore = gameState.score;
          gameState.saveHighScore();
        }
        checkGameOver();
      });

      if (!gameState.hasWon && gameState.board.any((row) => row.contains(2048))) {
        gameState.hasWon = true;
        _winAnimationController.forward();
      }
    }
  }

  void addNewTile() {
    List<Point<int>> emptyTiles = [];
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (gameState.board[i][j] == 0) {
          emptyTiles.add(Point(i, j));
        }
      }
    }
    if (emptyTiles.isNotEmpty) {
      final Point<int> newTilePosition = emptyTiles[random.nextInt(emptyTiles.length)];
      gameState.board[newTilePosition.x][newTilePosition.y] = random.nextInt(10) < 9 ? 2 : 4;
    }
  }

  List<List<int>> rotateBoard(List<List<int>> board, Direction direction) {
    List<List<int>> rotated = List.generate(4, (_) => List.generate(4, (_) => 0));

    switch (direction) {
      case Direction.up:
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            rotated[i][j] = board[i][j];
          }
        }
        break;
      case Direction.down:
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            rotated[i][j] = board[3 - i][j];
          }
        }
        break;
      case Direction.left:
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            rotated[i][j] = board[j][i];
          }
        }
        break;
      case Direction.right:
        for (int i = 0; i < 4; i++) {
          for (int j = 0; j < 4; j++) {
            rotated[i][j] = board[j][3 - i];
          }
        }
        break;
    }
    return rotated;
  }

  bool checkGameOver() {
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (gameState.board[i][j] == 0) return false;
      }
    }

    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 3; j++) {
        if (gameState.board[i][j] == gameState.board[i][j + 1] ||
            gameState.board[j][i] == gameState.board[j + 1][i]) {
          return false;
        }
      }
    }

    gameState.isGameOver = true;
    return true;
  }

  Widget buildScoreBoard() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            children: [
              Text('SCORE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${gameState.score}', style: TextStyle(fontSize: 24)),
            ],
          ),
          Column(
            children: [
              Text('BEST', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Text('${gameState.highScore}', style: TextStyle(fontSize: 24)),
            ],
          ),
          Row(
            children: [
              if (_showUndo)
                IconButton(
                  icon: Icon(Icons.undo),
                  onPressed: () {
                    setState(() {
                      if (gameState.undoLastMove()) {
                        _showUndo = false;
                      }
                    });
                  },
                ),
              ElevatedButton(
                onPressed: resetGame,
                child: Text('New Game'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget buildGameOverOverlay() {
    if (!gameState.isGameOver) return Container();

    return Container(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Game Over!',
              style: TextStyle(color: Colors.white, fontSize: 32),
            ),
            ElevatedButton(
              onPressed: resetGame,
              child: Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildWinOverlay() {
    if (!gameState.hasWon) return Container();

    return ScaleTransition(
      scale: _winAnimationController,
      child: Container(
        color: Colors.black54,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'You Win!',
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    gameState.hasWon = false;
                  });
                },
                child: Text('Keep Playing'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildGrid() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          padding: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(6.0),
            color: Colors.grey[300],
          ),
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 3.0,
              crossAxisSpacing: 3.0,
            ),
            itemCount: 16,
            itemBuilder: (context, index) {
              int row = index ~/ 4;
              int col = index % 4;
              int value = gameState.board[row][col];
              return buildTile(value, row, col);
            },
          ),
        ),
      ),
    );
  }

  Widget buildTile(int value, int row, int col) {
    final Color tileColor = getTileColor(value);
    final Color textColor = value <= 4 ? Colors.grey[900]! : Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return TweenAnimationBuilder(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, Widget? child) {
            return Transform.scale(
              scale: value,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8.0),
                  color: tileColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(26), // Changed from withOpacity(0.1)
                      blurRadius: 3,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Center(
            child: Text(
              value > 0 ? value.toString() : '',
              style: TextStyle(
                fontSize: value > 512 ? 20.0 : 24.0,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Color getTileColor(int value) {
    switch (value) {
      case 2: return Colors.orange[50]!;
      case 4: return Colors.orange[100]!;
      case 8: return Colors.orange[200]!;
      case 16: return Colors.orange[300]!;
      case 32: return Colors.orange[400]!;
      case 64: return Colors.orange[500]!;
      case 128: return Colors.orange[600]!;
      case 256: return Colors.orange[700]!;
      case 512: return Colors.orange[800]!;
      case 1024: return Colors.orange[900]!;
      case 2048: return Colors.red;
      default: return Colors.grey[200]!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent && !gameState.isGameOver) {
          if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            moveTiles(Direction.up);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            moveTiles(Direction.down);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
            moveTiles(Direction.left);
          } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
            moveTiles(Direction.right);
          } else if (event.logicalKey == LogicalKeyboardKey.space) {
            resetGame();
          }
        }
        return KeyEventResult.handled;
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: handlePanStart,
        onHorizontalDragUpdate: handlePanUpdate,
        onHorizontalDragEnd: handlePanEnd,
        onVerticalDragStart: handlePanStart,
        onVerticalDragUpdate: handlePanUpdate,
        onVerticalDragEnd: handlePanEnd,
        child: Scaffold(
          appBar: AppBar(title: const Text('2048')),
          body: SingleChildScrollView(
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 400,
                  maxHeight: MediaQuery.of(context).size.height - kToolbarHeight - 32,
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 400,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        buildScoreBoard(),
                        AspectRatio(
                          aspectRatio: 1,
                          child: Stack(
                            children: [
                              buildGrid(),
                              buildGameOverOverlay(),
                              buildWinOverlay(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum Direction { up, down, left, right }