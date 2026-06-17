import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus {
  present,
  absent,
  late,
  halfDay,
}

class Attendance {
  final String id;
  final String staffId;
  final DateTime date;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;
  final double duration;
  final String status;
  final String? notes;
  final String? checkInLocation;
  final String? checkOutLocation;
  final String? checkInIp;
  final String? checkOutIp;
  final bool? isWithinGeofence;
  final bool? archived;

  Attendance({
    required this.id,
    required this.staffId,
    required this.date,
    this.checkInTime,
    this.checkOutTime,
    this.duration = 0.0,
    this.status = 'checked_in',
    this.notes,
    this.checkInLocation,
    this.checkOutLocation,
    this.checkInIp,
    this.checkOutIp,
    this.isWithinGeofence,
    this.archived,
  });

  // Create from Firestore Map
  factory Attendance.fromMap(Map<String, dynamic> map, String id) {
    return Attendance(
      id: id,
      staffId: map['staffId'] ?? '',
      date: map['date'] != null 
          ? (map['date'] as Timestamp).toDate() 
          : DateTime.now(),
      checkInTime: map['checkInTime'] != null 
          ? (map['checkInTime'] as Timestamp).toDate() 
          : null,
      checkOutTime: map['checkOutTime'] != null 
          ? (map['checkOutTime'] as Timestamp).toDate() 
          : null,
      duration: (map['duration'] ?? map['totalHours'] ?? 0.0).toDouble(),
      status: map['status'] ?? 'checked_in',
      notes: map['notes'],
      checkInLocation: map['checkInLocation'],
      checkOutLocation: map['checkOutLocation'],
      checkInIp: map['checkInIp'],
      checkOutIp: map['checkOutIp'],
      isWithinGeofence: map['isWithinGeofence'],
      archived: map['archived'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'checkInTime': checkInTime != null ? Timestamp.fromDate(checkInTime!) : null,
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'duration': duration,
      'status': status,
      'notes': notes,
      'checkInLocation': checkInLocation,
      'checkOutLocation': checkOutLocation,
      'checkInIp': checkInIp,
      'checkOutIp': checkOutIp,
      'isWithinGeofence': isWithinGeofence,
      'archived': archived ?? false,
      'createdAt': Timestamp.now(),
    };
  }

  Attendance copyWith({
    String? id,
    String? staffId,
    DateTime? date,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    double? duration,
    String? status,
    String? notes,
    String? checkInLocation,
    String? checkOutLocation,
    String? checkInIp,
    String? checkOutIp,
    bool? isWithinGeofence,
    bool? archived,
  }) {
    return Attendance(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      date: date ?? this.date,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      duration: duration ?? this.duration,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      checkInLocation: checkInLocation ?? this.checkInLocation,
      checkOutLocation: checkOutLocation ?? this.checkOutLocation,
      checkInIp: checkInIp ?? this.checkInIp,
      checkOutIp: checkOutIp ?? this.checkOutIp,
      isWithinGeofence: isWithinGeofence ?? this.isWithinGeofence,
      archived: archived ?? this.archived,
    );
  }

  bool get isCheckedIn => checkInTime != null && checkOutTime == null;

  String statusDisplayText() {
    switch (status) {
      case 'checked_in':
        return 'Checked In';
      case 'completed':
        return 'Completed';
      case 'present':
        return 'Present';
      case 'late':
        return 'Late';
      case 'absent':
        return 'Absent';
      case 'halfDay':
        return 'Half Day';
      default:
        return status;
    }
  }

  // Backward-compatible: expose a getter expected by tests
  String get formattedDuration => formattedDurationString();

  // Method retained for existing call sites
  String formattedDurationString() {
    final minutes = (duration * 60).round();
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }
}
