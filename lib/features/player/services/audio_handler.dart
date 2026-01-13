import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _currentPosition = Duration.zero;

  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;

  Duration? _loopStart;
  Duration? _loopEnd;
  bool _autoLoop = true;

  // Track whether we've signaled completion for this playback session
  bool _hasSignaledCompletion = false;

  @override
  Future<void> stop() async {
    await _audioPlayer.stop();
    _hasSignaledCompletion = false;
  }

  @override
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setPlaybackRate(speed);
    _broadcastState();
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

  AudioPlayerHandler() {
    // Configure audio context for background playback
    AudioPlayer.global.setAudioContext(
      AudioContext(
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: {
            AVAudioSessionOptions.mixWithOthers,
            AVAudioSessionOptions.defaultToSpeaker,
            AVAudioSessionOptions.allowBluetooth,
            AVAudioSessionOptions.allowBluetoothA2DP,
          },
        ),
        android: AudioContextAndroid(
          isSpeakerphoneOn: true,
          stayAwake: true,
          contentType: AndroidContentType.music,
          usageType: AndroidUsageType.media,
          audioFocus: AndroidAudioFocus.gain,
        ),
      ),
    );

    // Listen to player state changes
    _audioPlayer.onPlayerStateChanged.listen(_handlePlayerStateChange);

    // Listen to position updates for loop boundary enforcement
    _audioPlayer.onPositionChanged.listen(_handlePositionUpdate);

    // Listen to duration changes to update media item
    _audioPlayer.onDurationChanged.listen(_handleDurationChange);

    // Handle natural audio completion
    _audioPlayer.onPlayerComplete.listen(_handlePlayerComplete);
  }

  void _handlePlayerStateChange(PlayerState state) {
    _broadcastState();
  }

  void _handlePositionUpdate(Duration position) {
    _currentPosition = position;
    _broadcastState();

    // Enforce loop boundaries
    _enforceLoopBoundaries(position);
  }

  void _handleDurationChange(Duration duration) {
    final item = mediaItem.value;
    if (item != null) {
      mediaItem.add(item.copyWith(duration: duration));
    }
  }

  void _handlePlayerComplete(_) {
    // Signal completion only once per playback session
    if (!_hasSignaledCompletion) {
      _hasSignaledCompletion = true;
      _signalCompletion();
    }
  }

  /// Enforce loop boundaries during playback
  void _enforceLoopBoundaries(Duration position) {
    // Check if we've reached the end boundary
    if (_loopEnd != null && position >= _loopEnd!) {
      if (_autoLoop && _loopStart != null) {
        // Single-chapter loop: automatically loop back to start
        seek(_loopStart!);
      } else {
        // Cross-chapter loop or end of clip: signal completion
        // The bloc will handle transitioning to the next chapter
        _signalCompletion();

        // Pause at the end position for visual feedback
        pause();
      }
    }
    // Enforce start boundary if user seeks backward in auto-loop mode
    // This prevents the user from accidentally playing content before the loop start
    else if (_autoLoop && _loopStart != null && position < _loopStart!) {
      seek(_loopStart!);
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

  void _broadcastState() {
    final playing = _audioPlayer.state == PlayerState.playing;
    final currentState = _audioPlayer.state;

    // Determine the appropriate processing state
    AudioProcessingState processingState;
    if (currentState == PlayerState.completed && _hasSignaledCompletion) {
      processingState = AudioProcessingState.completed;
    } else {
      processingState = _mapPlayerStateToProcessingState(currentState);
    }

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.rewind,
          if (playing) MediaControl.pause else MediaControl.play,
          MediaControl.stop,
          MediaControl.fastForward,
        ],
        systemActions: const {
          MediaAction.seek,
          MediaAction.seekForward,
          MediaAction.seekBackward,
        },
        androidCompactActionIndices: const [0, 1, 3],
        processingState: processingState,
        playing: playing,
        updatePosition: _currentPosition,
        bufferedPosition: _currentPosition,
        speed: _audioPlayer.playbackRate,
        queueIndex: 0,
      ),
    );
  }

  AudioProcessingState _mapPlayerStateToProcessingState(PlayerState state) {
    switch (state) {
      case PlayerState.stopped:
      case PlayerState.disposed:
        return AudioProcessingState.idle;
      case PlayerState.playing:
      case PlayerState.paused:
        return AudioProcessingState.ready;
      case PlayerState.completed:
        // Only mark as completed if we've signaled it
        return _hasSignaledCompletion
            ? AudioProcessingState.completed
            : AudioProcessingState.ready;
    }
  }

  @override
  Future<void> play() => _audioPlayer.resume();

  @override
  Future<void> pause() => _audioPlayer.pause();

  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  /// Start playing a new audio file
  ///
  /// This resets the completion flag and transitions through buffering
  /// to ensure clean state transitions
  Future<void> playFromFile(String filePath, MediaItem item) async {
    mediaItem.add(item);

    // Reset completion flag for new playback session
    _hasSignaledCompletion = false;

    // Transition to buffering state before starting playback
    // This ensures the UI shows loading status and prevents stale state
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
        playing: false,
      ),
    );

    // Start playback
    await _audioPlayer.play(DeviceFileSource(filePath));

    // State will be broadcast automatically through the state change listener
  }
}
