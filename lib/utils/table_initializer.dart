import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../firebase_options.dart';

class TableInitializer {
  static Future<void> initializeTables() async {
    try {
      // Initialize Firebase if not already initialized
      try {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } catch (e) {
        // Firebase might already be initialized
        print('Firebase already initialized or error: $e');
      }

      final FirebaseFirestore db = FirebaseFirestore.instance;

      // Check if tables already exist
      final tablesSnapshot = await db.collection('tables').limit(1).get();
      if (tablesSnapshot.docs.isNotEmpty) {
        print('Tables already exist, skipping initialization');
        return;
      }

      print('Initializing sample tables...');

      // Add sample tables (10 tables)
      final List<Map<String, dynamic>> tables = [];
      for (int i = 1; i <= 10; i++) {
        tables.add({
          'tableNumber': i,
          'capacity': i <= 5 ? 4 : 6, // Tables 1-5: 4 seats, Tables 6-10: 6 seats
          'isOccupied': false,
          'status': 'available', // Alternative field for compatibility
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      // Add tables to Firestore
      for (final table in tables) {
        await db.collection('tables').add(table);
      }
      
      print('Successfully initialized ${tables.length} sample tables');
      print('Table numbers: 1-10');
      print('All tables are currently marked as available');
    } catch (e) {
      print('Error initializing tables: $e');
      rethrow;
    }
  }

  static Future<void> checkTableStatus() async {
    try {
      final FirebaseFirestore db = FirebaseFirestore.instance;
      final tablesSnapshot = await db.collection('tables').get();
      
      if (tablesSnapshot.docs.isEmpty) {
        print('No tables found in Firestore');
        return;
      }

      print('Found ${tablesSnapshot.docs.length} tables:');
      for (final doc in tablesSnapshot.docs) {
        final data = doc.data();
        print('Table ${data['tableNumber']}: ${data['isOccupied'] == true ? 'Occupied' : 'Available'}');
      }
    } catch (e) {
      print('Error checking table status: $e');
    }
  }
}