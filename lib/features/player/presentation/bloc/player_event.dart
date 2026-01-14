import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';

abstract class PlayerEvent extends Equatable {
  const PlayerEvent();

  @override
  List<Object> get props => [];
}

class PlayEvent extends PlayerEvent {
  final String bookName;
  final Chapter chapter;
  final List<Chapter>? playlist;

  const PlayEvent({
    required this.bookName,
    required this.chapter,
    this.playlist,
  });

  @override
  List<Object> get props => [bookName, chapter, playlist ?? []];
}

class InternalPlaybackCompleteEvent extends PlayerEvent {
  final int chapterId;
  const InternalPlaybackCompleteEvent({required this.chapterId});

  @override
  List<Object> get props => [chapterId];
}

class PlayFromPositionEvent extends PlayerEvent {
  final String bookName;
  final Chapter chapter;
  final Duration position;
  final List<Chapter> playlist;
  final int? loopStartLine; // Optional: Start line for loop range
  final int? loopEndLine; // Optional: End line for loop range
  final String?
  startChapterId; // Optional: ID of start chapter (for cross-chapter)
  final String? endChapterId; // Optional: ID of end chapter (for cross-chapter)

  const PlayFromPositionEvent({
    required this.bookName,
    required this.chapter,
    required this.position,
    required this.playlist,
    this.loopStartLine,
    this.loopEndLine,
    this.startChapterId,
    this.endChapterId,
  });
}

class PauseEvent extends PlayerEvent {}

class StopEvent extends PlayerEvent {}

class SeekEvent extends PlayerEvent {
  final Duration position;

  const SeekEvent({required this.position});

  @override
  List<Object> get props => [position];
}

class SetSpeedEvent extends PlayerEvent {
  final double speed;

  const SetSpeedEvent({required this.speed});

  @override
  List<Object> get props => [speed];
}

class SyncPlayerStatusEvent extends PlayerEvent {
  final PlayerStatus status;

  const SyncPlayerStatusEvent(this.status);

  @override
  List<Object> get props => [status];
}

class SetLoopRangeEvent extends PlayerEvent {
  final int startLine;
  final int endLine;
  final String? startChapterId;
  final String? endChapterId;
  final List<Chapter>? playlist;

  const SetLoopRangeEvent({
    required this.startLine,
    required this.endLine,
    this.startChapterId,
    this.endChapterId,
    this.playlist,
  });

  @override
  List<Object> get props => [
    startLine,
    endLine,
    startChapterId ?? '',
    endChapterId ?? '',
    playlist ?? [],
  ];
}

class SetLoopModeEvent extends PlayerEvent {
  final LoopMode loopMode;

  const SetLoopModeEvent({required this.loopMode});

  @override
  List<Object> get props => [loopMode];
}
