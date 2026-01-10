import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_event.dart';
import 'package:rzi_hifdhapp/features/book/presentation/pages/main_screen.dart';
import 'package:rzi_hifdhapp/features/book/presentation/cubit/book_store_cubit.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_state.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart' as di;

import 'package:flutter/foundation.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:talker_bloc_logger/talker_bloc_logger.dart';
import 'package:rzi_hifdhapp/core/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  await NotificationService().init(); // Initialize notifications

  final talker = di.sl<Talker>();
  Bloc.observer = TalkerBlocObserver(talker: talker);

  FlutterError.onError = (details) =>
      talker.handle(details.exception, details.stack);
  PlatformDispatcher.instance.onError = (error, stack) {
    talker.handle(error, stack);
    return true;
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => di.sl<BookBloc>()..add(LoadBooks())),
        BlocProvider(create: (_) => di.sl<PlayerBloc>()),
        BlocProvider(create: (_) => di.sl<ThemeCubit>()),
        BlocProvider(create: (_) => di.sl<BookStoreCubit>()..loadBooks()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeState>(
        builder: (context, themeState) {
          return MaterialApp(
            title: 'Hifdh App',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.light,
              ),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
            themeMode: themeState.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
