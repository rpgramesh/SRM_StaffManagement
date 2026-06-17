import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';
import '../models/staff.dart';

class StaffMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _staffCollection = 'staff';

  /// Add PINs to existing staff records for authentication
  /// This enables authentication for existing staff members
  static Future<void> migrateStaffToAccounts() async {
    try {
      print('Starting staff migration to accounts...');
      
      // Get all active staff from the main staff collection
      final staffSnapshot = await _firestore
          .collection(_staffCollection)
          .where('isActive', isEqualTo: true)
          .get();
      
      if (staffSnapshot.docs.isEmpty) {
        print('No active staff found to migrate');
        return;
      }
      
      final authService = AuthService();
      int migratedCount = 0;
      int skippedCount = 0;
      
      for (final doc in staffSnapshot.docs) {
        try {
          final staff = Staff.fromFirestore(doc);
          
          // Check if staff already has a PIN
          if (staff.pin != null && staff.pin!.isNotEmpty) {
            print('Staff ${staff.name} (${staff.phone}) already has PIN');
            skippedCount++;
            continue;
          }
          
          // Add default PIN (staff should change this)
          // Using last 6 digits of phone as default PIN, or pad with leading zeros if needed
          final phoneDigits = staff.phone.replaceAll(RegExp(r'[^0-9]'), '');
          final defaultPin = phoneDigits.length >= 6 
              ? phoneDigits.substring(phoneDigits.length - 6)
              : phoneDigits.padLeft(6, '0');
          
          // Update the staff record with PIN
          await doc.reference.update({
            'pin': defaultPin,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          print('Added PIN to staff ${staff.name} (${staff.phone}) with PIN: $defaultPin');
          migratedCount++;
          
        } catch (e) {
          print('Error migrating staff ${doc.id}: $e');
        }
      }
      
      print('Migration completed: $migratedCount created, $skippedCount skipped');
      
    } catch (e) {
      print('Error during staff migration: $e');
      throw Exception('Failed to migrate staff accounts: $e');
    }
  }
  
  /// Add PIN to a specific staff member for authentication
  static Future<String?> createStaffAccount({
    required String staffId,
    required String pin,
  }) async {
    try {
      // Get staff details from main collection
      final staffDoc = await _firestore
          .collection(_staffCollection)
          .doc(staffId)
          .get();
      
      if (!staffDoc.exists) {
        throw Exception('Staff not found');
      }
      
      final staff = Staff.fromFirestore(staffDoc);
      
      // Check if staff already has a PIN
      if (staff.pin != null && staff.pin!.isNotEmpty) {
        throw Exception('Staff already has authentication PIN');
      }
      
      // Update the staff record with PIN
      await staffDoc.reference.update({
        'pin': pin,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      return staffId;
      
    } catch (e) {
      print('Error adding PIN to staff: $e');
      rethrow;
    }
  }
  
  /// Get staff account details by phone number
  static Future<Map<String, dynamic>?> getStaffAccount(String phoneNumber) async {
    try {
      final authService = AuthService();
      return await authService.getStaffByPhone(phoneNumber);
    } catch (e) {
      print('Error getting staff account: $e');
      return null;
    }
  }
  
  /// List all staff accounts
  static Future<List<Map<String, dynamic>>> getAllStaffAccounts() async {
    try {
      final snapshot = await _firestore
          .collection(_staffCollection)
          .where('isActive', isEqualTo: true)
          .get();
      
      final staffList = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return data;
      }).toList();
      
      // Sort by name in ascending order
      staffList.sort((a, b) => (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));
      
      return staffList;
      
    } catch (e) {
      print('Error getting staff accounts: $e');
      return [];
    }
  }
}