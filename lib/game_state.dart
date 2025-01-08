import 'package:shared_preferences/shared_preferences.dart';

class GameState {
  List<List<int>> board;
  int score;
  int highScore;
  bool isGameOver;
  bool hasWon;
  List<Map<String, dynamic>> moveHistory;

  GameState({
    required this.board,
    required this.score,
    required this.highScore,
    required this.isGameOver,
    this.hasWon = false,
    List<Map<String, dynamic>>? moveHistory,
  }) : moveHistory = moveHistory ?? [];

  void saveHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('highScore', highScore);
  }

  static Future<int> loadHighScore() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('highScore') ?? 0;
  }

  void saveMoveState() {
    moveHistory.add({
      'board': List<List<int>>.from(
          board.map((row) => List<int>.from(row))),
      'score': score,
    });
  }

  bool undoLastMove() {
    if (moveHistory.isEmpty) return false;
    
    final lastMove = moveHistory.removeLast();
    board = lastMove['board'];
    score = lastMove['score'];
    isGameOver = false;
    return true;
  }
}