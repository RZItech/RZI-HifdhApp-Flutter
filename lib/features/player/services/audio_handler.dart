import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';

final talker = sl<Talker>();

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  Duration _currentPosition = Duration.zero;

  Stream<Duration> get positionStream => _player.positionStream;
  Duration get currentPosition => _currentPosition;

  // Track whether we've signaled completion for this playback session
  bool _hasSignaledCompletion = false;

  AudioPlayerHandler() {
    // Configure audio session for background playback
    _configureAudioSession();

    // Listen to player state changes (playing/processing state)
    _player.playerStateStream.listen((state) {
      _broadcastState();
    });

    // Listen to playback events (buffering, error, etc)
    _player.playbackEventStream.listen(_broadcastState);

    // Listen to position updates
    _player.positionStream.listen((position) {
      _currentPosition = position;
    });

    // Handle natural audio completion
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        _handlePlayerComplete();
      }
    });

    // Listen to duration changes to update media item
    _player.durationStream.listen(_handleDurationChange);
  }

  Future<void> _configureAudioSession() async {
    final session = await AudioSession.instance;
    await session.configure(
      AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.allowBluetooth |
            AVAudioSessionCategoryOptions.defaultToSpeaker |
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          flags: AndroidAudioFlags.none,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ),
    );
  }

  void _handlePlayerComplete() {
    // Signal completion only once per playback session
    if (!_hasSignaledCompletion) {
      _hasSignaledCompletion = true;
      _signalCompletion();
    }
  }

  void _handleDurationChange(Duration? duration) {
    final item = mediaItem.value;
    if (item != null && duration != null) {
      mediaItem.add(item.copyWith(duration: duration));
    }
  }

  /// Configure loop boundaries for the current audio file using setClip
  /// Is async to support native calls
  Future<void> setLoopRange(
    Duration? start,
    Duration? end, {
    bool autoLoop = false,
  }) async {
    // Use just_audio's setClip to restrict playback region
    await _player.setClip(start: start, end: end);

    // Only use LoopMode.one if we have VALID boundaries AND autoLoop is true
    if (autoLoop && start != null && end != null) {
      await _player.setLoopMode(LoopMode.one);
    } else {
      await _player.setLoopMode(LoopMode.off);
    }

    talker.debug(
      '🎯 setClip applied: start=${start?.inSeconds}s, end=${end?.inSeconds}s, '
      'loopMode=${(autoLoop && start != null && end != null) ? "one" : "off"}',
    );
  }

  /// Signal that playback has completed
  void _signalCompletion() {
    if (_hasSignaledCompletion) return; // Already signaled

    _hasSignaledCompletion = true;

    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.completed,
      ),
    );
  }

  // Guard to prevent state flickering during file loading
  bool _isInitializingPlayback = false;

  void _broadcastState([PlaybackEvent? event]) {
    final playing = _player.playing;
    final processingState = _player.processingState;

    // If we are artificially holding the playing state (during file load),
    // override the player's actual 'false' state.
    final effectivePlaying = _isInitializingPlayback ? true : playing;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (effectivePlaying) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: _mapProcessingState(processingState),
        playing: effectivePlaying,
        updatePosition: _currentPosition,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: event?.currentIndex,
      ),
    );
  }

  AudioProcessingState _mapProcessingState(ProcessingState state) {
    switch (state) {
      case ProcessingState.idle:
        return AudioProcessingState.idle;
      case ProcessingState.loading:
        return AudioProcessingState.buffering;
      case ProcessingState.buffering:
        return AudioProcessingState.buffering;
      case ProcessingState.ready:
        return AudioProcessingState.ready;
      case ProcessingState.completed:
        return AudioProcessingState.completed;
    }
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> setSpeed(double speed) async {
    await _player.setSpeed(speed);
    _broadcastState();
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    _hasSignaledCompletion = false;
    super.stop();
  }

  /// Start playing a new audio file
  ///
  /// This resets the completion flag and transitions through buffering
  /// to ensure clean state transitions
  Future<void> playFromFile(
    String filePath,
    MediaItem item, {
    Duration initialPosition = Duration.zero,
    Duration? loopStart,
    Duration? loopEnd,
    bool autoLoop = false,
  }) async {
    mediaItem.add(item);

    // Reset completion flag for new playback session
    _hasSignaledCompletion = false;

    // Flag that we are initializing playback to prevent "Paused" flicker
    _isInitializingPlayback = true;

    // Transition to buffering state with optimistic playing=true
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: true,
      ),
    );

    try {
      // Set source (local file) with initial position
      await _player.setAudioSource(
        AudioSource.file(filePath),
        initialPosition: initialPosition,
      );

      // ALWAYS apply loop boundaries explicitly
      await setLoopRange(loopStart, loopEnd, autoLoop: autoLoop);

      // FORCE seek to ensure position stream emits
      await _player.seek(initialPosition);
      talker.debug(
        '🎯 Forced seek to ${initialPosition.inSeconds}s (start of playback)',
      );

      // Initialization complete, allowed to reflect actual player state
      _isInitializingPlayback = false;
      await _player.play();
    } catch (e) {
      _isInitializingPlayback = false;
      talker.error('Playback start failed: $e');
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
          playing: false,
        ),
      );
    }
  }
}
