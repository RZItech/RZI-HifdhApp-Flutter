import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/store_book.dart';
import 'package:rzi_hifdhapp/features/book/data/repositories/book_store_repository_impl.dart';

abstract class BookStoreState extends Equatable {
  const BookStoreState();

  @override
  List<Object?> get props => [];
}

class BookStoreInitial extends BookStoreState {}

class BookStoreLoading extends BookStoreState {}

class BookStoreLoaded extends BookStoreState {
  final List<StoreBook> books;
  const BookStoreLoaded(this.books);

  @override
  List<Object?> get props => [books];
}

class BookStoreError extends BookStoreState {
  final String message;
  const BookStoreError(this.message);

  @override
  List<Object?> get props => [message];
}

class BookStoreDownloading extends BookStoreState {
  final StoreBook book;
  final double progress;
  const BookStoreDownloading(this.book, this.progress);

  @override
  List<Object?> get props => [book, progress];
}

class BookStoreDownloaded extends BookStoreState {
  final StoreBook book;
  const BookStoreDownloaded(this.book);

  @override
  List<Object?> get props => [book];
}

class BookStoreCubit extends Cubit<BookStoreState> {
  final BookStoreRepository repository;

  BookStoreCubit({required this.repository}) : super(BookStoreInitial());

  Future<void> loadBooks() async {
    emit(BookStoreLoading());
    try {
      final books = await repository.getStoreBooks();
      emit(BookStoreLoaded(books));
    } catch (e) {
      emit(BookStoreError(e.toString()));
    }
  }

  Future<void> downloadBook(StoreBook book) async {
    final previousState = state;
    emit(BookStoreDownloading(book, 0.0));
    try {
      await repository.downloadBook(
        book,
        onProgress: (progress) {
          emit(BookStoreDownloading(book, progress));
        },
      );
      emit(BookStoreDownloaded(book));
      // Re-load list or return to loaded state
      if (previousState is BookStoreLoaded) {
        emit(BookStoreLoaded(previousState.books));
      }
    } catch (e) {
      emit(BookStoreError(e.toString()));
    }
  }
}
