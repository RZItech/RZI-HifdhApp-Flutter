import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/core/usecases/usecase.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/get_books.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/import_book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_event.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_state.dart';

class BookBloc extends Bloc<BookEvent, BookState> {
  final GetBooks getBooks;
  final ImportBook importBook;

  BookBloc({
    required this.getBooks,
    required this.importBook,
  }) : super(BookInitial()) {
    on<LoadBooks>((event, emit) async {
      emit(BookLoading());
      try {
        final books = await getBooks(NoParams());
        emit(BookLoaded(books: books));
      } catch (e) {
        emit(BookError(message: e.toString()));
      }
    });

    on<ImportBookEvent>((event, emit) async {
      try {
        await importBook(NoParams());
        add(LoadBooks());
      } catch (e) {
        emit(BookError(message: e.toString()));
      }
    });
  }
}
