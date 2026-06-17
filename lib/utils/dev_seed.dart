import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../config/app_config.dart';

/// Development-only data seeding for the Firestore emulator.
Future<void> seedDevData() async {
  if (AppConfig.isProduction) return;
  // Only seed when running locally and using the emulator.
  try {
    // Use a meta collection to avoid reseeding repeatedly.
    final metaRef = FirebaseFirestore.instance.collection('__meta__').doc('seed_state');
    final metaSnap = await metaRef.get();
    if (metaSnap.exists) {
      return; // Already seeded
    }

    final db = FirebaseFirestore.instance;

    // Create sample staff
    final staffBatch = db.batch();
    final staffARef = db.collection('staff').doc();
    final staffBRef = db.collection('staff').doc();
    final staffCRef = db.collection('staff').doc();

    staffBatch.set(staffARef, {
      'name': 'Alice Johnson',
      'email': 'alice@example.com',
      'phone': '+1-202-555-0147',
      'role': 'staff',
      'department': 'Front Desk',
      'hourlyRate': 22.5,
      'salary': 0.0,
      'hireDate': Timestamp.fromDate(DateTime(2023, 6, 1)),
      'isActive': true,
      'workHoursPerWeek': 40,
      'skills': ['customer_service'],
      'pin': '1234',
    });

    staffBatch.set(staffBRef, {
      'name': 'Brian Lee',
      'email': 'brian@example.com',
      'phone': '+1-202-555-0193',
      'role': 'staff',
      'department': 'Kitchen',
      'hourlyRate': 25.0,
      'salary': 0.0,
      'hireDate': Timestamp.fromDate(DateTime(2024, 2, 14)),
      'isActive': true,
      'workHoursPerWeek': 38,
      'skills': ['prep', 'line'],
      'pin': '5678',
    });

    staffBatch.set(staffCRef, {
      'name': 'Chandra Patel',
      'email': 'chandra@example.com',
      'phone': '+1-202-555-0176',
      'role': 'manager',
      'department': 'Operations',
      'hourlyRate': 35.0,
      'salary': 0.0,
      'hireDate': Timestamp.fromDate(DateTime(2022, 11, 10)),
      'isActive': true,
      'workHoursPerWeek': 45,
      'skills': ['scheduling', 'inventory'],
      'pin': '9012',
    });

    await staffBatch.commit();

    // Helper to add attendance docs
    Future<void> addAttendance({
      required DocumentReference staffRef,
      required String staffName,
      required DateTime checkIn,
      DateTime? checkOut,
      String status = 'checked_out',
      String? notes,
    }) async {
      final double durationHours = checkOut != null
          ? checkOut.difference(checkIn).inMinutes / 60.0
          : 0.0;
      await db.collection('staff_attendance').add({
        'staffId': staffRef.id,
        'staffName': staffName,
        'date': Timestamp.fromDate(DateTime(checkIn.year, checkIn.month, checkIn.day)),
        'checkInTime': Timestamp.fromDate(checkIn),
        'checkOutTime': checkOut != null ? Timestamp.fromDate(checkOut) : null,
        'duration': durationHours,
        'status': checkOut == null ? 'checked_in' : status,
        'notes': notes,
      });
    }

    final now = DateTime.now();
    // Seed last 3 days for Alice
    await addAttendance(
      staffRef: staffARef,
      staffName: 'Alice Johnson',
      checkIn: DateTime(now.year, now.month, now.day - 3, 9, 0),
      checkOut: DateTime(now.year, now.month, now.day - 3, 17, 15),
      notes: 'Front desk shift',
    );
    await addAttendance(
      staffRef: staffARef,
      staffName: 'Alice Johnson',
      checkIn: DateTime(now.year, now.month, now.day - 2, 9, 30),
      checkOut: DateTime(now.year, now.month, now.day - 2, 18, 0),
    );
    await addAttendance(
      staffRef: staffARef,
      staffName: 'Alice Johnson',
      checkIn: DateTime(now.year, now.month, now.day - 1, 22, 0),
      checkOut: DateTime(now.year, now.month, now.day, 6, 30),
      notes: 'Overnight coverage',
    );

    // Seed Brian with a missing checkout (in-progress)
    await addAttendance(
      staffRef: staffBRef,
      staffName: 'Brian Lee',
      checkIn: DateTime(now.year, now.month, now.day, 8, 45),
      checkOut: null,
      status: 'checked_in',
      notes: 'Currently working',
    );

    // Seed Chandra with two normal days
    await addAttendance(
      staffRef: staffCRef,
      staffName: 'Chandra Patel',
      checkIn: DateTime(now.year, now.month, now.day - 1, 10, 0),
      checkOut: DateTime(now.year, now.month, now.day - 1, 19, 0),
    );
    await addAttendance(
      staffRef: staffCRef,
      staffName: 'Chandra Patel',
      checkIn: DateTime(now.year, now.month, now.day - 2, 11, 15),
      checkOut: DateTime(now.year, now.month, now.day - 2, 20, 5),
    );

    // Mark as seeded
    await metaRef.set({
      'seeded': true,
      'seededAt': Timestamp.now(),
      'version': 'v1',
      'platform': kIsWeb ? 'web' : 'native',
    });
  } catch (e) {
    // Non-fatal in dev; leave app running even if seed fails
    debugPrint('Dev seed failed: $e');
  }
}

