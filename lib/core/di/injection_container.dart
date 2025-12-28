import 'package:audioplayers/audioplayers.dart';
import 'package:get_it/get_it.dart';
import 'package:rzi_hifdhapp/core/services/speech_recognition_service.dart'; // Added
import 'package:rzi_hifdhapp/features/book/data/datasources/book_local_data_source.dart';
import 'package:rzi_hifdhapp/features/book/data/repositories/book_repository_impl.dart';
import 'package:rzi_hifdhapp/features/book/domain/repositories/book_repository.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/get_books.dart';
import 'package:rzi_hifdhapp/features/book/domain/usecases/import_book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/test/presentation/bloc/test_bloc.dart'; // Added
import 'package:flutter/widgets.dart'; // Added for WidgetsFlutterBinding

final sl = GetIt.instance;

Future<void> init() async {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure Flutter binding is initialized
  // Blocs
  sl.registerFactory(() => BookBloc(getBooks: sl(), importBook: sl()));
  sl.registerFactory(() => PlayerBloc(audioPlayer: sl()));
  sl.registerFactory(() => TestBloc(speechRecognitionService: sl())); // Added

  // Use cases
  sl.registerLazySingleton(() => GetBooks(sl()));
  sl.registerLazySingleton(() => ImportBook(sl()));

  // Repositories
  sl.registerLazySingleton<BookRepository>(
      () => BookRepositoryImpl(localDataSource: sl()));

  // Data sources
  sl.registerLazySingleton<BookLocalDataSource>(
      () => BookLocalDataSourceImpl());

  // Services
  sl.registerLazySingleton<SpeechRecognitionService>(
      () => VoskSpeechRecognitionService()); // Changed from SherpaOnnxSpeechRecognitionService

  // External
  sl.registerLazySingleton(() => AudioPlayer());

  // Initialize the speech recognition service after registration
  await sl<SpeechRecognitionService>().initialize(); // Added
}
