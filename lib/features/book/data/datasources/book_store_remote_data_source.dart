import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:yaml/yaml.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/store_book.dart';

abstract class BookStoreRemoteDataSource {
  Future<List<StoreBook>> getStoreBooks();
  Future<void> downloadBook(StoreBook book, {Function(double)? onProgress});
}

class BookStoreRemoteDataSourceImpl implements BookStoreRemoteDataSource {
  final http.Client client;
  final Talker talker;
  static const String baseUrl =
      'https://raw.githubusercontent.com/RZItech/HifdhApp-Bookstore/main';
  static const String repoUrl = '$baseUrl/repo.yml';

  BookStoreRemoteDataSourceImpl({required this.client, required this.talker});

  @override
  Future<List<StoreBook>> getStoreBooks() async {
    final appDir = await getApplicationDocumentsDirectory();
    final localRepoFile = File('${appDir.path}/repo.yml');

    try {
      // Fetch with timestamp to bust cache
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final response = await client.get(Uri.parse('$repoUrl?t=$timestamp'));

      if (response.statusCode == 200) {
        // Save locally for offline fallback
        await localRepoFile.writeAsString(response.body);
        return _parseYaml(response.body);
      } else {
        talker.error('Failed to load store books: ${response.statusCode}');
      }
    } catch (e, st) {
      talker.handle(e, st, 'Error fetching store books');
      // Fallback to local file if fetch fails
      if (await localRepoFile.exists()) {
        final content = await localRepoFile.readAsString();
        return _parseYaml(content);
      }
    }
    throw Exception('Failed to load store books');
  }

  List<StoreBook> _parseYaml(String content) {
    try {
      final yaml = loadYaml(content);
      final List<StoreBook> books = [];

      final listData = yaml['list'];
      if (listData is List) {
        for (var item in listData) {
          if (item is Map) {
            books.add(_mapToStoreBook(item));
          }
        }
      } else if (listData is Map) {
        // Handle map of ID -> Book
        listData.forEach((key, value) {
          if (value is Map) {
            books.add(_mapToStoreBook(value));
          }
        });
      }

      return books;
    } catch (e, st) {
      talker.handle(e, st, 'Error parsing store yaml');
      return [];
    }
  }

  StoreBook _mapToStoreBook(Map item) {
    return StoreBook(
      name: item['name']?.toString() ?? 'Unknown',
      description: item['description']?.toString() ?? '',
      path: item['path']?.toString() ?? '',
      version: item['version']?.toString() ?? '1.0',
    );
  }

  @override
  Future<void> downloadBook(
    StoreBook book, {
    Function(double)? onProgress,
  }) async {
    try {
      talker.info('Starting download for ${book.name} (${book.id})');
      final appDir = await getApplicationDocumentsDirectory();
      final bookDir = Directory('${appDir.path}/books/${book.id}');

      if (await bookDir.exists()) {
        await bookDir.delete(recursive: true);
      }
      await bookDir.create(recursive: true);

      // 1. Download data.yml
      final dataUrl = '$baseUrl/${book.path}/data.yml';
      final dataResponse = await client.get(Uri.parse(dataUrl));
      if (dataResponse.statusCode != 200) {
        throw Exception(
          'Failed to download data.yml: ${dataResponse.statusCode}',
        );
      }

      final dataFile = File('${bookDir.path}/data.yml');
      await dataFile.writeAsBytes(dataResponse.bodyBytes);

      // 2. Parse data.yml to find audio files
      final yaml = loadYaml(dataResponse.body);
      final audioPaths = <String>[];
      yaml.forEach((key, value) {
        if (key is String && key.startsWith('chapter_') && value is Map) {
          final audioPath = value['audio'];
          if (audioPath != null && audioPath is String && audioPath != 'null') {
            audioPaths.add(audioPath);
          }
        }
      });

      // 3. Download audio files
      int downloadedCount = 0;
      for (final audioPath in audioPaths) {
        final audioUrl = '$baseUrl/${book.path}/$audioPath';
        final audioResponse = await client.get(Uri.parse(audioUrl));
        if (audioResponse.statusCode == 200) {
          final localAudioFile = File('${bookDir.path}/$audioPath');
          await localAudioFile.parent.create(recursive: true);
          await localAudioFile.writeAsBytes(audioResponse.bodyBytes);
        } else {
          talker.warning(
            'Failed to download audio for ${book.name}: $audioUrl',
          );
        }
        downloadedCount++;
        if (onProgress != null) {
          onProgress(downloadedCount / audioPaths.length);
        }
      }
      talker.info('Download complete for ${book.name}');
    } catch (e, st) {
      talker.handle(e, st, 'Error downloading book: ${book.name}');
      rethrow;
    }
  }
}
