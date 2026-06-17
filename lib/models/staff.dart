import 'package:cloud_firestore/cloud_firestore.dart';

class Staff {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String department;
  final double hourlyRate;
  final double? salary;
  final DateTime hireDate;
  final bool isActive;
  final String? profileImage;
  final String? emergencyContact;
  final String? address;
  final int? workHoursPerWeek;
  final String? shiftPreference;
  final Map<String, dynamic>? workingHours;
  final List<String>? skills;
  final DateTime? lastCheckIn;
  final DateTime? lastCheckOut;
  final double totalHoursWorked;
  final int shiftsCompleted;
  final String? pin; // Added PIN field

  Staff({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.department,
    required this.hourlyRate,
    this.salary,
    required this.hireDate,
    this.isActive = true,
    this.profileImage,
    this.emergencyContact,
    this.address,
    this.workHoursPerWeek,
    this.shiftPreference,
    this.workingHours,
    this.skills,
    this.lastCheckIn,
    this.lastCheckOut,
    this.totalHoursWorked = 0.0,
    this.shiftsCompleted = 0,
    this.pin, // Added PIN parameter
  });

  factory Staff.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Staff(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: data['role'] ?? '',
      department: data['department'] ?? '',
      hourlyRate: (data['hourlyRate'] ?? 0.0).toDouble(),
      salary: data['salary']?.toDouble(),
      hireDate: data['hireDate'] != null ? (data['hireDate'] as Timestamp).toDate() : DateTime.now(),
      isActive: data['isActive'] ?? true,
      profileImage: data['profileImage'],
      emergencyContact: data['emergencyContact'],
      address: data['address'],
      workHoursPerWeek: data['workHoursPerWeek'],
      shiftPreference: data['shiftPreference'],
      workingHours: data['workingHours'],
      skills: List<String>.from(data['skills'] ?? []),
      lastCheckIn: data['lastCheckIn'] != null 
          ? (data['lastCheckIn'] as Timestamp).toDate() 
          : null,
      lastCheckOut: data['lastCheckOut'] != null 
          ? (data['lastCheckOut'] as Timestamp).toDate() 
          : null,
      totalHoursWorked: (data['totalHoursWorked'] ?? 0.0).toDouble(),
      shiftsCompleted: data['shiftsCompleted'] ?? 0,
      pin: data['pin'], // Added PIN mapping
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
      'department': department,
      'hourlyRate': hourlyRate,
      'salary': salary,
      'hireDate': Timestamp.fromDate(hireDate),
      'isActive': isActive,
      'profileImage': profileImage,
      'emergencyContact': emergencyContact,
      'address': address,
      'workHoursPerWeek': workHoursPerWeek,
      'shiftPreference': shiftPreference,
      'workingHours': workingHours,
      'skills': skills,
      'lastCheckIn': lastCheckIn != null 
          ? Timestamp.fromDate(lastCheckIn!) 
          : null,
      'lastCheckOut': lastCheckOut != null 
          ? Timestamp.fromDate(lastCheckOut!) 
          : null,
      'totalHoursWorked': totalHoursWorked,
      'shiftsCompleted': shiftsCompleted,
      'pin': pin, // Added PIN to Firestore
    };
  }

  Staff copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    String? department,
    double? hourlyRate,
    double? salary,
    DateTime? hireDate,
    bool? isActive,
    String? profileImage,
    String? emergencyContact,
    String? address,
    int? workHoursPerWeek,
    String? shiftPreference,
    Map<String, dynamic>? workingHours,
    List<String>? skills,
    DateTime? lastCheckIn,
    DateTime? lastCheckOut,
    double? totalHoursWorked,
    int? shiftsCompleted,
    String? pin, // Added PIN to copyWith
  }) {
    return Staff(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      department: department ?? this.department,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      salary: salary ?? this.salary,
      hireDate: hireDate ?? this.hireDate,
      isActive: isActive ?? this.isActive,
      profileImage: profileImage ?? this.profileImage,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      address: address ?? this.address,
      workHoursPerWeek: workHoursPerWeek ?? this.workHoursPerWeek,
      shiftPreference: shiftPreference ?? this.shiftPreference,
      workingHours: workingHours ?? this.workingHours,
      skills: skills ?? this.skills,
      lastCheckIn: lastCheckIn ?? this.lastCheckIn,
      lastCheckOut: lastCheckOut ?? this.lastCheckOut,
      totalHoursWorked: totalHoursWorked ?? this.totalHoursWorked,
      shiftsCompleted: shiftsCompleted ?? this.shiftsCompleted,
      pin: pin ?? this.pin,
    );
  }
}