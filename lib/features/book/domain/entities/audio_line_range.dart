import 'package:equatable/equatable.dart';

class AudioLineRange extends Equatable {
  final double start;
  final double end;

  const AudioLineRange({required this.start, required this.end});

  factory AudioLineRange.fromString(String rangeStr) {
    final parts = rangeStr.trim().split('>');
    if (parts.length != 2) {
      return const AudioLineRange(start: 0.0, end: 0.0);
    }

    final start = double.tryParse(parts[0].trim()) ?? 0.0;
    final end = double.tryParse(parts[1].trim()) ?? 0.0;

    return AudioLineRange(start: start, end: end);
  }

  factory AudioLineRange.fromJson(Map<String, dynamic> json) => AudioLineRange(
    start: (json['start'] as num).toDouble(),
    end: (json['end'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'start': start, 'end': end};

  @override
  List<Object?> get props => [start, end];
}
