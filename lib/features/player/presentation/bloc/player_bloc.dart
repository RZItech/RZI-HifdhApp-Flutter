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

/// Represents the range of a loop across potentially multiple chapters
class LoopRange {
  final String startChapterId;
  final String endChapterId;
  final int startLine;
  final int endLine;

  const LoopRange({
    required this.startChapterId,
    required this.endChapterId,
    required this.startLine,
    required this.endLine,
  });

  bool get isSingleChapter => startChapterId == endChapterId;

  bool isStartChapter(String chapterId) => chapterId == startChapterId;
  bool isEndChapter(String chapterId) => chapterId == endChapterId;

  /// Check if a chapter is within the loop range based on playlist order
  bool containsChapter(String chapterId, List<Chapter> playlist) {
    final startIdx = playlist.indexWhere(
      (c) => c.id.toString() == startChapterId,
    );
    final endIdx = playlist.indexWhere((c) => c.id.toString() == endChapterId);
    final currentIdx = playlist.indexWhere((c) => c.id.toString() == chapterId);

    if (startIdx == -1 || endIdx == -1 || currentIdx == -1) return false;

    return currentIdx >= startIdx && currentIdx <= endIdx;
  }

  /// Get the boundaries to apply to the audio handler for a specific chapter
  AudioLoopBoundaries getBoundariesForChapter(Chapter chapter) {
    final chapterId = chapter.id.toString();
    Duration? startTime;
    Duration? endTime;

    // Set start boundary only for single-chapter loops
    if (isSingleChapter && isStartChapter(chapterId)) {
      if (startLine >= 0 && startLine < chapter.audioLines.length) {
        startTime = Duration(
          milliseconds: (chapter.audioLines[startLine].start * 1000).toInt(),
        );
      }
    }

    // Set end boundary for end chapters
    if (isEndChapter(chapterId)) {
      if (endLine >= 0 && endLine < chapter.audioLines.length) {
        endTime = Duration(
          milliseconds: (chapter.audioLines[endLine].end * 1000).toInt(),
        );
      }
    }

    // Only enable auto-loop if this is a single-chapter loop
    // For cross-chapter loops, the bloc handles the transition
    final autoLoop = isSingleChapter;

    return AudioLoopBoundaries(
      startTime: startTime,
      endTime: endTime,
      autoLoop: autoLoop,
    );
  }

  /// Get the position to seek to when restarting the loop
  Duration getRestartPosition(Chapter startChapter) {
    if (startLine < 0 || startLine >= startChapter.audioLines.length) {
      return Duration.zero;
    }
    return Duration(
      milliseconds: (startChapter.audioLines[startLine].start * 1000).toInt(),
    );
  }
}

class AudioLoopBoundaries {
  final Duration? startTime;
  final Duration? endTime;
  final bool autoLoop;

  const AudioLoopBoundaries({
    this.startTime,
    this.endTime,
    required this.autoLoop,
  });
}

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioHandler audioHandler;

  Stream<Duration> get positionStream {
    if (audioHandler is AudioPlayerHandler) {
      return (audioHandler as AudioPlayerHandler).positionStream;
    }
    // Fallback: could create a stream from playbackState, but UI often listens to bloc state or polls
    return const Stream.empty();
  }

  /// robust position getter that interpolates based on time
  Duration get currentPosition {
    // 1. Try direct access if not isolated
    if (audioHandler is AudioPlayerHandler) {
      return (audioHandler as AudioPlayerHandler).currentPosition;
    }

    // 2. Interpolate from PlaybackState for isolated handlers
    final state = audioHandler.playbackState.value;
    // value is non-null in AudioService (seeded) separate check not strictly needed but good safety
    // if (state == null) return Duration.zero; // ValueStream always has value in AudioService

    final updatePosition = state.updatePosition;
    final updateTime = state.updateTime;

    // If not playing, return the last known position
    if (!state.playing) {
      return updatePosition;
    }

    // Calculate elapsed time since last update
    final elapsed = DateTime.now().difference(updateTime);

    // Apply speed multiplier if needed (though usually speed is managed by player)
    // AudioService updates usually account for speed in the stream, but manual calc needs it
    // simple interpolation:
    return updatePosition + (elapsed * state.speed);
  }

  StreamSubscription? _playbackStateSub;
  AudioProcessingState? _lastProcessingState;
  DateTime _lastCompletionTime = DateTime.fromMillisecondsSinceEpoch(0);

  // Track whether we're currently in a cross-chapter loop transition
  bool _isTransitioningChapters = false;

  // Track whether we've signaled completion for the current loop end

  PlayerBloc({required this.audioHandler}) : super(const PlayerState()) {
    _setupPlaybackStateListener();
    _registerEventHandlers();
  }

  void _setupPlaybackStateListener() {
    _playbackStateSub = audioHandler.playbackState.listen((playbackState) {
      final derivedStatus = _derivePlayerStatus(playbackState);

      // CLEAR transition flag if we've successfully started buffering or playing new content
      // This prevents the "swallowing" of completion events for short files
      if (_isTransitioningChapters &&
          (playbackState.processingState == AudioProcessingState.buffering ||
              playbackState.processingState == AudioProcessingState.ready)) {
        _isTransitioningChapters = false;
        talker.debug(
          '🔄 Transition flag cleared - new state: ${playbackState.processingState}',
        );
      }

      // Handle completion - but only if we're not already transitioning
      if (_shouldHandleCompletion(playbackState) && !_isTransitioningChapters) {
        _handleCompletionDetected();
      }

      // Sync status if changed (skip paused during completion to avoid race)
      if (state.status != derivedStatus &&
          !_isCompletionTransition(playbackState, derivedStatus) &&
          !_isTransitioningChapters) {
        add(SyncPlayerStatusEvent(derivedStatus));
      }

      _lastProcessingState = playbackState.processingState;
    });
  }

  PlayerStatus _derivePlayerStatus(PlaybackState playbackState) {
    if (playbackState.playing) return PlayerStatus.playing;
    if (playbackState.processingState == AudioProcessingState.idle) {
      return PlayerStatus.stopped;
    }
    return PlayerStatus.paused;
  }

  bool _shouldHandleCompletion(PlaybackState playbackState) {
    final isCompleted =
        playbackState.processingState == AudioProcessingState.completed;
    final wasCompleted = _lastProcessingState == AudioProcessingState.completed;
    final timeSinceLastComplete = DateTime.now().difference(
      _lastCompletionTime,
    );

    return isCompleted &&
        !wasCompleted &&
        state.status != PlayerStatus.stopped &&
        state.chapter != null &&
        timeSinceLastComplete > const Duration(milliseconds: 500);
  }

  void _handleCompletionDetected() {
    talker.info('🎵 Audio completion detected');
    _lastCompletionTime = DateTime.now();
    add(InternalPlaybackCompleteEvent(chapterId: state.chapter!.id));
  }

  bool _isCompletionTransition(
    PlaybackState playbackState,
    PlayerStatus derivedStatus,
  ) {
    return derivedStatus == PlayerStatus.paused &&
        playbackState.processingState == AudioProcessingState.completed;
  }

  void _registerEventHandlers() {
    on<SyncPlayerStatusEvent>(_onSyncStatus);
    on<PlayEvent>(_onPlay);
    on<InternalPlaybackCompleteEvent>(_onInternalCompletion);
    on<PlayFromPositionEvent>(_onPlayFromPosition);
    on<PauseEvent>(_onPause);
    on<StopEvent>(_onStop);
    on<SeekEvent>(_onSeek);
    on<SetSpeedEvent>(_onSetSpeed);
    on<SetLoopRangeEvent>(_onSetLoopRange);
    on<SetLoopModeEvent>(_onSetLoopMode);
  }

  void _onSyncStatus(SyncPlayerStatusEvent event, Emitter<PlayerState> emit) {
    if (state.status != event.status) {
      emit(state.copyWith(status: event.status));
    }
  }

  Future<void> _onPlay(PlayEvent event, Emitter<PlayerState> emit) async {
    talker.debug('▶️ PlayEvent: ${event.chapter.name}');


    final audioPath = await _getAudioPath(event.bookName, event.chapter);
    if (!await _fileExists(audioPath)) {
      talker.warning('❌ Audio file missing: $audioPath');
      return;
    }

    await _playAudioFile(audioPath, event.bookName, event.chapter);

    emit(
      state.copyWith(
        status: PlayerStatus.playing,
        chapter: event.chapter,
        playlist: event.playlist ?? state.playlist,
        bookId: event.bookName,
      ),
    );
  }

  Future<void> _onInternalCompletion(
    InternalPlaybackCompleteEvent event,
    Emitter<PlayerState> emit,
  ) async {
    // Capture current state to avoid async issues
    final completedChapter = state.chapter;
    final completedBookId = state.bookId;
    final completedPlaylist = state.playlist;
    final currentLoopMode = state.loopMode;

    talker.info(
      '🎯 Completion event for: ${completedChapter?.name} (Mode: $currentLoopMode)',
    );

    // Basic validation
    if (!_isValidCompletionContext(
      event.chapterId,
      completedChapter,
      completedBookId,
    )) {
      return;
    }

    // Small delay for audio device cleanup
    await Future.delayed(const Duration(milliseconds: 300));

    // Re-verify state hasn't changed during delay
    if (!_isStillValidAfterDelay(event.chapterId, completedChapter)) {
      return;
    }

    // Handle the completion based on loop mode
    await _handleCompletionByMode(
      currentLoopMode,
      completedChapter!,
      completedBookId!,
      completedPlaylist,
      emit,
    );
  }

  bool _isValidCompletionContext(
    int eventChapterId,
    Chapter? chapter,
    String? bookId,
  ) {
    if (state.status == PlayerStatus.stopped ||
        chapter == null ||
        bookId == null) {
      talker.debug('🛑 Ignoring completion - invalid state');
      return false;
    }

    if (eventChapterId != chapter.id) {
      talker.warning(
        '⚠️ Completion ID mismatch: $eventChapterId != ${chapter.id}',
      );
      return false;
    }

    return true;
  }

  bool _isStillValidAfterDelay(int eventChapterId, Chapter? originalChapter) {
    if (state.status == PlayerStatus.stopped ||
        state.chapter?.id != originalChapter?.id) {
      talker.debug('🛑 Completion canceled during delay');
      return false;
    }
    return true;
  }

  Future<void> _handleCompletionByMode(
    LoopMode mode,
    Chapter completedChapter,
    String bookId,
    List<Chapter> playlist,
    Emitter<PlayerState> emit,
  ) async {
    switch (mode) {
      case LoopMode.chapter:
        // Simple chapter replay
        talker.info('🔁 Replaying chapter: ${completedChapter.name}');
        add(PlayEvent(bookName: bookId, chapter: completedChapter));
        break;

      case LoopMode.range:
        await _handleRangeLoopCompletion(
          completedChapter,
          bookId,
          playlist,
          emit,
        );
        break;

      default:
        // Auto-advance to next chapter
        _handleAutoAdvance(completedChapter, bookId, playlist, emit);
    }
  }

  Future<void> _handleRangeLoopCompletion(
    Chapter completedChapter,
    String bookId,
    List<Chapter> playlist,
    Emitter<PlayerState> emit,
  ) async {
    final loopRange = LoopRange(
      startChapterId: state.loopStartChapterId ?? '',
      endChapterId: state.loopEndChapterId ?? '',
      startLine: state.loopStartLine ?? 0,
      endLine: state.loopEndLine ?? 0,
    );

    final completedId = completedChapter.id.toString();

    talker.debug('🔁 Range completion check: completed=${completedChapter.name} (ID: $completedId), endChapterId=${loopRange.endChapterId}');

    // Check if we've reached the end of the loop range
    if (loopRange.isEndChapter(completedId)) {
      talker.info('🔁 Loop range complete, jumping back to start');
      await _restartLoopRange(loopRange, bookId, playlist);
    } else {
      // Advance to next chapter within the range
      talker.debug('🔁 Advancing within loop range');
      await _advanceWithinLoopRange(
        completedChapter,
        loopRange,
        bookId,
        playlist,
        emit,
      );
    }
  }

  Future<void> _restartLoopRange(
    LoopRange loopRange,
    String bookId,
    List<Chapter> playlist, {
    Chapter? forceChapter,
  }) async {
    final startChapter =
        forceChapter ?? _findChapterById(playlist, loopRange.startChapterId);

    if (startChapter == null) {
      talker.warning(
        'Could not find start chapter: ${loopRange.startChapterId}',
      );
      return;
    }

    final startPosition = loopRange.getRestartPosition(startChapter);

    talker.info(
      '🔁 Restarting loop at ${startChapter.name} (ID: ${startChapter.id}) : ${startPosition.inSeconds}s (line ${loopRange.startLine + 1})',
    );
    talker.debug('🔁 Loop range: ${loopRange.startChapterId} -> ${loopRange.endChapterId}');

    // Mark that we're transitioning to prevent duplicate completion events
    _isTransitioningChapters = true;

    add(
      PlayFromPositionEvent(
        bookName: bookId,
        chapter: startChapter,
        position: startPosition,
        playlist: playlist,
        loopStartLine: loopRange.startLine,
        loopEndLine: loopRange.endLine,
        startChapterId: loopRange.startChapterId,
        endChapterId: loopRange.endChapterId,
      ),
    );

    // Increased delay slightly for handler readiness
    await Future.delayed(const Duration(milliseconds: 100));
    _isTransitioningChapters = false;
  }

  Future<void> _advanceWithinLoopRange(
    Chapter completedChapter,
    LoopRange loopRange,
    String bookId,
    List<Chapter> playlist,
    Emitter<PlayerState> emit,
  ) async {
    final currentIndex = playlist.indexWhere(
      (c) => c.id == completedChapter.id,
    );

    talker.debug('🔁 Advance check: currentIndex=$currentIndex, playlistLength=${playlist.length}');

    if (currentIndex == -1 || currentIndex >= playlist.length - 1) {
      talker.warning('⚠️ Cannot advance - end of playlist or chapter not found');
      emit(state.copyWith(status: PlayerStatus.stopped));
      return;
    }

    final nextChapter = playlist[currentIndex + 1];
    final nextChapterId = nextChapter.id.toString();

    talker.debug('🔁 Next chapter: ${nextChapter.name} (ID: $nextChapterId), contains=${loopRange.containsChapter(nextChapterId, playlist)}');

    // Verify the next chapter is still within our loop range
    if (!loopRange.containsChapter(nextChapterId, playlist)) {
      talker.warning('⚠️ Next chapter outside loop range');
      emit(state.copyWith(status: PlayerStatus.stopped));
      return;
    }

    talker.info(
      '➡️ Range advance: ${completedChapter.name} → ${nextChapter.name}',
    );

    // Mark that we're transitioning
    _isTransitioningChapters = true;

    add(PlayEvent(bookName: bookId, chapter: nextChapter));

    // Clear transition flag
    Future.delayed(const Duration(milliseconds: 100), () {
      _isTransitioningChapters = false;
    });
  }

  void _handleAutoAdvance(
    Chapter completedChapter,
    String bookId,
    List<Chapter> playlist,
    Emitter<PlayerState> emit,
  ) {
    if (playlist.isEmpty) {
      talker.info('🏁 Playlist empty, stopping');
      emit(state.copyWith(status: PlayerStatus.stopped));
      return;
    }

    final currentIndex = playlist.indexWhere(
      (c) => c.id == completedChapter.id,
    );

    if (currentIndex == -1 || currentIndex >= playlist.length - 1) {
      talker.info('🏁 End of playlist reached');
      emit(state.copyWith(status: PlayerStatus.stopped));
      return;
    }

    final nextChapter = playlist[currentIndex + 1];
    talker.info('⏭️ Auto-advancing to: ${nextChapter.name}');
    add(PlayEvent(bookName: bookId, chapter: nextChapter));
  }

  Future<void> _onPlayFromPosition(
    PlayFromPositionEvent event,
    Emitter<PlayerState> emit,
  ) async {
    talker.debug('PlayFromPosition: ${event.position.inSeconds}s');


    final audioPath = await _getAudioPath(event.bookName, event.chapter);
    if (!await _fileExists(audioPath)) {
      talker.warning('Audio file not found: $audioPath');
      return;
    }

    final item = MediaItem(
      id: event.chapter.id.toString(),
      title: event.chapter.name,
      // Add other fields if needed, like artist or artUri
    );

    // Cast and call with initialPosition
    // Calculate optional loop boundaries
    Duration? loopStart;
    Duration? loopEnd;
    bool autoLoop = false;

    if (event.loopStartLine != null &&
        event.loopEndLine != null &&
        event.startChapterId != null &&
        event.endChapterId != null) {
      final loopRange = LoopRange(
        startChapterId: event.startChapterId!,
        endChapterId: event.endChapterId!,
        startLine: event.loopStartLine!,
        endLine: event.loopEndLine!,
      );

      final boundaries = loopRange.getBoundariesForChapter(event.chapter);
      loopStart = boundaries.startTime;
      loopEnd = boundaries.endTime;
      autoLoop = boundaries.autoLoop;

      // Update state with loop details, mode, AND chapter info
      emit(
        state.copyWith(
          status: PlayerStatus.playing,
          chapter: event.chapter,
          bookId: event.bookName,
          playlist: event.playlist,
          loopMode: LoopMode.range,
          loopStartChapterId: event.startChapterId,
          loopEndChapterId: event.endChapterId,
          loopStartLine: event.loopStartLine,
          loopEndLine: event.loopEndLine,
        ),
      );
    }
    // Only re-apply if not setting new ones (and we are in range mode)
    else if (state.loopMode == LoopMode.range &&
        state.loopStartLine != null &&
        state.loopEndLine != null) {
      final loopRange = LoopRange(
        startChapterId: state.loopStartChapterId!,
        endChapterId: state.loopEndChapterId!,
        startLine: state.loopStartLine!,
        endLine: state.loopEndLine!,
      );
      final boundaries = loopRange.getBoundariesForChapter(event.chapter);
      loopStart = boundaries.startTime;
      loopEnd = boundaries.endTime;
      autoLoop = boundaries.autoLoop;
    }

    // Cast and call with parameters
    await (audioHandler as AudioPlayerHandler).playFromFile(
      audioPath,
      item,
      initialPosition: event.position,
      loopStart: loopStart,
      loopEnd: loopEnd,
      autoLoop: autoLoop,
    );

    // If we didn't emit above (no new loop range), verify we emit the new chapter info
    if (state.chapter?.id != event.chapter.id ||
        state.bookId != event.bookName) {
      emit(
        state.copyWith(
          status: PlayerStatus.playing, // Optimistic update
          chapter: event.chapter,
          bookId: event.bookName,
          playlist: event.playlist,
        ),
      );
    }
  }

  Future<void> _onPause(PauseEvent event, Emitter<PlayerState> emit) async {
    await audioHandler.pause();
    if (state.status == PlayerStatus.playing) {
      emit(state.copyWith(status: PlayerStatus.paused));
    }
  }

  Future<void> _onStop(StopEvent event, Emitter<PlayerState> emit) async {
    _isTransitioningChapters = false; // Clear any transition flags
    await audioHandler.stop();
    emit(state.copyWith(status: PlayerStatus.stopped));
  }

  Future<void> _onSeek(SeekEvent event, Emitter<PlayerState> emit) async {
    talker.debug('⏩ Seeking to ${event.position.inSeconds}s');
    await audioHandler.seek(event.position);
  }

  Future<void> _onSetSpeed(
    SetSpeedEvent event,
    Emitter<PlayerState> emit,
  ) async {
    talker.debug('⏩ Setting speed to ${event.speed}x');
    if (audioHandler is AudioPlayerHandler) {
      await (audioHandler as AudioPlayerHandler).setSpeed(event.speed);
    }
    emit(state.copyWith(speed: event.speed));
  }

  Future<void> _onSetLoopRange(
    SetLoopRangeEvent event,
    Emitter<PlayerState> emit,
  ) async {
    if (state.chapter == null) return;

    final loopRange = LoopRange(
      startChapterId: event.startChapterId ?? state.chapter!.id.toString(),
      endChapterId: event.endChapterId ?? state.chapter!.id.toString(),
      startLine: event.startLine,
      endLine: event.endLine,
    );

    talker.info(
      '🔁 Setting loop range: ${loopRange.startChapterId}:${loopRange.startLine} → ${loopRange.endChapterId}:${loopRange.endLine} (Immediate: ${event.playImmediately})',
    );
    talker.debug('🔁 Current chapter: ${state.chapter!.name} (ID: ${state.chapter!.id})');
    talker.debug('🔁 Playlist length: ${state.playlist.length}');

    emit(
      state.copyWith(
        loopMode: LoopMode.range,
        loopStartLine: loopRange.startLine,
        loopEndLine: loopRange.endLine,
        loopStartChapterId: loopRange.startChapterId,
        loopEndChapterId: loopRange.endChapterId,
        playlist: event.playlist ?? state.playlist,
      ),
    );

    // Apply the loop range to the currently playing chapter
    if (state.chapter != null) {
      _applyLoopRange(state.chapter!, loopRange);
    }

    if (event.playImmediately) {
      // Find the start chapter to jump to
      final startChapter =
          state.chapter!.id.toString() == loopRange.startChapterId
          ? state.chapter
          : _findChapterById(state.playlist, loopRange.startChapterId);

      talker.debug('🔁 Start chapter decision: current=${state.chapter!.id}, startId=${loopRange.startChapterId}, found=${startChapter?.name}');

      if (startChapter != null) {
        talker.info('🔁 Jumping to start of loop range: ${startChapter.name}');
        await _restartLoopRange(
          loopRange,
          state.bookId ?? '',
          state.playlist,
          forceChapter: startChapter,
        );
      } else {
        talker.warning('🔁 Could not find start chapter for loop range');
      }
    }
  }

  void _onSetLoopMode(SetLoopModeEvent event, Emitter<PlayerState> emit) {
    talker.debug('🔁 Setting loop mode to ${event.loopMode}');

    // Clear loop constraints when not in range mode
    if (audioHandler is AudioPlayerHandler &&
        event.loopMode != LoopMode.range) {
      (audioHandler as AudioPlayerHandler).setLoopRange(null, null);
    }

    emit(state.copyWith(loopMode: event.loopMode));
  }

  // Helper methods

  Future<String> _getAudioPath(String bookName, Chapter chapter) async {
    final appDir = await getApplicationDocumentsDirectory();
    return '${appDir.path}/books/$bookName/${chapter.audioPath}';
  }

  Future<bool> _fileExists(String path) async {
    return File(path).existsSync();
  }

  Future<void> _playAudioFile(
    String audioPath,
    String bookName,
    Chapter chapter,
  ) async {
    if (audioHandler is! AudioPlayerHandler) return;
    final handler = audioHandler as AudioPlayerHandler;

    final mediaItem = MediaItem(
      id: audioPath,
      album: bookName,
      title: chapter.name,
    );

    // Calculate loop boundaries if in range mode
    Duration? loopStart;
    Duration? loopEnd;
    bool autoLoop = false;

    if (state.loopMode == LoopMode.range &&
        state.loopStartLine != null &&
        state.loopEndLine != null) {
      final loopRange = LoopRange(
        startChapterId: state.loopStartChapterId ?? chapter.id.toString(),
        endChapterId: state.loopEndChapterId ?? chapter.id.toString(),
        startLine: state.loopStartLine!,
        endLine: state.loopEndLine!,
      );

      final boundaries = loopRange.getBoundariesForChapter(chapter);
      loopStart = boundaries.startTime;
      loopEnd = boundaries.endTime;
      autoLoop = boundaries.autoLoop;
    }

    await handler.playFromFile(
      audioPath,
      mediaItem,
      loopStart: loopStart,
      loopEnd: loopEnd,
      autoLoop: autoLoop,
    );
    await handler.setSpeed(state.speed);
  }

  void _applyLoopRange(Chapter chapter, LoopRange loopRange) {
    if (audioHandler is! AudioPlayerHandler) return;

    final boundaries = loopRange.getBoundariesForChapter(chapter);

    talker.debug(
      '🎯 Applying loop boundaries: '
      'start=${boundaries.startTime?.inSeconds}s, '
      'end=${boundaries.endTime?.inSeconds}s, '
      'autoLoop=${boundaries.autoLoop}',
    );

    (audioHandler as AudioPlayerHandler).setLoopRange(
      boundaries.startTime,
      boundaries.endTime,
      autoLoop: boundaries.autoLoop,
    );
  }

  Chapter? _findChapterById(List<Chapter> playlist, String chapterId) {
    for (final chapter in playlist) {
      if (chapter.id.toString() == chapterId) {
        return chapter;
      }
    }
    return null;
  }

  @override
  Future<void> close() {
    _playbackStateSub?.cancel();
    return super.close();
  }
}
