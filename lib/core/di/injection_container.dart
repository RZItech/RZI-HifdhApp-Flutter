import 'package:get_it/get_it.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rzi_hifdhapp/core/services/speech_service.dart';
import 'package:rzi_hifdhapp/features/book/data/datasources/book_local_data_source_platform.dart';
import 'package:rzi_hifdhapp/features/book/data/repositories/book_repository_impl.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/get_books.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/import_book.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/delete_book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:http/http.dart' as http;
import 'package:rzi_hifdhapp/features/book/data/datasources/book_store_remote_data_source.dart';
import 'package:rzi_hifdhapp/features/book/data/repositories/book_store_repository_impl.dart';
import 'package:rzi_hifdhapp/features/book/presentation/cubit/book_store_cubit.dart';
import 'package:rzi_hifdhapp/features/player/services/audio_handler.dart';
import 'package:rzi_hifdhapp/features/settings/data/repositories/reminder_repository.dart';

final sl = GetIt.instance;

Future<void> init() async {
  // Services
  final audioHandler = await AudioService.init(
    builder: () => AudioPlayerHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.rzi_hifdhapp.channel.audio',
      androidNotificationChannelName: 'Audio Playback',
      androidNotificationOngoing: true,
    ),
  );
  sl.registerSingleton<AudioHandler>(audioHandler);

  // Blocs
  sl.registerFactory(
    () => BookBloc(getBooks: sl(), importBook: sl(), deleteBook: sl()),
  );
  sl.registerFactory(() => PlayerBloc(audioHandler: sl()));
  sl.registerLazySingleton(() => ThemeCubit(sl()));
  sl.registerFactory(() => BookStoreCubit(repository: sl()));

  // Use cases
  sl.registerLazySingleton(() => GetBooks(sl()));
  sl.registerLazySingleton(() => ImportBook(sl()));
  sl.registerLazySingleton(() => DeleteBook(sl()));

  // Repositories
  sl.registerLazySingleton<BookRepository>(
    () => BookRepositoryImpl(localDataSource: sl()),
  );
  sl.registerLazySingleton<BookStoreRepository>(
    () => BookStoreRepositoryImpl(remoteDataSource: sl()),
  );
  sl.registerLazySingleton(() => ReminderRepository(sl()));

  // Data sources
  sl.registerLazySingleton<BookLocalDataSource>(
    () => BookLocalDataSourceImpl(),
  );
  sl.registerLazySingleton<BookStoreRemoteDataSource>(
    () => BookStoreRemoteDataSourceImpl(client: sl(), talker: sl()),
  );

  // Services
  sl.registerLazySingleton(() => SpeechService());

  // External
  sl.registerLazySingleton(() => http.Client());
  final sharedPreferences = await SharedPreferences.getInstance();
  sl.registerLazySingleton(() => sharedPreferences);
  sl.registerLazySingleton(() => SharedPreferencesAsync());

  // Logging
  sl.registerLazySingleton(() => TalkerFlutter.init());
}
