import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/data/models/chapter_model.dart';

class BookModel extends Book {
  const BookModel({
    required super.id,
    required super.name,
    required super.chapters,
  });

  factory BookModel.fromYaml(Map<dynamic, dynamic> yaml, String bookName) {
    final chapters = <ChapterModel>[];
    yaml.forEach((key, value) {
      if (key is String && key.startsWith('chapter_')) {
        final id = int.tryParse(key.substring(8));
        if (id != null && value is Map) {
          chapters.add(ChapterModel.fromYaml(value, id));
        }
      }
    });
    chapters.sort((a, b) => a.id.compareTo(b.id));

    return BookModel(
      id: bookName,
      name: yaml['name'] ?? bookName,
      chapters: chapters,
    );
  }
}
