import 'package:equatable/equatable.dart';

class ReminderSettings extends Equatable {
  final String bookId;
  final bool isEnabled;
  final int hour;
  final int minute;
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday

  const ReminderSettings({
    required this.bookId,
    this.isEnabled = false,
    this.hour = 8,
    this.minute = 0,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7], // Default to daily
  });

  ReminderSettings copyWith({
    String? bookId,
    bool? isEnabled,
    int? hour,
    int? minute,
    List<int>? daysOfWeek,
  }) {
    return ReminderSettings(
      bookId: bookId ?? this.bookId,
      isEnabled: isEnabled ?? this.isEnabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'isEnabled': isEnabled,
      'hour': hour,
      'minute': minute,
      'daysOfWeek': daysOfWeek,
    };
  }

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    return ReminderSettings(
      bookId: json['bookId'] as String,
      isEnabled: json['isEnabled'] as bool? ?? false,
      hour: json['hour'] as int? ?? 8,
      minute: json['minute'] as int? ?? 0,
      daysOfWeek:
          (json['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
    );
  }

  @override
  List<Object?> get props => [bookId, isEnabled, hour, minute, daysOfWeek];
}
