import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'lib/firebase_options.dart';

const targetPhone = '+61481904384';
const targetPin = '123456';

String hashPin(String pin) {
  final bytes = utf8.encode(pin);
  return sha256.convert(bytes).toString();
}

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  
  print('Creating test staff record for $targetPhone...');
  
  try {
    // Create or update staff record with 6-digit PIN
    final staffData = {
      'name': 'Test Staff',
      'phone': targetPhone,
      'email': 'test@example.com',
      'role': 'admin',
      'department': 'general',
      'isActive': true,
      'pin': hashPin(targetPin),
      'hourlyRate': 15.0,
      'hireDate': FieldValue.serverTimestamp(),
      'totalHoursWorked': 0.0,
      'shiftsCompleted': 0,
      'skills': [],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    // Check if staff already exists
    final querySnapshot = await firestore
        .collection('staff')
        .where('phone', isEqualTo: targetPhone)
        .get();
    
    if (querySnapshot.docs.isEmpty) {
      // Create new staff record
      final docRef = await firestore.collection('staff').add(staffData);
      print('✅ Created new staff record with ID: ${docRef.id}');
    } else {
      // Update existing staff record
      final doc = querySnapshot.docs.first;
      await doc.reference.update({
        'pin': hashPin(targetPin),
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated existing staff record with ID: ${doc.id}');
    }
    
    print('\n🎉 Staff authentication setup complete!');
    print('   Phone: $targetPhone');
    print('   PIN: $targetPin');
    print('\nYou can now test staff login in the app.');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}
