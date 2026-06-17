import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class StaffAuthService {
  static const String _pinKey = 'staff_pin_hash';
  static const String _biometricEnabledKey = 'biometric_enabled';
  static const String _lastStaffIdKey = 'last_staff_id';

  final LocalAuthentication _localAuth = LocalAuthentication();

  // Store PIN securely (hashed)
  Future<bool> setStaffPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final hashedPin = _hashPin(pin);
      return await prefs.setString(_pinKey, hashedPin);
    } catch (e) {
      print('Error setting staff PIN: $e');
      return false;
    }
  }

  // Verify PIN
  Future<bool> verifyStaffPin(String pin) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedHash = prefs.getString(_pinKey);
      if (storedHash == null) return false;
      
      final inputHash = _hashPin(pin);
      return storedHash == inputHash;
    } catch (e) {
      print('Error verifying staff PIN: $e');
      return false;
    }
  }

  // Check if PIN is set
  Future<bool> isPinSet() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.containsKey(_pinKey);
    } catch (e) {
      print('Error checking PIN status: $e');
      return false;
    }
  }

  // Enable/disable biometric authentication
  Future<bool> setBiometricEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setBool(_biometricEnabledKey, enabled);
    } catch (e) {
      print('Error setting biometric preference: $e');
      return false;
    }
  }

  // Check if biometric is enabled
  Future<bool> isBiometricEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_biometricEnabledKey) ?? false;
    } catch (e) {
      print('Error checking biometric preference: $e');
      return false;
    }
  }

  // Check biometric availability
  Future<bool> canUseBiometrics() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();
      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      print('Error checking biometric availability: $e');
      return false;
    }
  }

  // Authenticate with biometrics
  Future<bool> authenticateWithBiometrics() async {
    try {
      final bool isAvailable = await canUseBiometrics();
      if (!isAvailable) return false;

      final bool isEnabled = await isBiometricEnabled();
      if (!isEnabled) return false;

      return await _localAuth.authenticate(
        localizedReason: 'Please authenticate to access staff management',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      print('Error during biometric authentication: $e');
      return false;
    }
  }

  // Store last authenticated staff ID
  Future<bool> setLastStaffId(String staffId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_lastStaffIdKey, staffId);
    } catch (e) {
      print('Error storing last staff ID: $e');
      return false;
    }
  }

  // Get last authenticated staff ID
  Future<String?> getLastStaffId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_lastStaffIdKey);
    } catch (e) {
      print('Error retrieving last staff ID: $e');
      return null;
    }
  }

  // Clear all staff auth data
  Future<bool> clearStaffAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_pinKey) &&
             await prefs.remove(_biometricEnabledKey) &&
             await prefs.remove(_lastStaffIdKey);
    } catch (e) {
      print('Error clearing staff auth data: $e');
      return false;
    }
  }

  // Hash PIN using SHA-256
  String _hashPin(String pin) {
    final bytes = utf8.encode(pin);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Get available biometric types
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (e) {
      print('Error getting available biometrics: $e');
      return [];
    }
  }
}