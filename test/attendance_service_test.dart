import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_management_app/models/attendance.dart';

void main() {
  group('AttendanceService', () {
    test('should create attendance with correct data structure', () {
      // Test that Attendance model matches StaffService format
      final now = DateTime.now();
      final attendance = Attendance(
        id: 'test-id',
        staffId: 'test-staff-id',
        date: DateTime(now.year, now.month, now.day),
        checkInTime: now,
        checkOutTime: null,
        duration: 0.0,
        status: 'checked_in',
        notes: null,
      );

      // Convert to map and verify structure
      final map = attendance.toMap();
      
      expect(map['staffId'], equals('test-staff-id'));
      expect(map['date'], isA<Timestamp>());
      expect(map['checkInTime'], isA<Timestamp>());
      expect(map['checkOutTime'], isNull);
      expect(map['duration'], equals(0.0));
      expect(map['status'], equals('checked_in'));
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('should parse attendance from map correctly', () {
      // Test parsing from StaffService format
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final map = {
        'staffId': 'test-staff-id',
        'date': Timestamp.fromDate(today),
        'checkInTime': Timestamp.fromDate(now),
        'checkOutTime': null,
        'duration': 8.5,
        'status': 'completed',
        'notes': 'Test notes',
      };

      final attendance = Attendance.fromMap(map, 'test-id');
      
      expect(attendance.id, equals('test-id'));
      expect(attendance.staffId, equals('test-staff-id'));
      expect(attendance.date, equals(today));
      expect(attendance.checkInTime, equals(now));
      expect(attendance.checkOutTime, isNull);
      expect(attendance.duration, equals(8.5));
      expect(attendance.status, equals('completed'));
      expect(attendance.notes, equals('Test notes'));
    });

    test('should handle legacy totalHours field for backward compatibility', () {
      // Test backward compatibility with old format
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final map = {
        'staffId': 'test-staff-id',
        'date': Timestamp.fromDate(today),
        'checkInTime': Timestamp.fromDate(now),
        'checkOutTime': null,
        'totalHours': 7.5, // Legacy field
        'status': 'present',
        'notes': null,
      };

      final attendance = Attendance.fromMap(map, 'test-id');
      
      expect(attendance.duration, equals(7.5)); // Should use totalHours if duration not present
      expect(attendance.status, equals('present'));
    });

    test('should determine checked-in status correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Test checked in (has check-in but no check-out)
      final checkedInAttendance = Attendance(
        id: 'test-id',
        staffId: 'test-staff-id',
        date: today,
        checkInTime: now,
        checkOutTime: null,
        duration: 0.0,
        status: 'checked_in',
        notes: null,
      );
      
      expect(checkedInAttendance.isCheckedIn, isTrue);
      
      // Test checked out (has both check-in and check-out)
      final checkedOutAttendance = Attendance(
        id: 'test-id',
        staffId: 'test-staff-id',
        date: today,
        checkInTime: now,
        checkOutTime: now.add(const Duration(hours: 8)),
        duration: 8.0,
        status: 'completed',
        notes: null,
      );
      
      expect(checkedOutAttendance.isCheckedIn, isFalse);
    });

    test('should display status text correctly', () {
      expect(_getStatusDisplayText('checked_in'), equals('Checked In'));
      expect(_getStatusDisplayText('completed'), equals('Completed'));
      expect(_getStatusDisplayText('present'), equals('Present'));
      expect(_getStatusDisplayText('absent'), equals('Absent'));
      expect(_getStatusDisplayText('late'), equals('Late'));
      expect(_getStatusDisplayText('halfDay'), equals('Half Day'));
      expect(_getStatusDisplayText('unknown'), equals('unknown'));
    });

    test('should format duration correctly', () {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      final attendance = Attendance(
        id: 'test-id',
        staffId: 'test-staff-id',
        date: today,
        checkInTime: now.subtract(const Duration(hours: 8, minutes: 30)),
        checkOutTime: now,
        duration: 8.5,
        status: 'completed',
        notes: null,
      );
      
      expect(attendance.formattedDuration, equals('8h 30m'));
    });
  });
}

// Helper function to test status display text
String _getStatusDisplayText(String status) {
  switch (status) {
    case 'checked_in':
      return 'Checked In';
    case 'completed':
      return 'Completed';
    case 'present':
      return 'Present';
    case 'absent':
      return 'Absent';
    case 'late':
      return 'Late';
    case 'halfDay':
      return 'Half Day';
    default:
      return status;
  }
}