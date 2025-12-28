import 'package:equatable/equatable.dart';

class Chapter extends Equatable {
  final int id;
  final String name;
  final String arabicText;
  final String englishText;
  final String audioPath;

  const Chapter({
    required this.id,
    required this.name,
    required this.arabicText,
    required this.englishText,
    required this.audioPath,
  });

  @override
  List<Object?> get props => [id, name, arabicText, englishText, audioPath];
}
