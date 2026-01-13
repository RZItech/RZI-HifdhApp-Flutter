import 'package:flutter/material.dart';
import 'package:equatable/equatable.dart';
import 'package:rzi_hifdhapp/features/settings/data/models/theme_mode_preference.dart';

class ThemeState extends Equatable {
  final ThemeMode themeMode;
  final ThemeModePreference preference;
  final double arabicFontSize;
  final double englishFontSize;

  const ThemeState({
    required this.themeMode,
    required this.preference,
    required this.arabicFontSize,
    required this.englishFontSize,
  });

  const ThemeState.initial()
    : themeMode = ThemeMode.system,
      preference = ThemeModePreference.auto,
      arabicFontSize = 28.0,
      englishFontSize = 16.0;

  ThemeState copyWith({
    ThemeMode? themeMode,
    ThemeModePreference? preference,
    double? arabicFontSize,
    double? englishFontSize,
  }) {
    return ThemeState(
      themeMode: themeMode ?? this.themeMode,
      preference: preference ?? this.preference,
      arabicFontSize: arabicFontSize ?? this.arabicFontSize,
      englishFontSize: englishFontSize ?? this.englishFontSize,
    );
  }

  @override
  List<Object?> get props => [
    themeMode,
    preference,
    arabicFontSize,
    englishFontSize,
  ];
}
