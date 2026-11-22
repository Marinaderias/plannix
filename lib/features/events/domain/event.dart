class Event {
  const Event({
    required this.id,
    required this.title,
    required this.startTime,
    required this.endTime,
    this.description,
    this.location,
    this.color,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;

  /// Color stored as a hex string like "#7C3AED".
  final String? color;
  final DateTime startTime;
  final DateTime endTime;

  factory Event.fromMap(Map<String, dynamic> map) {
    return Event(
      id: map['id'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      location: map['location'] as String?,
      color: map['color'] as String?,
      startTime: DateTime.parse(map['start_time'] as String).toLocal(),
      endTime: DateTime.parse(map['end_time'] as String).toLocal(),
    );
  }

  /// Map used for insert/update. `user_id` is filled by the database default.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'location': location,
      'color': color,
      'start_time': startTime.toUtc().toIso8601String(),
      'end_time': endTime.toUtc().toIso8601String(),
    };
  }
}
