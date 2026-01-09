import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rzi_hifdhapp/features/settings/domain/entities/reminder_settings.dart';

class ReminderRepository {
  final SharedPreferences _prefs;
  static const String _key = 'reminder_settings_list';

  ReminderRepository(this._prefs);

  List<ReminderSettings> loadSettings() {
    final jsonString = _prefs.getString(_key);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => ReminderSettings.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveSettings(ReminderSettings settings) async {
    final list = loadSettings();
    final index = list.indexWhere((s) => s.bookId == settings.bookId);

    if (index != -1) {
      list[index] = settings;
    } else {
      list.add(settings);
    }

    await _saveList(list);
  }

  Future<void> _saveList(List<ReminderSettings> list) async {
    final jsonList = list.map((s) => s.toJson()).toList();
    await _prefs.setString(_key, jsonEncode(jsonList));
  }

  ReminderSettings getSettingsForBook(String bookId) {
    return loadSettings().firstWhere(
      (s) => s.bookId == bookId,
      orElse: () => ReminderSettings(bookId: bookId),
    );
  }
}
