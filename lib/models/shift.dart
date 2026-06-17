import 'package:cloud_firestore/cloud_firestore.dart';

class Shift {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime date; // date portion
  final DateTime startTime; // full DateTime
  final DateTime endTime;   // full DateTime
  final String role;
  final String department;
  final String? location;
  final String? notes;
  final String status; // scheduled | completed | in_progress, etc.

  Shift({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.role,
    required this.department,
    this.location,
    this.notes,
    this.status = 'scheduled',
  });

  /// Robust parser supporting Timestamp or HH:mm strings for start/end
  factory Shift.fromMap(Map<String, dynamic> map, String id) {
    final DateTime date = (map['date'] is Timestamp)
        ? (map['date'] as Timestamp).toDate()
        : DateTime.tryParse(map['date']?.toString() ?? '') ?? DateTime.now();

    DateTime combine(DateTime d, dynamic t) {
      if (t is Timestamp) return t.toDate();
      final String s = t?.toString() ?? '';
      final parts = s.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        return DateTime(d.year, d.month, d.day, h, m);
      }
      // Fallback to start/end of day
      return DateTime(d.year, d.month, d.day);
    }

    final DateTime startTime = combine(date, map['startTime']);
    final DateTime endTime = combine(date, map['endTime']);

    return Shift(
      id: id,
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      date: DateTime(date.year, date.month, date.day),
      startTime: startTime,
      endTime: endTime,
      role: map['role'] ?? '',
      department: map['department'] ?? '',
      location: map['location'],
      notes: map['notes'],
      status: map['status'] ?? 'scheduled',
    );
  }

  Map<String, dynamic> toMap() {
    String fmt(DateTime dt) =>
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return {
      'staffId': staffId,
      'staffName': staffName,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'startTime': fmt(startTime),
      'endTime': fmt(endTime),
      'role': role,
      'department': department,
      'location': location,
      'notes': notes,
      'status': status,
    };
  }
}

