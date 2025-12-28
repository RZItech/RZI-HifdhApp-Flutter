import 'package:rzi_hifdhapp/core/usecases/usecase.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';

class GetBooks implements UseCase<List<Book>, NoParams> {
  final BookRepository repository;

  GetBooks(this.repository);

  @override
  Future<List<Book>> call(NoParams params) {
    return repository.getBooks();
  }
}
