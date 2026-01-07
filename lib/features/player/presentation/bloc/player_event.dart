import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object> get props => [];
}

class PlayEvent extends PlayerEvent {
  final String bookName;
  final Chapter chapter;

  const PlayEvent({required this.bookName, required this.chapter});

  @override
  List<Object> get props => [bookName, chapter];
}

class PauseEvent extends PlayerEvent {}

class StopEvent extends PlayerEvent {}

class SeekEvent extends PlayerEvent {
  final Duration position;

  const SeekEvent({required this.position});

  @override
  List<Object> get props => [position];
}
