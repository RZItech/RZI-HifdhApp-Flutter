import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

class Book extends Equatable {
  final String name;
  final List<Chapter> chapters;

  const Book({
    required this.name,
    required this.chapters,
  });

  @override
  List<Object?> get props => [name, chapters];
}
