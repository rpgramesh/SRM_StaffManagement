import 'package:flutter/material.dart';
import '../services/permissions_service.dart';

/// Widget that conditionally shows content based on user permissions
class PermissionGuard extends StatefulWidget {
  /// The permission required to show the child widget
  final String permission;
  
  /// The widget to show if user has permission
  final Widget child;
  
  /// Optional widget to show if user doesn't have permission
  final Widget? fallback;
  
  /// Whether to show a loading indicator while checking permissions
  final bool showLoading;
  
  /// Custom loading widget
  final Widget? loadingWidget;
  
  /// Whether to show an error message if permission is denied
  final bool showDeniedMessage;
  
  /// Custom denied message widget
  final Widget? deniedWidget;

  const PermissionGuard({
    super.key,
    required this.permission,
    required this.child,
    this.fallback,
    this.showLoading = true,
    this.loadingWidget,
    this.showDeniedMessage = false,
    this.deniedWidget,
  });

  @override
  State<PermissionGuard> createState() => _PermissionGuardState();
}

class _PermissionGuardState extends State<PermissionGuard> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _isLoading = true;
  bool _hasPermission = false;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await _permissionsService.hasPermission(widget.permission);
      final userRole = await _permissionsService.getCurrentUserRole();
      
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _userRole = userRole;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoading) {
      return widget.loadingWidget ?? 
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    }

    if (_hasPermission) {
      return widget.child;
    }

    // Permission denied
    if (widget.fallback != null) {
      return widget.fallback!;
    }

    if (widget.showDeniedMessage) {
      return widget.deniedWidget ?? 
          Container(
            padding: const EdgeInsets.all(8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  'Access Restricted',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
    }

    // Return empty container if no fallback and no denied message
    return const SizedBox.shrink();
  }
}

/// Widget that shows different content based on user role
class RoleBasedWidget extends StatefulWidget {
  /// Content to show for admin users
  final Widget? adminWidget;
  
  /// Content to show for staff users
  final Widget? staffWidget;
  
  /// Default content to show if role doesn't match
  final Widget? defaultWidget;
  
  /// Whether to show loading while determining role
  final bool showLoading;

  const RoleBasedWidget({
    super.key,
    this.adminWidget,
    this.staffWidget,
    this.defaultWidget,
    this.showLoading = true,
  });

  @override
  State<RoleBasedWidget> createState() => _RoleBasedWidgetState();
}

class _RoleBasedWidgetState extends State<RoleBasedWidget> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _getUserRole();
  }

  Future<void> _getUserRole() async {
    try {
      final role = await _permissionsService.getCurrentUserRole();
      if (mounted) {
        setState(() {
          _userRole = role;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && widget.showLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    switch (_userRole) {
      case 'admin':
        return widget.adminWidget ?? widget.defaultWidget ?? const SizedBox.shrink();
      case 'staff':
        return widget.staffWidget ?? widget.defaultWidget ?? const SizedBox.shrink();
      default:
        return widget.defaultWidget ?? const SizedBox.shrink();
    }
  }
}

/// Button that is only enabled if user has required permission
class PermissionButton extends StatefulWidget {
  /// The permission required to enable the button
  final String permission;
  
  /// The button widget
  final Widget child;
  
  /// Callback when button is pressed
  final VoidCallback? onPressed;
  
  /// Style for the button
  final ButtonStyle? style;
  
  /// Whether to show a tooltip explaining why button is disabled
  final bool showTooltip;
  
  /// Custom tooltip message
  final String? tooltipMessage;

  const PermissionButton({
    super.key,
    required this.permission,
    required this.child,
    this.onPressed,
    this.style,
    this.showTooltip = true,
    this.tooltipMessage,
  });

  @override
  State<PermissionButton> createState() => _PermissionButtonState();
}

class _PermissionButtonState extends State<PermissionButton> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _hasPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await _permissionsService.hasPermission(widget.permission);
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ElevatedButton(
        onPressed: null,
        style: widget.style,
        child: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    final button = ElevatedButton(
      onPressed: _hasPermission ? widget.onPressed : null,
      style: widget.style,
      child: widget.child,
    );

    if (!_hasPermission && widget.showTooltip) {
      return Tooltip(
        message: widget.tooltipMessage ?? 'You don\'t have permission to perform this action',
        child: button,
      );
    }

    return button;
  }
}

/// ListTile that is only shown if user has required permission
class PermissionListTile extends StatefulWidget {
  /// The permission required to show the list tile
  final String permission;
  
  /// The list tile properties
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;

  const PermissionListTile({
    super.key,
    required this.permission,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
  });

  @override
  State<PermissionListTile> createState() => _PermissionListTileState();
}

class _PermissionListTileState extends State<PermissionListTile> {
  final PermissionsService _permissionsService = PermissionsService();
  bool _hasPermission = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    try {
      final hasPermission = await _permissionsService.hasPermission(widget.permission);
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return ListTile(
        leading: widget.leading,
        title: widget.title,
        subtitle: widget.subtitle,
        trailing: const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        enabled: false,
      );
    }

    if (!_hasPermission) {
      return const SizedBox.shrink();
    }

    return ListTile(
      leading: widget.leading,
      title: widget.title,
      subtitle: widget.subtitle,
      trailing: widget.trailing,
      onTap: widget.onTap,
      enabled: widget.enabled,
    );
  }
}