import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

enum TestStatus { idle, loading, listening, evaluating, success, error }

enum WordStatus { hidden, correct, incorrect, current }

class TestState extends Equatable {
  final TestStatus status;
  final List<Chapter> chaptersToTest;
  final int currentChapterIndex;
  final int currentWordIndex;
  final List<WordStatus> wordStatuses;
  final int incorrectAttempts;
  final String errorMessage;

  const TestState({
    this.status = TestStatus.idle,
    this.chaptersToTest = const [],
    this.currentChapterIndex = 0,
    this.currentWordIndex = 0,
    this.wordStatuses = const [],
    this.incorrectAttempts = 0,
    this.errorMessage = '',
  });

  TestState copyWith({
    TestStatus? status,
    List<Chapter>? chaptersToTest,
    int? currentChapterIndex,
    int? currentWordIndex,
    List<WordStatus>? wordStatuses,
    int? incorrectAttempts,
    String? errorMessage,
  }) {
    return TestState(
      status: status ?? this.status,
      chaptersToTest: chaptersToTest ?? this.chaptersToTest,
      currentChapterIndex: currentChapterIndex ?? this.currentChapterIndex,
      currentWordIndex: currentWordIndex ?? this.currentWordIndex,
      wordStatuses: wordStatuses ?? this.wordStatuses,
      incorrectAttempts: incorrectAttempts ?? this.incorrectAttempts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        chaptersToTest,
        currentChapterIndex,
        currentWordIndex,
        wordStatuses,
        incorrectAttempts,
        errorMessage,
      ];
}
