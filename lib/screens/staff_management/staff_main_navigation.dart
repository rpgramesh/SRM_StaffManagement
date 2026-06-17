import 'package:flutter/material.dart';
import 'staff_dashboard_screen.dart';
import 'staff_attendance_screen.dart';
import '../staff_management_app_screen.dart';
import '../../widgets/navigation/staff_bottom_navigation.dart';
import '../staff/daily_roster_screen.dart';

class StaffMainNavigation extends StatefulWidget {
  const StaffMainNavigation({super.key});

  @override
  State<StaffMainNavigation> createState() => _StaffMainNavigationState();
}

class _StaffMainNavigationState extends State<StaffMainNavigation> {
  final int _currentIndex = 0;

  final List<Widget> _screens = [
    const StaffDashboardScreen(),
    const StaffAttendanceScreen(),
    const DailyRosterScreen(),
    const StaffManagementAppScreen(), // Profile/Settings placeholder
  ];



  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: StaffBottomNavigation(
        currentIndex: _currentIndex,
        onTap: (index) {
          // Use named routes so URL updates to hash (e.g., #/daily_roster)
          StaffBottomNavigation.handleNavigation(context, index, isManager: false);
        },
      ),
    );
  }
}
