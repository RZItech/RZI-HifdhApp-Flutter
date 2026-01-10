import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/cubit/book_store_cubit.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_state.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_event.dart';

class BookStorePage extends StatelessWidget {
  const BookStorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Store'),
        actions: [
          IconButton(
            icon: const Icon(Icons.folder_open),
            onPressed: () {
              context.read<BookBloc>().add(ImportBookEvent());
            },
            tooltip: 'Import Local ZIP',
          ),
        ],
      ),
      body: BlocConsumer<BookStoreCubit, BookStoreState>(
        listener: (context, state) {
          if (state is BookStoreDownloaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${state.book.name} installed')),
            );
            context.read<BookBloc>().add(LoadBooks());
          } else if (state is BookStoreError) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('Error: ${state.message}')));
          }
        },
        builder: (context, state) {
          if (state is BookStoreLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is BookStoreLoaded ||
              state is BookStoreDownloading ||
              state is BookStoreDownloaded) {
            // Re-fetch books if we are in downloading/downloaded to keep list visible
            // In a real app we'd keep the list in the state.

            if (state is BookStoreDownloading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Downloading ${state.book.name}...'),
                    const SizedBox(height: 16),
                    CircularProgressIndicator(value: state.progress),
                    const SizedBox(height: 8),
                    Text('${(state.progress * 100).toStringAsFixed(0)}%'),
                  ],
                ),
              );
            }

            if (state is BookStoreLoaded) {
              if (state.books.isEmpty) {
                return const Center(
                  child: Text('No books available in the store.'),
                );
              }
              return BlocBuilder<BookBloc, BookState>(
                builder: (context, bookState) {
                  final installedBooks = (bookState is BookLoaded)
                      ? bookState.books
                      : <Book>[];

                  return RefreshIndicator(
                    onRefresh: () => context.read<BookStoreCubit>().loadBooks(),
                    child: ListView.builder(
                      itemCount: state.books.length,
                      itemBuilder: (context, index) {
                        final book = state.books[index];
                        final installedBook = installedBooks
                            .cast<Book?>()
                            .firstWhere(
                              (b) => b?.id == book.id,
                              orElse: () => null,
                            );

                        bool needsUpdate = false;
                        if (installedBook != null) {
                          // Simple version comparison: if store version is different from installed, assume update
                          // (User specifically said "if there is an update", usually means store > local)
                          needsUpdate = book.version != installedBook.version;
                        }

                        return Card(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: ListTile(
                            title: Text(book.name),
                            subtitle: Text(
                              '${book.description}\nVersion: ${book.version}',
                            ),
                            isThreeLine: true,
                            trailing: installedBook == null
                                ? ElevatedButton(
                                    onPressed: () {
                                      context
                                          .read<BookStoreCubit>()
                                          .downloadBook(book);
                                    },
                                    child: const Text('Install'),
                                  )
                                : needsUpdate
                                ? ElevatedButton(
                                    onPressed: () {
                                      context
                                          .read<BookStoreCubit>()
                                          .downloadBook(book);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                    child: const Text('Update'),
                                  )
                                : const OutlinedButton(
                                    onPressed: null,
                                    child: Text('Installed'),
                                  ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            }
          } else if (state is BookStoreError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error: ${state.message}'),
                  ElevatedButton(
                    onPressed: () => context.read<BookStoreCubit>().loadBooks(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }
          return const Center(child: Text('Failed to load store.'));
        },
      ),
    );
  }
}
