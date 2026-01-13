import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

class Book extends Equatable {
  final String id;
  final String name;
  final String version;
  final List<Chapter> chapters;
  final Map<String, String> normalizationRules;

  const Book({
    required this.id,
    required this.name,
    required this.version,
    required this.chapters,
    this.normalizationRules = const {},
  });

  @override
  List<Object?> get props => [id, name, version, chapters, normalizationRules];
}
