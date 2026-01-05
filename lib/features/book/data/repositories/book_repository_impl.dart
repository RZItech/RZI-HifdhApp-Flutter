import 'package:rzi_hifdhapp/features/book/data/datasources/book_local_data_source_platform.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';

class BookRepositoryImpl implements BookRepository {
  final BookLocalDataSource localDataSource;

  BookRepositoryImpl({required this.localDataSource});

  @override
  Future<List<Book>> getBooks() {
    return localDataSource.getBooks();
  }

  @override
  Future<void> importBook() {
    return localDataSource.importBook();
  }

  @override
  Future<void> deleteBook(Book book) {
    return localDataSource.deleteBook(book.id);
  }
}
