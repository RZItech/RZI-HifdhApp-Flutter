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
  bool _isManuallyCompleted = false;

  @override
  Future<void> stop() => _audioPlayer.stop();

  @override
  Future<void> setSpeed(double speed) async {
    await _audioPlayer.setPlaybackRate(speed);
    _broadcastState();
  }

  void setLoopRange(Duration? start, Duration? end, {bool autoLoop = true}) {
    _loopStart = start;
    _loopEnd = end;
    _autoLoop = autoLoop;
  }

  AudioPlayerHandler() {
    // Configure global audio context for background support on iOS
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

    // Listen to playback state events from the audio player
    _audioPlayer.onPlayerStateChanged.listen(_propagatePlayerState);
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      _broadcastState();

      // Handle Looping
      if (_loopEnd != null && position >= _loopEnd!) {
        if (_autoLoop) {
          seek(_loopStart ?? Duration.zero);
        } else {
          // End of clip reached (for cross-chapter ending)
          // Treat as completion
          pause();
          seek(_loopEnd!); // Visual feedback
          _isManuallyCompleted = true;
          playbackState.add(
            playbackState.value.copyWith(
              processingState: AudioProcessingState.completed,
            ),
          );
        }
      } else if (_loopStart != null && position < _loopStart!) {
        // Generally enforce start boundary if strictly clipping
        // But usually we just seek there initially.
        // If user seeks backwards, maybe we let them?
        // For now, let's enforce simple seeking to start if autoLoop is on.
        if (_autoLoop) seek(_loopStart!);
      }
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      final item = mediaItem.value;
      if (item != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });

    // Handle audio session completion
    _audioPlayer.onPlayerComplete.listen((_) {
      _isManuallyCompleted = true;
      if (playbackState.value.processingState !=
          AudioProcessingState.completed) {
        playbackState.add(
          playbackState.value.copyWith(
            processingState: AudioProcessingState.completed,
          ),
        );
      }
    });
  }

  void _propagatePlayerState(PlayerState state) {
    _broadcastState();
  }

  void _broadcastState() {
    final playing = _audioPlayer.state == PlayerState.playing;
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
        processingState: () {
          final state = _audioPlayer.state;
          if (state == PlayerState.completed) {
            // ONLY broadcast completed if it was actually triggered by ending/clipping
            return _isManuallyCompleted
                ? AudioProcessingState.completed
                : AudioProcessingState.ready;
          }
          return const {
            PlayerState.stopped: AudioProcessingState.idle,
            PlayerState.playing: AudioProcessingState.ready,
            PlayerState.paused: AudioProcessingState.ready,
            PlayerState.completed: AudioProcessingState.completed,
            PlayerState.disposed: AudioProcessingState.idle,
          }[state]!;
        }(),
        playing: playing,
        updatePosition: _currentPosition,
        bufferedPosition: _currentPosition,
        speed: _audioPlayer.playbackRate,
        queueIndex: 0,
      ),
    );
  }

  @override
  Future<void> play() => _audioPlayer.resume();

  @override
  Future<void> pause() => _audioPlayer.pause();

  @override
  Future<void> seek(Duration position) => _audioPlayer.seek(position);

  Future<void> playFromFile(String filePath, MediaItem item) async {
    mediaItem.add(item);
    _isManuallyCompleted = false;

    // Explicitly transition out of completed/idle state before starting
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.buffering,
      ),
    );

    await _audioPlayer.play(DeviceFileSource(filePath));
    // Skip manual _broadcastState() here to avoid stale state races
  }
}
