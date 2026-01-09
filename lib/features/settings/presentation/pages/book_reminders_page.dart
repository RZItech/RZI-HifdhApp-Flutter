import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rzi_hifdhapp/core/di/injection_container.dart';
import 'package:rzi_hifdhapp/core/services/notification_service.dart';
import 'package:rzi_hifdhapp/features/book/domain/entities/book.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_bloc.dart';
import 'package:rzi_hifdhapp/features/book/presentation/bloc/book_state.dart';
import 'package:rzi_hifdhapp/features/settings/data/repositories/reminder_repository.dart';
import 'package:rzi_hifdhapp/features/settings/domain/entities/reminder_settings.dart';

class BookRemindersPage extends StatefulWidget {
  const BookRemindersPage({super.key});

  @override
  State<BookRemindersPage> createState() => _BookRemindersPageState();
}

class _BookRemindersPageState extends State<BookRemindersPage> {
  late ReminderRepository _repository;
  final Map<String, ReminderSettings> _settingsCache = {};

  @override
  void initState() {
    super.initState();
    _repository = sl<ReminderRepository>();
    _loadSettings();
  }

  void _loadSettings() {
    final settingsList = _repository.loadSettings();
    setState(() {
      for (var s in settingsList) {
        _settingsCache[s.bookId] = s;
      }
    });
  }

  String _formatTime(int hour, int minute) {
    final dt = DateTime(2022, 1, 1, hour, minute);
    return TimeOfDay.fromDateTime(dt).format(context);
  }

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'Daily';
    if (days.isEmpty) return 'Never';
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => weekdays[d - 1]).join(', ');
  }

  Future<void> _toggleReminder(Book book, bool value) async {
    final current =
        _settingsCache[book.id] ?? ReminderSettings(bookId: book.id);
    final newSettings = current.copyWith(isEnabled: value);

    await _repository.saveSettings(newSettings);
    setState(() {
      _settingsCache[book.id] = newSettings;
    });

    if (value) {
      _scheduleForBook(book, newSettings);
    } else {
      _cancelForBook(book.id);
    }
  }

  void _scheduleForBook(Book book, ReminderSettings settings) {
    // Generate a unique ID base from book ID hash code or similar
    // We need stable IDs per day per book to cancel/reschedule.
    // For simplicity, let's assume hashcode + dayIndex.

    final baseId = book.id.hashCode;

    for (var day in settings.daysOfWeek) {
      // Create unique ID combining book and day
      // Using prime multiplier to avoid collisions
      final notificationId = baseId + (day * 1000);

      NotificationService().scheduleWeeklyReminder(
        id: notificationId,
        title: 'Learn ${book.name}',
        body: 'Time to review your Hifdh!',
        time: TimeOfDay(hour: settings.hour, minute: settings.minute),
        dayOfWeek: day,
      );
    }
  }

  void _cancelForBook(String bookId) {
    final baseId = bookId.hashCode;
    for (int i = 1; i <= 7; i++) {
      NotificationService().cancelReminder(baseId + (i * 1000));
    }
  }

  void _showConfigDialog(Book book) {
    final current =
        _settingsCache[book.id] ?? ReminderSettings(bookId: book.id);
    int selectedHour = current.hour;
    int selectedMinute = current.minute;
    List<int> selectedDays = List.from(current.daysOfWeek);

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Reminder for ${book.name}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Time'),
                    subtitle: Text(_formatTime(selectedHour, selectedMinute)),
                    trailing: const Icon(Icons.access_time),
                    onTap: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay(
                          hour: selectedHour,
                          minute: selectedMinute,
                        ),
                      );
                      if (t != null) {
                        setState(() {
                          selectedHour = t.hour;
                          selectedMinute = t.minute;
                        });
                      }
                    },
                  ),
                  const Divider(),
                  const Text(
                    'Days',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (int i = 1; i <= 7; i++)
                        FilterChip(
                          label: Text(
                            ['M', 'T', 'W', 'T', 'F', 'S', 'S'][i - 1],
                          ),
                          selected: selectedDays.contains(i),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                selectedDays.add(i);
                              } else {
                                selectedDays.remove(i);
                              }
                              selectedDays.sort();
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () => Navigator.pop(ctx),
                ),
                ElevatedButton(
                  child: const Text('Save'),
                  onPressed: () {
                    // Save and update
                    if (selectedDays.isEmpty) {
                      // Warn or allow? If empty, it won't schedule anything.
                    }
                    final newSettings = current.copyWith(
                      hour: selectedHour,
                      minute: selectedMinute,
                      daysOfWeek: selectedDays,
                      isEnabled:
                          true, // Auto enable on save logic? Or keep current state? Let's auto-enable to be helpful.
                    );

                    _repository.saveSettings(newSettings);
                    this.setState(() {
                      // Update parent state
                      _settingsCache[book.id] = newSettings;
                    });

                    // Reschedule (Cancel old, schedule new)
                    _cancelForBook(book.id);
                    _scheduleForBook(book, newSettings);

                    Navigator.pop(ctx);
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Book Reminders')),
      body: BlocBuilder<BookBloc, BookState>(
        builder: (context, state) {
          if (state is BookLoaded) {
            final books = state.books;
            if (books.isEmpty) {
              return const Center(
                child: Text('No books available. Import a book first!'),
              );
            }
            return ListView.builder(
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                final settings =
                    _settingsCache[book.id] ??
                    ReminderSettings(bookId: book.id);

                return ListTile(
                  title: Text(book.name),
                  subtitle: Text(
                    settings.isEnabled
                        ? '${_formatTime(settings.hour, settings.minute)} • ${_formatDays(settings.daysOfWeek)}'
                        : 'Reminders off',
                  ),
                  trailing: Switch(
                    value: settings.isEnabled,
                    onChanged: (val) => _toggleReminder(book, val),
                  ),
                  onTap: () => _showConfigDialog(book),
                );
              },
            );
          }
          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }
}
