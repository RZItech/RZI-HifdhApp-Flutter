import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

enum PlayerStatus { initial, playing, paused, stopped }

enum LoopMode { off, chapter, line, range }

class PlayerState extends Equatable {
  final PlayerStatus status;
  final Chapter? chapter;
  final double speed;
  final LoopMode loopMode;
  final List<Chapter> playlist;
  final String? bookId; // Needed to construct path for next chapter
  final int? loopStartLine;
  final int? loopEndLine;
  final String? loopStartChapterId;
  final String? loopEndChapterId;

  const PlayerState({
    this.status = PlayerStatus.initial,
    this.chapter,
    this.speed = 1.0,
    this.loopMode = LoopMode.off,
    this.playlist = const [],
    this.bookId,
    this.loopStartLine,
    this.loopEndLine,
    this.loopStartChapterId,
    this.loopEndChapterId,
  });

  PlayerState copyWith({
    PlayerStatus? status,
    Chapter? chapter,
    double? speed,
    LoopMode? loopMode,
    List<Chapter>? playlist,
    String? bookId,
    int? loopStartLine,
    int? loopEndLine,
    String? loopStartChapterId,
    String? loopEndChapterId,
  }) {
    return PlayerState(
      status: status ?? this.status,
      chapter: chapter ?? this.chapter,
      speed: speed ?? this.speed,
      loopMode: loopMode ?? this.loopMode,
      playlist: playlist ?? this.playlist,
      bookId: bookId ?? this.bookId,
      loopStartLine: loopStartLine ?? this.loopStartLine,
      loopEndLine: loopEndLine ?? this.loopEndLine,
      loopStartChapterId: loopStartChapterId ?? this.loopStartChapterId,
      loopEndChapterId: loopEndChapterId ?? this.loopEndChapterId,
    );
  }

  @override
  List<Object?> get props => [
    status,
    chapter,
    speed,
    loopMode,
    playlist,
    bookId,
    loopStartLine,
    loopEndLine,
    loopStartChapterId,
    loopEndChapterId,
  ];
}
