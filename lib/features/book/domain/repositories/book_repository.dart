import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';

abstract class BookRepository {
  Future<List<Book>> getBooks();
  Future<void> importBook();
}
