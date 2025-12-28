import 'package:flutter/material.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/widgets/chapter_card.dart';

class BookPage extends StatefulWidget { // Keep as StatefulWidget for now, will revert ChapterCard first
  final Book book;

  const BookPage({super.key, required this.book});

  @override
  State<BookPage> createState() => _BookPageState();
}

class _BookPageState extends State<BookPage> {
  bool _isEnglishVisible = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.book.name),
        actions: [
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
            bookName: widget.book.name,
            chapter: chapter,
            isEnglishVisible: _isEnglishVisible,
          );
        },
      ),
    );
  }
}