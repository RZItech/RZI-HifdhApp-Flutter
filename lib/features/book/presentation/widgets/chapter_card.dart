import 'dart:async';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_state.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';
import 'package:rzi_hifdhapp/core/services/speech_service.dart';
import 'package:rzi_hifdhapp/core/utils/text_utils.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_event.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_state.dart';

final talker = sl<Talker>();

enum LineState { neutral, listening, correct, incorrect, failed }

class ChapterCard extends StatefulWidget {
  final String bookId;
  final Chapter chapter;
  final List<Chapter> allChapters;
  final bool isEnglishVisible;
  final bool isTestingMode;
  final Map<String, String> normalizationRules;

  const ChapterCard({
    super.key,
    required this.bookId,
    required this.chapter,
    this.allChapters = const [],
    required this.isEnglishVisible,
    required this.isTestingMode,
    this.normalizationRules = const {},
  });

  @override
  State<ChapterCard> createState() => _ChapterCardState();
}

class _ChapterCardState extends State<ChapterCard> {
  final SpeechService _speechService = sl<SpeechService>();
  bool _isRecording = false;

  // Interactive Mode State
  List<String> _lines = [];
  List<String> _englishLines = [];
  final Map<int, LineState> _lineStates = {};
  final Map<int, int> _attempts = {};
  int? _currentLineIndex;

  // Audio playback tracking for Player Mode
  int? _currentPlayingLine;

  @override
  void initState() {
    super.initState();
    _parseLines();
    _speechService.initSpeech();
    _speechService.statusNotifier.addListener(_onStatusChange);
    _speechService.errorNotifier.addListener(_onError);
    _speechService.recognizedWordsNotifier.addListener(
      _onRecognizedWordsChange,
    );

    // Listen to audio position for Player Mode
    if (!widget.isTestingMode) {
      talker.debug(
        '🎧 Player Mode: audioLines count = ${widget.chapter.audioLines.length}',
      );
      _positionSub = context.read<PlayerBloc>().positionStream.listen((
        position,
      ) {
        if (mounted && widget.chapter.audioLines.isNotEmpty) {
          _updateCurrentPlayingLine(position.inSeconds.toDouble());
        }
      });
    }
  }

  StreamSubscription? _positionSub;

  @override
  void dispose() {
    _positionSub?.cancel();
    _speechService.statusNotifier.removeListener(_onStatusChange);
    _speechService.errorNotifier.removeListener(_onError);
    _speechService.recognizedWordsNotifier.removeListener(
      _onRecognizedWordsChange,
    );
    super.dispose();
  }

  void _updateCurrentPlayingLine(double currentSeconds) {
    final playerState = context.read<PlayerBloc>().state;
    if (playerState.bookId != widget.bookId ||
        playerState.chapter?.id != widget.chapter.id) {
      if (_currentPlayingLine != null) {
        setState(() {
          _currentPlayingLine = null;
        });
      }
      return;
    }

    int? newPlayingLine;
    for (int i = 0; i < widget.chapter.audioLines.length; i++) {
      final range = widget.chapter.audioLines[i];
      if (currentSeconds >= range.start && currentSeconds <= range.end) {
        newPlayingLine = i;
        break;
      }
    }

    if (newPlayingLine != _currentPlayingLine) {
      setState(() {
        _currentPlayingLine = newPlayingLine;
      });
    }
  }

  void _parseLines() {
    _lines = widget.chapter.arabicText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    // Attempt to split English lines similarly.
    // Assumes 1:1 mapping based on newlines.
    _englishLines = widget.chapter.englishText
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .toList();

    for (int i = 0; i < _lines.length; i++) {
      _lineStates[i] = LineState.neutral;
      _attempts[i] = 0;
    }
  }

  void _onRecognizedWordsChange() {
    if (mounted) {
      setState(() {});
      // Perform live validation to give immediate feedback
      _checkLiveMatch();
    }
  }

  void _checkLiveMatch() {
    if (_currentLineIndex == null || !_isRecording) return;

    final index = _currentLineIndex!;
    final recognizedText = _speechService.recognizedWordsNotifier.value;
    final targetText = _lines[index];

    final normalizedRecognized = TextUtils.normalizeArabic(
      recognizedText,
      widget.normalizationRules,
    );
    final normalizedTarget = TextUtils.normalizeArabic(
      targetText,
      widget.normalizationRules,
    );

    sl<Talker>().debug(
      'Live check - Rec: "$normalizedRecognized" | Tar: "$normalizedTarget"',
    );

    // Check for exact match logic (same as validate)
    if (normalizedRecognized.isNotEmpty &&
        normalizedRecognized == normalizedTarget) {
      sl<Talker>().info('✓ Live Match Found for Line $index!');
      setState(() {
        _lineStates[index] = LineState.correct;
        _attempts[index] = 0;
      });
      _isRecording =
          false; // Prevent onStatusChange from triggering validation again
      _stopListening();

      // Auto-advance to next line
      int nextIndex = index + 1;
      if (nextIndex < _lines.length) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _startListeningForLine(nextIndex);
        });
      } else {
        sl<Talker>().info('Chapter Completed!');
      }
    }
  }

  void _onStatusChange() {
    final status = _speechService.statusNotifier.value;
    if (mounted &&
        _isRecording &&
        (status == 'done' || status == 'notListening')) {
      setState(() {
        _isRecording = false;
      });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) _validateSpeech();
      });
    }
  }

  void _onError() {
    final error = _speechService.errorNotifier.value;
    if (error != null) {
      sl<Talker>().error("Speech recognition error: ${error.errorMsg}");
      if (_isRecording) {
        setState(() {
          _isRecording = false;
        });
      }
    }
  }

  void _startListeningForLine(int index) async {
    if (_isRecording) {
      _stopListening();
    }

    await _speechService.requestPermission();

    setState(() {
      _currentLineIndex = index;
      _lineStates[index] = LineState.listening;
      _isRecording = true;
    });

    _speechService.startListening();
  }

  void _stopListening() {
    _speechService.stopListening();
  }

  void _validateSpeech() {
    if (_currentLineIndex == null) return;

    final index = _currentLineIndex!;
    final recognizedText = _speechService.recognizedWordsNotifier.value;
    final targetText = _lines[index];

    final normalizedRecognized = TextUtils.normalizeArabic(
      recognizedText,
      widget.normalizationRules,
    );
    final normalizedTarget = TextUtils.normalizeArabic(
      targetText,
      widget.normalizationRules,
    );

    sl<Talker>().info(
      'Validating Line $index\nRec: $normalizedRecognized\nTar: $normalizedTarget',
    );

    bool isMatch = normalizedRecognized == normalizedTarget;

    if (isMatch) {
      sl<Talker>().info('✓ Match Found for Line $index!');
      _handleSuccess(index);
    } else {
      sl<Talker>().info(
        'Line was incorrect expected: \n$normalizedTarget \nbut got: \n$normalizedRecognized',
      );
      _handleFailure(index);
    }
  }

  void _handleSuccess(int index) {
    setState(() {
      _lineStates[index] = LineState.correct;
      _attempts[index] = 0;
    });

    int nextIndex = index + 1;
    if (nextIndex < _lines.length) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _startListeningForLine(nextIndex);
      });
    } else {
      sl<Talker>().info('Chapter Completed!');
    }
  }

  void _handleFailure(int index) {
    setState(() {
      _lineStates[index] = LineState.incorrect;
      _attempts[index] = (_attempts[index] ?? 0) + 1;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        setState(() {
          if ((_attempts[index] ?? 0) >= 3) {
            _lineStates[index] = LineState.failed;
          } else {
            _lineStates[index] = LineState.neutral;
            _startListeningForLine(index);
          }
        });
      }
    });
  }

  void _seekToLine(int lineIndex) {
    talker.debug('👆 Tapped line $lineIndex');
    if (lineIndex < widget.chapter.audioLines.length) {
      final range = widget.chapter.audioLines[lineIndex];
      talker.debug('🎯 Seeking to: ${range.start}s');

      final playerState = context.read<PlayerBloc>().state;

      // Use PlayFromPositionEvent to handle both playing and seeking
      if (playerState.status == PlayerStatus.playing &&
          playerState.bookId == widget.bookId &&
          playerState.chapter?.id == widget.chapter.id) {
        talker.debug('▶️ Already playing, sending SeekEvent');
        // Already playing this chapter, just seek
        context.read<PlayerBloc>().add(
          SeekEvent(
            position: Duration(milliseconds: (range.start * 1000).toInt()),
          ),
        );
      } else {
        talker.debug(
          '⏯️ Not playing (or different chapter), sending PlayFromPositionEvent',
        );
        // Start playing from this position
        context.read<PlayerBloc>().add(
          PlayFromPositionEvent(
            bookName: widget.bookId,
            chapter: widget.chapter,
            position: Duration(milliseconds: (range.start * 1000).toInt()),
            playlist: widget.allChapters,
          ),
        );
      }
    } else {
      talker.warning('⚠️ Line index $lineIndex out of bounds');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              widget.chapter.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildBody(),

            if (!widget.isTestingMode) ...[
              const SizedBox(height: 16),
              _buildPlayerControls(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    // Unified List View for both modes
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _lines.length,
      itemBuilder: (context, index) {
        return _buildLineItem(index);
      },
    );
  }

  Widget _buildLineItem(int index) {
    // Safe access for English line
    final englishLine = index < _englishLines.length
        ? _englishLines[index]
        : '';
    final arabicLine = _lines[index];

    final state = _lineStates[index] ?? LineState.neutral;

    Color? backgroundColor;
    Color? textColor; // Use default theme color by making this nullable/unset

    // Only apply colored states in Testing Mode
    if (widget.isTestingMode) {
      switch (state) {
        case LineState.correct:
          backgroundColor = Colors.green.withValues(alpha: 0.2);
          textColor = Colors.green;
          break;
        case LineState.incorrect:
          backgroundColor = Colors.red.withValues(alpha: 0.5); // Flash red
          break;
        case LineState.failed:
          backgroundColor = Colors.red.withValues(alpha: 0.2);
          textColor = Colors.red;
          break;
        case LineState.listening:
          backgroundColor = Colors.blue.withValues(alpha: 0.1);
          break;
        case LineState.neutral:
          break;
      }
    } else {
      // Styling for Player Mode: Highlight currently playing line
      final playerState = context.read<PlayerBloc>().state;
      final bool isCurrentHandled =
          playerState.bookId == widget.bookId &&
          playerState.chapter?.id == widget.chapter.id;

      if (isCurrentHandled && _currentPlayingLine == index) {
        backgroundColor = Colors.blue.withValues(alpha: 0.15);
      } else {
        backgroundColor = null;
      }
    }

    return InkWell(
      onLongPress: () {
        showModalBottomSheet(
          context: context,
          builder: (ctx) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Verse ${index + 1} Options',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    leading: const Icon(Icons.play_arrow),
                    title: const Text('Play from here'),
                    onTap: () {
                      if (widget.chapter.audioLines.isNotEmpty &&
                          index < widget.chapter.audioLines.length) {
                        _seekToLine(index);
                      }
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.repeat),
                    title: const Text('Loop this verse'),
                    onTap: () {
                      // Using PlayFromPositionEvent ensures playback starts AND loop is applied
                      // atomically, avoiding race conditions if player was stopped.
                      final startTime = Duration(
                        milliseconds:
                            (widget.chapter.audioLines[index].start * 1000)
                                .toInt(),
                      );

                      context.read<PlayerBloc>().add(
                        PlayFromPositionEvent(
                          bookName: widget.bookId,
                          chapter: widget.chapter,
                          position: startTime,
                          loopStartLine: index,
                          loopEndLine: index,
                          startChapterId: widget.chapter.id.toString(),
                          endChapterId: widget.chapter.id.toString(),
                          playlist: widget.allChapters,
                        ),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.linear_scale),
                    title: const Text('Loop starting here...'),
                    onTap: () {
                      Navigator.pop(ctx);
                      // Pre-fill start, ask for end
                      _showCustomRangePickerInitial(index);
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.repeat, color: Colors.red),
                    title: const Text(
                      'Stop Loop',
                      style: TextStyle(color: Colors.red),
                    ),
                    onTap: () {
                      context.read<PlayerBloc>().add(
                        const SetLoopModeEvent(loopMode: LoopMode.off),
                      );
                      Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
      onTap: widget.isTestingMode
          ? () => _startListeningForLine(index)
          : (widget.chapter.audioLines.isNotEmpty &&
                index < widget.chapter.audioLines.length)
          ? () => _seekToLine(index)
          : null,
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: (widget.isTestingMode && state == LineState.listening)
                  ? Border.all(color: Colors.blue, width: 2)
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Arabic Text with Blur Effect in Testing Mode
                Builder(
                  builder: (context) {
                    final bool isArabicHidden =
                        widget.isTestingMode &&
                        state != LineState.correct &&
                        state != LineState.failed;

                    Widget arabicTextWidget = Text(
                      arabicLine,
                      style: TextStyle(
                        fontSize: themeState.arabicFontSize,
                        fontFamily: 'Arabic',
                        color: textColor,
                      ),
                      textAlign: TextAlign.right,
                      textDirection: TextDirection.rtl,
                    );

                    if (isArabicHidden) {
                      return ImageFiltered(
                        imageFilter: ui.ImageFilter.blur(
                          sigmaX: 10,
                          sigmaY: 10,
                        ),
                        child: arabicTextWidget,
                      );
                    }
                    return arabicTextWidget;
                  },
                ),
                if (widget.isEnglishVisible && englishLine.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    englishLine,
                    style: TextStyle(
                      fontSize: themeState.englishFontSize,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.grey[400]
                          : Colors.grey[600],
                    ),
                    textAlign: TextAlign.right,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _showLoopMenu() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Loop Mode',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.repeat, color: Colors.grey),
                title: const Text('Loop Off'),
                onTap: () {
                  context.read<PlayerBloc>().add(
                    const SetLoopModeEvent(loopMode: LoopMode.off),
                  );
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.repeat_one),
                title: const Text('Loop Chapter'),
                onTap: () {
                  context.read<PlayerBloc>().add(
                    const SetLoopModeEvent(loopMode: LoopMode.chapter),
                  );
                  Navigator.pop(ctx);
                },
              ),
              if (_currentPlayingLine != null &&
                  _currentPlayingLine! < widget.chapter.audioLines.length)
                ListTile(
                  leading: const Icon(Icons.graphic_eq),
                  title: Text(
                    'Loop Current Verse (${_currentPlayingLine! + 1})',
                  ),
                  onTap: () {
                    context.read<PlayerBloc>().add(
                      SetLoopRangeEvent(
                        startLine: _currentPlayingLine!,
                        endLine: _currentPlayingLine!,
                        playlist: widget.allChapters,
                      ),
                    );
                    // SetLoopRange sets mode to Range
                    Navigator.pop(ctx);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.linear_scale),
                title: const Text('Custom Range'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showCustomRangePicker();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showCustomRangePicker() {
    // Simple dialog for picking start/end line
    int start = 0;
    int end = widget.chapter.audioLines.length - 1;

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Select Loop Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter Verse Numbers (1-${widget.chapter.audioLines.length})',
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Start Verse'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 0) start = val - 1;
                },
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'End Verse'),
                keyboardType: TextInputType.number,
                onChanged: (v) {
                  final val = int.tryParse(v);
                  if (val != null && val > 0) end = val - 1;
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            ElevatedButton(
              child: const Text('Loop'),
              onPressed: () {
                if (start <= end &&
                    start >= 0 &&
                    end < widget.chapter.audioLines.length) {
                  context.read<PlayerBloc>().add(
                    SetLoopRangeEvent(
                      startLine: start,
                      endLine: end,
                      playlist: widget.allChapters,
                    ),
                  );
                }
                Navigator.pop(ctx);
              },
            ),
          ],
        );
      },
    );
  }

  void _showCustomRangePickerInitial(int initialStart) {
    int startLine = initialStart;
    Chapter startChapter = widget.chapter;

    // Default End to current chapter end
    Chapter endChapter = widget.chapter;
    int endLine = widget.chapter.audioLines.length - 1;

    // Controller for the wheel
    final FixedExtentScrollController scrollController =
        FixedExtentScrollController(initialItem: endLine);

    // Filter valid chapters (starting from current one onwards)
    final validChapters = widget.allChapters.isNotEmpty
        ? widget.allChapters.skipWhile((c) => c.id != startChapter.id).toList()
        : [widget.chapter];

    showDialog(
      context: context,
      builder: (ctx) {
        // Use StatefulBuilder to handle dropdown state updates within Dialog
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Select Loop Range'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Start: ${startChapter.name} - Verse ${startLine + 1}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    const Text('End Position:'),
                    if (widget.allChapters.isNotEmpty)
                      DropdownButton<Chapter>(
                        isExpanded: true,
                        value: validChapters.contains(endChapter)
                            ? endChapter
                            : validChapters.first,
                        items: validChapters.map((c) {
                          return DropdownMenuItem(
                            value: c,
                            child: Text(
                              c.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              endChapter = val;
                              // Reset end line to end of new chapter or default 0?
                              // Usually 0 or last. Let's default to last line for convenience?
                              // Or 1st line? Let's default to 1st line to force user to scroll?
                              // Or last line as requested implies "loop until here".
                              // If I switch chapter, I probably want to loop a chunk.
                              // Let's reset to 0 (verse 1) to be safe, easier to scroll down.
                              endLine = 0;
                              scrollController.jumpToItem(0);
                            });
                          }
                        },
                      ),

                    // Helper to display current selection visual
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'End Verse: ${endLine + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(
                      height: 150,
                      child: ListWheelScrollView.useDelegate(
                        controller: scrollController,
                        itemExtent: 40,
                        physics: const FixedExtentScrollPhysics(),
                        perspective: 0.005,
                        onSelectedItemChanged: (index) {
                          // No setState needed for variables as we read them at end,
                          // BUT if we want to update the "End Verse: X" text above, we need setState.
                          // The onChanged callback is outside build, so we can call setState.
                          setState(() {
                            endLine = index;
                          });
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (context, index) {
                            final isSelected = index == endLine;
                            final theme = Theme.of(context);
                            final colorScheme = theme.colorScheme;
                            final isDark = theme.brightness == Brightness.dark;

                            // Explicit fallback: White for Dark Mode, Black for Light Mode
                            final unselectedColor = isDark
                                ? Colors.white.withValues(alpha: 0.5)
                                : Colors.black.withValues(alpha: 0.5);

                            return Center(
                              child: Text(
                                'Verse ${index + 1}',
                                style: TextStyle(
                                  fontSize: isSelected ? 20 : 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isSelected
                                      ? colorScheme.primary
                                      : unselectedColor,
                                ),
                              ),
                            );
                          },
                          childCount: endChapter.audioLines.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ElevatedButton(
                  child: const Text('Loop'),
                  onPressed: () {
                    // Validate
                    if (endLine >= 0 &&
                        endLine < endChapter.audioLines.length) {
                      // If same chapter, start <= end check
                      if (startChapter.id == endChapter.id &&
                          startLine > endLine) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('End verse must be after start!'),
                          ),
                        );
                        return;
                      }

                      // If loop is set but audio not started, PlayFromPosition ensures it plays correctly.
                      // We dispatch PlayFromPosition first to set the Chapter in state.
                      // Then SetLoopRangeEvent applies the constraints.

                      // Calculate start position
                      final startTime = Duration(
                        milliseconds:
                            (startChapter.audioLines[startLine].start * 1000)
                                .toInt(),
                      );

                      context.read<PlayerBloc>().add(
                        PlayFromPositionEvent(
                          bookName: widget.bookId,
                          chapter: startChapter,
                          position: startTime,
                          loopStartLine: startLine,
                          loopEndLine: endLine,
                          startChapterId: startChapter.id.toString(),
                          endChapterId: endChapter.id.toString(),
                          playlist: widget.allChapters,
                        ),
                      );
                      Navigator.pop(ctx);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invalid End Verse!')),
                      );
                    }
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPlayerControls() {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, playerState) {
        bool isPlaying = false;
        if (playerState.status == PlayerStatus.playing &&
            playerState.chapter?.id == widget.chapter.id) {
          isPlaying = true;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Loop Mode
            IconButton(
              icon: Icon(
                playerState.loopMode == LoopMode.off
                    ? Icons.repeat
                    : playerState.loopMode == LoopMode.chapter
                    ? Icons.repeat_one
                    : Icons.graphic_eq, // Visual indicator for range/line
                color: playerState.loopMode == LoopMode.off
                    ? Colors.grey
                    : Theme.of(context).primaryColor,
              ),
              onPressed: _showLoopMenu, // Updated to show menu
            ),

            // Play/Pause
            IconButton(
              icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
              onPressed: () {
                if (isPlaying) {
                  context.read<PlayerBloc>().add(PauseEvent());
                } else {
                  context.read<PlayerBloc>().add(
                    PlayEvent(
                      bookName: widget.bookId,
                      chapter: widget.chapter,
                      playlist: widget.allChapters,
                    ),
                  );
                }
              },
            ),

            // Speed
            TextButton(
              onPressed: () {
                final speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];
                final currentIndex = speeds.indexOf(playerState.speed);
                final nextIndex = (currentIndex + 1) % speeds.length;
                context.read<PlayerBloc>().add(
                  SetSpeedEvent(speed: speeds[nextIndex]),
                );
              },
              child: Text('${playerState.speed}x'),
            ),
          ],
        );
      },
    );
  }
}
