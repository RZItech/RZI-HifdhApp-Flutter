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
  final bool isEnglishVisible;
  final bool isTestingMode;

  const ChapterCard({
    super.key,
    required this.bookId,
    required this.chapter,
    required this.isEnglishVisible,
    required this.isTestingMode,
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
      context.read<PlayerBloc>().positionStream.listen((position) {
        if (mounted && widget.chapter.audioLines.isNotEmpty) {
          _updateCurrentPlayingLine(position.inSeconds.toDouble());
        }
      });
    }
  }

  void _updateCurrentPlayingLine(double currentSeconds) {
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

  @override
  void dispose() {
    _speechService.statusNotifier.removeListener(_onStatusChange);
    _speechService.errorNotifier.removeListener(_onError);
    _speechService.recognizedWordsNotifier.removeListener(
      _onRecognizedWordsChange,
    );
    super.dispose();
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

    final normalizedRecognized = TextUtils.normalizeArabic(recognizedText);
    final normalizedTarget = TextUtils.normalizeArabic(targetText);

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

    final normalizedRecognized = TextUtils.normalizeArabic(recognizedText);
    final normalizedTarget = TextUtils.normalizeArabic(targetText);

    sl<Talker>().info(
      'Validating Line $index\nRec: $normalizedRecognized\nTar: $normalizedTarget',
    );

    bool isMatch = normalizedRecognized == normalizedTarget;

    if (isMatch) {
      _handleSuccess(index);
    } else {
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
      if (playerState is PlayerPlaying &&
          playerState.chapter.id == widget.chapter.id) {
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
      if (_currentPlayingLine == index) {
        backgroundColor = Colors.blue.withValues(alpha: 0.15);
      } else {
        backgroundColor = null;
      }
    }

    return InkWell(
      onTap: widget.isTestingMode
          ? () => _startListeningForLine(index)
          : (widget.chapter.audioLines.isNotEmpty &&
                index < widget.chapter.audioLines.length)
          ? () => _seekToLine(index)
          : null,
      child: Container(
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
                    fontSize: 22,
                    fontFamily: 'Arabic',
                    color: textColor,
                  ),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                );

                if (isArabicHidden) {
                  return ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
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
                  fontSize: 14,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.grey[400]
                      : Colors.grey[600],
                ),
                textAlign: TextAlign
                    .right, // English aligned right to match Arabic flow? Or Center?
                // User didn't specify alignment, but usually below arabic implies matching alignment or center.
                // Given standard Quran apps, english usually follows RTL flow visually if block, or LTR if line.
                // Let's try Center for translation or Right to keep flow. Right feels safer for "under line".
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerControls() {
    return BlocBuilder<PlayerBloc, PlayerState>(
      builder: (context, playerState) {
        bool isPlaying = false;
        if (playerState is PlayerPlaying &&
            playerState.chapter.id == widget.chapter.id) {
          isPlaying = true;
        }

        return IconButton(
          icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
          onPressed: () {
            if (isPlaying) {
              context.read<PlayerBloc>().add(PauseEvent());
            } else {
              context.read<PlayerBloc>().add(
                PlayEvent(bookName: widget.bookId, chapter: widget.chapter),
              );
            }
          },
        );
      },
    );
  }
}
