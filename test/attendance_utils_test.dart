import 'package:flutter_test/flutter_test.dart';
import 'package:staff_management_app/models/attendance.dart';
import 'package:staff_management_app/utils/attendance_utils.dart';

void main() {
  group('Attendance Utils - computeDayStatus', () {
    test('future dates are not marked absent', () {
      final today = DateTime.now();
      final future = today.add(const Duration(days: 2));
      final status = computeDayStatus(future, []);
      expect(status, equals('future'));
    });

    test('today without record is not absent', () {
      final today = DateTime.now();
      final status = computeDayStatus(DateTime(today.year, today.month, today.day), []);
      expect(status, equals('today_no_record'));
    });

    test('past date without record is absent', () {
      final today = DateTime.now();
      final past = today.subtract(const Duration(days: 3));
      final status = computeDayStatus(DateTime(past.year, past.month, past.day), []);
      expect(status, equals('absent'));
    });

    test('present/completed record uses underlying status', () {
      final today = DateTime.now();
      final past = today.subtract(const Duration(days: 1));
      final record = Attendance(
        id: 'r1',
        staffId: 's1',
        date: DateTime(past.year, past.month, past.day),
        status: 'completed',
        duration: 8.0,
      );
      final status = computeDayStatus(record.date, [record]);
      expect(status, equals('completed'));
    });

    test('displayTextForStatus returns user-friendly text', () {
      expect(displayTextForStatus('future'), equals('Upcoming'));
      expect(displayTextForStatus('today_no_record'), equals('No activity yet'));
      expect(displayTextForStatus('absent'), equals('Absent'));

      final today = DateTime.now();
      final ci = DateTime(today.year, today.month, today.day, 9, 0);
      final co = DateTime(today.year, today.month, today.day, 17, 0);
      final record = Attendance(
        id: 'r1',
        staffId: 's1',
        date: DateTime(today.year, today.month, today.day),
        status: 'present',
        checkInTime: ci,
        checkOutTime: co,
        duration: 8.0,
      );
      final text = displayTextForStatus('present', record: record);
      expect(text.contains('Present'), isTrue);
      expect(text.contains('8 hours'), isTrue);
    });
  });
}
