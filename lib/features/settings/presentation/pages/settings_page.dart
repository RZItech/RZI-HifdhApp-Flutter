import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/settings/data/models/theme_mode_preference.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_state.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/pages/book_reminders_page.dart';
import 'package:rzi_hifdhapp/features/book/presentation/cubit/book_store_cubit.dart';
import 'package:talker_flutter/talker_flutter.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart' as di;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'General',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: ListTile(
              title: const Text('Book Reminders'),
              subtitle: const Text('Schedule periodic reminders to learn'),
              leading: const Icon(Icons.notifications_active),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => const BookRemindersPage(),
                  ),
                );
              },
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Appearance',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Theme',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: [
                          _ThemeOption(
                            title: 'Light',
                            subtitle: 'Use light theme',
                            value: ThemeModePreference.light,
                            groupValue: state.preference,
                            onChanged: (val) => context
                                .read<ThemeCubit>()
                                .setThemePreference(val!),
                          ),
                          _ThemeOption(
                            title: 'Dark',
                            subtitle: 'Use dark theme',
                            value: ThemeModePreference.dark,
                            groupValue: state.preference,
                            onChanged: (val) => context
                                .read<ThemeCubit>()
                                .setThemePreference(val!),
                          ),
                          _ThemeOption(
                            title: 'Auto',
                            subtitle: 'Follow system theme',
                            value: ThemeModePreference.auto,
                            groupValue: state.preference,
                            onChanged: (val) => context
                                .read<ThemeCubit>()
                                .setThemePreference(val!),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Typography',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          BlocBuilder<ThemeCubit, ThemeState>(
            builder: (context, state) {
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _FontSizeSlider(
                        label: 'Arabic Font Size',
                        value: state.arabicFontSize,
                        min: 16,
                        max: 64,
                        division: 2,
                        onChanged: (val) =>
                            context.read<ThemeCubit>().setArabicFontSize(val),
                        previewText: 'علي نبيه ومصطفاه',
                        isArabic: true,
                      ),
                      const Divider(),
                      _FontSizeSlider(
                        label: 'English Font Size',
                        value: state.englishFontSize,
                        min: 12,
                        max: 32,
                        division: 2,
                        onChanged: (val) =>
                            context.read<ThemeCubit>().setEnglishFontSize(val),
                        previewText: 'On His Prophet and His Chosen One',
                        isArabic: false,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Debug',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                ListTile(
                  title: const Text('Open Logs'),
                  leading: const Icon(Icons.monitor_heart),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) =>
                            TalkerScreen(talker: di.sl<Talker>()),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  title: const Text('Refresh Book Store'),
                  leading: const Icon(Icons.refresh),
                  onTap: () {
                    context.read<BookStoreCubit>().loadBooks();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Book store refreshed')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final ThemeModePreference value;
  final ThemeModePreference groupValue;
  final ValueChanged<ThemeModePreference?> onChanged;

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeModePreference>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
    );
  }
}

class _FontSizeSlider extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final String previewText;
  final int division;
  final bool isArabic;

  const _FontSizeSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.previewText,
    required this.division,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            Text('${value.toInt()} px'),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: (max - min).toInt(),
          onChanged: onChanged,
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            previewText,
            textAlign: isArabic ? TextAlign.right : TextAlign.left,
            style: TextStyle(
              fontSize: value,
              fontFamily: isArabic ? 'Traditional Arabic' : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
