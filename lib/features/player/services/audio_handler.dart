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

  Duration? _loopStart;
  Duration? _loopEnd;
  bool _autoLoop = true;

  // Track whether we've signaled completion for this playback session
  bool _hasSignaledCompletion = false;

  AudioPlayerHandler() {
    // Configure audio session for background playback
    _configureAudioSession();

    // Listen to player state changes
    _player.playbackEventStream.listen(_broadcastState);

    // Listen to position updates for loop boundary enforcement
    _player.positionStream.listen((position) {
      _currentPosition = position;
      _enforceLoopBoundaries(position);
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

  /// Configure loop boundaries for the current audio file
  ///
  /// For single-chapter loops: Both start and end are set, autoLoop=true
  /// For cross-chapter loops: Only relevant boundaries are set, autoLoop=false
  void setLoopRange(Duration? start, Duration? end, {bool autoLoop = true}) {
    _loopStart = start;
    _loopEnd = end;
    _autoLoop = autoLoop;
  }

  /// Enforce loop boundaries during playback
  void _enforceLoopBoundaries(Duration position) {
    // Check if we've reached the end boundary
    if (_loopEnd != null && position >= _loopEnd!) {
      if (_autoLoop && _loopStart != null) {
        // Single-chapter loop: automatically loop back to start
        _player.seek(_loopStart!);
      } else {
        // Cross-chapter loop or end of clip: signal completion
        // The bloc will handle transitioning to the next chapter
        _signalCompletion();
        pause(); // Pause at the end position for visual feedback
      }
    }
    // Enforce start boundary if user seeks backward in auto-loop mode
    else if (_autoLoop && _loopStart != null && position < _loopStart!) {
      _player.seek(_loopStart!);
    }
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

  void _broadcastState([PlaybackEvent? event]) {
    final playing = _player.playing;
    final processingState = _player.processingState;

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
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
        playing: playing,
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
  }) async {
    mediaItem.add(item);

    // Reset completion flag for new playback session
    _hasSignaledCompletion = false;

    // Transition to buffering state before starting playback
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: false,
      ),
    );

    try {
      // Set source (local file) with initial position
      await _player.setAudioSource(
        AudioSource.file(filePath),
        initialPosition: initialPosition,
      );
      await _player.play();
    } catch (e) {
      talker.error('Playback start failed: $e');
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.error,
        ),
      );
    }
  }
}
