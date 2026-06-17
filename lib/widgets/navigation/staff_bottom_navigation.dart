import 'package:flutter/material.dart';

class StaffBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final bool isManager;

  const StaffBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isManager = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue[600],
        unselectedItemColor: Colors.grey[400],
        selectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
        ),
        currentIndex: currentIndex,
        onTap: onTap,
        items: _getNavigationItems(),
      ),
    );
  }

  List<BottomNavigationBarItem> _getNavigationItems() {
    if (isManager) {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Staff',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.schedule),
          label: 'Roster',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_today),
          label: 'Schedule',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.analytics),
          label: 'Reports',
        ),
      ];
    } else {
      return const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.access_time),
          label: 'Attendance',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.schedule),
          label: 'Roster',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Profile',
        ),
      ];
    }
  }

  /// Handle navigation for staff-specific routes
  static void handleNavigation(BuildContext context, int index,
      {bool isManager = false}) {
    if (isManager) {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/staff_dashboard');
          break;
        case 1:
          Navigator.pushNamed(context, '/staff-list');
          break;
        case 2:
          Navigator.pushNamed(context, '/daily_roster');
          break;
        case 3:
          Navigator.pushNamed(context, '/weekly_schedule');
          break;
        case 4:
          Navigator.pushNamed(context, '/staff_reports');
          break;
      }
    } else {
      switch (index) {
        case 0:
          Navigator.pushReplacementNamed(context, '/staff_dashboard');
          break;
        case 1:
          Navigator.pushNamed(context, '/staff-attendance');
          break;
        case 2:
          // Replace dashboard with roster so it doesn't stack in back
          Navigator.pushReplacementNamed(context, '/daily_roster');
          break;
        case 3:
          Navigator.pushNamed(context, '/staff-profile');
          break;
      }
    }
  }
}
