import 'package:cloud_firestore/cloud_firestore.dart';

enum LeaveType {
  sick,
  vacation,
  personal,
  emergency,
  maternity,
  paternity,
  bereavement,
  other,
}

enum LeaveStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class LeaveRequest {
  final String id;
  final String staffId;
  final String staffName;
  final LeaveType leaveType;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveStatus status;
  final String? approvedBy;
  final DateTime? approvedAt;
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<String>? attachments; // URLs to supporting documents
  final bool isHalfDay;
  final String? halfDayPeriod; // 'morning' or 'afternoon'

  LeaveRequest({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = LeaveStatus.pending,
    this.approvedBy,
    this.approvedAt,
    this.rejectionReason,
    required this.createdAt,
    this.updatedAt,
    this.attachments,
    this.isHalfDay = false,
    this.halfDayPeriod,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'leaveType': leaveType.name,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'reason': reason,
      'status': status.name,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt != null ? Timestamp.fromDate(approvedAt!) : null,
      'rejectionReason': rejectionReason,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'attachments': attachments,
      'isHalfDay': isHalfDay,
      'halfDayPeriod': halfDayPeriod,
    };
  }

  // Create from Firestore Map
  factory LeaveRequest.fromMap(Map<String, dynamic> map, String id) {
    return LeaveRequest(
      id: id,
      staffId: map['staffId'] ?? '',
      staffName: map['staffName'] ?? '',
      leaveType: LeaveType.values.firstWhere(
        (e) => e.name == map['leaveType'],
        orElse: () => LeaveType.other,
      ),
      startDate: (map['startDate'] as Timestamp).toDate(),
      endDate: (map['endDate'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
      status: LeaveStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => LeaveStatus.pending,
      ),
      approvedBy: map['approvedBy'],
      approvedAt: map['approvedAt'] != null 
          ? (map['approvedAt'] as Timestamp).toDate() 
          : null,
      rejectionReason: map['rejectionReason'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: map['updatedAt'] != null 
          ? (map['updatedAt'] as Timestamp).toDate() 
          : null,
      attachments: map['attachments'] != null 
          ? List<String>.from(map['attachments']) 
          : null,
      isHalfDay: map['isHalfDay'] ?? false,
      halfDayPeriod: map['halfDayPeriod'],
    );
  }

  // Create a copy with updated fields
  LeaveRequest copyWith({
    String? id,
    String? staffId,
    String? staffName,
    LeaveType? leaveType,
    DateTime? startDate,
    DateTime? endDate,
    String? reason,
    LeaveStatus? status,
    String? approvedBy,
    DateTime? approvedAt,
    String? rejectionReason,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? attachments,
    bool? isHalfDay,
    String? halfDayPeriod,
  }) {
    return LeaveRequest(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      leaveType: leaveType ?? this.leaveType,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      attachments: attachments ?? this.attachments,
      isHalfDay: isHalfDay ?? this.isHalfDay,
      halfDayPeriod: halfDayPeriod ?? this.halfDayPeriod,
    );
  }

  // Calculate total leave days
  int get totalDays {
    if (isHalfDay) return 1;
    return endDate.difference(startDate).inDays + 1;
  }

  // Check if leave is current/active
  bool get isActive {
    final now = DateTime.now();
    return status == LeaveStatus.approved &&
           now.isAfter(startDate.subtract(const Duration(days: 1))) &&
           now.isBefore(endDate.add(const Duration(days: 1)));
  }

  // Check if leave is upcoming
  bool get isUpcoming {
    return status == LeaveStatus.approved && 
           startDate.isAfter(DateTime.now());
  }

  // Get leave type display name
  String get leaveTypeDisplayName {
    switch (leaveType) {
      case LeaveType.sick:
        return 'Sick Leave';
      case LeaveType.vacation:
        return 'Vacation';
      case LeaveType.personal:
        return 'Personal Leave';
      case LeaveType.emergency:
        return 'Emergency Leave';
      case LeaveType.maternity:
        return 'Maternity Leave';
      case LeaveType.paternity:
        return 'Paternity Leave';
      case LeaveType.bereavement:
        return 'Bereavement Leave';
      case LeaveType.other:
        return 'Other';
    }
  }

  // Get status display name
  String get statusDisplayName {
    switch (status) {
      case LeaveStatus.pending:
        return 'Pending';
      case LeaveStatus.approved:
        return 'Approved';
      case LeaveStatus.rejected:
        return 'Rejected';
      case LeaveStatus.cancelled:
        return 'Cancelled';
    }
  }

  @override
  String toString() {
    return 'LeaveRequest(id: $id, staffName: $staffName, leaveType: $leaveType, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LeaveRequest &&
        other.id == id &&
        other.staffId == staffId;
  }

  @override
  int get hashCode {
    return id.hashCode ^ staffId.hashCode;
  }
}