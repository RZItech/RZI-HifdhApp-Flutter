import 'package:rzi_hifdhapp/features/book/data/models/book_model.dart';

abstract class BookLocalDataSource {
  Future<List<BookModel>> getBooks();
  Future<void> importBook();
  Future<void> deleteBook(String id);
}

class BookLocalDataSourceImpl implements BookLocalDataSource {
  @override
  Future<List<BookModel>> getBooks() async {
    throw UnimplementedError('Platform not supported');
  }

  @override
  Future<void> importBook() async {
    throw UnimplementedError('Platform not supported');
  }

  @override
  Future<void> deleteBook(String id) async {
    throw UnimplementedError('Platform not supported');
  }
}
