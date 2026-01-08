import 'package:flutter/material.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';
import 'package:rzi_hifdhapp/core/services/speech_service.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/widgets/chapter_card.dart';

class BookPage extends StatefulWidget {
  final Book book;

  const BookPage({super.key, required this.book});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  final SpeechService _speechService = sl<SpeechService>();
  bool _isEnglishVisible = true;
  bool _isTestingMode = false;
  String _recognizedWords = '';

  @override
  void initState() {
    super.initState();
    _speechService.recognizedWordsNotifier.addListener(
      _onRecognizedWordsChange,
    );
  }

  @override
  void dispose() {
    _speechService.recognizedWordsNotifier.removeListener(
      _onRecognizedWordsChange,
    );
    super.dispose();
  }

  void _onRecognizedWordsChange() {
    if (mounted) {
      setState(() {
        _recognizedWords = _speechService.recognizedWordsNotifier.value;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            onPressed: () {
              setState(() {
                _isTestingMode = !_isTestingMode;
              });
            },
          ),
          IconButton(
            icon: Icon(
              _isEnglishVisible ? Icons.visibility_off : Icons.visibility,
            ),
            onPressed: () {
              setState(() {
                _isEnglishVisible = !_isEnglishVisible;
              });
            },
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: widget.book.chapters.length,
        itemBuilder: (context, index) {
          final chapter = widget.book.chapters[index];
          return ChapterCard(
            bookId: widget.book.id,
            chapter: chapter,
            allChapters: widget.book.chapters,
            isEnglishVisible: _isEnglishVisible,
            isTestingMode: _isTestingMode,
          );
        },
      ),
      bottomNavigationBar: _isTestingMode
          ? BottomAppBar(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  _recognizedWords,
                  style: const TextStyle(fontSize: 18),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : null,
    );
  }
}
