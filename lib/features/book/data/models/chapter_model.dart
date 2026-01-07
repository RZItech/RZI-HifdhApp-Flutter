import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/audio_line_range.dart';

class ChapterModel extends Chapter {
  const ChapterModel({
    required super.id,
    required super.name,
    required super.arabicText,
    required super.englishText,
    required super.audioPath,
    super.audioLines,
  });

  factory ChapterModel.fromYaml(Map<dynamic, dynamic> yaml, int id) {
    // Parse audio_lines if present
    List<AudioLineRange> audioLines = [];
    if (yaml['audio_lines'] != null) {
      final audioLinesStr = yaml['audio_lines'] as String;
      final lines = audioLinesStr
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();
      audioLines = lines
          .map((line) => AudioLineRange.fromString(line))
          .toList();
    }

    return ChapterModel(
      id: id,
      name: yaml['name'] ?? '',
      arabicText: yaml['arabic'] ?? '',
      englishText: yaml['translation'] ?? '',
      audioPath: yaml['audio'] ?? '',
      audioLines: audioLines,
    );
  }
}
