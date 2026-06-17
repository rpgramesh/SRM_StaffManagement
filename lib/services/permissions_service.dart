import 'package:flutter/foundation.dart';
import 'auth_service.dart';

/// Service for managing role-based permissions throughout the application
class PermissionsService {
  static final PermissionsService _instance = PermissionsService._internal();
  factory PermissionsService() => _instance;
  PermissionsService._internal();

  final AuthService _authService = AuthService();

  /// Get current user role
  Future<String?> getCurrentUserRole() async {
    // Use the AuthService's getCurrentUserRole method which handles custom token claims
    return await _authService.getCurrentUserRole();
  }

  /// Check if current user has admin permissions
  Future<bool> isAdmin() async {
    final role = await getCurrentUserRole();
    return role == 'admin';
  }

  /// Check if current user has staff permissions
  Future<bool> isStaff() async {
    final role = await getCurrentUserRole();
    return role == 'staff';
  }

  /// Check if user can access staff management features
  Future<bool> canManageStaff() async {
    return await isAdmin();
  }

  /// Check if user can view reports and analytics
  Future<bool> canViewReports() async {
    return await isAdmin();
  }

  /// Check if user can manage schedules
  Future<bool> canManageSchedules() async {
    return await isAdmin();
  }

  /// Check if user can view all staff attendance
  Future<bool> canViewAllAttendance() async {
    return await isAdmin();
  }

  /// Check if user can modify system settings
  Future<bool> canModifySettings() async {
    return await isAdmin();
  }

  /// Check if user can access migration tools
  Future<bool> canAccessMigration() async {
    return await isAdmin();
  }

  /// Check if user can add/edit/delete staff
  Future<bool> canModifyStaffData() async {
    return await isAdmin();
  }

  /// Check if user can view their own attendance only
  Future<bool> canViewOwnAttendance() async {
    final role = await getCurrentUserRole();
    return role == 'staff' || role == 'admin';
  }

  /// Check if user can check in/out
  Future<bool> canCheckInOut() async {
    final role = await getCurrentUserRole();
    return role == 'staff' || role == 'admin';
  }

  /// Check if user can view their own profile
  Future<bool> canViewOwnProfile() async {
    final role = await getCurrentUserRole();
    return role == 'staff' || role == 'admin';
  }

  /// Check if user can update their own profile (limited fields)
  Future<bool> canUpdateOwnProfile() async {
    final role = await getCurrentUserRole();
    return role == 'staff' || role == 'admin';
  }

  /// Get list of permissions for current user
  Future<List<String>> getCurrentUserPermissions() async {
    final role = await getCurrentUserRole();
    if (role == null) return [];

    switch (role) {
      case 'admin':
        return [
          'manage_staff',
          'view_reports',
          'manage_schedules',
          'view_all_attendance',
          'modify_settings',
          'access_migration',
          'modify_staff_data',
          'view_own_attendance',
          'check_in_out',
          'view_own_profile',
          'update_own_profile',
        ];
      case 'staff':
        return [
          'view_own_attendance',
          'check_in_out',
          'view_own_profile',
          'update_own_profile',
        ];
      default:
        return [];
    }
  }

  /// Check if user has specific permission
  Future<bool> hasPermission(String permission) async {
    final permissions = await getCurrentUserPermissions();
    return permissions.contains(permission);
  }

  /// Get user-friendly role name
  String getRoleDisplayName(String? role) {
    switch (role) {
      case 'admin':
        return 'Administrator';
      case 'staff':
        return 'Staff Member';
      default:
        return 'Unknown';
    }
  }

  /// Debug method to print current user permissions
  Future<void> debugPrintPermissions() async {
    if (kDebugMode) {
      final role = await getCurrentUserRole();
      final permissions = await getCurrentUserPermissions();
      print('Current User Role: $role');
      print('Current User Permissions: $permissions');
    }
  }
}

/// Exception thrown when user doesn't have required permissions
class PermissionDeniedException implements Exception {
  final String message;
  final String requiredPermission;
  final String? userRole;

  const PermissionDeniedException({
    required this.message,
    required this.requiredPermission,
    this.userRole,
  });

  @override
  String toString() {
    return 'PermissionDeniedException: $message (Required: $requiredPermission, User Role: $userRole)';
  }
}

/// Mixin for widgets that need permission checking
mixin PermissionMixin {
  final PermissionsService _permissionsService = PermissionsService();

  /// Check permission and throw exception if denied
  Future<void> requirePermission(String permission) async {
    final hasPermission = await _permissionsService.hasPermission(permission);
    if (!hasPermission) {
      final role = await _permissionsService.getCurrentUserRole();
      throw PermissionDeniedException(
        message: 'Access denied: insufficient permissions',
        requiredPermission: permission,
        userRole: role,
      );
    }
  }

  /// Check if user has permission (returns boolean)
  Future<bool> checkPermission(String permission) async {
    return await _permissionsService.hasPermission(permission);
  }

  /// Get current user role
  Future<String?> getUserRole() async {
    return await _permissionsService.getCurrentUserRole();
  }
}