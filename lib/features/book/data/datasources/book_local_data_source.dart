import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rzi_hifdhapp/features/book/data/models/book_model.dart';
import 'package:yaml/yaml.dart';

abstract class BookLocalDataSource {
  Future<List<BookModel>> getBooks();
  Future<void> importBook();
  Future<void> deleteBook(String id);
}

class BookLocalDataSourceImpl implements BookLocalDataSource {
  @override
  Future<List<BookModel>> getBooks() async {
    final appDir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${appDir.path}/books');

    // On web, if no books exist, auto-load the bundled example book
    if (kIsWeb && !await booksDir.exists()) {
      await _loadBundledBookForWeb();
    }

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

  Future<void> _loadBundledBookForWeb() async {
    try {
      // Load the bundled example.zip from assets
      final byteData = await rootBundle.load('assets/example.zip');
      final bytes = byteData.buffer.asUint8List();

      final appDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${appDir.path}/books');
      if (!await booksDir.exists()) {
        await booksDir.create();
      }

      final bookName = 'example';
      final bookDir = Directory('${booksDir.path}/$bookName');
      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      await bookDir.create();

      final archive = ZipDecoder().decodeBytes(bytes);
      extractArchiveToDisk(archive, bookDir.path);
    } catch (e) {
      // Silently fail if bundled book can't be loaded
      if (kDebugMode) {
        print('Failed to load bundled book: $e');
      }
    }
  }

  @override
  Future<void> importBook() async {
    // On web, file picker is not supported, so we skip this operation
    if (kIsWeb) {
      return;
    }

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

  @override
  Future<void> deleteBook(String id) async {
    final appDir = await getApplicationDocumentsDirectory();
    final bookDir = Directory('${appDir.path}/books/$id');
    if (await bookDir.exists()) {
      await bookDir.delete(recursive: true);
    }
  }
}
