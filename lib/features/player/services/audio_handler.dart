import 'package:audio_service/audio_service.dart';
import 'package:audioplayers/audioplayers.dart';

class AudioPlayerHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Duration _currentPosition = Duration.zero;

  Stream<Duration> get onPositionChanged => _audioPlayer.onPositionChanged;

  AudioPlayerHandler() {
    // Listen to playback state events from the audio player
    _audioPlayer.onPlayerStateChanged.listen(_propagatePlayerState);
    _audioPlayer.onPositionChanged.listen((position) {
      _currentPosition = position;
      _broadcastState();
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      final item = mediaItem.value;
      if (item != null) {
        mediaItem.add(item.copyWith(duration: duration));
      }
    });

    // Handle audio session completion
    _audioPlayer.onPlayerComplete.listen((_) {
      playbackState.add(
        playbackState.value.copyWith(
          processingState: AudioProcessingState.completed,
        ),
      );
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
        processingState: const {
          PlayerState.stopped: AudioProcessingState.idle,
          PlayerState.playing: AudioProcessingState.ready,
          PlayerState.paused: AudioProcessingState.ready,
          PlayerState.completed: AudioProcessingState.completed,
          PlayerState.disposed: AudioProcessingState.idle,
        }[_audioPlayer.state]!,
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

  @override
  Future<void> stop() => _audioPlayer.stop();

  Future<void> playFromFile(String filePath, MediaItem item) async {
    mediaItem.add(item);
    await _audioPlayer.play(DeviceFileSource(filePath));
    _broadcastState();
  }
}
