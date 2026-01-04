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

class ChapterCard extends StatefulWidget {
  final String bookName;
  final Chapter chapter;
  final bool isEnglishVisible;
  final bool isTestingMode;

  const ChapterCard({
    super.key,
    required this.bookName,
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
  int _incorrectAttempts = 0;
  bool _isCorrect = false;
  bool _showFailedWord = false;
  String _partiallyRecognizedText = '';
  Color? _cardColor;

  @override
  void initState() {
    super.initState();
    _speechService.initSpeech();
    _speechService.statusNotifier.addListener(_onStatusChange);
    _speechService.errorNotifier.addListener(_onError);
    _speechService.recognizedWordsNotifier.addListener(
      _onRecognizedWordsChange,
    );
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
      setState(() {
        _partiallyRecognizedText = _speechService.recognizedWordsNotifier.value;
      });
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
      _validateSpeech();
    }
  }

  void _onError() {
    final error = _speechService.errorNotifier.value;
    if (error != null) {
      sl<Talker>().error("Speech recognition error: ${error.errorMsg}");
    }
  }

  void _startListening() async {
    await _speechService.requestPermission();
    setState(() {
      _isRecording = true;
    });
    _speechService.startListening();
  }

  void _stopListening() {
    _speechService.stopListening();
  }

  void _validateSpeech() {
    final recognizedText = _speechService.recognizedWordsNotifier.value;
    final normalizedRecognized = TextUtils.normalizeArabic(recognizedText);
    final normalizedTarget = TextUtils.normalizeArabic(
      widget.chapter.arabicText,
    );

    if (normalizedRecognized == normalizedTarget) {
      sl<Talker>().info('Speech validation success');
      setState(() {
        _isCorrect = true;
        _cardColor = Colors.green;
      });
    } else {
      sl<Talker>().error(
        'Speech validation failed.\n'
        'Raw Recognized: "$recognizedText"\n'
        'Normalized Recognized: "$normalizedRecognized"\n'
        'Normalized Target: "$normalizedTarget"\n'
        'Difference index: ${_findFirstDifference(normalizedRecognized, normalizedTarget)}',
      );
      setState(() {
        _incorrectAttempts++;
        if (_incorrectAttempts >= 3) {
          _cardColor = Colors.red;
          _showFailedWord = true;
        } else {
          _flashCardRed();
        }
      });
    }
  }

  void _flashCardRed() {
    setState(() {
      _cardColor = Colors.red;
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _cardColor = null;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      color: _cardColor,
      margin: const EdgeInsets.all(8.0),
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
                Expanded(child: _buildArabicText()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.isTestingMode)
                  IconButton(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    onPressed: _isRecording ? _stopListening : _startListening,
                  ),
                if (!widget.isTestingMode)
                  BlocBuilder<PlayerBloc, PlayerState>(
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
                              PlayEvent(
                                bookName: widget.bookName,
                                chapter: widget.chapter,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArabicText() {
    const baseStyle = TextStyle(fontSize: 20, fontFamily: 'Arabic');
    if (!widget.isTestingMode) {
      return Text(
        widget.chapter.arabicText,
        style: baseStyle,
        textAlign: TextAlign.right,
      );
    }

    if (_isCorrect) {
      return Text(
        widget.chapter.arabicText,
        style: baseStyle.copyWith(color: Colors.green),
        textAlign: TextAlign.right,
      );
    }

    if (_showFailedWord) {
      return Text(
        widget.chapter.arabicText,
        style: baseStyle.copyWith(color: Colors.red),
        textAlign: TextAlign.right,
      );
    }

    if (_isRecording || _partiallyRecognizedText.isNotEmpty) {
      final targetWords = widget.chapter.arabicText.split(' ');
      final recognizedWords = _partiallyRecognizedText.split(' ');
      final List<TextSpan> spans = [];
      bool mismatchFound = false;

      for (int i = 0; i < targetWords.length; i++) {
        String targetWord = targetWords[i];
        TextSpan currentSpan;

        if (!mismatchFound && i < recognizedWords.length) {
          String recognizedWord = recognizedWords[i];
          if (TextUtils.normalizeArabic(targetWord) ==
              TextUtils.normalizeArabic(recognizedWord)) {
            currentSpan = TextSpan(
              text: '$targetWord ',
              style: baseStyle.copyWith(color: Colors.green),
            );
          } else {
            mismatchFound = true;
            currentSpan = TextSpan(
              text: '$targetWord ',
              style: baseStyle.copyWith(color: Colors.grey),
            );
          }
        } else {
          mismatchFound = true;
          currentSpan = TextSpan(
            text: '$targetWord ',
            style: baseStyle.copyWith(color: Colors.grey),
          );
        }
        spans.add(currentSpan);
      }

      return RichText(
        text: TextSpan(children: spans, style: baseStyle),
        textAlign: TextAlign.right,
      );
    }

    return Container(color: Colors.grey[300], height: 20);
  }

  int _findFirstDifference(String s1, String s2) {
    for (int i = 0; i < s1.length && i < s2.length; i++) {
      if (s1[i] != s2[i]) return i;
    }
    return s1.length < s2.length ? s1.length : s2.length;
  }
}
