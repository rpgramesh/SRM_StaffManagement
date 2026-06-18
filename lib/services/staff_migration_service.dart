import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

import '../services/auth_service.dart';
import '../models/staff.dart';
import '../utils/australian_phone_number.dart';

class StaffMigrationService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _staffCollection = 'staff';

  static String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    return sha256.convert(bytes).toString();
  }

  static bool _isValidPin(String pin) {
    return RegExp(r'^\d{6}$').hasMatch(pin);
  }

  static String? generateDefaultPinFromPhone(String phoneNumber) {
    final normalized =
        AustralianPhoneNumber.normalizeToStorageFormat(phoneNumber);
    if (normalized == null) {
      return null;
    }

    final digits = normalized.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) {
      return null;
    }

    return digits.length >= 6
        ? digits.substring(digits.length - 6)
        : digits.padLeft(6, '0');
  }

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
          final defaultPin = generateDefaultPinFromPhone(staff.phone);
          if (defaultPin == null) {
            throw Exception(
              'Staff must have a valid Australian phone number before migration.',
            );
          }

          await setStaffPin(
            staffId: doc.id,
            pin: defaultPin,
            overwriteExisting: false,
          );

          print(
              'Added PIN to staff ${staff.name} (${staff.phone}) with PIN: $defaultPin');
          migratedCount++;
        } catch (e) {
          print('Error migrating staff ${doc.id}: $e');
        }
      }

      print(
          'Migration completed: $migratedCount created, $skippedCount skipped');
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
    return setStaffPin(
      staffId: staffId,
      pin: pin,
      overwriteExisting: false,
    );
  }

  /// Create or reset the PIN for a specific staff member.
  static Future<String?> setStaffPin({
    required String staffId,
    required String pin,
    bool overwriteExisting = true,
  }) async {
    try {
      // Get staff details from main collection
      final staffDoc =
          await _firestore.collection(_staffCollection).doc(staffId).get();

      if (!staffDoc.exists) {
        throw Exception('Staff not found');
      }

      final staff = Staff.fromFirestore(staffDoc);

      if (staff.phone.trim().isEmpty ||
          AustralianPhoneNumber.normalizeToStorageFormat(staff.phone) == null) {
        throw Exception(
          'Staff must have a valid Australian phone number before setting a PIN.',
        );
      }

      if (!_isValidPin(pin)) {
        throw Exception('PIN must be exactly 6 digits.');
      }

      // Check if staff already has a PIN
      if (!overwriteExisting && staff.pin != null && staff.pin!.isNotEmpty) {
        throw Exception('Staff already has authentication PIN');
      }

      // Update the staff record with PIN
      await staffDoc.reference.update({
        'pin': _hashPin(pin),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return staffId;
    } catch (e) {
      print('Error adding PIN to staff: $e');
      rethrow;
    }
  }

  static Future<void> deleteStaffAccount(String staffId) async {
    try {
      final staffDoc =
          await _firestore.collection(_staffCollection).doc(staffId).get();

      if (!staffDoc.exists) {
        throw Exception('Staff not found');
      }

      await staffDoc.reference.delete();
    } catch (e) {
      print('Error deleting staff account: $e');
      rethrow;
    }
  }

  /// Get staff account details by phone number
  static Future<Map<String, dynamic>?> getStaffAccount(
      String phoneNumber) async {
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
      staffList.sort((a, b) =>
          (a['name'] as String? ?? '').compareTo(b['name'] as String? ?? ''));

      return staffList;
    } catch (e) {
      print('Error getting staff accounts: $e');
      return [];
    }
  }
}
