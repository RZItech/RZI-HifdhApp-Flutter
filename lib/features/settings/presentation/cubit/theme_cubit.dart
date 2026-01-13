import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rzi_hifdhapp/features/settings/data/models/theme_mode_preference.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_state.dart';

class ThemeCubit extends Cubit<ThemeState> {
  static const String _themePreferenceKey = 'theme_preference';
  static const String _arabicFontSizeKey = 'arabic_font_size';
  static const String _englishFontSizeKey = 'english_font_size';
  final SharedPreferencesAsync _prefs;

  ThemeCubit(this._prefs) : super(const ThemeState.initial()) {
    _loadThemePreference();
  }

  Future<void> _loadThemePreference() async {
    try {
      final preferenceString = await _prefs.getString(_themePreferenceKey);
      final arabicSize = await _prefs.getDouble(_arabicFontSizeKey);
      final englishSize = await _prefs.getDouble(_englishFontSizeKey);

      final preference = preferenceString != null
          ? ThemeModePreferenceExtension.fromJson(preferenceString)
          : ThemeModePreference.auto;

      _applyPreference(preference, arabicSize, englishSize);
    } catch (e) {
      emit(const ThemeState.initial());
    }
  }

  Future<void> setThemePreference(ThemeModePreference preference) async {
    await _prefs.setString(_themePreferenceKey, preference.toJson());
    _applyPreference(preference, state.arabicFontSize, state.englishFontSize);
  }

  Future<void> setArabicFontSize(double size) async {
    await _prefs.setDouble(_arabicFontSizeKey, size);
    emit(state.copyWith(arabicFontSize: size));
  }

  Future<void> setEnglishFontSize(double size) async {
    await _prefs.setDouble(_englishFontSizeKey, size);
    emit(state.copyWith(englishFontSize: size));
  }

  void _applyPreference(
    ThemeModePreference preference,
    double? arabicSize,
    double? englishSize,
  ) {
    ThemeMode themeMode;

    switch (preference) {
      case ThemeModePreference.light:
        themeMode = ThemeMode.light;
        break;
      case ThemeModePreference.dark:
        themeMode = ThemeMode.dark;
        break;
      case ThemeModePreference.auto:
        themeMode = ThemeMode.system;
        break;
    }

    emit(
      ThemeState(
        themeMode: themeMode,
        preference: preference,
        arabicFontSize: arabicSize ?? 24.0,
        englishFontSize: englishSize ?? 14.0,
      ),
    );
  }
}
