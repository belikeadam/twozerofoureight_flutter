import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'package:flutter/foundation.dart'; // Add this import
import 'game_state.dart';

class GameBoard extends StatefulWidget {
  const GameBoard({super.key});

  @override
  _GameBoardState createState() => _GameBoardState();
}

class _GameBoardState extends State<GameBoard> {
  late GameState gameState;
  final Random random = Random();

  @override
  void initState() {
    super.initState();
    gameState = GameState(
      board: List.generate(4, (_) => List.generate(4, (_) => 0)),
      score: 0,
      highScore: 0,
      isGameOver: false,
    );
    addNewTile();
    addNewTile();
  }

  void handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
        moveTiles(Direction.up);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
        moveTiles(Direction.down);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
        moveTiles(Direction.left);
      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
        moveTiles(Direction.right);
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
            rotated[i][j] = board[3-i][j];
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
            rotated[i][j] = board[j][3-i];
          }
        }
        break;
    }
    return rotated;
  }

  void moveTiles(Direction direction) {
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
      gameState.board = rotateBoard(rotated, direction);
      addNewTile();
      if (gameState.score > gameState.highScore) {
        gameState.highScore = gameState.score;
      }
      checkGameOver();
      setState(() {});
    }
  }

  bool checkGameOver() {
    // Check for any empty cells
    for (int i = 0; i < 4; i++) {
      for (int j = 0; j < 4; j++) {
        if (gameState.board[i][j] == 0) return false;
      }
    }
    
    // Check for possible merges
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
              return buildTile(value);
            },
          ),
        ),
      ),
    );
  }

  Widget buildTile(int value) {
    final Color tileColor = getTileColor(value);
    final Color textColor = value <= 4 ? Colors.grey[900]! : Colors.white;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3.0),
        color: tileColor,
      ),
      child: Center(
        child: Text(
          value > 0 ? value.toString() : '',
          style: TextStyle(
            fontSize: 24.0,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
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
    return KeyboardListener(
      focusNode: FocusNode(),
      autofocus: true,
      onKeyEvent: handleKeyEvent,
      child: GestureDetector(
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 0) {
            moveTiles(Direction.down);
          } else {
            moveTiles(Direction.up);
          }
        },
        onHorizontalDragUpdate: (details) {
          if (details.delta.dx > 0) {
            moveTiles(Direction.right);
          } else {
            moveTiles(Direction.left);
          }
        },
        child: Scaffold(
          appBar: AppBar(title: const Text('2048')),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              buildGrid(),
            ],
          ),
        ),
      ),
    );
  }
}

enum Direction { up, down, left, right }