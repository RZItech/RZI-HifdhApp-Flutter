import 'package:audioplayers/audioplayers.dart';
import 'package:get_it/get_it.dart';
import 'package:rzi_hifdhapp/core/services/speech_service.dart';
import 'package:rzi_hifdhapp/features/book/data/datasources/book_local_data_source_platform.dart';
import 'package:rzi_hifdhapp/features/book/data/repositories/book_repository_impl.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/get_books.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/import_book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Blocs
  sl.registerFactory(() => BookBloc(getBooks: sl(), importBook: sl()));
  sl.registerFactory(() => PlayerBloc(audioPlayer: sl()));
  sl.registerLazySingleton(() => ThemeCubit(sl()));

  // Use cases
  sl.registerLazySingleton(() => GetBooks(sl()));
  sl.registerLazySingleton(() => ImportBook(sl()));

  // Repositories
  sl.registerLazySingleton<BookRepository>(
    () => BookRepositoryImpl(localDataSource: sl()),
  );

  // Data sources
  sl.registerLazySingleton<BookLocalDataSource>(
    () => BookLocalDataSourceImpl(),
  );

  // Services
  sl.registerLazySingleton(() => SpeechService());

  // External
  sl.registerLazySingleton(() => AudioPlayer());
  sl.registerLazySingleton(() => SharedPreferencesAsync());
}
