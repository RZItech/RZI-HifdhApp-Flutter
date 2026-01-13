import 'dart:async';
import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_event.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';
import 'package:rzi_hifdhapp/features/player/services/audio_handler.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

final talker = sl<Talker>();

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioHandler audioHandler;

  Stream<Duration> get positionStream {
    if (audioHandler is AudioPlayerHandler) {
      return (audioHandler as AudioPlayerHandler).onPositionChanged;
    }
    return const Stream.empty();
  }

  StreamSubscription? _playbackStateSub;

  PlayerBloc({required this.audioHandler}) : super(const PlayerState()) {
    // Listen to playback state to detect completion and syncing
    _playbackStateSub = audioHandler.playbackState.listen((state) {
      final isPlaying = state.playing;
      final derivedStatus = isPlaying
          ? PlayerStatus.playing
          : (state.processingState == AudioProcessingState.idle
                ? PlayerStatus.stopped
                : PlayerStatus.paused);

      // detect transition to completed
      if (state.processingState == AudioProcessingState.completed &&
          this.state.status != PlayerStatus.stopped) {
        talker.debug('🏁 Audio handler reported completion');
        add(InternalPlaybackCompleteEvent());
      }

      // Sync playing status (Notification -> App)
      // Only add event if status is actually different to avoid log spam
      if (this.state.status != derivedStatus) {
        // Optimization: Skip syncing to 'paused' if we just hit 'completed'
        // and a loop/advance is expected (handled by InternalPlaybackCompleteEvent).
        if (derivedStatus == PlayerStatus.paused &&
            state.processingState == AudioProcessingState.completed &&
            this.state.loopMode != LoopMode.off) {
          talker.debug(
            '⏭️ Skipping sync to paused during loop/advance transition',
          );
        } else {
          add(SyncPlayerStatusEvent(derivedStatus));
        }
      }
    });

    on<SyncPlayerStatusEvent>((event, emit) {
      if (state.status != event.status) {
        emit(state.copyWith(status: event.status));
      }
    });

    on<PlayEvent>((event, emit) async {
      talker.debug('▶️ PlayEvent triggered for ${event.chapter.name}');
      final appDir = await getApplicationDocumentsDirectory();
      final audioPath =
          '${appDir.path}/books/${event.bookName}/${event.chapter.audioPath}';

      talker.debug('📁 Audio path: $audioPath');

      if (File(audioPath).existsSync()) {
        talker.debug('✅ File exists, playing...');

        final mediaItem = MediaItem(
          id: audioPath,
          album: event.bookName,
          title: event.chapter.name,
        );

        if (audioHandler is AudioPlayerHandler) {
          final handler = audioHandler as AudioPlayerHandler;
          await handler.playFromFile(audioPath, mediaItem);
          // Apply current speed setting
          await handler.setSpeed(state.speed);

          // Apply Loop Constraints
          if (state.loopMode == LoopMode.range) {
            _applyLoopConstraints(
              audioHandler,
              event.chapter,
              state.loopStartChapterId ?? '',
              state.loopStartLine ?? 0,
              state.loopEndChapterId ?? '',
              state.loopEndLine ?? 0,
            );
          } else {
            handler.setLoopRange(null, null);
          }
        }

        emit(
          state.copyWith(
            status: PlayerStatus.playing,
            chapter: event.chapter,
            playlist: event.playlist ?? state.playlist,
            bookId: event.bookName,
          ),
        );
      } else {
        talker.warning('❌ Audio file missing!');
      }
    });

    on<InternalPlaybackCompleteEvent>((event, emit) async {
      talker.debug(
        '🔄 Handling InternalPlaybackCompleteEvent. Mode: ${state.loopMode}',
      );

      if (state.loopMode == LoopMode.chapter) {
        // Replay current chapter
        if (state.chapter != null && state.bookId != null) {
          talker.debug('🔁 Looping chapter: ${state.chapter!.name}');
          add(PlayEvent(bookName: state.bookId!, chapter: state.chapter!));
        } else {
          talker.warning('⚠️ Chapter or BookId missing for loop');
          emit(state.copyWith(status: PlayerStatus.stopped));
        }
      } else if (state.loopMode == LoopMode.range) {
        // Check if we finished the END chapter
        if (state.chapter?.id.toString() == state.loopEndChapterId) {
          // Finished loop cycle -> Jump to Start
          final startChapter = state.playlist.firstWhere(
            (c) => c.id.toString() == state.loopStartChapterId,
            orElse: () => state.chapter!,
          );

          // Play Start Chapter
          add(PlayEvent(bookName: state.bookId ?? '', chapter: startChapter));

          // We need to seek to start line.
          // PlayEvent is async... we can't easily wait here.
          // Dispatching a SeekEvent immediately might fail if Play hasn't initialized.
          // Solution: Trigger PlayFromPosition?
          // Yes, PlayFromPosition is cleaner.
          final startLine = state.loopStartLine ?? 0;
          if (startLine < startChapter.audioLines.length) {
            final pos = Duration(
              milliseconds: (startChapter.audioLines[startLine].start * 1000)
                  .toInt(),
            );
            // Override: use PlayFromPositionEvent
            // Note: PlayFromPositionEvent logic also needs to apply loop constraints!
            // Let's rely on PlayFromPositionEvent and update it to apply constraints too.
            add(
              PlayFromPositionEvent(
                bookName: state.bookId ?? '',
                chapter: startChapter,
                position: pos,
              ),
            );
            return; // Done
          }
        } else {
          // In Start or Middle chapter -> Auto Advance
          if (state.playlist.isNotEmpty && state.chapter != null) {
            final currentIndex = state.playlist.indexWhere(
              (c) => c.id == state.chapter!.id,
            );
            if (currentIndex != -1 &&
                currentIndex < state.playlist.length - 1) {
              final nextChapter = state.playlist[currentIndex + 1];
              if (state.bookId != null) {
                add(PlayEvent(bookName: state.bookId!, chapter: nextChapter));
              }
            } else {
              emit(state.copyWith(status: PlayerStatus.stopped));
            }
          }
        }
      } else {
        // Auto-advance logic (Loop Off)
        talker.debug('➡️ Auto-advance logic (Loop Off)');
        if (state.playlist.isNotEmpty && state.chapter != null) {
          final currentIndex = state.playlist.indexWhere(
            (c) => c.id == state.chapter!.id,
          );
          talker.debug(
            '📍 Current Index: $currentIndex / ${state.playlist.length}',
          );

          if (currentIndex != -1 && currentIndex < state.playlist.length - 1) {
            final nextChapter = state.playlist[currentIndex + 1];
            if (state.bookId != null) {
              talker.debug('⏭️ Advancing to next chapter: ${nextChapter.name}');
              add(PlayEvent(bookName: state.bookId!, chapter: nextChapter));
            } else {
              talker.warning('⚠️ BookId missing for auto-advance');
              emit(state.copyWith(status: PlayerStatus.stopped));
            }
          } else {
            talker.info(
              '🏁 End of playlist reached or chapter not found in list',
            );
            emit(state.copyWith(status: PlayerStatus.stopped));
          }
        } else {
          talker.debug('⏹️ Playlist empty or no current chapter, stopping');
          emit(state.copyWith(status: PlayerStatus.stopped));
        }
      }
    });

    on<PlayFromPositionEvent>((event, emit) async {
      talker.debug(
        '🎵 PlayFromPosition - Position: ${event.position.inSeconds}s',
      );
      final appDir = await getApplicationDocumentsDirectory();
      final audioPath =
          '${appDir.path}/books/${event.bookName}/${event.chapter.audioPath}';

      if (File(audioPath).existsSync()) {
        talker.debug('✅ File exists, starting playback');

        final mediaItem = MediaItem(
          id: audioPath,
          album: event.bookName,
          title: event.chapter.name,
        );

        // Update loop state if provided
        LoopMode currentLoopMode = state.loopMode;
        int? currentStartLine = state.loopStartLine;
        int? currentEndLine = state.loopEndLine;
        String? currentStartChapterId = state.loopStartChapterId;
        String? currentEndChapterId = state.loopEndChapterId;

        if (event.loopStartLine != null && event.loopEndLine != null) {
          currentLoopMode = LoopMode.range;
          currentStartLine = event.loopStartLine;
          currentEndLine = event.loopEndLine;
          currentStartChapterId =
              event.startChapterId ?? event.chapter.id.toString();
          currentEndChapterId =
              event.endChapterId ?? event.chapter.id.toString();
        }

        if (audioHandler is AudioPlayerHandler) {
          final handler = audioHandler as AudioPlayerHandler;
          await handler.playFromFile(audioPath, mediaItem);
          await handler.setSpeed(state.speed);

          if (currentLoopMode == LoopMode.range) {
            _applyLoopConstraints(
              audioHandler,
              event.chapter,
              currentStartChapterId ?? '',
              currentStartLine ?? 0,
              currentEndChapterId ?? '',
              currentEndLine ?? 0,
            );
          } else {
            handler.setLoopRange(null, null);
          }

          await Future.delayed(const Duration(milliseconds: 100));
          talker.debug('⏩ Seeking to position');
          await handler.seek(event.position);
        }

        emit(
          state.copyWith(
            status: PlayerStatus.playing,
            chapter: event.chapter,
            bookId: event.bookName,
            loopMode: currentLoopMode,
            loopStartLine: currentStartLine,
            loopEndLine: currentEndLine,
            loopStartChapterId: currentStartChapterId,
            loopEndChapterId: currentEndChapterId,
            playlist: event.playlist ?? state.playlist,
          ),
        );
      } else {
        talker.warning('❌ Audio file not found: $audioPath');
      }
    });

    on<PauseEvent>((event, emit) async {
      await audioHandler.pause();
      if (state.status == PlayerStatus.playing) {
        emit(state.copyWith(status: PlayerStatus.paused));
      }
    });

    on<StopEvent>((event, emit) async {
      await audioHandler.stop();
      emit(state.copyWith(status: PlayerStatus.stopped));
    });

    on<SeekEvent>((event, emit) async {
      talker.debug('⏩ SeekEvent to ${event.position.inSeconds}s');
      await audioHandler.seek(event.position);
    });

    on<SetSpeedEvent>((event, emit) async {
      talker.debug('⏩ Set Speed to ${event.speed}x');
      if (audioHandler is AudioPlayerHandler) {
        await (audioHandler as AudioPlayerHandler).setSpeed(event.speed);
      }
      emit(state.copyWith(speed: event.speed));
    });

    on<SetLoopRangeEvent>((event, emit) {
      if (state.chapter == null) return;

      final startLine = event.startLine;
      final endLine = event.endLine;
      final startChapterId =
          event.startChapterId ?? state.chapter!.id.toString();
      final endChapterId = event.endChapterId ?? state.chapter!.id.toString();

      // Calculate times using the chapters from the playlist if valid
      // We need to access the actual chapter objects to get audioLines.
      // Use state.playlist to find them.

      emit(
        state.copyWith(
          loopMode: LoopMode.range,
          loopStartLine: startLine,
          loopEndLine: endLine,
          loopStartChapterId: startChapterId,
          loopEndChapterId: endChapterId,
        ),
      );

      // If currently playing one of these checks, update handler imediately
      if (state.chapter != null) {
        _applyLoopConstraints(
          audioHandler,
          state.chapter!,
          startChapterId,
          startLine,
          endChapterId,
          endLine,
        );
      }
    });

    on<SetLoopModeEvent>((event, emit) {
      talker.debug('🔁 Set Loop Mode to ${event.loopMode}');

      if (audioHandler is AudioPlayerHandler) {
        final handler = audioHandler as AudioPlayerHandler;
        if (event.loopMode == LoopMode.off ||
            event.loopMode == LoopMode.chapter) {
          handler.setLoopRange(null, null);
        } else if (event.loopMode == LoopMode.line) {
          handler.setLoopRange(null, null);
        }
      }

      emit(state.copyWith(loopMode: event.loopMode));
    });
  }

  void _applyLoopConstraints(
    AudioHandler handler,
    Chapter currentChapter,
    String startId,
    int startLine,
    String endId,
    int endLine,
  ) {
    if (handler is! AudioPlayerHandler) return;
    final player = handler;

    Duration? startTime;
    Duration? endTime;
    bool autoLoop = false;

    // Same chapter loop
    if (startId == endId && currentChapter.id.toString() == startId) {
      // Standard loop
      if (startLine >= 0 && startLine < currentChapter.audioLines.length) {
        startTime = Duration(
          milliseconds: (currentChapter.audioLines[startLine].start * 1000)
              .toInt(),
        );
      }
      if (endLine >= 0 && endLine < currentChapter.audioLines.length) {
        endTime = Duration(
          milliseconds: (currentChapter.audioLines[endLine].end * 1000).toInt(),
        );
      }
      autoLoop = true;
    } else {
      // Cross chapter
      if (currentChapter.id.toString() == startId) {
        if (startLine >= 0 && startLine < currentChapter.audioLines.length) {
          startTime = Duration(
            milliseconds: (currentChapter.audioLines[startLine].start * 1000)
                .toInt(),
          );
        }
      }

      if (currentChapter.id.toString() == endId) {
        if (endLine >= 0 && endLine < currentChapter.audioLines.length) {
          endTime = Duration(
            milliseconds: (currentChapter.audioLines[endLine].end * 1000)
                .toInt(),
          );
        }
      }
      autoLoop = false; // Let Bloc handle the jump
    }

    player.setLoopRange(startTime, endTime, autoLoop: autoLoop);
  }

  @override
  Future<void> close() {
    _playbackStateSub?.cancel();
    return super.close();
  }
}
