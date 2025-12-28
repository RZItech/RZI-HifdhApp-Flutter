import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/chapter.dart';

abstract class PlayerState extends Equatable {
  const PlayerState();

  @override
  List<Object> get props => [];
}

class PlayerInitial extends PlayerState {}

class PlayerPlaying extends PlayerState {
  final Chapter chapter;

  const PlayerPlaying({required this.chapter});

  @override
  List<Object> get props => [chapter];
}

class PlayerPaused extends PlayerState {
  final Chapter chapter;

  const PlayerPaused({required this.chapter});

  @override
  List<Object> get props => [chapter];
}

class PlayerStopped extends PlayerState {}
