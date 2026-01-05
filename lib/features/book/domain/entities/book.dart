import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

class Book extends Equatable {
  final String id;
  final String name;
  final List<Chapter> chapters;

  const Book({required this.id, required this.name, required this.chapters});

  @override
  List<Object?> get props => [id, name, chapters];
}
