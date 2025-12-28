import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_event.dart';
import 'package:rzi_hifdhapp/features/book/presentation/pages/home_page.dart';
import 'package:rzi_hifdhapp/features/player/presentation/bloc/player_bloc.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart' as di;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await di.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => di.sl<BookBloc>()..add(LoadBooks()),
        ),
        BlocProvider(
          create: (_) => di.sl<PlayerBloc>(),
        ),
      ],
      child: MaterialApp(
        title: 'Hifdh App',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const HomePage(),
      ),
    );
  }
}
