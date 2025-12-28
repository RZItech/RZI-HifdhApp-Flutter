import 'package:rzi_hifdhapp/core/usecases/usecase.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';

class ImportBook implements UseCase<void, NoParams> {
  final BookRepository repository;

  ImportBook(this.repository);

  @override
  Future<void> call(NoParams params) {
    return repository.importBook();
  }
}
