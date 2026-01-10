import 'package:equatable/equatable.dart';

class StoreBook extends Equatable {
  final String name;
  final String description;
  final String path;
  final String version;

  const StoreBook({
    required this.name,
    required this.description,
    required this.path,
    required this.version,
  });

  String get id => path.split('/').last;

  @override
  List<Object?> get props => [name, description, path, version];
}
