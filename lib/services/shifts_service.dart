import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:staff_management_app/models/shift.dart';

class ShiftsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String _collection = 'shifts';

  Stream<List<Shift>> getShiftsForStaffByDateRange(
    String staffId,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    Query query = _db
        .collection(_collection)
        .where('staffId', isEqualTo: staffId)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));

    return query.snapshots().map((snapshot) {
      final shifts = snapshot.docs
          .map((doc) => Shift.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      return shifts;
    });
  }

  Stream<List<Shift>> getDepartmentShifts(
    String department,
    DateTime startDate,
    DateTime endDate,
  ) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59);

    Query query = _db
        .collection(_collection)
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(end));

    if (department.isNotEmpty && department != 'All') {
      query = query.where('department', isEqualTo: department);
    }

    return query.snapshots().map((snapshot) {
      final shifts = snapshot.docs
          .map((doc) => Shift.fromMap(doc.data() as Map<String, dynamic>, doc.id))
          .toList();
      shifts.sort((a, b) => a.startTime.compareTo(b.startTime));
      return shifts;
    });
  }
}

