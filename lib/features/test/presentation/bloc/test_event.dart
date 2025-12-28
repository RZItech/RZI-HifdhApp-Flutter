import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

abstract class TestEvent extends Equatable {
  const TestEvent();

  @override
  List<Object> get props => [];
}

class StartTestFromBeginning extends TestEvent {
  final Book book;

  const StartTestFromBeginning(this.book);

  @override
  List<Object> get props => [book];
}

class StartTestFromChapter extends TestEvent {
  final Chapter chapter;

  const StartTestFromChapter(this.chapter);

  @override
  List<Object> get props => [chapter];
}

class SpeechRecognized extends TestEvent {
  final String text;

  const SpeechRecognized(this.text);

  @override
  List<Object> get props => [text];
}

class StopTest extends TestEvent {}
