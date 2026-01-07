import 'dart:io';

import 'package:audioplayers/audioplayers.dart' hide PlayerState;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';

import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_event.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';

class PlayerBloc extends Bloc<PlayerEvent, PlayerState> {
  final AudioPlayer audioPlayer;

  PlayerBloc({required this.audioPlayer}) : super(PlayerInitial()) {
    on<PlayEvent>((event, emit) async {
      final appDir = await getApplicationDocumentsDirectory();
      final audioPath =
          '${appDir.path}/books/${event.bookName}/${event.chapter.audioPath}';

      if (File(audioPath).existsSync()) {
        await audioPlayer.play(DeviceFileSource(audioPath));
        emit(PlayerPlaying(chapter: event.chapter));
      }
    });

    on<PauseEvent>((event, emit) async {
      await audioPlayer.pause();
      if (state is PlayerPlaying) {
        emit(PlayerPaused(chapter: (state as PlayerPlaying).chapter));
      }
    });

    on<StopEvent>((event, emit) async {
      await audioPlayer.stop();
      emit(PlayerStopped());
    });

    on<SeekEvent>((event, emit) async {
      await audioPlayer.seek(event.position);
    });
  }
}
