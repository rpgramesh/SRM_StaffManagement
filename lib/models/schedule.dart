import 'package:cloud_firestore/cloud_firestore.dart';

enum ShiftType {
  morning,
  afternoon,
  evening,
  night,
  fullDay,
}

class Schedule {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime date;
  final DateTime startTime;
  final DateTime endTime;
  final ShiftType shiftType;
  final String? location;
  final String? notes;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Schedule({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.shiftType,
    this.location,
    this.notes,
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'date': Timestamp.fromDate(date),
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'shiftType': shiftType.name,
      'location': location,
      'notes': notes,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
    };
  }

  // Create from Firestore Map
  factory Schedule.fromMap(Map<String, dynamic> map, String id) {
    return Schedule(
      id: id,
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      date: (map['date'] as Timestamp).toDate(),
      startTime: (map['startTime'] as Timestamp).toDate(),
      endTime: (map['endTime'] as Timestamp).toDate(),
      shiftType: ShiftType.values.firstWhere(
        (e) => e.name == map['shiftType'],
        orElse: () => ShiftType.fullDay,
      ),
      location: map['location'],
      notes: map['notes'],
      isActive: map['isActive'] ?? true,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
    );
  }

  // Create a copy with updated fields
  Schedule copyWith({
    String? id,
    String? staffId,
    String? staffName,
    DateTime? date,
    DateTime? startTime,
    DateTime? endTime,
    ShiftType? shiftType,
    String? location,
    String? notes,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Schedule(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      shiftType: shiftType ?? this.shiftType,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // Calculate shift duration in hours
  double get durationInHours {
    return endTime.difference(startTime).inMinutes / 60.0;
  }

  // Check if schedule is for today
  bool get isToday {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  // Check if schedule is upcoming
  bool get isUpcoming {
    return date.isAfter(DateTime.now());
  }

  @override
  String toString() {
    return 'Schedule(id: $id, staffName: $staffName, date: $date, shiftType: $shiftType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Schedule &&
        other.id == id &&
        other.staffId == staffId &&
        other.date == date;
  }

  @override
  int get hashCode {
    return id.hashCode ^ staffId.hashCode ^ date.hashCode;
  }
}