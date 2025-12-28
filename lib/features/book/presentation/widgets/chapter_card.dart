import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_event.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';
import 'package:rzi_hifdhapp/features/test/presentation/bloc/test_bloc.dart';
import 'package:rzi_hifdhapp/features/test/presentation/bloc/test_event.dart';
import 'package:rzi_hifdhapp/features/test/presentation/bloc/test_state.dart';
import 'package:rzi_hifdhapp/core/utils/arabic_text_utils.dart';


class ChapterCard extends StatefulWidget { // Changed to StatefulWidget for animation
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
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _colorAnimation = ColorTween(begin: Colors.transparent, end: Colors.red.withOpacity(0.3)).animate(_animationController);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TestBloc, TestState>( // Use BlocConsumer for listening to state changes
      listener: (context, testState) {
        // Handle flashing red effect
        if (testState.status == TestStatus.listening &&
            testState.chaptersToTest.isNotEmpty &&
            testState.currentChapterIndex < testState.chaptersToTest.length && // Ensure index is valid
            testState.chaptersToTest[testState.currentChapterIndex].id == widget.chapter.id && // Check if this is the current chapter being tested
            testState.incorrectAttempts > 0) { // Only flash on incorrect attempts
          _animationController.forward().then((_) => _animationController.reverse());
        }
      },
      builder: (context, testState) {
        bool isTestingThisChapter = false;
        List<String> expectedWords = [];
        List<WordStatus> wordStatuses = [];

        if (testState.status != TestStatus.idle &&
            testState.chaptersToTest.isNotEmpty &&
            testState.chaptersToTest.contains(widget.chapter)) {
          isTestingThisChapter = true;
          expectedWords = ArabicTextUtils.splitArabicTextIntoWords(widget.chapter.arabicText);
          
          // Determine word statuses for this chapter
          if (testState.currentChapterIndex < testState.chaptersToTest.length &&
              testState.chaptersToTest[testState.currentChapterIndex].id == widget.chapter.id) {
            wordStatuses = List<WordStatus>.from(testState.wordStatuses); // Get current state word statuses
          } else {
            // If another chapter is being tested, this chapter's words should be hidden
            wordStatuses = List.generate(expectedWords.length, (index) => WordStatus.hidden);
          }
        }


        return AnimatedBuilder(
          animation: _colorAnimation,
          builder: (context, child) {
            return Card(
              margin: const EdgeInsets.all(8.0),
              color: _colorAnimation.value, // Apply flashing color
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      widget.chapter.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.isEnglishVisible)
                          Expanded(
                            child: Text(
                              widget.chapter.englishText,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        if (widget.isEnglishVisible) const SizedBox(width: 16),
                        Expanded(
                          child: Wrap( // Use Wrap for word-by-word display
                            alignment: WrapAlignment.end, // Arabic is right-to-left
                            textDirection: TextDirection.rtl,
                            children: expectedWords.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final String word = entry.value;
                              final WordStatus status = wordStatuses.length > index ? wordStatuses[index] : WordStatus.hidden; // Default to hidden if status not available

                              Color wordColor;
                              bool isHidden = false;

                              if (isTestingThisChapter) {
                                switch (status) {
                                  case WordStatus.hidden:
                                    wordColor = Colors.transparent; // Blank out
                                    isHidden = true;
                                    break;
                                  case WordStatus.correct:
                                    wordColor = Colors.green;
                                    break;
                                  case WordStatus.incorrect:
                                    wordColor = Colors.red;
                                    break;
                                  case WordStatus.current:
                                    wordColor = Colors.blue; // Highlight current word
                                    break;
                                }
                              } else {
                                wordColor = Colors.black; // Default if not testing
                              }


                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                child: Text(
                                  isHidden ? '____' : word, // Show underscore for hidden word
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontFamily: 'Arabic',
                                    color: wordColor,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    BlocBuilder<PlayerBloc, PlayerState>(
                      builder: (context, playerState) {
                        bool isPlaying = false;
                        if (playerState is PlayerPlaying && playerState.chapter.id == widget.chapter.id) {
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
                                      bookName: widget.bookName, chapter: widget.chapter));
                                }
                              },
                            ),
                            // Test button
                            IconButton(
                              icon: isTestingThisChapter && testState.status == TestStatus.listening && testState.currentChapterIndex < testState.chaptersToTest.length && testState.chaptersToTest[testState.currentChapterIndex].id == widget.chapter.id ? const Icon(Icons.stop) : const Icon(Icons.mic),
                              onPressed: () {
                                if (isTestingThisChapter && testState.status == TestStatus.listening && testState.currentChapterIndex < testState.chaptersToTest.length && testState.chaptersToTest[testState.currentChapterIndex].id == widget.chapter.id) {
                                  context.read<TestBloc>().add(StopTest());
                                } else {
                                  context
                                      .read<TestBloc>()
                                      .add(StartTestFromChapter(widget.chapter));
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
          },
        );
      },
    );
  }
}
