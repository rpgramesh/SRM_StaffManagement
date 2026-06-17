import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import '../../services/auth_service.dart';
import '../../services/staff_auth_service.dart';
import '../../widgets/navigation/staff_bottom_navigation.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  String? _currentStaffId;
  Staff? _currentStaff;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeCurrentUser();
      // Only initialize provider after authentication to avoid unauthenticated Firestore listeners
      if (AuthService().currentUser != null) {
        context.read<StaffProvider>().initialize();
      }
    });
  }

  Future<void> _initializeCurrentUser() async {
    final authService = AuthService();
    final user = authService.currentUser;
    if (user != null) {
      final staff = await context.read<StaffProvider>().getStaff(user.uid);
      setState(() {
        _currentStaffId = user.uid;
        _currentStaff = staff;
      });
    }
  }

  bool get _isManager => _currentStaff?.role.toLowerCase() == 'manager';

  Future<void> _handleCheckIn() async {
    if (_currentStaffId != null) {
      try {
        await context.read<StaffProvider>().checkInStaff(_currentStaffId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checked in successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to check in: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleCheckOut() async {
    if (_currentStaffId != null) {
      try {
        await context.read<StaffProvider>().checkOutStaff(_currentStaffId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checked out successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to check out: $e')),
          );
        }
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Sign out from Firebase Auth
        final authService = AuthService();
        
        // Cancel Firestore listeners before signing out
        await context.read<StaffProvider>().clearListeners();
        
        await authService.signOut();
        
        // Clear staff authentication data
        await StaffAuthService().clearStaffAuthData();
        
        // Navigate to initial setup (main screen)
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      } catch (e) {
        print('Error during staff logout: $e');
        if (mounted) {
          // Ensure navigation even if an error occurs
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Staff Dashboard'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: () {
            // Open menu drawer
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Consumer<StaffProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => provider.initialize(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCheckInOutSection(),
                  const SizedBox(height: 24),
                  _buildWeeklyHoursCard(),
                  const SizedBox(height: 24),
                  _buildAttendanceSection(),
                  const SizedBox(height: 24),
                  _buildReportsSection(),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: StaffBottomNavigation(
          currentIndex: 0,
          isManager: _isManager,
          onTap: (index) {
            StaffBottomNavigation.handleNavigation(context, index, isManager: _isManager);
          },
        ),
    );
  }

  Widget _buildCheckInOutSection() {
    if (_currentStaffId == null || _currentStaff == null) {
      return const SizedBox();
    }

    final provider = context.watch<StaffProvider>();
    final isCheckedIn = provider.checkInStatus[_currentStaffId] ?? false;

    Map<String, dynamic>? todayRecord;
    for (final rec in provider.todayAttendance) {
      if (rec['staffId'] == _currentStaffId) {
        todayRecord = rec;
        break;
      }
    }

    DateTime? checkInTime = todayRecord?['checkInTime'] as DateTime?;
    DateTime? checkOutTime = todayRecord?['checkOutTime'] as DateTime?;
    final recordedDuration = (todayRecord?['duration'] as double?) ?? 0.0;

    String formatDuration(Duration d) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      if (h <= 0 && m <= 0) return '0m';
      if (h <= 0) return '${m}m';
      if (m <= 0) return '${h}h';
      return '${h}h ${m}m';
    }

    String? statusText;
    Widget? liveDurationWidget;

    if (isCheckedIn && checkInTime != null) {
      statusText =
          'Checked in since: ${DateFormat('MMM d, h:mm a').format(checkInTime)}';
      // Optional live ticker to show elapsed time (updates every minute)
      liveDurationWidget = StreamBuilder<DateTime>(
        stream:
            Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now())
              ..listen((event) {}, onDone: () {}),
        builder: (context, snapshot) {
          final now = snapshot.data ?? DateTime.now();
          final diff = now.difference(checkInTime);
          return Text(
            'Elapsed: ${formatDuration(diff)}',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
          );
        },
      );
    } else if (!isCheckedIn && checkOutTime != null) {
      statusText =
          'Last check-out: ${DateFormat('MMM d, h:mm a').format(checkOutTime)}';
    } else if (!isCheckedIn && checkInTime != null && checkOutTime == null) {
      // Fallback: record exists but map didn’t reflect status yet
      statusText =
          'Checked in since: ${DateFormat('MMM d, h:mm a').format(checkInTime)}';
    } else {
      statusText = 'No activity recorded today';
    }

    String? durationText;
    if (!isCheckedIn && recordedDuration > 0) {
      // When checked out, use stored duration (in hours as double)
      final minutes = (recordedDuration * 60).round();
      durationText =
          'Duration today: ${formatDuration(Duration(minutes: minutes))}';
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCheckedIn ? null : _handleCheckIn,
                    icon: const Icon(Icons.login),
                    label: const Text('Check In'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isCheckedIn ? _handleCheckOut : null,
                    icon: const Icon(Icons.logout),
                    label: const Text('Check Out'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              statusText ?? '',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (liveDurationWidget != null) ...[
              const SizedBox(height: 4),
              liveDurationWidget,
            ],
            if (durationText != null) ...[
              const SizedBox(height: 4),
              Text(
                durationText,
                style: const TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklyHoursCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Hours',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Total: 120 hours',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 25,
                  barTouchData: BarTouchData(enabled: false),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun'
                          ];
                          return Text(
                            days[value.toInt()],
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        interval: 5,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 5,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.withOpacity(0.2),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [BarChartRodData(toY: 20, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [BarChartRodData(toY: 18, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [BarChartRodData(toY: 22, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 3,
                      barRods: [BarChartRodData(toY: 16, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 4,
                      barRods: [BarChartRodData(toY: 20, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 5,
                      barRods: [BarChartRodData(toY: 12, color: Colors.blue)],
                    ),
                    BarChartGroupData(
                      x: 6,
                      barRods: [BarChartRodData(toY: 12, color: Colors.blue)],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Present',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '15',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.cancel,
                        color: Colors.red,
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Absent',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '3',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildReportsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Export PDF functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting PDF...')),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Export PDF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  // Export Excel functionality
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Exporting Excel...')),
                  );
                },
                icon: const Icon(Icons.table_chart),
                label: const Text('Export Excel'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }


}
