import 'package:flutter/material.dart';
import '../staff_management_app_screen.dart';
import '../staff_management/staff_main_navigation.dart';
import '../../services/auth_service.dart';

class RoleBasedDashboard extends StatefulWidget {
  const RoleBasedDashboard({super.key});

  @override
  State<RoleBasedDashboard> createState() => _RoleBasedDashboardState();
}

class _RoleBasedDashboardState extends State<RoleBasedDashboard> {
  bool _isLoading = true;
  String? _userRole;
  String? _error;

  @override
  void initState() {
    super.initState();
    _determineUserRole();
  }

  Future<void> _determineUserRole() async {
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        setState(() {
          _error = 'No user logged in';
          _isLoading = false;
        });
        return;
      }

      // Use the updated getCurrentUserRole method from AuthService
      final role = await authService.getCurrentUserRole();
      
      if (role != null) {
        setState(() {
          _userRole = role;
          _isLoading = false;
        });
        return;
      }

      // Default fallback
      setState(() {
        _error = 'Unable to determine user role';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error determining user role: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading dashboard...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/',
                    (route) => false,
                  );
                },
                child: const Text('Go to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Navigate to appropriate dashboard based on role
    if (_userRole == 'admin') {
      return const StaffManagementAppScreen();
    } else {
      // For staff or any other role, show staff dashboard
      return const StaffMainNavigation();
    }
  }
}