import 'package:rzi_hifdhapp/features/book/data/datasources/book_store_remote_data_source.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/store_book.dart';

abstract class BookStoreRepository {
  Future<List<StoreBook>> getStoreBooks();
  Future<void> downloadBook(StoreBook book, {Function(double)? onProgress});
}

class BookStoreRepositoryImpl implements BookStoreRepository {
  final BookStoreRemoteDataSource remoteDataSource;

  BookStoreRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<StoreBook>> getStoreBooks() {
    return remoteDataSource.getStoreBooks();
  }

  @override
  Future<void> downloadBook(StoreBook book, {Function(double)? onProgress}) {
    return remoteDataSource.downloadBook(book, onProgress: onProgress);
  }
}
