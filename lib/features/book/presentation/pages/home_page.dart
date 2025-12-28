import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_event.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_state.dart';
import 'package:rzi_hifdhapp/features/book/presentation/pages/book_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.read<BookBloc>().add(ImportBookEvent());
            },
          ),
        ],
      ),
      body: BlocBuilder<BookBloc, BookState>(
        builder: (context, state) {
          if (state is BookLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BookLoaded) {
            if (state.books.isEmpty) {
              return const Center(
                child: Text('No books yet. Press + to import a book.'),
              );
            }
            return ListView.builder(
              itemCount: state.books.length,
              itemBuilder: (context, index) {
                final book = state.books[index];
                return ListTile(
                  title: Text(book.name),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookPage(book: book),
                      ),
                    );
                  },
                );
              },
            );
          } else if (state is BookError) {
            return Center(child: Text(state.message));
          }
          return const Center(
            child: Text('Press + to import a book.'),
          );
        },
      ),
    );
  }
}
