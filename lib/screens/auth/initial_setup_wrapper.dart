import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'admin_setup_screen.dart';
import 'staff_login_screen.dart';

class InitialSetupWrapper extends StatefulWidget {
  const InitialSetupWrapper({super.key});

  @override
  State<InitialSetupWrapper> createState() => _InitialSetupWrapperState();
}

class _InitialSetupWrapperState extends State<InitialSetupWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _needsSetup = false;

  @override
  void initState() {
    super.initState();
    _checkInitialSetup();
  }

  Future<void> _checkInitialSetup() async {
    try {
      final needsSetup = await _authService.needsInitialSetup();
      if (mounted) {
        setState(() {
          _needsSetup = needsSetup;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error checking initial setup: $e');
      if (mounted) {
        setState(() {
          _needsSetup = false; // Default to login screen on error
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_needsSetup) {
      return const AdminSetupScreen();
    }

    return const StaffLoginScreen();
  }
}