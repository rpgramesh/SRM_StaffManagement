import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_management_app/models/schedule.dart';

class ScheduleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'schedules';

  // Create a new schedule
  Future<String> createSchedule(Schedule schedule) async {
    try {
      final docRef = await _db.collection(_collection).add(schedule.toMap());
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create schedule: $e');
    }
  }

  // Get schedule by ID
  Future<Schedule?> getScheduleById(String scheduleId) async {
    try {
      final doc = await _db.collection(_collection).doc(scheduleId).get();
      if (doc.exists && doc.data() != null) {
        return Schedule.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to get schedule: $e');
    }
  }

  // Get schedules for a specific staff member
  Stream<List<Schedule>> getSchedulesForStaff(String staffId) {
    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          final schedules = snapshot.docs
              .map((doc) => Schedule.fromMap(doc.data(), doc.id))
              .toList();
          
          // Sort by date in ascending order
          schedules.sort((a, b) => a.date.compareTo(b.date));
          
          return schedules;
        });
  }

  // Get schedules for a specific date range
  Stream<List<Schedule>> getSchedulesByDateRange(
    String staffId,
    DateTime startDate,
    DateTime endDate,
  ) {
    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snapshot) {
          final schedules = snapshot.docs
              .map((doc) => Schedule.fromMap(doc.data(), doc.id))
              .where((schedule) => 
                  schedule.isActive &&
                  schedule.date.isAfter(startDate.subtract(Duration(days: 1))) &&
                  schedule.date.isBefore(endDate.add(Duration(days: 1))))
              .toList();
          
          // Sort by date in ascending order
          schedules.sort((a, b) => a.date.compareTo(b.date));
          
          return schedules;
        });
  }

  // Get today's schedule for a staff member
  Stream<List<Schedule>> getTodaySchedule(String staffId) {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snapshot) {
          final schedules = snapshot.docs
              .map((doc) => Schedule.fromMap(doc.data(), doc.id))
              .where((schedule) => 
                  schedule.isActive &&
                  schedule.date.isAfter(startOfDay.subtract(Duration(seconds: 1))) &&
                  schedule.date.isBefore(endOfDay.add(Duration(seconds: 1))))
              .toList();
          
          // Sort by date in ascending order
          schedules.sort((a, b) => a.date.compareTo(b.date));
          
          return schedules;
        });
  }

  // Get upcoming schedules (next 7 days)
  Stream<List<Schedule>> getUpcomingSchedules(String staffId) {
    final now = DateTime.now();
    final nextWeek = now.add(const Duration(days: 7));

    return _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .snapshots()
        .map((snapshot) {
          final schedules = snapshot.docs
              .map((doc) => Schedule.fromMap(doc.data(), doc.id))
              .where((schedule) => 
                  schedule.isActive &&
                  schedule.date.isAfter(now.subtract(Duration(seconds: 1))) &&
                  schedule.date.isBefore(nextWeek.add(Duration(seconds: 1))))
              .toList();
          
          // Sort by date in ascending order
          schedules.sort((a, b) => a.date.compareTo(b.date));
          
          return schedules;
        });
  }

  // Get all schedules for a department (for managers)
  Stream<List<Schedule>> getDepartmentSchedules(
    String department,
    DateTime? startDate,
    DateTime? endDate,
  ) {
    return _db
        .collection(_collection)
        .snapshots()
        .map((snapshot) {
          final schedules = snapshot.docs
              .map((doc) => Schedule.fromMap(doc.data(), doc.id))
              .where((schedule) {
                if (!schedule.isActive) return false;
                if (startDate != null && schedule.date.isBefore(startDate)) return false;
                if (endDate != null && schedule.date.isAfter(endDate)) return false;
                return true;
              })
              .toList();
          
          // Sort by date in ascending order
          schedules.sort((a, b) => a.date.compareTo(b.date));
          
          return schedules;
        });
  }

  // Update schedule
  Future<void> updateSchedule(String scheduleId, Schedule schedule) async {
    try {
      final updatedSchedule = schedule.copyWith(
        updatedAt: DateTime.now(),
      );
      await _db.collection(_collection).doc(scheduleId).update(updatedSchedule.toMap());
    } catch (e) {
      throw Exception('Failed to update schedule: $e');
    }
  }

  // Delete schedule (soft delete by setting isActive to false)
  Future<void> deleteSchedule(String scheduleId) async {
    try {
      await _db.collection(_collection).doc(scheduleId).update({
        'isActive': false,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
    } catch (e) {
      throw Exception('Failed to delete schedule: $e');
    }
  }

  // Bulk create schedules (for creating weekly/monthly schedules)
  Future<List<String>> createBulkSchedules(List<Schedule> schedules) async {
    try {
      final batch = _db.batch();
      final List<String> scheduleIds = [];

      for (final schedule in schedules) {
        final docRef = _db.collection(_collection).doc();
        batch.set(docRef, schedule.toMap());
        scheduleIds.add(docRef.id);
      }

      await batch.commit();
      return scheduleIds;
    } catch (e) {
      throw Exception('Failed to create bulk schedules: $e');
    }
  }

  // Check for schedule conflicts
  Future<bool> hasScheduleConflict(
    String staffId,
    DateTime date,
    DateTime startTime,
    DateTime endTime,
    {String? excludeScheduleId}
  ) async {
    try {
      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final snapshot = await _db
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .get();
      
      final filteredDocs = snapshot.docs.where((doc) {
        final schedule = Schedule.fromMap(doc.data(), doc.id);
        return schedule.isActive &&
               schedule.date.isAfter(startOfDay.subtract(Duration(seconds: 1))) &&
               schedule.date.isBefore(endOfDay.add(Duration(seconds: 1)));
      }).toList();
      
      for (final doc in filteredDocs) {
        if (excludeScheduleId != null && doc.id == excludeScheduleId) {
          continue;
        }
        
        final schedule = Schedule.fromMap(doc.data(), doc.id);
        
        // Check for time overlap
        if (startTime.isBefore(schedule.endTime) && endTime.isAfter(schedule.startTime)) {
          return true;
        }
      }
      
      return false;
    } catch (e) {
      throw Exception('Failed to check schedule conflict: $e');
    }
  }

  // Get schedule statistics for a staff member
  Future<Map<String, dynamic>> getScheduleStats(
    String staffId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final snapshot = await _db
          .collection(_collection)
          .where('staffId', isEqualTo: staffId)
          .get();

      final schedules = snapshot.docs
          .map((doc) => Schedule.fromMap(doc.data(), doc.id))
          .where((schedule) => 
              schedule.isActive &&
              schedule.date.isAfter(startDate.subtract(Duration(seconds: 1))) &&
              schedule.date.isBefore(endDate.add(Duration(seconds: 1))))
          .toList();

      double totalHours = 0;
      int totalShifts = schedules.length;
      Map<String, int> shiftTypeCounts = {};
      Map<String, int> locationCounts = {};

      for (final schedule in schedules) {
        totalHours += schedule.durationInHours;
        
        final shiftTypeKey = schedule.shiftType.name;
        shiftTypeCounts[shiftTypeKey] = 
            (shiftTypeCounts[shiftTypeKey] ?? 0) + 1;
        
        final locationKey = schedule.location ?? 'Unknown';
        locationCounts[locationKey] = 
            (locationCounts[locationKey] ?? 0) + 1;
      }

      return {
        'totalHours': totalHours,
        'totalShifts': totalShifts,
        'averageHoursPerShift': totalShifts > 0 ? totalHours / totalShifts : 0,
        'shiftTypeCounts': shiftTypeCounts,
        'locationCounts': locationCounts,
      };
    } catch (e) {
      throw Exception('Failed to get schedule statistics: $e');
    }
  }
}