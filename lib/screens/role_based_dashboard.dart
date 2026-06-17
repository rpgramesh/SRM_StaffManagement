import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'admin/admin_dashboard_screen.dart';
import 'staff/staff_dashboard_screen.dart';

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
      final user = authService.currentUser;
      
      if (user == null) {
        // No user logged in, redirect to login
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/');
        }
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
      
      // Unable to determine role
      setState(() {
        _error = 'Unable to determine user role. Please login again.';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error determining user role: $e';
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
              Text('Loading...'),
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
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[300],
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacementNamed('/');
                },
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      );
    }

    // Route to appropriate dashboard based on role
    switch (_userRole) {
      case 'admin':
        return const AdminDashboardScreen();
      case 'staff':
        return const StaffDashboardScreen();
      default:
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.person_off,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Unknown User Role',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Unable to determine your access level',
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacementNamed('/');
                  },
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        );
    }
  }
}

// Helper widget for role-based navigation
class RoleBasedNavigation {
  static void navigateBasedOnRole(BuildContext context, String role) {
    switch (role.toLowerCase()) {
      case 'admin':
      case 'manager':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const AdminDashboardScreen(),
          ),
        );
        break;
      case 'staff':
      case 'employee':
      case 'waiter':
      case 'cook':
      case 'cashier':
      case 'supervisor':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => const StaffDashboardScreen(),
          ),
        );
        break;
      default:
        // Unknown role, show error or redirect to login
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Access Denied'),
            content: Text('Unknown role: $role. Please contact your administrator.'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamedAndRemoveUntil(
                    '/',
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
    }
  }

  static bool isAdminRole(String role) {
    return ['admin', 'manager'].contains(role.toLowerCase());
  }

  static bool isStaffRole(String role) {
    return ['staff', 'employee', 'waiter', 'cook', 'cashier', 'supervisor']
        .contains(role.toLowerCase());
  }
}

// Route guard for protecting admin-only routes
class AdminRouteGuard {
  static bool canAccess(String userRole) {
    return RoleBasedNavigation.isAdminRole(userRole);
  }

  static Widget guardedRoute({
    required String userRole,
    required Widget adminWidget,
    Widget? fallbackWidget,
  }) {
    if (canAccess(userRole)) {
      return adminWidget;
    }
    
    return fallbackWidget ?? 
        const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
  }
}

// Route guard for protecting staff-only routes
class StaffRouteGuard {
  static bool canAccess(String userRole) {
    return RoleBasedNavigation.isStaffRole(userRole);
  }

  static Widget guardedRoute({
    required String userRole,
    required Widget staffWidget,
    Widget? fallbackWidget,
  }) {
    if (canAccess(userRole)) {
      return staffWidget;
    }
    
    return fallbackWidget ?? 
        const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock,
                  size: 64,
                  color: Colors.red,
                ),
                SizedBox(height: 16),
                Text(
                  'Access Denied',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'You do not have permission to access this page.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
  }
}