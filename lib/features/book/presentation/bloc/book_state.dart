import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';

abstract class BookState extends Equatable {
  const BookState();

  @override
  List<Object> get props => [];
}

class BookInitial extends BookState {}

class BookLoading extends BookState {}

class BookLoaded extends BookState {
  final List<Book> books;

  const BookLoaded({required this.books});

  @override
  List<Object> get props => [books];
}

class BookError extends BookState {
  final String message;

  const BookError({required this.message});

  @override
  List<Object> get props => [message];
}
