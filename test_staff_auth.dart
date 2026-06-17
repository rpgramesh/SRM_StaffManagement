import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;
  
  print('Creating test staff record for +919843095986...');
  
  try {
    // Create or update staff record with 6-digit PIN
    final staffData = {
      'name': 'Test Staff',
      'phone': '+919843095986',
      'email': 'test@example.com',
      'role': 'staff',
      'department': 'general',
      'isActive': true,
      'pin': '095986', // Last 6 digits of phone as PIN
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
        .where('phone', isEqualTo: '+919843095986')
        .get();
    
    if (querySnapshot.docs.isEmpty) {
      // Create new staff record
      final docRef = await firestore.collection('staff').add(staffData);
      print('✅ Created new staff record with ID: ${docRef.id}');
    } else {
      // Update existing staff record
      final doc = querySnapshot.docs.first;
      await doc.reference.update({
        'pin': '095986',
        'isActive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ Updated existing staff record with ID: ${doc.id}');
    }
    
    print('\n🎉 Staff authentication setup complete!');
    print('   Phone: +919843095986');
    print('   PIN: 095986');
    print('\nYou can now test staff login in the app.');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}