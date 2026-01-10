import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_event.dart';
import 'package:rzi_hifdhapp/features/book/presentation/cubit/book_store_cubit.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/store_book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_state.dart';
import 'package:rzi_hifdhapp/features/book/presentation/pages/book_page.dart';
import 'package:rzi_hifdhapp/features/book/presentation/pages/drafts_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Books'),
        actions: [
          // Only show drafts button on non-web platforms
          if (!kIsWeb)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DraftsPage()),
                );
              },
              tooltip: 'Drafts',
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
                return Dismissible(
                  key: Key(book.id),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.red,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Delete Book'),
                          content: Text(
                            'Are you sure you want to delete "${book.name}"?',
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                  onDismissed: (direction) {
                    context.read<BookBloc>().add(DeleteBookEvent(book));
                  },
                  child: BlocBuilder<BookStoreCubit, BookStoreState>(
                    builder: (context, storeState) {
                      bool hasUpdate = false;
                      if (storeState is BookStoreLoaded) {
                        final storeBook = storeState.books
                            .cast<StoreBook?>()
                            .firstWhere(
                              (sb) => sb?.id == book.id,
                              orElse: () => null,
                            );
                        if (storeBook != null &&
                            storeBook.version != book.version) {
                          hasUpdate = true;
                        }
                      }

                      return ListTile(
                        title: Row(
                          children: [
                            Expanded(child: Text(book.name)),
                            if (hasUpdate)
                              const Tooltip(
                                message: 'Update available',
                                child: Icon(
                                  Icons.system_update_alt,
                                  color: Colors.orange,
                                  size: 18,
                                ),
                              ),
                          ],
                        ),
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
                  ),
                );
              },
            );
          } else if (state is BookError) {
            return Center(child: Text(state.message));
          }
          return const Center(child: Text('Press + to import a book.'));
        },
      ),
    );
  }
}
