import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class QuizProgressData {
  final int currentIndex;
  final List<Map<String, dynamic>> answers;
  final DateTime updatedAt;

  QuizProgressData({
    required this.currentIndex,
    required this.answers,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
    'currentIndex': currentIndex,
    'answers': answers,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory QuizProgressData.fromJson(Map<String, dynamic> json) => QuizProgressData(
    currentIndex: json['currentIndex'] as int? ?? 0,
    answers: (json['answers'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e as Map))
            .toList() ??
        [],
    updatedAt: json['updatedAt'] != null
        ? DateTime.tryParse(json['updatedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
  );
}

class QuizStorageService {
  final FlutterSecureStorage _storage;

  const QuizStorageService([this._storage = const FlutterSecureStorage()]);

  static const String _activeQuizIdsKey = 'active_quiz_ids';

  String _progressKey(String quizId) => 'quiz_progress_$quizId';

  /// Save progress for a given quiz
  Future<void> saveProgress(
    String quizId,
    int currentIndex,
    List<Map<String, dynamic>> answers,
  ) async {
    try {
      final data = QuizProgressData(
        currentIndex: currentIndex,
        answers: answers,
        updatedAt: DateTime.now(),
      );
      await _storage.write(
        key: _progressKey(quizId),
        value: jsonEncode(data.toJson()),
      );

      // Add to active quiz IDs
      final activeIds = await getActiveQuizIds();
      activeIds.add(quizId);
      await _storage.write(
        key: _activeQuizIdsKey,
        value: jsonEncode(activeIds.toList()),
      );
    } catch (_) {}
  }

  /// Retrieve saved progress for a quiz
  Future<QuizProgressData?> getProgress(String quizId) async {
    try {
      final raw = await _storage.read(key: _progressKey(quizId));
      if (raw == null) return null;
      final Map<String, dynamic> json = jsonDecode(raw);
      return QuizProgressData.fromJson(json);
    } catch (_) {
      return null;
    }
  }

  /// Clear saved progress when finished or restarted
  Future<void> clearProgress(String quizId) async {
    try {
      await _storage.delete(key: _progressKey(quizId));
      final activeIds = await getActiveQuizIds();
      activeIds.remove(quizId);
      await _storage.write(
        key: _activeQuizIdsKey,
        value: jsonEncode(activeIds.toList()),
      );
    } catch (_) {}
  }

  /// Get all active quiz IDs that have saved progress
  Future<Set<String>> getActiveQuizIds() async {
    try {
      final raw = await _storage.read(key: _activeQuizIdsKey);
      if (raw == null) return {};
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }
}
