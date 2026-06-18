import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'lib/firebase_options.dart';

const targetPhone = '+61481904384';

void main() async {
  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  print('Checking staff record for phone $targetPhone...');

  try {
    // Query staff collection for the specific phone number
    final querySnapshot = await firestore
        .collection('staff')
        .where('phone', isEqualTo: targetPhone)
        .get();

    if (querySnapshot.docs.isEmpty) {
      print('❌ No staff found with phone $targetPhone');

      // List current staff records to inspect available phone formats.
      final allStaff = await firestore.collection('staff').get();
      print('\n📋 All staff records:');
      for (final doc in allStaff.docs) {
        final data = doc.data();
        print('  - ID: ${doc.id}');
        print('    Name: ${data['name']}');
        print('    Phone: ${data['phone']}');
        print('    PIN: ${data['pin']}');
        print('    Active: ${data['isActive']}');
        print('    ---');
      }
    } else {
      print('✅ Found staff with phone $targetPhone');
      final staffDoc = querySnapshot.docs.first;
      final data = staffDoc.data();
      print('Staff Data:');
      print('  - ID: ${staffDoc.id}');
      print('  - Name: ${data['name']}');
      print('  - Phone: ${data['phone']}');
      print(
          '  - PIN: ${data['pin']} (length: ${data['pin']?.toString().length ?? 0})');
      print('  - Active: ${data['isActive']}');
      print('  - Role: ${data['role']}');
      print('  - Department: ${data['department']}');
    }
  } catch (e) {
    print('❌ Error checking staff: $e');
  }
}
