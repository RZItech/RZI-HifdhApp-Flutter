import 'dart:io';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_event.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';
import 'package:rzi_hifdhapp/features/player/services/audio_handler.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';

final talker = sl<Talker>();

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioHandler audioHandler;

  Stream<Duration> get positionStream {
    if (audioHandler is AudioPlayerHandler) {
      return (audioHandler as AudioPlayerHandler).onPositionChanged;
    }
    return const Stream.empty();
  }

  PlayerBloc({required this.audioHandler}) : super(PlayerInitial()) {
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
          // You could add duration if known, or artUri
        );

        if (audioHandler is AudioPlayerHandler) {
          await (audioHandler as AudioPlayerHandler).playFromFile(
            audioPath,
            mediaItem,
          );
        }

        emit(PlayerPlaying(chapter: event.chapter));
      } else {
        talker.warning('❌ Audio file missing!');
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

        if (audioHandler is AudioPlayerHandler) {
          await (audioHandler as AudioPlayerHandler).playFromFile(
            audioPath,
            mediaItem,
          );
          // Brief delay to allow load
          await Future.delayed(const Duration(milliseconds: 100));
          talker.debug('⏩ Seeking to position');
          await audioHandler.seek(event.position);
        }

        emit(PlayerPlaying(chapter: event.chapter));
      } else {
        talker.warning('❌ Audio file not found: $audioPath');
      }
    });

    on<PauseEvent>((event, emit) async {
      await audioHandler.pause();
      if (state is PlayerPlaying) {
        emit(PlayerPaused(chapter: (state as PlayerPlaying).chapter));
      }
    });

    on<StopEvent>((event, emit) async {
      await audioHandler.stop();
      emit(PlayerStopped());
    });

    on<SeekEvent>((event, emit) async {
      talker.debug('⏩ SeekEvent to ${event.position.inSeconds}s');
      await audioHandler.seek(event.position);
    });
  }
}
