import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/data/models/chapter_model.dart';

class BookModel extends Book {
  const BookModel({
    required super.id,
    required super.name,
    required super.version,
    required super.chapters,
    required super.normalizationRules,
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

    final Map<String, String> normalizationRules = {};
    final normalizeValue = yaml['normalize'];
    if (normalizeValue is String) {
      final lines = normalizeValue.split('\n');
      for (var line in lines) {
        if (line.contains('>')) {
          final parts = line.split('>');
          if (parts.length == 2) {
            final from = parts[0].trim();
            final to = parts[1].trim();
            if (from.isNotEmpty && to.isNotEmpty) {
              normalizationRules[from] = to;
            }
          }
        }
      }
    }

    return BookModel(
      id: bookName,
      name: yaml['name'] ?? bookName,
      version: (yaml['version'] ?? '1.0').toString(),
      chapters: chapters,
      normalizationRules: normalizationRules,
    );
  }
}
