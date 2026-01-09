import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/features/settings/data/models/theme_mode_preference.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_cubit.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/cubit/theme_state.dart';
import 'package:rzi_hifdhapp/features/settings/presentation/pages/book_reminders_page.dart';
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
                      RadioGroup<ThemeModePreference>(
                        groupValue: state.preference,
                        onChanged: (value) {
                          if (value != null) {
                            context.read<ThemeCubit>().setThemePreference(
                              value,
                            );
                          }
                        },
                        child: Column(
                          children: const [
                            _ThemeOption(
                              title: 'Light',
                              subtitle: 'Use light theme',
                              value: ThemeModePreference.light,
                            ),
                            _ThemeOption(
                              title: 'Dark',
                              subtitle: 'Use dark theme',
                              value: ThemeModePreference.dark,
                            ),
                            _ThemeOption(
                              title: 'Auto',
                              subtitle: 'Follow system theme',
                              value: ThemeModePreference.auto,
                            ),
                          ],
                        ),
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
            child: ListTile(
              title: const Text('Open Logs'),
              leading: const Icon(Icons.monitor_heart),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => TalkerScreen(talker: di.sl<Talker>()),
                  ),
                );
              },
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

  const _ThemeOption({
    required this.title,
    required this.subtitle,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return RadioListTile<ThemeModePreference>(
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      contentPadding: EdgeInsets.zero,
    );
  }
}
