import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/staff.dart';
import '../data/demo_staff_data.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StaffService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _staffCollection =
      FirebaseFirestore.instance.collection('staff');
  final CollectionReference _attendanceCollection =
      FirebaseFirestore.instance.collection('staff_attendance');

  // Staff CRUD operations
  Future<String> addStaff(Staff staff) async {
    try {
      final data = staff.toFirestore();
      final pinVal = staff.pin;
      if (pinVal != null && pinVal.isNotEmpty) {
        data['pin'] = _hashPin(pinVal);
      } else {
        data.remove('pin');
      }
      DocumentReference docRef = await _staffCollection.add(data);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add staff: $e');
    }
  }

  Future<void> updateStaff(Staff staff) async {
    try {
      final data = staff.toFirestore();
      final pinVal = staff.pin;
      if (pinVal != null && pinVal.isNotEmpty) {
        data['pin'] = _hashPin(pinVal);
      } else {
        data.remove('pin');
      }
      await _staffCollection.doc(staff.id).update(data);
    } catch (e) {
      throw Exception('Failed to update staff: $e');
    }
  }

  Future<void> deleteStaff(String staffId) async {
    try {
      await _staffCollection.doc(staffId).delete();
    } catch (e) {
      throw Exception('Failed to delete staff: $e');
    }
  }

  Future<Staff?> getStaff(String staffId) async {
    try {
      DocumentSnapshot doc = await _staffCollection.doc(staffId).get();
      if (doc.exists) {
        return Staff.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get staff: $e');
    }
  }

  Stream<List<Staff>> getAllStaff() {
    return _staffCollection.snapshots().map((snapshot) {
      final staff =
          snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      // Sort by name in ascending order
      staff.sort((a, b) => a.name.compareTo(b.name));
      return staff;
    });
  }

  // Stream a single staff member by ID for real-time updates
  Stream<Staff?> getStaffStream(String staffId) {
    return _staffCollection.doc(staffId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Staff.fromFirestore(doc);
    });
  }

  Stream<List<Staff>> getStaffByDepartment(String department) {
    return _staffCollection
        .where('department', isEqualTo: department)
        .snapshots()
        .map((snapshot) {
      final staff =
          snapshot.docs.map((doc) => Staff.fromFirestore(doc)).toList();
      // Sort by name in ascending order
      staff.sort((a, b) => a.name.compareTo(b.name));
      return staff;
    });
  }

  // Check-in/out functionality
  Future<void> checkIn(String staffId) async {
    try {
      final now = DateTime.now();

      // Update staff document
      await _staffCollection.doc(staffId).update({
        'lastCheckIn': Timestamp.fromDate(now),
      });

      // Create attendance record
      await _attendanceCollection.add({
        'staffId': staffId,
        'checkInTime': Timestamp.fromDate(now),
        'checkOutTime': null,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'status': 'checked_in',
      });
    } catch (e) {
      throw Exception('Failed to check in: $e');
    }
  }

  Future<void> checkOut(String staffId) async {
    try {
      final now = DateTime.now();

      // Update staff document
      await _staffCollection.doc(staffId).update({
        'lastCheckOut': Timestamp.fromDate(now),
      });

      // Update today's attendance record
      final today = DateTime(now.year, now.month, now.day);
      final querySnapshot = await _attendanceCollection
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: Timestamp.fromDate(today))
          .where('checkOutTime', isNull: true)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final checkInTime = (doc['checkInTime'] as Timestamp).toDate();
        final duration = now.difference(checkInTime).inMinutes / 60.0;

        await doc.reference.update({
          'checkOutTime': Timestamp.fromDate(now),
          'duration': duration,
          'status': 'completed',
        });

        // Update total hours worked
        final staffDoc = await _staffCollection.doc(staffId).get();
        final currentTotal = (staffDoc['totalHoursWorked'] ?? 0.0).toDouble();
        final currentShifts = staffDoc['shiftsCompleted'] ?? 0;

        await _staffCollection.doc(staffId).update({
          'totalHoursWorked': currentTotal + duration,
          'shiftsCompleted': currentShifts + 1,
        });
      }
    } catch (e) {
      throw Exception('Failed to check out: $e');
    }
  }

  // Attendance queries
  Future<bool> isCheckedIn(String staffId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final querySnapshot = await _attendanceCollection
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkOutTime', isNull: true)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Real-time check-in status for all staff
  Stream<Map<String, bool>> getAllCheckInStatus() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _attendanceCollection
        .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((snapshot) {
      Map<String, bool> statusMap = {};
      for (var doc in snapshot.docs) {
        final staffId = doc['staffId'] as String;
        final isCheckedIn = doc['checkOutTime'] == null;
        statusMap[staffId] = isCheckedIn;
      }
      return statusMap;
    });
  }

  Stream<List<Map<String, dynamic>>> getTodayAttendance() {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _attendanceCollection
        .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'staffId': doc['staffId'],
                  'checkInTime': (doc['checkInTime'] as Timestamp).toDate(),
                  'checkOutTime': doc['checkOutTime'] != null
                      ? (doc['checkOutTime'] as Timestamp).toDate()
                      : null,
                  'duration': doc['duration'],
                  'status': doc['status'],
                })
            .toList());
  }

  Future<List<Map<String, dynamic>>> getAttendanceHistory(String staffId,
      {DateTime? startDate, DateTime? endDate}) async {
    try {
      Query query = _attendanceCollection.where('staffId', isEqualTo: staffId);

      if (startDate != null) {
        query = query.where('date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }
      if (endDate != null) {
        query = query.where('date',
            isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      final snapshot = await query.get();
      final attendanceList = snapshot.docs
          .map((doc) => {
                'id': doc.id,
                'date': (doc['date'] as Timestamp).toDate(),
                'checkInTime': (doc['checkInTime'] as Timestamp).toDate(),
                'checkOutTime': doc['checkOutTime'] != null
                    ? (doc['checkOutTime'] as Timestamp).toDate()
                    : null,
                'duration': doc['duration'] ?? 0.0,
                'status': doc['status'],
              })
          .toList();

      // Sort by date in descending order (most recent first)
      attendanceList.sort((a, b) {
        final aDate = a['date'] as DateTime;
        final bDate = b['date'] as DateTime;
        return bDate.compareTo(aDate);
      });

      return attendanceList;
    } catch (e) {
      throw Exception('Failed to get attendance history: $e');
    }
  }

  // Schedule management

  // Populate demo data
  Future<void> populateDemoData() async {
    await DemoStaffData.populateDemoData();
  }

  Future<void> addSchedule({
    required String staffId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) async {
    try {
      // Check for conflicts on the same day for the same staff
      final hasConflict = await hasScheduleConflict(
        staffId: staffId,
        date: date,
        startTime: startTime,
        endTime: endTime,
      );
      if (hasConflict) {
        throw Exception(
            'Schedule conflict detected for this staff and time range');
      }

      await _firestore.collection('staff_schedule').add({
        'staffId': staffId,
        'date': Timestamp.fromDate(date),
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'notes': notes,
        'createdAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to add schedule: $e');
    }
  }

  /// Delete a schedule by id
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _firestore.collection('staff_schedule').doc(scheduleId).delete();
    } catch (e) {
      throw Exception('Failed to delete schedule: $e');
    }
  }

  /// Detect schedule conflicts for a staff on a given date
  Future<bool> hasScheduleConflict({
    required String staffId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String? excludeScheduleId,
  }) async {
    try {
      final targetDate = DateTime(date.year, date.month, date.day);
      final snapshot = await _firestore
          .collection('staff_schedule')
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: Timestamp.fromDate(targetDate))
          .get();

      for (final doc in snapshot.docs) {
        if (excludeScheduleId != null && doc.id == excludeScheduleId) continue;
        final data = doc.data();
        final existingStart = (data['startTime'] as Timestamp).toDate();
        final existingEnd = (data['endTime'] as Timestamp).toDate();
        // Overlap if new start < existing end AND new end > existing start
        if (startTime.isBefore(existingEnd) && endTime.isAfter(existingStart)) {
          return true;
        }
      }
      return false;
    } catch (e) {
      throw Exception('Failed to check schedule conflict: $e');
    }
  }

  Stream<List<Map<String, dynamic>>> getScheduleForDate(DateTime date) {
    final targetDate = DateTime(date.year, date.month, date.day);

    return _firestore
        .collection('staff_schedule')
        .where('date', isEqualTo: Timestamp.fromDate(targetDate))
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {
                  'id': doc.id,
                  'staffId': doc['staffId'],
                  'date': (doc['date'] as Timestamp).toDate(),
                  'startTime': (doc['startTime'] as Timestamp).toDate(),
                  'endTime': (doc['endTime'] as Timestamp).toDate(),
                  'notes': doc['notes'],
                })
            .toList());
  }

  // Reports and analytics - Real-time dashboard data
  Stream<Map<String, dynamic>> getStaffDashboardData() {
    return _staffCollection.snapshots().asyncMap((staffSnapshot) async {
      final totalStaff = staffSnapshot.docs.length;

      final activeStaff =
          staffSnapshot.docs.where((doc) => doc['isActive'] == true).length;

      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final todayAttendance = await _attendanceCollection
          .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      final checkedInToday = todayAttendance.docs.length;
      final completedShifts = todayAttendance.docs
          .where((doc) => doc['status'] == 'completed')
          .length;

      final departments = staffSnapshot.docs
          .map((doc) => doc['department'] as String)
          .toSet()
          .length;

      return {
        'totalStaff': totalStaff,
        'activeStaff': activeStaff,
        'checkedIn': checkedInToday,
        'departments': departments,
        'onSchedule': checkedInToday, // For now, same as checkedIn
        'completedShifts': completedShifts,
      };
    });
  }

  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }
}
// Removed stray global _hashPin and extra closing brace
