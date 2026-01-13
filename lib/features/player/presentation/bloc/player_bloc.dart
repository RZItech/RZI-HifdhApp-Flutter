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
  AudioProcessingState? _lastProcessingState;
  DateTime _lastCompletionTime = DateTime.fromMillisecondsSinceEpoch(0);

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
      final isCompleted =
          state.processingState == AudioProcessingState.completed;
      final wasCompleted =
          _lastProcessingState == AudioProcessingState.completed;

      final now = DateTime.now();
      final timeSinceLastComplete = now.difference(_lastCompletionTime);

      if (isCompleted &&
          !wasCompleted &&
          this.state.status != PlayerStatus.stopped &&
          this.state.chapter != null &&
          timeSinceLastComplete > const Duration(milliseconds: 500)) {
        talker.info('🏁 Audio handler reported completion (New transition)');
        _lastCompletionTime = now;
        add(InternalPlaybackCompleteEvent(chapterId: this.state.chapter!.id));
      }
      _lastProcessingState = state.processingState;

      // Sync playing status (Notification -> App)
      // Only add event if status is actually different to avoid log spam
      if (this.state.status != derivedStatus) {
        // Optimization: Skip syncing to 'paused' if we just hit 'completed'
        // and a transition is expected (handled by InternalPlaybackCompleteEvent).
        if (derivedStatus == PlayerStatus.paused &&
            state.processingState == AudioProcessingState.completed) {
          talker.debug(
            '⏭️ Skipping sync to paused during completion transition',
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
      // Capture state variables BEFORE the delay to avoid async state shifts
      final completedChapter = state.chapter;
      final completedBookId = state.bookId;
      final completedPlaylist = state.playlist;
      final currentLoopMode = state.loopMode;

      talker.info(
        '🎯 InternalPlaybackCompleteEvent triggered for chapter ${event.chapterId} (${completedChapter?.name}). Mode: $currentLoopMode',
      );

      // Stop logic: ignore if already stopped or cleaning up or inconsistent state
      if (state.status == PlayerStatus.stopped ||
          completedChapter == null ||
          completedBookId == null) {
        talker.debug(
          '🛑 Ignoring completion event - stopped or inconsistent state',
        );
        return;
      }

      // TOKEN VALIDATION: Ensure we are still talking about the same chapter.
      // If chapterId mismatch, it means we've already jumped to a new chapter
      // and this is a delayed "completed" signal from the previous one.
      if (event.chapterId != completedChapter.id) {
        talker.warning(
          '⚠️ Completion mismatch (Double-jump prevention): Event ID ${event.chapterId} != Current state ID ${completedChapter.id}',
        );
        return;
      }

      // Small delay to allow audio device/session to reset
      await Future.delayed(const Duration(milliseconds: 300));

      // Re-verify general status and chapter consistency after delay
      if (state.status == PlayerStatus.stopped ||
          state.chapter?.id != completedChapter.id) {
        talker.debug(
          '🛑 Completion canceled: Player stopped or chapter changed during delay',
        );
        return;
      }

      if (currentLoopMode == LoopMode.chapter) {
        // Replay current chapter (use captured variables)
        talker.info('🔁 Loop: Restarting chapter ${completedChapter.name}');
        add(PlayEvent(bookName: completedBookId, chapter: completedChapter));
      } else if (currentLoopMode == LoopMode.range) {
        // Range check logic...
        if (completedChapter.id.toString() == state.loopEndChapterId) {
          talker.info(
            '🔁 Loop Range: Reached end chapter ${completedChapter.id}, jumping back to start ${state.loopStartChapterId}',
          );

          // SAFE FIND: Use a for loop instead of firstWhere to avoid complex type mismatch crashes
          // like 'type () => Chapter is not a subtype of () => ChapterModel'.
          Chapter startChapter = completedChapter;
          for (final c in completedPlaylist) {
            if (c.id.toString() == state.loopStartChapterId) {
              startChapter = c;
              break;
            }
          }

          final startLine = state.loopStartLine ?? 0;
          final pos = (startLine < startChapter.audioLines.length)
              ? Duration(
                  milliseconds:
                      (startChapter.audioLines[startLine].start * 1000).toInt(),
                )
              : Duration.zero;

          add(
            PlayFromPositionEvent(
              bookName: completedBookId,
              chapter: startChapter,
              position: pos,
            ),
          );
        } else {
          // Advance to next chapter within range
          talker.info('➡️ Loop Range: Advancing from ${completedChapter.name}');
          final currentIndex = completedPlaylist.indexWhere(
            (c) => c.id == completedChapter.id,
          );
          if (currentIndex != -1 &&
              currentIndex < completedPlaylist.length - 1) {
            final nextChapter = completedPlaylist[currentIndex + 1];
            talker.info(
              '⏭️ Range Advance: Next chapter is ${nextChapter.name}',
            );
            add(PlayEvent(bookName: completedBookId, chapter: nextChapter));
          } else {
            talker.warning(
              '⏹️ Loop Range: End of playlist reached WITHOUT matching loopEndChapterId (${state.loopEndChapterId}). '
              'Current Chapter ID: ${completedChapter.id}, Playlist IDs: ${completedPlaylist.map((c) => c.id).toList()}',
            );
            emit(state.copyWith(status: PlayerStatus.stopped));
          }
        }
      } else {
        // Auto-advance logic (Loop Off)
        talker.info('➡️ Auto-advance logic (Loop Off)');
        if (completedPlaylist.isNotEmpty) {
          final currentIndex = completedPlaylist.indexWhere(
            (c) => c.id == completedChapter.id,
          );
          talker.debug(
            '📍 Captured Current Index: $currentIndex / ${completedPlaylist.length}',
          );

          if (currentIndex != -1 &&
              currentIndex < completedPlaylist.length - 1) {
            final nextChapter = completedPlaylist[currentIndex + 1];
            talker.info('⏭️ Advancing to next chapter: ${nextChapter.name}');
            add(PlayEvent(bookName: completedBookId, chapter: nextChapter));
          } else {
            talker.info(
              '🏁 End of playlist reached or chapter not found in list',
            );
            emit(state.copyWith(status: PlayerStatus.stopped));
          }
        } else {
          talker.debug('⏹️ Playlist empty, stopping');
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
          playlist: event.playlist ?? state.playlist,
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
