import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_event.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';


class ChapterCard extends StatelessWidget {
  final String bookName;
  final Chapter chapter;
  final bool isEnglishVisible;

  const ChapterCard({
    super.key,
    required this.bookName,
    required this.chapter,
    required this.isEnglishVisible,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              chapter.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isEnglishVisible)
                  Expanded(
                    child: Text(
                      chapter.englishText,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                if (isEnglishVisible) const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    chapter.arabicText,
                    style: const TextStyle(fontSize: 20, fontFamily: 'Arabic'),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            BlocBuilder<PlayerBloc, PlayerState>(
              builder: (context, playerState) {
                bool isPlaying = false;
                if (playerState is PlayerPlaying && playerState.chapter.id == chapter.id) {
                  isPlaying = true;
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                      onPressed: () {
                        if (isPlaying) {
                          context.read<PlayerBloc>().add(PauseEvent());
                        } else {
                          context.read<PlayerBloc>().add(PlayEvent(
                              bookName: bookName, chapter: chapter));
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}