import 'package:flutter/material.dart';
import 'dart:io';
import 'package:just_audio/just_audio.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/audio_line_range.dart';
import 'dart:async'; // For StreamSubscription

final talker = sl<Talker>();

class AudioTimingEditorPage extends StatefulWidget {
  final File audioFile;
  final List lines;
  final List? initialRanges;

  const AudioTimingEditorPage({
    super.key,
    required this.audioFile,
    required this.lines,
    this.initialRanges,
  });

  @override
  State createState() => _AudioTimingEditorPageState();
}

class _AudioTimingEditorPageState extends State<AudioTimingEditorPage> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _scrollController = ScrollController();

  // Timestamps storage (start, end)
  late List<double?> _startTimes;
  late List<double?> _endTimes;

  // Playback State
  ProcessingState _playerState = ProcessingState.idle;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  int _currentLineIndex = 0;

  StreamSubscription? _posSub;
  StreamSubscription? _stateSub;
  StreamSubscription? _durSub;

  bool _isDraggingSlider = false;

  @override
  void initState() {
    super.initState();
    _startTimes = List.filled(widget.lines.length, null);
    _endTimes = List.filled(widget.lines.length, null);

    if (widget.initialRanges != null &&
        widget.initialRanges!.length == widget.lines.length) {
      for (int i = 0; i < widget.lines.length; i++) {
        _startTimes[i] = widget.initialRanges![i].start;
        _endTimes[i] = widget.initialRanges![i].end;
      }
    }

    _setupPlayer();
  }

  void _setupPlayer() async {
    _stateSub = _player.playerStateStream.listen((state) {
      if (mounted) setState(() => _playerState = state.processingState);
    });

    _posSub = _player.positionStream.listen((pos) {
      if (mounted && !_isDraggingSlider) {
        setState(() => _position = pos);
        _updateActiveLine(pos);
      }
    });

    _durSub = _player.durationStream.listen((dur) {
      if (mounted && dur != null) setState(() => _duration = dur);
    });

    if (!widget.audioFile.existsSync()) {
      talker.warning('Audio file does not exist: ${widget.audioFile.path}');
    } else {
      talker.debug('Audio file exists: ${widget.audioFile.path}');
      try {
        await _player.setAudioSource(AudioSource.file(widget.audioFile.path));
      } catch (e) {
        talker.error('Error setting player source: $e');
      }
    }
  }

  void _updateActiveLine(Duration pos) {
    if (_playerState != ProcessingState.ready) return;

    // In record mode, we don't auto-jump based on time unless we are just "previewing".
    // But implementation logic is:
    // If playing, facilitate "Next Line" action.
    // If just listening, maybe highlight based on existing ranges?
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _durSub?.cancel();
    _player.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _togglePlay() async {
    if (_player.playing) {
      await _player.pause();
    } else {
      if (_playerState == ProcessingState.completed) {
        await _player.seek(Duration.zero);
      }
      await _player.play();
    }
  }

  void _markNextLine() {
    final nowSeconds = _position.inMilliseconds / 1000.0;

    setState(() {
      // End previous line if exists
      if (_currentLineIndex > 0 &&
          _currentLineIndex - 1 < widget.lines.length) {
        _endTimes[_currentLineIndex - 1] = nowSeconds;
      }

      // Start current line
      if (_currentLineIndex < widget.lines.length) {
        _startTimes[_currentLineIndex] = nowSeconds;
        // Optionally clear end time
        _endTimes[_currentLineIndex] = null;
      }

      // Advance
      if (_currentLineIndex < widget.lines.length) {
        _currentLineIndex++;

        // Auto-scroll
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _currentLineIndex * 60.0, // approx height
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else {
        // End of list, just mark end of last line
        if (_currentLineIndex - 1 < widget.lines.length) {
          _endTimes[_currentLineIndex - 1] = nowSeconds;
        }
        _player.pause();
      }
    });
  }

  void _saveAndExit() {
    // Construct results
    List results = [];
    for (int i = 0; i < widget.lines.length; i++) {
      double start = _startTimes[i] ?? 0.0;
      double end =
          _endTimes[i] ??
          (_startTimes[i] ?? 0.0) + 5.0; // Default 5s if missing end?
      // Or if end is null, assume up to start of next line?
      if (_endTimes[i] == null) {
        if (i + 1 < widget.lines.length && _startTimes[i + 1] != null) {
          end = _startTimes[i + 1]!;
        } else {
          // Last line or no next start, default to duration or start+5
          // Actually if playing stopped, we might have valid last time.
          // Assuming end is just start + small buffer if unspecified.
          end = start + 2.0;
        }
      }
      results.add(AudioLineRange(start: start, end: end));
    }

    Navigator.pop(context, results);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    final ms = (d.inMilliseconds % 1000) ~/ 100;
    return '$m:${s.toString().padLeft(2, '0')}.$ms';
  }

  @override
  Widget build(BuildContext context) {
    // Determine the active line for display
    // If recording, it's _currentLineIndex.
    // If existing types, check timestamp.
    int activeIndex = _currentLineIndex;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync Audio'),
        actions: [
          IconButton(icon: const Icon(Icons.check), onPressed: _saveAndExit),
        ],
      ),
      body: Column(
        children: [
          // Audio Controls
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).cardColor,
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _player.playing ? Icons.pause : Icons.play_arrow,
                      ),
                      onPressed: _togglePlay,
                    ),
                    Expanded(
                      child: Slider(
                        value: _position.inMilliseconds.toDouble().clamp(
                          0,
                          _duration.inMilliseconds.toDouble(),
                        ),
                        max: _duration.inMilliseconds.toDouble(),
                        onChangeStart: (val) {
                          setState(() => _isDraggingSlider = true);
                        },
                        onChanged: (val) {
                          setState(() {
                            _position = Duration(milliseconds: val.toInt());
                          });
                        },
                        onChangeEnd: (val) async {
                          await _player.seek(
                            Duration(milliseconds: val.toInt()),
                          );
                          setState(() => _isDraggingSlider = false);
                        },
                      ),
                    ),
                    Text(_formatDuration(_position)),
                  ],
                ),
              ],
            ),
          ),

          // List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              itemCount: widget.lines.length + 1, // +1 for padding at bottom
              itemBuilder: (context, index) {
                if (index == widget.lines.length) {
                  return const SizedBox(height: 100);
                }

                final isCurrent = index == activeIndex;
                final start = _startTimes[index];
                final end = _endTimes[index];
                final info = start != null
                    ? '${start.toStringAsFixed(1)}s > ${end != null ? end.toStringAsFixed(1) : "..."}s'
                    : 'Not set';

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _player.seek(
                        Duration(milliseconds: ((start ?? 0) * 1000).toInt()),
                      );
                      _currentLineIndex = index;
                    });
                  },
                  child: Container(
                    color: isCurrent
                        ? Theme.of(context).primaryColor.withValues(alpha: 0.1)
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Text(
                          '${index + 1}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.lines[index],
                                style: const TextStyle(fontSize: 16),
                                textDirection: TextDirection.rtl,
                              ),
                              Text(
                                info,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isCurrent)
                          const Icon(Icons.arrow_back, color: Colors.blue),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _markNextLine,
        label: Text(
          _currentLineIndex >= widget.lines.length ? 'Done' : 'Mark Next Line',
        ),
        icon: const Icon(Icons.touch_app),
        backgroundColor: _player.playing ? Colors.redAccent : Colors.grey,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}
