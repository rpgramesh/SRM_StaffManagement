import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../services/auth_service.dart';

// Firebase-ready Data Models
class StaffMember {
  final String id;
  final String name;
  final String role;
  final String department;
  final String email;
  final String phone;
  final bool isActive;
  final String? photoUrl;

  StaffMember({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.email,
    required this.phone,
    this.isActive = true,
    this.photoUrl,
  });

  factory StaffMember.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffMember(
      id: doc.id,
      name: data['name'] ?? '',
      role: data['role'] ?? '',
      department: data['department'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      isActive: data['isActive'] ?? true,
      photoUrl: data['photoUrl'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      'department': department,
      'email': email,
      'phone': phone,
      'isActive': isActive,
      'photoUrl': photoUrl,
    };
  }

  factory StaffMember.fromJson(Map<String, dynamic> json) {
    return StaffMember(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      department: json['department'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      isActive: json['isActive'] ?? true,
      photoUrl: json['photoUrl'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
        'department': department,
        'email': email,
        'phone': phone,
        'isActive': isActive,
        'photoUrl': photoUrl,
      };

  StaffMember copyWith({
    String? id,
    String? name,
    String? role,
    String? department,
    String? email,
    String? phone,
    bool? isActive,
    String? photoUrl,
  }) {
    return StaffMember(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      isActive: isActive ?? this.isActive,
      photoUrl: photoUrl ?? this.photoUrl,
    );
  }
  }


class StaffManagementAppScreen extends StatefulWidget {
  const StaffManagementAppScreen({super.key});

  @override
  State<StaffManagementAppScreen> createState() => _StaffManagementAppScreenState();
}

class _StaffManagementAppScreenState extends State<StaffManagementAppScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'create_staff':
                  Navigator.pushNamed(context, '/staff-registration');
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'create_staff',
                child: ListTile(
                  leading: Icon(Icons.person_add),
                  title: Text('Create Staff Account'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout),
                  title: Text('Logout'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.dashboard,
              size: 80,
              color: Colors.blue,
            ),
            SizedBox(height: 16),
            Text(
              'Staff Management Dashboard',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Welcome to the staff management system',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Clear admin authentication data
      try {
        final authService = AuthService();
        await authService.signOut();
      } catch (e) {
        print('Error during admin logout: $e');
      }
      
      // Navigate to main screen
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/',
          (route) => false,
        );
      }
    }
  }
}
class StaffShift {
  final String id;
  final String staffId;
  final String staffName;
  final DateTime date;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final String role;
  final String department;
  final String notes;
  final String status;

  StaffShift({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.role,
    required this.department,
    required this.notes,
    this.status = 'scheduled',
  });

  factory StaffShift.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StaffShift(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      startTime: TimeOfDay(
        hour: int.parse((data['startTime'] ?? '09:00').split(':')[0]),
        minute: int.parse((data['startTime'] ?? '09:00').split(':')[1]),
      ),
      endTime: TimeOfDay(
        hour: int.parse((data['endTime'] ?? '17:00').split(':')[0]),
        minute: int.parse((data['endTime'] ?? '17:00').split(':')[1]),
      ),
      role: data['role'] ?? '',
      department: data['department'] ?? '',
      notes: data['notes'] ?? '',
      status: data['status'] ?? 'scheduled',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'date': Timestamp.fromDate(date),
      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'role': role,
      'department': department,
      'notes': notes,
      'status': status,
    };
  }

  factory StaffShift.fromJson(Map<String, dynamic> json) {
    return StaffShift(
      id: json['id'] ?? '',
      staffId: json['staffId'] ?? '',
      staffName: json['staffName'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      startTime: TimeOfDay(
        hour: int.parse((json['startTime'] ?? '09:00').split(':')[0]),
        minute: int.parse((json['startTime'] ?? '09:00').split(':')[1])
      ),
      endTime: TimeOfDay(
        hour: int.parse((json['endTime'] ?? '17:00').split(':')[0]),
        minute: int.parse((json['endTime'] ?? '17:00').split(':')[1])
      ),
      role: json['role'] ?? '',
      department: json['department'] ?? '',
      notes: json['notes'] ?? '',
      status: json['status'] ?? 'scheduled',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'date': date.toIso8601String(),
      'startTime': '${startTime.hour.toString().padLeft(2, '0')}:${startTime.minute.toString().padLeft(2, '0')}',
      'endTime': '${endTime.hour.toString().padLeft(2, '0')}:${endTime.minute.toString().padLeft(2, '0')}',
      'role': role,
      'department': department,
      'notes': notes,
      'status': status,
    };
  }

  StaffShift copyWith({
    String? id,
    String? staffId,
    String? staffName,
    DateTime? date,
    TimeOfDay? startTime,
    TimeOfDay? endTime,
    String? role,
    String? department,
    String? notes,
    String? status,
  }) {
    return StaffShift(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      date: date ?? this.date,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      role: role ?? this.role,
      department: department ?? this.department,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }
}

class SwapRequest {
  final String id;
  final String requestingStaffId;
  final String requestingStaffName;
  final String targetStaffId;
  final String targetStaffName;
  final String shiftId;
  final String reason;
  final String status;
  final DateTime timestamp;

  SwapRequest({
    required this.id,
    required this.requestingStaffId,
    required this.requestingStaffName,
    required this.targetStaffId,
    required this.targetStaffName,
    required this.shiftId,
    required this.reason,
    required this.status,
    required this.timestamp,
  });

  factory SwapRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SwapRequest(
      id: doc.id,
      requestingStaffId: data['requestingStaffId'] ?? '',
      requestingStaffName: data['requestingStaffName'] ?? '',
      targetStaffId: data['targetStaffId'] ?? '',
      targetStaffName: data['targetStaffName'] ?? '',
      shiftId: data['shiftId'] ?? '',
      reason: data['reason'] ?? '',
      status: data['status'] ?? 'pending',
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'requestingStaffId': requestingStaffId,
      'requestingStaffName': requestingStaffName,
      'targetStaffId': targetStaffId,
      'targetStaffName': targetStaffName,
      'shiftId': shiftId,
      'reason': reason,
      'status': status,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    return SwapRequest(
      id: json['id'] ?? '',
      requestingStaffId: json['requestingStaffId'] ?? '',
      requestingStaffName: json['requestingStaffName'] ?? '',
      targetStaffId: json['targetStaffId'] ?? '',
      targetStaffName: json['targetStaffName'] ?? '',
      shiftId: json['shiftId'] ?? '',
      reason: json['reason'] ?? '',
      status: json['status'] ?? 'pending',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'requestingStaffId': requestingStaffId,
        'requestingStaffName': requestingStaffName,
        'targetStaffId': targetStaffId,
        'targetStaffName': targetStaffName,
        'shiftId': shiftId,
        'reason': reason,
        'status': status,
        'timestamp': timestamp.toIso8601String(),
      };

  SwapRequest copyWith({
    String? id,
    String? requestingStaffId,
    String? requestingStaffName,
    String? targetStaffId,
    String? targetStaffName,
    String? shiftId,
    String? reason,
    String? status,
    DateTime? timestamp,
  }) {
    return SwapRequest(
      id: id ?? this.id,
      requestingStaffId: requestingStaffId ?? this.requestingStaffId,
      requestingStaffName: requestingStaffName ?? this.requestingStaffName,
      targetStaffId: targetStaffId ?? this.targetStaffId,
      targetStaffName: targetStaffName ?? this.targetStaffName,
      shiftId: shiftId ?? this.shiftId,
      reason: reason ?? this.reason,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}

class CheckInOut {
  final String id;
  final String staffId;
  final String staffName;
  final String shiftId;
  final DateTime checkInTime;
  final DateTime? checkOutTime;
  final bool isLate;
  final DateTime timestamp;
  final String type;

  CheckInOut({
    required this.id,
    required this.staffId,
    required this.staffName,
    required this.shiftId,
    required this.checkInTime,
    this.checkOutTime,
    this.isLate = false,
    required this.timestamp,
    required this.type,
  });

  factory CheckInOut.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CheckInOut(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      staffName: data['staffName'] ?? '',
      shiftId: data['shiftId'] ?? '',
      checkInTime: (data['checkInTime'] as Timestamp).toDate(),
      checkOutTime: data['checkOutTime'] != null ? (data['checkOutTime'] as Timestamp).toDate() : null,
      isLate: data['isLate'] ?? false,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      type: data['type'] ?? 'check_in',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'staffName': staffName,
      'shiftId': shiftId,
      'checkInTime': Timestamp.fromDate(checkInTime),
      'checkOutTime': checkOutTime != null ? Timestamp.fromDate(checkOutTime!) : null,
      'isLate': isLate,
      'timestamp': Timestamp.fromDate(timestamp),
      'type': type,
    };
  }

  factory CheckInOut.fromJson(Map<String, dynamic> json) {
    return CheckInOut(
      id: json['id'] ?? '',
      staffId: json['staffId'] ?? '',
      staffName: json['staffName'] ?? '',
      shiftId: json['shiftId'] ?? '',
      checkInTime: DateTime.parse(json['checkInTime'] ?? DateTime.now().toIso8601String()),
      checkOutTime: json['checkOutTime'] != null ? DateTime.parse(json['checkOutTime']) : null,
      isLate: json['isLate'] ?? false,
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
      type: json['type'] ?? 'check_in',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'staffName': staffName,
      'shiftId': shiftId,
      'checkInTime': checkInTime.toIso8601String(),
      'checkOutTime': checkOutTime?.toIso8601String(),
      'isLate': isLate,
      'timestamp': timestamp.toIso8601String(),
      'type': type,
    };
  }

  CheckInOut copyWith({
    String? id,
    String? staffId,
    String? staffName,
    String? shiftId,
    DateTime? checkInTime,
    DateTime? checkOutTime,
    bool? isLate,
    DateTime? timestamp,
    String? type,
  }) {
    return CheckInOut(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      staffName: staffName ?? this.staffName,
      shiftId: shiftId ?? this.shiftId,
      checkInTime: checkInTime ?? this.checkInTime,
      checkOutTime: checkOutTime ?? this.checkOutTime,
      isLate: isLate ?? this.isLate,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
    );
  }
}

class AppNotification {
  final String id;
  final String staffId;
  final String title;
  final String message;
  final String type;
  final bool isRead;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.staffId,
    required this.title,
    required this.message,
    required this.type,
    this.isRead = false,
    required this.payload,
    required this.timestamp,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      staffId: data['staffId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      type: data['type'] ?? 'info',
      isRead: data['isRead'] ?? false,
      payload: Map<String, dynamic>.from(data['payload'] ?? {}),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'staffId': staffId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'payload': payload,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] ?? '',
      staffId: json['staffId'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      type: json['type'] ?? 'info',
      isRead: json['isRead'] ?? false,
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'staffId': staffId,
      'title': title,
      'message': message,
      'type': type,
      'isRead': isRead,
      'payload': payload,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  AppNotification copyWith({
    String? id,
    String? staffId,
    String? title,
    String? message,
    String? type,
    bool? isRead,
    Map<String, dynamic>? payload,
    DateTime? timestamp,
  }) {
    return AppNotification(
      id: id ?? this.id,
      staffId: staffId ?? this.staffId,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      payload: payload ?? this.payload,
      timestamp: timestamp ?? this.timestamp,
    );
  }
}