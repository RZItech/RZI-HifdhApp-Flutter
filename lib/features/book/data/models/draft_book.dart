import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class DraftChapter {
  String name;
  String arabic;
  String translation;
  String? audioPath;

  DraftChapter({
    this.name = '',
    this.arabic = '',
    this.translation = '',
    this.audioPath,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'arabic': arabic,
    'translation': translation,
    'audioPath': audioPath,
  };

  factory DraftChapter.fromJson(Map<String, dynamic> json) => DraftChapter(
    name: json['name'] ?? '',
    arabic: json['arabic'] ?? '',
    translation: json['translation'] ?? '',
    audioPath: json['audioPath'],
  );
}

class DraftBook {
  final String id;
  String name;
  List<DraftChapter> chapters;
  DateTime lastModified;

  DraftBook({
    required this.id,
    this.name = '',
    this.chapters = const [],
    required this.lastModified,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'chapters': chapters.map((c) => c.toJson()).toList(),
    'lastModified': lastModified.toIso8601String(),
  };

  factory DraftBook.fromJson(Map<String, dynamic> json) => DraftBook(
    id: json['id'],
    name: json['name'] ?? '',
    chapters: (json['chapters'] as List? ?? [])
        .map((c) => DraftChapter.fromJson(c))
        .toList(),
    lastModified: DateTime.parse(json['lastModified']),
  );
}

class DraftService {
  static Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/book_drafts';
  }

  static Future<Directory> get _localDir async {
    final path = await _localPath;
    final dir = Directory(path);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  static Future<void> saveDraft(DraftBook draft) async {
    final dir = await _localDir;
    final file = File('${dir.path}/${draft.id}.json');
    await file.writeAsString(jsonEncode(draft.toJson()));
  }

  static Future<List<DraftBook>> getDrafts() async {
    try {
      final dir = await _localDir;
      final List<FileSystemEntity> files = await dir.list().toList();
      final drafts = <DraftBook>[];

      for (var entity in files) {
        if (entity is File && entity.path.endsWith('.json')) {
          final content = await entity.readAsString();
          drafts.add(DraftBook.fromJson(jsonDecode(content)));
        }
      }

      drafts.sort((a, b) => b.lastModified.compareTo(a.lastModified));
      return drafts;
    } catch (e) {
      return [];
    }
  }

  static Future<void> deleteDraft(String id) async {
    final dir = await _localDir;
    final file = File('${dir.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }
}
