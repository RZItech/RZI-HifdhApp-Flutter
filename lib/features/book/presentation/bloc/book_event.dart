import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';

abstract class BookEvent extends Equatable {
  const BookEvent();

  @override
  List<Object> get props => [];
}

class LoadBooks extends BookEvent {}

class ImportBookEvent extends BookEvent {}

class DeleteBookEvent extends BookEvent {
  final Book book;

  const DeleteBookEvent(this.book);

  @override
  List<Object> get props => [book];
}
