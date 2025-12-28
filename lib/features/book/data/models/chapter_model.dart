import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

class ChapterModel extends Chapter {
  const ChapterModel({
    required super.id,
    required super.name,
    required super.arabicText,
    required super.englishText,
    required super.audioPath,
  });

  factory ChapterModel.fromYaml(Map<dynamic, dynamic> yaml, int id) {
    return ChapterModel(
      id: id,
      name: yaml['name'] ?? '',
      arabicText: yaml['arabic'] ?? '',
      englishText: yaml['translation'] ?? '',
      audioPath: yaml['audio'] ?? '',
    );
  }
}
