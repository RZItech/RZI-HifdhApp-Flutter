import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/audio_line_range.dart';

class Chapter extends Equatable {
  final int id;
  final String name;
  final String arabicText;
  final String englishText;
  final String audioPath;
  final List<AudioLineRange> audioLines;

  const Chapter({
    required this.id,
    required this.name,
    required this.arabicText,
    required this.englishText,
    required this.audioPath,
    this.audioLines = const [],
  });

  @override
  List<Object?> get props => [
    id,
    name,
    arabicText,
    englishText,
    audioPath,
    audioLines,
  ];
}
