import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rzi_hifdhapp/features/book/data/models/book_model.dart';
import 'package:yaml/yaml.dart';

abstract class BookLocalDataSource {
  Future<List<BookModel>> getBooks();
  Future<void> importBook();
}

class BookLocalDataSourceImpl implements BookLocalDataSource {
  @override
  Future<List<BookModel>> getBooks() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');
    if (!await booksDir.exists()) {
      return [];
    }

    final bookDirs = await booksDir.list().toList();
    final books = <BookModel>[];

    for (var bookDir in bookDirs) {
      if (bookDir is Directory) {
        final dataFile = File('${bookDir.path}/data.yml');
        if (await dataFile.exists()) {
          final yamlString = await dataFile.readAsString();
          final yamlMap = loadYaml(yamlString) as Map;
          final bookName = bookDir.path.split('/').last;
          books.add(BookModel.fromYaml(yamlMap, bookName));
        }
      }
    }
    return books;
  }

  @override
  Future<void> importBook() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result != null) {
      final file = File(result.files.single.path!);
      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create();
      }

      final bookName = result.files.single.name.replaceAll('.zip', '');
      final bookDir = Directory('${booksDir.path}/$bookName');
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      await bookDir.create();

      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      extractArchiveToDisk(archive, bookDir.path);
    }
  }
}
