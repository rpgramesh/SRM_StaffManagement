import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import '../models/attendance.dart';
import 'auth_service.dart';
// TODO: Add geolocator dependency to pubspec.yaml
// import 'package:geolocator/geolocator.dart';

// #region debug-point A:reporter
Future<void> _dbgAttendance(String hypothesisId, String location, String msg,
    [Map<String, dynamic>? data]) async {
  try {
    const url = 'http://127.0.0.1:7777/event';
    const sessionId = 'firestore-write-failure';
    await http
        .post(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': sessionId,
              'runId': 'pre-fix',
              'hypothesisId': hypothesisId,
              'location': location,
              'msg': msg,
              'data': data ?? <String, dynamic>{},
              'ts': DateTime.now().millisecondsSinceEpoch,
            }))
        .timeout(const Duration(seconds: 1));
  } catch (_) {}
}
// #endregion

class AttendanceService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _collection = 'staff_attendance';

  // Office location coordinates (example - should be configurable)
  static const double _officeLatitude = 37.7749;
  static const double _officeLongitude = -122.4194;
  static const double _allowedRadius = 100.0; // meters

  // Estimate server time offset to account for client clock drift and latency
  static Future<Duration> estimateServerOffset() async {
    try {
      // #region debug-point E:time-sync-entry
      _dbgAttendance(
          'E',
          'lib/services/attendance_service.dart:estimateServerOffset',
          '[DEBUG] estimateServerOffset entered', {
        'projectId': Firebase.app().options.projectId,
        'authUid': FirebaseAuth.instance.currentUser?.uid,
      });
      // #endregion
      final localBefore = DateTime.now().toUtc();
      final docRef = await _firestore.collection('time_sync').add({
        'createdAt': FieldValue.serverTimestamp(),
      });
      // #region debug-point E:time-sync-success
      _dbgAttendance(
          'E',
          'lib/services/attendance_service.dart:estimateServerOffset',
          '[DEBUG] estimateServerOffset wrote time_sync', {
        'docId': docRef.id,
        'authUid': FirebaseAuth.instance.currentUser?.uid,
      });
      // #endregion
      final snap = await docRef.get();
      final localAfter = DateTime.now().toUtc();
      final serverTs = (snap.data()?['createdAt'] as Timestamp?);
      if (serverTs == null) return Duration.zero;
      // Approximate network latency by midpoint of request window
      final localMid = DateTime.fromMillisecondsSinceEpoch(
        ((localBefore.millisecondsSinceEpoch +
                localAfter.millisecondsSinceEpoch) ~/
            2),
        isUtc: true,
      );
      final serverTime = serverTs.toDate().toUtc();
      return serverTime.difference(localMid);
    } catch (e) {
      // #region debug-point E:time-sync-error
      _dbgAttendance(
          'E',
          'lib/services/attendance_service.dart:estimateServerOffset',
          '[DEBUG] estimateServerOffset failed', {
        'authUid': FirebaseAuth.instance.currentUser?.uid,
        'error': e.toString(),
        'firebaseCode': e is FirebaseException ? e.code : null,
      });
      // #endregion
      return Duration.zero;
    }
  }

  // Check in staff member with geofencing
  static Future<Map<String, dynamic>> checkIn(String staffId,
      {bool skipLocationCheck = false}) async {
    try {
      // #region debug-point A:attendance-checkin-entry
      _dbgAttendance('A', 'lib/services/attendance_service.dart:checkIn',
          '[DEBUG] AttendanceService.checkIn entered', {
        'projectId': Firebase.app().options.projectId,
        'authUid': FirebaseAuth.instance.currentUser?.uid,
        'staffId': staffId,
        'skipLocationCheck': skipLocationCheck,
      });
      // #endregion
      final now = DateTime.now();
      final dateKey = _getDateKey(now);

      // Check location if not skipped (placeholder for geofencing)
      Map<String, double>? currentPosition;
      bool isWithinGeofence = true;

      if (!skipLocationCheck) {
        // TODO: Implement location checking when geolocator is added
        // For now, we'll skip location validation
        print('Location checking skipped - geolocator not yet implemented');
      }

      // Check if already checked in today
      final existingRecord = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: dateKey)
          .get();

      if (existingRecord.docs.isNotEmpty) {
        final record = existingRecord.docs.first;
        final data = record.data();
        if (data['checkOutTime'] == null) {
          return {
            'success': false,
            'message': 'Already checked in today',
            'errorType': 'already_checked_in'
          };
        }
      }

      final attendanceData = {
        'staffId': staffId,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
        'checkInTime': Timestamp.fromDate(now),
        'checkOutTime': null,
        'status': 'checked_in',
        'checkInLocation': null,
        'isWithinGeofence': isWithinGeofence,
        'createdAt': Timestamp.fromDate(now),
      };

      final docRef =
          await _firestore.collection(_collection).add(attendanceData);

      // #region debug-point A:attendance-checkin-success
      _dbgAttendance('A', 'lib/services/attendance_service.dart:checkIn',
          '[DEBUG] AttendanceService.checkIn wrote attendance', {
        'docId': docRef.id,
        'authUid': FirebaseAuth.instance.currentUser?.uid,
        'staffId': staffId,
      });
      // #endregion

      return {
        'success': true,
        'message': 'Successfully checked in',
        'attendanceId': docRef.id,
        'checkInTime': now,
      };
    } catch (e) {
      // #region debug-point A:attendance-checkin-error
      _dbgAttendance('A', 'lib/services/attendance_service.dart:checkIn',
          '[DEBUG] AttendanceService.checkIn failed', {
        'authUid': FirebaseAuth.instance.currentUser?.uid,
        'staffId': staffId,
        'error': e.toString(),
        'firebaseCode': e is FirebaseException ? e.code : null,
      });
      // #endregion
      print('Error checking in: $e');
      return {
        'success': false,
        'message': 'Failed to check in: $e',
        'errorType': 'system_error'
      };
    }
  }

  // Check out staff member with location tracking
  static Future<Map<String, dynamic>> checkOut(String staffId,
      {bool skipLocationCheck = false}) async {
    try {
      final now = DateTime.now();
      final dateKey = _getDateKey(now);

      // Check location if not skipped (placeholder for geofencing)
      Map<String, double>? currentPosition;
      bool isWithinGeofence = true;

      if (!skipLocationCheck) {
        // TODO: Implement location checking when geolocator is added
        // For now, we'll skip location validation
        print('Location checking skipped - geolocator not yet implemented');
      }

      // Find today's check-in record
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .get();

      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        return data['date'] == dateKey && data['checkOutTime'] == null;
      }).toList();

      if (filteredDocs.isEmpty) {
        return {
          'success': false,
          'message': 'No active check-in found for today',
          'errorType': 'no_checkin_found'
        };
      }

      final doc = filteredDocs.first;
      final data = doc.data();
      final checkInTime = (data['checkInTime'] as Timestamp).toDate();

      final totalHours = now.difference(checkInTime).inMinutes / 60.0;

      final updateData = {
        'checkOutTime': Timestamp.fromDate(now),
        'duration': totalHours,
        'status': 'completed',
        'checkOutLocation': null,
        'updatedAt': Timestamp.fromDate(now),
      };

      await doc.reference.update(updateData);

      return {
        'success': true,
        'message': 'Successfully checked out',
        'checkOutTime': now,
        'duration': totalHours,
      };
    } catch (e) {
      print('Error checking out: $e');
      return {
        'success': false,
        'message': 'Failed to check out: $e',
        'errorType': 'system_error'
      };
    }
  }

  // Get today's attendance for a staff member
  static Future<Attendance?> getTodayAttendance(String staffId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
          .get();

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      return Attendance.fromMap(doc.data(), doc.id);
    } catch (e) {
      print('Error getting today\'s attendance: $e');
      return null;
    }
  }

  // Get attendance history for a staff member
  static Future<List<Attendance>> getAttendanceHistory(String staffId,
      {int limit = 30}) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .get();

      final attendanceList = querySnapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .toList();

      // Sort by date in descending order (most recent first)
      attendanceList.sort((a, b) => b.date.compareTo(a.date));

      // Apply limit after sorting
      return attendanceList.take(limit).toList();
    } catch (e) {
      print('Error getting attendance history: $e');
      return [];
    }
  }

  // Get weekly attendance summary
  static Future<Map<String, dynamic>> getWeeklyAttendance(
      String staffId) async {
    try {
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));

      final startDate =
          DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
      final endDate = DateTime(endOfWeek.year, endOfWeek.month, endOfWeek.day);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .get();

      final attendanceRecords = querySnapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .where((record) =>
              record.date.isAfter(startDate) &&
              record.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      double totalHours = 0;
      int daysPresent = 0;

      for (final record in attendanceRecords) {
        if (record.status == 'completed' || record.status == 'present') {
          totalHours += record.duration;
          daysPresent++;
        }
      }

      return {
        'totalHours': totalHours,
        'daysPresent': daysPresent,
        'records': attendanceRecords,
      };
    } catch (e) {
      print('Error getting weekly attendance: $e');
      return {
        'totalHours': 0.0,
        'daysPresent': 0,
        'records': <Attendance>[],
      };
    }
  }

  // Check if staff is currently checked in
  static Future<bool> isCheckedIn(String staffId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);

      final querySnapshot = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
          .where('checkOutTime', isNull: true)
          .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      print('Error checking if checked in: $e');
      return false;
    }
  }

  // Helper method to get date key (YYYY-MM-DD format)
  static String _getDateKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  // Stream today's attendance for real-time updates
  static Stream<Attendance?> streamTodayAttendance(String staffId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);

    return _firestore
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .where('date', isEqualTo: Timestamp.fromDate(startOfDay))
        .snapshots()
        .map((snapshot) {
      if (snapshot.docs.isEmpty) {
        return null;
      }
      final doc = snapshot.docs.first;
      return Attendance.fromMap(doc.data(), doc.id);
    });
  }

  // Get attendance records by date range
  static Future<List<Attendance>> getAttendanceByDateRange(
    String staffId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final querySnapshot = await _firestore
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .get();

      final attendanceList = querySnapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .where((record) =>
              record.date
                  .isAfter(startDate.subtract(const Duration(days: 1))) &&
              record.date.isBefore(endDate.add(const Duration(days: 1))))
          .toList();

      // Sort by date in descending order (most recent first)
      attendanceList.sort((a, b) => b.date.compareTo(a.date));

      return attendanceList;
    } catch (e) {
      print('Error getting attendance by date range: $e');
      return [];
    }
  }

  static Future<Map<String, dynamic>> updateAttendanceWithAudit(
    String attendanceId,
    Map<String, dynamic> updates, {
    required String reason,
  }) async {
    try {
      final now = DateTime.now();
      final docRef = _firestore.collection(_collection).doc(attendanceId);
      final snapshot = await docRef.get();
      if (!snapshot.exists) {
        return {
          'success': false,
          'message': 'Attendance record not found',
        };
      }

      // Enforce role-based permissions: only admin can modify records
      final role = await AuthService().getCurrentUserRole();
      if (role != 'admin') {
        return {
          'success': false,
          'message': 'Insufficient permissions to modify attendance',
          'errorType': 'permission_denied',
        };
      }

      final original = snapshot.data() ?? {};
      final Map<String, dynamic> previousValues = {};
      final Map<String, dynamic> newValues = {};

      updates.forEach((key, value) {
        previousValues[key] = original[key];
        newValues[key] = value is DateTime ? Timestamp.fromDate(value) : value;
      });

      await docRef.update({
        ...newValues,
        'updatedAt': Timestamp.fromDate(now),
      });

      final user = AuthService.getCurrentUser();
      await docRef.collection('audits').add({
        'performedBy': user?.uid ?? 'anonymous',
        'performedByEmail': user?.email ?? '',
        'role': role ?? 'unknown',
        'reason': reason,
        'changedFields': updates.keys.toList(),
        'previousValues': previousValues,
        'newValues': newValues,
        'timestamp': Timestamp.fromDate(now),
      });

      return {
        'success': true,
        'message': 'Attendance updated successfully',
      };
    } catch (e) {
      print('Error updating attendance with audit: $e');
      return {
        'success': false,
        'message': 'Failed to update attendance: $e',
      };
    }
  }

  static Future<String> exportAttendanceToCSV(
    String staffId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    // Role gate: only admin can export
    final role = await AuthService().getCurrentUserRole();
    if (role != 'admin') {
      throw Exception('Permission denied: export is restricted to admin');
    }

    final records = await getAttendanceByDateRange(staffId, startDate, endDate);
    final buffer = StringBuffer();
    buffer.writeln(
        'id,staffId,date,checkInTime,checkOutTime,duration,status,notes');
    for (final a in records) {
      final dateStr = a.date.toIso8601String();
      final ci = a.checkInTime?.toIso8601String() ?? '';
      final co = a.checkOutTime?.toIso8601String() ?? '';
      final notes = (a.notes ?? '').replaceAll(',', ';');
      buffer.writeln(
          '${a.id},${a.staffId},$dateStr,$ci,$co,${a.duration},${a.status},$notes');
    }
    return buffer.toString();
  }

  static Future<Map<String, dynamic>> importAttendanceFromCSV(
    String csv, {
    bool overwrite = false,
  }) async {
    try {
      // Role gate: only admin can import
      final role = await AuthService().getCurrentUserRole();
      if (role != 'admin') {
        return {
          'success': false,
          'message': 'Permission denied: import is restricted to admin',
          'errorType': 'permission_denied',
        };
      }

      final lines = csv
          .split(RegExp(r'\r?\n'))
          .where((l) => l.trim().isNotEmpty)
          .toList();
      if (lines.isEmpty) {
        return {
          'success': false,
          'message': 'CSV data is empty',
        };
      }
      final hasHeader = lines.first.toLowerCase().contains('staffid');
      final startIndex = hasHeader ? 1 : 0;
      int imported = 0;

      for (int i = startIndex; i < lines.length; i++) {
        final cols = _parseCsvLine(lines[i]);
        if (cols.length < 7) continue;
        final id = cols[0];
        final staffId = cols[1];
        final date = DateTime.tryParse(cols[2]) ?? DateTime.now();
        final checkIn = cols[3].isNotEmpty ? DateTime.tryParse(cols[3]) : null;
        final checkOut = cols[4].isNotEmpty ? DateTime.tryParse(cols[4]) : null;
        final duration = double.tryParse(cols[5]) ?? 0.0;
        final status = cols[6];
        final notes = cols.length > 7 ? cols[7] : null;

        final data = {
          'staffId': staffId,
          'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
          'checkInTime': checkIn != null ? Timestamp.fromDate(checkIn) : null,
          'checkOutTime':
              checkOut != null ? Timestamp.fromDate(checkOut) : null,
          'duration': duration,
          'status': status,
          'notes': notes,
          'createdAt': Timestamp.now(),
        };

        if (overwrite && id.isNotEmpty) {
          await _firestore
              .collection(_collection)
              .doc(id)
              .set(data, SetOptions(merge: true));
        } else {
          await _firestore.collection(_collection).add(data);
        }
        imported++;
      }

      return {
        'success': true,
        'imported': imported,
      };
    } catch (e) {
      print('Error importing attendance CSV: $e');
      return {
        'success': false,
        'message': 'Failed to import: $e',
      };
    }
  }

  static List<String> _parseCsvLine(String line) {
    final List<String> result = [];
    final StringBuffer current = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        inQuotes = !inQuotes;
      } else if (char == ',' && !inQuotes) {
        result.add(current.toString());
        current.clear();
      } else {
        current.write(char);
      }
    }
    result.add(current.toString());
    return result;
  }

  static Future<Map<String, dynamic>> getPeriodSummary(
    String staffId, {
    required String period, // 'monthly' | 'quarterly' | 'yearly'
  }) async {
    try {
      final now = DateTime.now();
      DateTime start;
      DateTime end;

      switch (period) {
        case 'monthly':
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
          break;
        case 'quarterly':
          final quarter = ((now.month - 1) ~/ 3) + 1;
          final startMonth = (quarter - 1) * 3 + 1;
          start = DateTime(now.year, startMonth, 1);
          end = DateTime(now.year, startMonth + 3, 0);
          break;
        case 'yearly':
          start = DateTime(now.year, 1, 1);
          end = DateTime(now.year, 12, 31);
          break;
        default:
          start = DateTime(now.year, now.month, 1);
          end = DateTime(now.year, now.month + 1, 0);
      }

      final records = await getAttendanceByDateRange(staffId, start, end);
      double totalHours = 0;
      int presentDays = 0;
      int lateDays = 0;
      int absentDays = 0;

      for (final r in records) {
        totalHours += r.duration;
        if (r.status == 'present' || r.status == 'completed') presentDays++;
        if (r.status == 'late') lateDays++;
        if (r.status == 'absent') absentDays++;
      }

      return {
        'period': period,
        'startDate': start,
        'endDate': end,
        'totalHours': totalHours,
        'daysPresent': presentDays,
        'daysLate': lateDays,
        'daysAbsent': absentDays,
        'records': records,
      };
    } catch (e) {
      print('Error generating summary: $e');
      return {
        'period': period,
        'totalHours': 0.0,
        'daysPresent': 0,
        'daysLate': 0,
        'daysAbsent': 0,
        'records': <Attendance>[],
      };
    }
  }
}
