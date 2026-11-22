import 'scheduled_item.dart';

/// A free period of time.
class TimeSlot {
  const TimeSlot(this.start, this.end);

  final DateTime start;
  final DateTime end;

  Duration get duration => end.difference(start);

  @override
  bool operator ==(Object other) =>
      other is TimeSlot && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => 'TimeSlot($start - $end)';
}

class SchedulingService {
  const SchedulingService._();

  /// True if two ranges overlap. Touching ranges (one ends exactly when the
  /// other starts) do NOT overlap.
  static bool overlaps(
    DateTime startA,
    DateTime endA,
    DateTime startB,
    DateTime endB,
  ) {
    return startA.isBefore(endB) && startB.isBefore(endA);
  }

  /// Items that conflict with the proposed range.
  ///
  /// [excludeId] lets you ignore the item being edited, so it doesn't
  /// conflict with itself.
  static List<ScheduledItem> findConflicts({
    required DateTime start,
    required DateTime end,
    required List<ScheduledItem> items,
    String? excludeId,
  }) {
    return items
        .where((item) => item.id != excludeId)
        .where((item) => overlaps(start, end, item.start, item.end))
        .toList();
  }

  /// Free slots inside [dayStart]..[dayEnd], between the given items.
  ///
  /// Overlapping items are merged first, and slots shorter than [minDuration]
  /// are dropped.
  static List<TimeSlot> findFreeSlots({
    required DateTime dayStart,
    required DateTime dayEnd,
    required List<ScheduledItem> items,
    Duration minDuration = const Duration(minutes: 15),
  }) {
    if (!dayEnd.isAfter(dayStart)) return [];

    // Keep only items that touch the window, clipped to it, sorted by start.
    final busy =
        items
            .where((i) => overlaps(dayStart, dayEnd, i.start, i.end))
            .map(
              (i) => TimeSlot(
                i.start.isBefore(dayStart) ? dayStart : i.start,
                i.end.isAfter(dayEnd) ? dayEnd : i.end,
              ),
            )
            .toList()
          ..sort((a, b) => a.start.compareTo(b.start));

    // Merge overlapping or touching busy ranges.
    final merged = <TimeSlot>[];
    for (final slot in busy) {
      if (merged.isNotEmpty && !slot.start.isAfter(merged.last.end)) {
        final last = merged.removeLast();
        merged.add(
          TimeSlot(
            last.start,
            slot.end.isAfter(last.end) ? slot.end : last.end,
          ),
        );
      } else {
        merged.add(slot);
      }
    }

    // The gaps between busy ranges are the free slots.
    final free = <TimeSlot>[];
    var cursor = dayStart;
    for (final b in merged) {
      if (b.start.isAfter(cursor)) free.add(TimeSlot(cursor, b.start));
      cursor = b.end;
    }
    if (dayEnd.isAfter(cursor)) free.add(TimeSlot(cursor, dayEnd));

    return free.where((s) => s.duration >= minDuration).toList();
  }

  /// Total free time of a list of slots.
  static Duration totalFree(List<TimeSlot> slots) =>
      slots.fold(Duration.zero, (sum, s) => sum + s.duration);
}
