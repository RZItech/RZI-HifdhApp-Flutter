import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/services.dart';
import 'package:rzi_hifdhapp/features/book/data/models/book_model.dart';
import 'package:yaml/yaml.dart';

abstract class BookLocalDataSource {
  Future<List<BookModel>> getBooks();
  Future<void> importBook();
  Future<void> deleteBook(String id);
}

// Web-specific implementation that uses in-memory storage
class BookLocalDataSourceImpl implements BookLocalDataSource {
  static final Map<String, Map<Object?, Object?>> _webBookStorage = {};
  static bool _isInitialized = false;

  @override
  Future<List<BookModel>> getBooks() async {
    if (!_isInitialized) {
      await _loadBundledBook();
      _isInitialized = true;
    }

    final books = <BookModel>[];
    for (var entry in _webBookStorage.entries) {
      final bookName = entry.key;
      final yamlMap = entry.value;
      books.add(BookModel.fromYaml(yamlMap, bookName));
    }
    return books;
  }

  Future<void> _loadBundledBook() async {
    // Load the bundled example.zip from assets
    final byteData = await rootBundle.load('assets/example.zip');
    final bytes = byteData.buffer.asUint8List();

    // Extract the zip
    final archive = ZipDecoder().decodeBytes(bytes);

    // Find and parse data.yml
    for (var file in archive) {
      if (file.isFile && file.name.endsWith('data.yml')) {
        final content = file.content as List<int>;
        final yamlString = utf8.decode(content);
        final yamlDoc = loadYaml(yamlString);
        final yamlMap = Map<Object?, Object?>.from(yamlDoc as Map);
        _webBookStorage['example'] = yamlMap;
        break;
      }
    }
  }

  @override
  Future<void> importBook() async {
    // File picker is not supported on web
    return;
  }

  @override
  Future<void> deleteBook(String id) async {
    _webBookStorage.remove(id);
  }
}
