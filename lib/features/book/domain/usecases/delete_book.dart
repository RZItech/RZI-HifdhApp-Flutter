import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/core/usecases/usecase.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';

class DeleteBook implements UseCase<void, DeleteBookParams> {
  final BookRepository repository;

  DeleteBook(this.repository);

  @override
  Future<void> call(DeleteBookParams params) {
    return repository.deleteBook(params.book);
  }
}

class DeleteBookParams extends Equatable {
  final Book book;

  const DeleteBookParams({required this.book});

  @override
  List<Object> get props => [book];
}
