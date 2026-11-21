import 'package:flutter_test/flutter_test.dart';
import 'package:plannix/core/scheduling/scheduled_item.dart';
import 'package:plannix/core/scheduling/scheduling_service.dart';

DateTime t(int hour, [int minute = 0]) => DateTime(2026, 11, 21, hour, minute);

ScheduledItem item(String id, DateTime start, DateTime end) => ScheduledItem(
      id: id,
      title: id,
      start: start,
      end: end,
      type: ScheduledItemType.event,
    );

void main() {
  group('overlaps', () {
    test('detects partial overlap', () {
      expect(SchedulingService.overlaps(t(10), t(12), t(11), t(13)), isTrue);
    });

    test('detects one range inside another', () {
      expect(SchedulingService.overlaps(t(9), t(17), t(11), t(12)), isTrue);
    });

    test('touching ranges are not a conflict', () {
      expect(SchedulingService.overlaps(t(10), t(11), t(11), t(12)), isFalse);
    });

    test('separate ranges are not a conflict', () {
      expect(SchedulingService.overlaps(t(8), t(9), t(10), t(11)), isFalse);
    });
  });

  group('findConflicts', () {
    final items = [
      item('a', t(9), t(10)),
      item('b', t(11), t(12)),
    ];

    test('returns only the conflicting items', () {
      final result = SchedulingService.findConflicts(
        start: t(9, 30),
        end: t(11, 30),
        items: items,
      );
      expect(result.map((i) => i.id), ['a', 'b']);
    });

    test('returns empty when there is no conflict', () {
      final result = SchedulingService.findConflicts(
        start: t(10),
        end: t(11),
        items: items,
      );
      expect(result, isEmpty);
    });

    test('ignores the item being edited', () {
      final result = SchedulingService.findConflicts(
        start: t(9),
        end: t(10),
        items: items,
        excludeId: 'a',
      );
      expect(result, isEmpty);
    });
  });

  group('findFreeSlots', () {
    test('whole day is free when there are no items', () {
      final slots = SchedulingService.findFreeSlots(
        dayStart: t(8),
        dayEnd: t(18),
        items: [],
      );
      expect(slots, [TimeSlot(t(8), t(18))]);
    });

    test('returns the gaps between items', () {
      final slots = SchedulingService.findFreeSlots(
        dayStart: t(8),
        dayEnd: t(18),
        items: [item('a', t(9), t(10)), item('b', t(12), t(13))],
      );
      expect(slots, [
        TimeSlot(t(8), t(9)),
        TimeSlot(t(10), t(12)),
        TimeSlot(t(13), t(18)),
      ]);
    });

    test('merges overlapping items', () {
      final slots = SchedulingService.findFreeSlots(
        dayStart: t(8),
        dayEnd: t(18),
        items: [item('a', t(9), t(11)), item('b', t(10), t(12))],
      );
      expect(slots, [TimeSlot(t(8), t(9)), TimeSlot(t(12), t(18))]);
    });

    test('clips items that go outside the day window', () {
      final slots = SchedulingService.findFreeSlots(
        dayStart: t(8),
        dayEnd: t(18),
        items: [item('a', t(7), t(9)), item('b', t(17), t(20))],
      );
      expect(slots, [TimeSlot(t(9), t(17))]);
    });

    test('drops slots shorter than the minimum', () {
      final slots = SchedulingService.findFreeSlots(
        dayStart: t(8),
        dayEnd: t(12),
        items: [item('a', t(8, 10), t(12))],
        minDuration: const Duration(minutes: 15),
      );
      expect(slots, isEmpty);
    });

    test('returns nothing when the day is fully booked', () {
      final slots = SchedulingService.findFreeSlots(
        dayStart: t(8),
        dayEnd: t(10),
        items: [item('a', t(8), t(10))],
      );
      expect(slots, isEmpty);
    });
  });

  test('totalFree adds the slot durations', () {
    final total = SchedulingService.totalFree(
      [TimeSlot(t(8), t(9)), TimeSlot(t(10), t(11, 30))],
    );
    expect(total, const Duration(hours: 2, minutes: 30));
  });
}