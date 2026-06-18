import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import '../utils/australian_phone_number.dart';

// #region debug-point A:reporter
Future<void> _dbgAuth(String hypothesisId, String location, String msg,
    [Map<String, dynamic>? data]) async {
  try {
    const url = 'http://127.0.0.1:7777/event';
    const sessionId = 'firestore-write-failure';
    await http
        .post(Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'sessionId': sessionId,
              'runId': 'pre-fix',
              'hypothesisId': hypothesisId,
              'location': location,
              'msg': msg,
              'data': data ?? <String, dynamic>{},
              'ts': DateTime.now().millisecondsSinceEpoch,
            }))
        .timeout(const Duration(seconds: 1));
  } catch (_) {}
}
// #endregion

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email']);
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'australia-southeast1');
  static const String _staffCollection = 'staff';

  Future<QuerySnapshot<Map<String, dynamic>>> _queryStaffByPhone(
    String phoneNumber, {
    bool activeOnly = true,
  }) async {
    for (final candidate in AustralianPhoneNumber.lookupVariants(phoneNumber)) {
      var query = _firestore
          .collection(_staffCollection)
          .where('phone', isEqualTo: candidate);
      if (activeOnly) {
        query = query.where('isActive', isEqualTo: true);
      }

      final querySnapshot = await query.limit(1).get();
      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot;
      }
    }

    return _firestore
        .collection(_staffCollection)
        .where('phone', isEqualTo: '__no_match__')
        .limit(1)
        .get();
  }

  String _normalizeAustralianPhoneOrThrow(String phoneNumber) {
    final normalized =
        AustralianPhoneNumber.normalizeToStorageFormat(phoneNumber);
    if (normalized == null) {
      throw Exception(AustralianPhoneNumber.submitErrorMessage(
        internationalMode: phoneNumber.trim().startsWith('+61'),
      ));
    }
    return normalized;
  }

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Static method to get current user
  static User? getCurrentUser() {
    return FirebaseAuth.instance.currentUser;
  }

  // Auth state changes stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign in with Google
  Future<User?> signInWithGoogle() async {
    try {
      // For web, use signInSilently first, then fallback to signIn
      if (kIsWeb) {
        // Try silent sign in first
        final GoogleSignInAccount? googleUser =
            await _googleSignIn.signInSilently();
        if (googleUser != null) {
          return await _signInWithGoogleAccount(googleUser);
        }

        // If silent sign in fails, use regular sign in
        final GoogleSignInAccount? googleUserSignIn =
            await _googleSignIn.signIn();
        if (googleUserSignIn != null) {
          return await _signInWithGoogleAccount(googleUserSignIn);
        }
      } else {
        // For mobile, use the regular sign in flow
        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          return await _signInWithGoogleAccount(googleUser);
        }
      }

      // User canceled the sign-in flow
      return null;
    } catch (error) {
      print('Error signing in with Google: $error');
      return null;
    }
  }

  // Helper method to sign in with Google account
  Future<User?> _signInWithGoogleAccount(GoogleSignInAccount googleUser) async {
    try {
      // Obtain the auth details from the Google Sign-In
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential for Firebase
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final UserCredential authResult =
          await _auth.signInWithCredential(credential);
      return authResult.user;
    } catch (error) {
      print('Error signing in with Google account: $error');
      return null;
    }
  }

  // Sign out - handles both admin (Google) and staff (custom token) logout
  Future<void> signOut() async {
    try {
      // Sign out from Google (for admin users)
      await _googleSignIn.signOut();

      // Sign out from Firebase Auth (for both admin and staff)
      await _auth.signOut();

      print('User signed out successfully');
    } catch (error) {
      print('Error signing out: $error');
      rethrow;
    }
  }

  // Sign out admin user specifically
  Future<void> signOutAdmin() async {
    try {
      // Ensure we're signing out from Google
      await _googleSignIn.signOut();
      await _auth.signOut();

      print('Admin signed out successfully');
    } catch (error) {
      print('Error signing out admin: $error');
      rethrow;
    }
  }

  // Sign out staff user specifically
  Future<void> signOutStaff() async {
    try {
      // Staff users don't use Google Sign-In, just Firebase Auth
      await _auth.signOut();

      print('Staff signed out successfully');
    } catch (error) {
      print('Error signing out staff: $error');
      rethrow;
    }
  }

  // Get current user role
  Future<String?> getCurrentUserRole() async {
    try {
      final user = _auth.currentUser;

      if (user != null) {
        // Check if user is admin (has Google provider)
        final providerData = user.providerData;
        final hasGoogleProvider =
            providerData.any((provider) => provider.providerId == 'google.com');

        if (hasGoogleProvider) {
          return 'admin';
        }

        // For staff users, prefer custom claims when available.
        final idTokenResult = await user.getIdTokenResult();
        final role = idTokenResult.claims?['role'] as String?;
        if (role != null && role.isNotEmpty) {
          return role;
        }
      }

      // Phone + PIN logins create anonymous Firebase sessions, so fall back to
      // the persisted staff session and then Firestore to resolve the role.
      final prefs = await SharedPreferences.getInstance();
      final storedRole = prefs.getString('currentStaffRole');
      if (storedRole != null && storedRole.trim().isNotEmpty) {
        return storedRole.trim().toLowerCase();
      }

      final storedStaffId = prefs.getString('currentStaffId');
      if (storedStaffId != null && storedStaffId.trim().isNotEmpty) {
        final staffDoc = await _firestore
            .collection(_staffCollection)
            .doc(storedStaffId)
            .get();
        if (staffDoc.exists) {
          final resolvedRole = (staffDoc.data()?['role'] ?? 'staff')
              .toString()
              .trim()
              .toLowerCase();
          await prefs.setString('currentStaffRole', resolvedRole);
          return resolvedRole;
        }
      }

      final storedPhone = prefs.getString('currentStaffPhone');
      if (storedPhone != null && storedPhone.trim().isNotEmpty) {
        final querySnapshot = await _queryStaffByPhone(
          storedPhone,
          activeOnly: false,
        );
        if (querySnapshot.docs.isNotEmpty) {
          final resolvedRole =
              (querySnapshot.docs.first.data()['role'] ?? 'staff')
                  .toString()
                  .trim()
                  .toLowerCase();
          await prefs.setString('currentStaffRole', resolvedRole);
          return resolvedRole;
        }
      }

      return null;
    } catch (error) {
      print('Error getting user role: $error');
      return null;
    }
  }

  // STAFF AUTHENTICATION METHODS

  // Check if staff exists with given phone number
  Future<bool> checkStaffExists(String phoneNumber) async {
    try {
      final querySnapshot = await _queryStaffByPhone(phoneNumber);

      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      throw Exception('Failed to check staff existence: $e');
    }
  }

  // Verify staff PIN
  Future<bool> verifyStaffPin(String phoneNumber, String pin) async {
    try {
      final querySnapshot = await _queryStaffByPhone(phoneNumber);

      if (querySnapshot.docs.isEmpty) {
        return false;
      }

      final staffDoc = querySnapshot.docs.first;
      final storedPin = staffDoc.data()['pin'] as String?;

      if (storedPin == null) {
        return false;
      }

      // Compare against hashed PIN first; support legacy plain-text PINs
      final String hashedInputPin = _hashPin(pin);
      if (storedPin == hashedInputPin) {
        return true;
      }

      // Legacy support: if stored PIN is plain text and matches input,
      // migrate to hashed PIN for future sign-ins
      if (storedPin == pin) {
        try {
          await staffDoc.reference.update({
            'pin': hashedInputPin,
            'updatedAt': FieldValue.serverTimestamp()
          });
        } catch (_) {
          // Ignore migration failure; still return success
        }
        return true;
      }

      return false;
    } catch (e) {
      throw Exception('Failed to verify PIN: $e');
    }
  }

  // Sign in staff user with phone number and PIN (simplified version without Cloud Functions)
  Future<Map<String, dynamic>?> signInStaffWithPin(
      String phoneNumber, String pin) async {
    try {
      final normalizedPhoneNumber =
          _normalizeAustralianPhoneOrThrow(phoneNumber);
      // #region debug-point A:staff-pin-signin-entry
      _dbgAuth('A', 'lib/services/auth_service.dart:signInStaffWithPin',
          '[DEBUG] signInStaffWithPin entered', {
        'projectId': Firebase.app().options.projectId,
        'authUidBefore': _auth.currentUser?.uid,
        'phoneNumber': normalizedPhoneNumber,
      });
      // #endregion
      // Get staff details from Firestore and verify PIN
      final querySnapshot = await _queryStaffByPhone(normalizedPhoneNumber);

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Staff not found or inactive');
      }

      final staffDoc = querySnapshot.docs.first;
      final staffData = staffDoc.data();
      final storedPin = staffData['pin'] as String?;

      if (storedPin == null) {
        throw Exception('Invalid PIN');
      }

      // Hash the input PIN and compare with stored hashed PIN
      final String hashedInputPin = _hashPin(pin);
      if (storedPin != hashedInputPin) {
        // Legacy support: plain text PIN stored
        if (storedPin == pin) {
          // Migrate to hashed PIN
          try {
            await staffDoc.reference.update({
              'pin': hashedInputPin,
              'updatedAt': FieldValue.serverTimestamp()
            });
          } catch (_) {}
        } else {
          throw Exception('Invalid PIN');
        }
      }

      // Sign in anonymously to get a Firebase user
      final userCredential = await _auth.signInAnonymously();

      // #region debug-point A:staff-pin-signin-anon-user
      _dbgAuth('A', 'lib/services/auth_service.dart:signInStaffWithPin',
          '[DEBUG] signInStaffWithPin created anonymous auth session', {
        'staffId': staffDoc.id,
        'authUidAfter': userCredential.user?.uid,
        'isAnonymous': userCredential.user?.isAnonymous,
      });
      // #endregion

      if (userCredential.user == null) {
        throw Exception('Failed to create authentication session');
      }

      // Return staff data for session management
      final staffInfo = {
        'user': userCredential.user,
        'staffId': staffDoc.id,
        'staffData': staffData,
        'role': staffData['role'] ?? 'staff',
        'isStaff': true,
      };

      return staffInfo;
    } catch (e) {
      // #region debug-point A:staff-pin-signin-error
      _dbgAuth('A', 'lib/services/auth_service.dart:signInStaffWithPin',
          '[DEBUG] signInStaffWithPin failed', {
        'authUid': _auth.currentUser?.uid,
        'error': e.toString(),
        'firebaseCode': e is FirebaseException ? e.code : null,
      });
      // #endregion
      throw Exception('Failed to sign in staff: $e');
    }
  }

  // Generate custom token for staff using Firebase Cloud Function
  Future<Map<String, dynamic>> generateStaffCustomToken({
    required String staffId,
    required String phoneNumber,
    required String pin,
  }) async {
    try {
      final callable = _functions.httpsCallable('generateStaffToken');

      final result = await callable.call({
        'staffId': staffId,
        'phone': phoneNumber,
        'pin': pin,
      });

      return Map<String, dynamic>.from(result.data);
    } catch (e) {
      throw Exception('Failed to generate custom token: $e');
    }
  }

  // Update staff with PIN for authentication
  Future<String> createStaffAccount({
    required String phoneNumber,
    required String pin,
    required String name,
    required String role,
    String? department,
    String? email,
  }) async {
    try {
      final normalizedPhoneNumber =
          _normalizeAustralianPhoneOrThrow(phoneNumber);
      // #region debug-point C:create-staff-entry
      _dbgAuth('C', 'lib/services/auth_service.dart:createStaffAccount',
          '[DEBUG] createStaffAccount entered', {
        'projectId': Firebase.app().options.projectId,
        'authUid': _auth.currentUser?.uid,
        'phoneNumber': normalizedPhoneNumber,
        'role': role,
      });
      // #endregion
      // Check if staff already exists
      final querySnapshot = await _queryStaffByPhone(
        normalizedPhoneNumber,
        activeOnly: false,
      );

      // Hash the PIN before storing
      final String hashedPin = _hashPin(pin);

      if (querySnapshot.docs.isNotEmpty) {
        // Update existing staff with PIN
        final docRef = querySnapshot.docs.first.reference;
        await docRef.update({
          'phone': normalizedPhoneNumber,
          'pin': hashedPin,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        // #region debug-point C:create-staff-updated
        _dbgAuth('C', 'lib/services/auth_service.dart:createStaffAccount',
            '[DEBUG] createStaffAccount updated existing staff', {
          'docId': docRef.id,
          'authUid': _auth.currentUser?.uid,
        });
        // #endregion
        return docRef.id;
      } else {
        // Create new staff document
        final docRef = await _firestore.collection(_staffCollection).add({
          'phone': normalizedPhoneNumber,
          'pin': hashedPin,
          'name': name,
          'role': role,
          'department': department ?? '',
          'email': email ?? '',
          'isActive': true,
          'hourlyRate': 0.0,
          'hireDate': FieldValue.serverTimestamp(),
          'totalHoursWorked': 0.0,
          'shiftsCompleted': 0,
          'skills': [],
        });
        // #region debug-point C:create-staff-created
        _dbgAuth('C', 'lib/services/auth_service.dart:createStaffAccount',
            '[DEBUG] createStaffAccount created staff doc', {
          'docId': docRef.id,
          'authUid': _auth.currentUser?.uid,
        });
        // #endregion
        return docRef.id;
      }
    } catch (e) {
      // #region debug-point C:create-staff-error
      _dbgAuth('C', 'lib/services/auth_service.dart:createStaffAccount',
          '[DEBUG] createStaffAccount failed', {
        'authUid': _auth.currentUser?.uid,
        'error': e.toString(),
        'firebaseCode': e is FirebaseException ? e.code : null,
      });
      // #endregion
      throw Exception('Failed to create staff account: $e');
    }
  }

  // Get staff details by phone number
  Future<Map<String, dynamic>?> getStaffByPhone(String phoneNumber) async {
    try {
      final normalizedPhoneNumber =
          _normalizeAustralianPhoneOrThrow(phoneNumber);
      // Ensure we have an auth context to satisfy rules that require authentication
      if (_auth.currentUser == null) {
        await _auth.signInAnonymously();
      }

      final querySnapshot = await _queryStaffByPhone(normalizedPhoneNumber);

      if (querySnapshot.docs.isEmpty) {
        return null;
      }

      final doc = querySnapshot.docs.first;
      final data = doc.data();
      data['id'] = doc.id;
      data['phone'] = AustralianPhoneNumber.normalizeToStorageFormat(
            (data['phone'] ?? '').toString(),
          ) ??
          (data['phone'] ?? '').toString();
      return data;
    } catch (e) {
      throw Exception('Failed to get staff details: $e');
    }
  }

  // Hash PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Validate PIN format (6 digits)
  bool isValidPin(String pin) {
    return RegExp(r'^\d{6}$').hasMatch(pin);
  }

  // Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    return AustralianPhoneNumber.isValidPhoneNumber(phoneNumber);
  }

  // Temporary method to create initial admin account
  Future<bool> createInitialAdmin({
    required String phoneNumber,
    required String pin,
    required String name,
  }) async {
    try {
      final normalizedPhoneNumber =
          _normalizeAustralianPhoneOrThrow(phoneNumber);
      // #region debug-point D:create-admin-entry
      _dbgAuth('D', 'lib/services/auth_service.dart:createInitialAdmin',
          '[DEBUG] createInitialAdmin entered', {
        'projectId': Firebase.app().options.projectId,
        'authUid': _auth.currentUser?.uid,
        'phoneNumber': normalizedPhoneNumber,
        'name': name,
      });
      // #endregion
      // Check if any admin already exists
      final QuerySnapshot adminQuery = await _firestore
          .collection('staff')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      if (adminQuery.docs.isNotEmpty) {
        print('Admin account already exists');
        return false;
      }

      // Validate inputs
      if (!isValidPhoneNumber(normalizedPhoneNumber)) {
        print('Invalid phone number format');
        return false;
      }

      if (!isValidPin(pin)) {
        print('Invalid PIN format');
        return false;
      }

      // Create admin account
      final String hashedPin = _hashPin(pin);
      final String staffId = 'admin_${DateTime.now().millisecondsSinceEpoch}';

      await _firestore.collection('staff').doc(staffId).set({
        'staffId': staffId,
        'name': name,
        'phone': normalizedPhoneNumber,
        'pin': hashedPin,
        'role': 'admin',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // #region debug-point D:create-admin-success
      _dbgAuth('D', 'lib/services/auth_service.dart:createInitialAdmin',
          '[DEBUG] createInitialAdmin wrote staff doc', {
        'staffId': staffId,
        'authUid': _auth.currentUser?.uid,
      });
      // #endregion

      print('Initial admin account created successfully');
      return true;
    } catch (e) {
      // #region debug-point D:create-admin-error
      _dbgAuth('D', 'lib/services/auth_service.dart:createInitialAdmin',
          '[DEBUG] createInitialAdmin failed', {
        'authUid': _auth.currentUser?.uid,
        'error': e.toString(),
        'firebaseCode': e is FirebaseException ? e.code : null,
      });
      // #endregion
      print('Error creating initial admin: $e');
      return false;
    }
  }

  // Check if system needs initial setup (no admin exists)
  Future<bool> needsInitialSetup() async {
    try {
      // #region debug-point E:needs-setup-entry
      _dbgAuth('E', 'lib/services/auth_service.dart:needsInitialSetup',
          '[DEBUG] needsInitialSetup query start', {
        'projectId': Firebase.app().options.projectId,
        'authUid': _auth.currentUser?.uid,
      });
      // #endregion
      final QuerySnapshot adminQuery = await _firestore
          .collection('staff')
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      // #region debug-point E:needs-setup-result
      _dbgAuth('E', 'lib/services/auth_service.dart:needsInitialSetup',
          '[DEBUG] needsInitialSetup query completed', {
        'authUid': _auth.currentUser?.uid,
        'adminCount': adminQuery.docs.length,
        'needsSetup': adminQuery.docs.isEmpty,
      });
      // #endregion

      return adminQuery.docs.isEmpty;
    } catch (e) {
      // #region debug-point E:needs-setup-error
      _dbgAuth('E', 'lib/services/auth_service.dart:needsInitialSetup',
          '[DEBUG] needsInitialSetup failed', {
        'authUid': _auth.currentUser?.uid,
        'error': e.toString(),
        'firebaseCode': e is FirebaseException ? e.code : null,
      });
      // #endregion
      print('Error checking initial setup: $e');
      return false;
    }
  }

  Future<bool> changeStaffPin({
    required String phoneNumber,
    required String currentPin,
    required String newPin,
  }) async {
    try {
      final normalizedPhoneNumber =
          _normalizeAustralianPhoneOrThrow(phoneNumber);
      // Basic validation
      if (newPin.length != 6 || !RegExp(r'^\d{6}$').hasMatch(newPin)) {
        throw Exception('New PIN must be a 6-digit number');
      }

      // Fetch staff document
      final querySnapshot = await _queryStaffByPhone(normalizedPhoneNumber);

      if (querySnapshot.docs.isEmpty) {
        throw Exception('Staff not found or inactive');
      }

      final staffDoc = querySnapshot.docs.first;
      final staffData = staffDoc.data();
      final storedPin = staffData['pin'] as String?;

      if (storedPin == null) {
        throw Exception('No PIN set for this account');
      }

      final String currentHashed = _hashPin(currentPin);

      // Verify current PIN (hashed first, fallback to plain text)
      bool verified = false;
      if (storedPin == currentHashed) {
        verified = true;
      } else if (storedPin == currentPin) {
        verified = true;
      }

      if (!verified) {
        throw Exception('Current PIN is incorrect');
      }

      // Hash and update to new PIN
      final String newHashed = _hashPin(newPin);
      await staffDoc.reference.update({
        'pin': newHashed,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return true;
    } catch (e) {
      throw Exception('Failed to change PIN: $e');
    }
  }
}
