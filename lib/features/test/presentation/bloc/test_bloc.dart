import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/core/services/speech_recognition_service.dart';
import 'package:rzi_hifdhapp/core/utils/arabic_text_utils.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';
import 'package:rzi_hifdhapp/features/test/presentation/bloc/test_event.dart';
import 'package:rzi_hifdhapp/features/test/presentation/bloc/test_state.dart';

class TestBloc extends Bloc<TestEvent, TestState> {
  final SpeechRecognitionService speechRecognitionService;
  StreamSubscription? _recognitionSubscription;

  TestBloc({required this.speechRecognitionService}) : super(const TestState()) {
    on<StartTestFromBeginning>(_onStartTestFromBeginning);
    on<StartTestFromChapter>(_onStartTestFromChapter);
    on<SpeechRecognized>(_onSpeechRecognized);
    on<StopTest>(_onStopTest);
  }

  Future<void> _onStartTestFromBeginning(
      StartTestFromBeginning event, Emitter<TestState> emit) async {
    emit(state.copyWith(status: TestStatus.loading));
    try {
      // For now, let's assume we start with the first chapter
      final chapters = event.book.chapters;
      if (chapters.isEmpty) {
        emit(state.copyWith(
            status: TestStatus.error, errorMessage: 'No chapters to test.'));
        return;
      }

      await _startRecognition(chapters, 0, emit);
    } catch (e) {
      emit(state.copyWith(status: TestStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onStartTestFromChapter(
      StartTestFromChapter event, Emitter<TestState> emit) async {
    emit(state.copyWith(status: TestStatus.loading));
    try {
      final chapters = [event.chapter]; // Only test this single chapter
      await _startRecognition(chapters, 0, emit);
    } catch (e) {
      emit(state.copyWith(status: TestStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _startRecognition(
      List<Chapter> chapters, int chapterIndex, Emitter<TestState> emit) async {
    await speechRecognitionService.initialize(); // Ensure service is initialized
    await speechRecognitionService.stopListening(); // Stop any previous listening

    final currentChapter = chapters[chapterIndex];
    final words =
        ArabicTextUtils.splitArabicTextIntoWords(currentChapter.arabicText);

    final initialWordStatuses =
        List.generate(words.length, (index) => WordStatus.hidden);
    if (words.isNotEmpty) {
      initialWordStatuses[0] = WordStatus.current; // Mark first word as current
    }

    emit(state.copyWith(
      status: TestStatus.listening,
      chaptersToTest: chapters,
      currentChapterIndex: chapterIndex,
      currentWordIndex: 0,
      wordStatuses: initialWordStatuses,
      incorrectAttempts: 0,
      errorMessage: '',
    ));

    await speechRecognitionService.startListening(
      onResult: (partialResult) {
        // We are interested in partial results to update word status in real-time
        add(SpeechRecognized(partialResult));
      },
      onFinalResult: (finalResult) {
        // For VOSK, onPartial should be enough for word-by-word
        // If final result is needed, we can also use it
      },
      onError: (error) {
        add(StopTest()); // Stop test on error
        emit(state.copyWith(
            status: TestStatus.error, errorMessage: 'Recognition Error: $error'));
      },
    );
  }

  Future<void> _onSpeechRecognized(
      SpeechRecognized event, Emitter<TestState> emit) async {
    if (state.status != TestStatus.listening) return;

    final currentChapter = state.chaptersToTest[state.currentChapterIndex];
    final expectedWords =
        ArabicTextUtils.splitArabicTextIntoWords(currentChapter.arabicText);

    if (state.currentWordIndex >= expectedWords.length) {
      // All words recognized for this chapter
      await speechRecognitionService.stopListening();
      emit(state.copyWith(status: TestStatus.success)); // Or move to next chapter
      return;
    }

    final expectedWord = expectedWords[state.currentWordIndex];
    final normalizedExpectedWord =
        ArabicTextUtils.normalizeArabicWord(expectedWord);
    final recognizedWords = ArabicTextUtils.splitArabicTextIntoWords(event.text);

    if (recognizedWords.isNotEmpty) {
      final lastRecognizedWord = recognizedWords.last;
      final normalizedLastRecognizedWord =
          ArabicTextUtils.normalizeArabicWord(lastRecognizedWord);

      if (normalizedLastRecognizedWord == normalizedExpectedWord) {
        // Correct word recognized
        final newWordStatuses = List<WordStatus>.from(state.wordStatuses);
        newWordStatuses[state.currentWordIndex] = WordStatus.correct;

        final nextWordIndex = state.currentWordIndex + 1;
        if (nextWordIndex < expectedWords.length) {
          // Mark next word as current
          newWordStatuses[nextWordIndex] = WordStatus.current;
        } else {
          // Chapter finished
          await speechRecognitionService.stopListening();
          emit(state.copyWith(
              status: TestStatus.success,
              wordStatuses: newWordStatuses,
              currentWordIndex: nextWordIndex));
          return;
        }

        emit(state.copyWith(
          currentWordIndex: nextWordIndex,
          wordStatuses: newWordStatuses,
          incorrectAttempts: 0, // Reset attempts on correct word
        ));
      } else {
        // Incorrect word recognized
        final newIncorrectAttempts = state.incorrectAttempts + 1;
        final newWordStatuses = List<WordStatus>.from(state.wordStatuses);

        if (newIncorrectAttempts >= 3) {
          // Show word in red after 3 incorrect attempts
          newWordStatuses[state.currentWordIndex] = WordStatus.incorrect;
          // Optionally move to next word or keep trying
          // For now, let's keep it on the same word and show in red
        } else {
          // Keep it hidden, just register incorrect attempt
          newWordStatuses[state.currentWordIndex] = WordStatus.current; // Keep current state
        }

        emit(state.copyWith(
          incorrectAttempts: newIncorrectAttempts,
          wordStatuses: newWordStatuses,
        ));
      }
    }
  }

  Future<void> _onStopTest(StopTest event, Emitter<TestState> emit) async {
    await speechRecognitionService.stopListening();
    emit(state.copyWith(status: TestStatus.idle));
  }

  @override
  Future<void> close() {
    _recognitionSubscription?.cancel(); // Cancel any lingering subscription
    speechRecognitionService.dispose();
    return super.close();
  }
}
