import 'package:flutter_test/flutter_test.dart';
import 'package:staff_management_app/utils/attendance_utils.dart';

void main() {
  group('formatDetailedDuration', () {
    test('formats minutes only', () {
      expect(formatDetailedDuration(const Duration(minutes: 45)), '45 minutes');
    });

    test('formats hours and minutes', () {
      expect(formatDetailedDuration(const Duration(hours: 1, minutes: 30)), '1 hour 30 minutes');
    });

    test('formats hours only', () {
      expect(formatDetailedDuration(const Duration(hours: 2)), '2 hours');
    });
  });

  group('formatMinutesBetween', () {
    test('same-day check-in/out', () {
      final ci = DateTime(2025, 11, 1, 9, 0);
      final co = DateTime(2025, 11, 1, 9, 45);
      expect(formatMinutesBetween(ci, co), '45 minutes');
    });

    test('overnight stay', () {
      final ci = DateTime(2025, 11, 1, 22, 30);
      final co = DateTime(2025, 11, 2, 6, 0);
      expect(formatMinutesBetween(ci, co), '7 hours 30 minutes');
    });

    test('missing checkout returns N/A', () {
      final ci = DateTime(2025, 11, 1, 9, 0);
      expect(formatMinutesBetween(ci, null), 'N/A');
    });

    test('timezone utc handling', () {
      final ci = DateTime.utc(2025, 11, 1, 20, 0);
      final co = DateTime.utc(2025, 11, 1, 21, 30);
      expect(formatMinutesBetween(ci, co), '1 hour 30 minutes');
    });
  });
}
