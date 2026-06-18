import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/staff_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/navigation/staff_bottom_navigation.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../utils/australian_phone_number.dart';
import '../../utils/attendance_utils.dart';
import 'daily_roster_content.dart';

class StaffDashboardScreen extends StatefulWidget {
  const StaffDashboardScreen({super.key});

  @override
  State<StaffDashboardScreen> createState() => _StaffDashboardScreenState();
}

class _StaffDashboardScreenState extends State<StaffDashboardScreen> {
  int _selectedIndex = 2; // Default to Roster tab
  final bool _checkInOutProcessing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (AuthService().currentUser != null) {
        context.read<StaffProvider>().initialize();
      }
    });
  }

  final List<Widget> _pages = [
    const StaffHomeTab(),
    const StaffAttendanceTab(),
    const DailyRosterContent(),
    const StaffProfileTab(),
  ];

  final List<String> _titles = [
    'Dashboard',
    'Attendance',
    'Daily Roster',
    'Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              // TODO: Show notifications
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'logout') {
                _handleLogout();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Logout'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: StaffBottomNavigation(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
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
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        // Cancel Firestore listeners before signing out
        await context.read<StaffProvider>().clearListeners();

        final authService = AuthService();
        await authService.signOut();

        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      } catch (e) {
        debugPrint('Error during staff logout: $e');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    }
  }
}

class StaffHomeTab extends StatelessWidget {
  const StaffHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        // Use single source of truth from StaffProvider
        final currentStaff = provider.currentStaff ??
            (provider.allStaff.isNotEmpty ? provider.allStaff.first : null);
        final isCheckedIn = currentStaff != null
            ? (provider.checkInStatus[currentStaff.id] ?? false)
            : false;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Welcome Card
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.blue[700],
                        child: Text(
                          currentStaff?.name.substring(0, 1).toUpperCase() ??
                              'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome, ${currentStaff?.name ?? 'Staff'}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${currentStaff?.role ?? 'Staff'} • ${currentStaff?.department ?? 'Department'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              DateFormat(
                                'EEEE, MMMM d, y',
                              ).format(DateTime.now()),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Attendance Status Card
              Card(
                color: isCheckedIn ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isCheckedIn ? Icons.check_circle : Icons.cancel,
                        color: isCheckedIn ? Colors.green : Colors.red,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isCheckedIn ? 'Checked In' : 'Not Checked In',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isCheckedIn
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                            ),
                            Text(
                              isCheckedIn
                                  ? 'You are currently at work'
                                  : 'Please check in to start your shift',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            if (currentStaff != null) ...[
                              const SizedBox(height: 8),
                              _LiveWorkTimerContainer(staffId: currentStaff.id),
                            ],
                          ],
                        ),
                      ),
                      PermissionGuard(
                        permission: 'check_in_out',
                        child: ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  if (currentStaff != null) {
                                    provider.clearError();
                                    // Immediate feedback while processing
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isCheckedIn
                                              ? 'Checking out...'
                                              : 'Checking in...',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 800,
                                        ),
                                      ),
                                    );
                                    if (isCheckedIn) {
                                      await provider.checkOutStaff(
                                        currentStaff.id,
                                      );
                                    } else {
                                      await provider.checkInStaff(
                                        currentStaff.id,
                                      );
                                    }
                                    final err = provider.error;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          err.isNotEmpty
                                              ? err
                                              : (isCheckedIn
                                                  ? 'Checked out successfully'
                                                  : 'Checked in successfully'),
                                        ),
                                        backgroundColor: err.isNotEmpty
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isCheckedIn ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: provider.isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isCheckedIn
                                          ? 'Processing...'
                                          : 'Processing...',
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                )
                              : Text(isCheckedIn ? 'Check Out' : 'Check In'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      'View Schedule',
                      Icons.schedule,
                      Colors.blue,
                      () {
                        Navigator.pushNamed(context, '/weekly_schedule');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'Attendance History',
                      Icons.history,
                      Colors.green,
                      () {
                        Navigator.pushNamed(context, '/staff-attendance');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildActionCard(
                      'Update Profile',
                      Icons.person,
                      Colors.purple,
                      () {
                        Navigator.pushNamed(context, '/update_profile');
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildActionCard(
                      'Request Leave',
                      Icons.event_busy,
                      Colors.orange,
                      () {
                        Navigator.pushNamed(context, '/request_leave');
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Upcoming Schedule
              const Text(
                'Upcoming Schedule',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildScheduleItem(
                        'Today',
                        '9:00 AM - 5:00 PM',
                        'Kitchen',
                        Colors.green,
                        true,
                      ),
                      const Divider(),
                      _buildScheduleItem(
                        'Tomorrow',
                        '10:00 AM - 6:00 PM',
                        'Front Desk',
                        Colors.blue,
                        false,
                      ),
                      const Divider(),
                      _buildScheduleItem(
                        'Friday',
                        'Day Off',
                        '',
                        Colors.grey,
                        false,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Today's Summary
              const Text(
                'Today\'s Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        'Check-in Time',
                        isCheckedIn ? '9:00 AM' : 'Not checked in',
                      ),
                      const Divider(),
                      _buildSummaryRow(
                        'Hours Worked',
                        isCheckedIn ? '4.5 hrs' : '0 hrs',
                      ),
                      const Divider(),
                      _buildSummaryRow('Break Time', '30 min'),
                      const Divider(),
                      _buildSummaryRow(
                        'Status',
                        isCheckedIn ? 'Active' : 'Inactive',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionCard(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleItem(
    String day,
    String time,
    String location,
    Color color,
    bool isToday,
  ) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    day,
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                      fontSize: 14,
                      color: isToday ? color : Colors.black87,
                    ),
                  ),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Today',
                        style: TextStyle(
                          color: color,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Text(
                time,
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
              if (location.isNotEmpty)
                Text(
                  location,
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        ),
      ],
    );
  }

  void _showLeaveRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Leave'),
        content: const Text(
          'Leave request functionality will be implemented soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class StaffAttendanceTab extends StatefulWidget {
  const StaffAttendanceTab({super.key});

  @override
  State<StaffAttendanceTab> createState() => _StaffAttendanceTabState();
}

class _StaffAttendanceTabState extends State<StaffAttendanceTab> {
  DateTime _weekStart = _startOfWeek(DateTime.now());
  DateTime _weekEnd = _startOfWeek(DateTime.now()).add(const Duration(days: 6));
  List<Attendance> _weekRecords = [];
  bool _loading = false;
  String? _error;
  String? _currentStaffId;

  static DateTime _startOfWeek(DateTime date) {
    // Monday-start week
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final provider = context.read<StaffProvider>();
    final currentStaff =
        provider.allStaff.isNotEmpty ? provider.allStaff.first : null;
    if (_currentStaffId == null && currentStaff != null) {
      _currentStaffId = currentStaff.id;
      _fetchWeek();
    }
  }

  Future<void> _fetchWeek() async {
    if (_currentStaffId == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final records = await AttendanceService.getAttendanceByDateRange(
        _currentStaffId!,
        _weekStart,
        _weekEnd,
      );
      setState(() {
        _weekRecords = records;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load attendance: ${e.toString()}';
        _loading = false;
      });
    }
  }

  void _changeWeek(int deltaWeeks) {
    setState(() {
      _weekStart = _weekStart.add(Duration(days: 7 * deltaWeeks));
      _weekEnd = _weekStart.add(const Duration(days: 6));
    });
    _fetchWeek();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        final currentStaff =
            provider.allStaff.isNotEmpty ? provider.allStaff.first : null;
        final isCheckedIn = currentStaff != null
            ? (provider.checkInStatus[currentStaff.id] ?? false)
            : false;

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current Status Card
              Card(
                color: isCheckedIn ? Colors.green[50] : Colors.red[50],
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(
                            isCheckedIn ? Icons.check_circle : Icons.cancel,
                            color: isCheckedIn ? Colors.green : Colors.red,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Current Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                Text(
                                  isCheckedIn ? 'Checked In' : 'Not Checked In',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: isCheckedIn
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.isLoading
                              ? null
                              : () async {
                                  if (currentStaff != null) {
                                    provider.clearError();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          isCheckedIn
                                              ? 'Checking out...'
                                              : 'Checking in...',
                                        ),
                                        duration: const Duration(
                                          milliseconds: 800,
                                        ),
                                      ),
                                    );
                                    if (isCheckedIn) {
                                      await provider.checkOutStaff(
                                        currentStaff.id,
                                      );
                                    } else {
                                      await provider.checkInStaff(
                                        currentStaff.id,
                                      );
                                    }
                                    final err = provider.error;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          err.isNotEmpty
                                              ? err
                                              : (isCheckedIn
                                                  ? 'Checked out successfully'
                                                  : 'Checked in successfully'),
                                        ),
                                        backgroundColor: err.isNotEmpty
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                    );
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                isCheckedIn ? Colors.red : Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: provider.isLoading
                              ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: const [
                                    SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.white,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Processing...',
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ],
                                )
                              : const Text(
                                  'Toggle Check-In',
                                  style: TextStyle(fontSize: 16),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Attendance History
              const Text(
                'Attendance History',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Week selector with range
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              onPressed: () => _changeWeek(-1),
                              icon: const Icon(Icons.chevron_left),
                              tooltip: 'Previous Week',
                            ),
                            Column(
                              children: [
                                Text(
                                  '${DateFormat('MMM d').format(_weekStart)} - ${DateFormat('MMM d').format(_weekEnd)}',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _startOfWeek(DateTime.now()) == _weekStart
                                      ? 'This Week'
                                      : '',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                            IconButton(
                              onPressed: () => _changeWeek(1),
                              icon: const Icon(Icons.chevron_right),
                              tooltip: 'Next Week',
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Attendance list with loading/error states
                        Expanded(
                          child: _loading
                              ? const Center(child: CircularProgressIndicator())
                              : _error != null
                                  ? Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            size: 48,
                                            color: Colors.grey[400],
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _error!,
                                            style: TextStyle(
                                              color: Colors.grey[700],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          ElevatedButton(
                                            onPressed: _fetchWeek,
                                            child: const Text('Retry'),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      itemCount: 7,
                                      itemBuilder: (context, index) {
                                        final day = _weekStart.add(
                                          Duration(days: index),
                                        );
                                        final isToday = DateUtils.isSameDay(
                                          day,
                                          DateTime.now(),
                                        );

                                        // Determine status with rules (future/today/past)
                                        final status = computeDayStatus(
                                          day,
                                          _weekRecords,
                                        );
                                        final record = _weekRecords.firstWhere(
                                          (r) =>
                                              DateUtils.isSameDay(r.date, day),
                                          orElse: () => Attendance(
                                            id: 'none',
                                            staffId: _currentStaffId ?? '',
                                            date: day,
                                            status: '',
                                            duration: 0.0,
                                          ),
                                        );

                                        final isAbsent = status == 'absent';
                                        final isPresent = status != 'future' &&
                                            status != 'today_no_record' &&
                                            !isAbsent;
                                        final subtitle = displayTextForStatus(
                                          status,
                                          record: record.id == 'none'
                                              ? null
                                              : record,
                                        );

                                        Color avatarColor;
                                        IconData avatarIcon;
                                        Color? subtitleColor;

                                        if (isPresent) {
                                          avatarColor = Colors.green;
                                          avatarIcon = Icons.check;
                                          subtitleColor = Colors.green[700];
                                        } else if (isAbsent) {
                                          avatarColor = Colors.red;
                                          avatarIcon = Icons.close;
                                          subtitleColor = Colors.red[700];
                                        } else {
                                          avatarColor = Colors.grey;
                                          avatarIcon = Icons.schedule;
                                          subtitleColor = Colors.grey[700];
                                        }

                                        return Card(
                                          margin:
                                              const EdgeInsets.only(bottom: 8),
                                          color:
                                              isToday ? Colors.blue[50] : null,
                                          child: ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: avatarColor,
                                              child: Icon(
                                                avatarIcon,
                                                color: Colors.white,
                                              ),
                                            ),
                                            title: Text(
                                              DateFormat('EEEE, MMM d')
                                                  .format(day),
                                              style: TextStyle(
                                                fontWeight: isToday
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                              ),
                                            ),
                                            subtitle: Text(
                                              subtitle,
                                              style: TextStyle(
                                                color: subtitleColor,
                                              ),
                                            ),
                                            trailing: isToday
                                                ? Chip(
                                                    label: const Text('Today'),
                                                    backgroundColor:
                                                        Colors.blue[100],
                                                  )
                                                : null,
                                          ),
                                        );
                                      },
                                    ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StaffScheduleTab extends StatelessWidget {
  const StaffScheduleTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'My Schedule',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),

          // Week selector
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Week of ${DateFormat('MMM d, y').format(DateTime.now())}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Schedule list
          Expanded(
            child: ListView.builder(
              itemCount: 7,
              itemBuilder: (context, index) {
                final date = DateTime.now().add(Duration(days: index));
                final isToday = DateUtils.isSameDay(date, DateTime.now());
                final hasShift =
                    index % 6 != 0; // Mock data - day off every 6th day

                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: isToday ? Colors.blue[50] : null,
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          hasShift ? Colors.blue[700] : Colors.grey,
                      child: Text(
                        DateFormat('d').format(date),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      DateFormat('EEEE, MMM d').format(date),
                      style: TextStyle(
                        fontWeight:
                            isToday ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    subtitle: Text(
                      hasShift ? '9:00 AM - 5:00 PM' : 'Day Off',
                      style: TextStyle(
                        color: hasShift ? Colors.blue[700] : Colors.grey[600],
                      ),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (isToday)
                          Chip(
                            label: const Text('Today'),
                            backgroundColor: Colors.blue[100],
                          ),
                        if (hasShift)
                          Text(
                            '8 hours',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class StaffProfileTab extends StatelessWidget {
  const StaffProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        // For now, we'll use the first staff member as current staff
        // In a real app, this would be determined by authentication
        final currentStaff =
            provider.allStaff.isNotEmpty ? provider.allStaff.first : null;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Header
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: Colors.blue[700],
                        child: Text(
                          currentStaff?.name.substring(0, 1).toUpperCase() ??
                              'S',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              currentStaff?.name ?? 'Staff Name',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '${currentStaff?.role ?? 'Role'} • ${currentStaff?.department ?? 'Department'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Employee ID: ${currentStaff?.id ?? 'N/A'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Profile Information
              const Text(
                'Profile Information',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildInfoRow(
                        'Phone Number',
                        AustralianPhoneNumber.formatForDisplay(
                          currentStaff?.phone,
                          emptyFallback: 'Not provided',
                        ),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Email',
                        currentStaff?.email ?? 'Not provided',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Department',
                        currentStaff?.department ?? 'Not assigned',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Role',
                        currentStaff?.role ?? 'Not assigned',
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Join Date',
                        DateFormat(
                          'MMM d, y',
                        ).format(currentStaff?.hireDate ?? DateTime.now()),
                      ),
                      const Divider(),
                      _buildInfoRow(
                        'Status',
                        currentStaff?.isActive == true ? 'Active' : 'Inactive',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Quick Actions
              const Text(
                'Account Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit, color: Colors.blue),
                      title: const Text('Edit Profile'),
                      subtitle: const Text('Update your personal information'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showEditProfileDialog(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock, color: Colors.orange),
                      title: const Text('Change PIN'),
                      subtitle: const Text('Update your login PIN'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showChangePinDialog(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.help, color: Colors.green),
                      title: const Text('Help & Support'),
                      subtitle: const Text('Get help or contact support'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        _showHelpDialog(context);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ),
      ],
    );
  }

  void _showEditProfileDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Profile'),
        content: const Text(
          'Profile editing functionality will be implemented soon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: !isSubmitting,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: currentPinController,
                    decoration: const InputDecoration(
                      labelText: 'Current PIN',
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  TextField(
                    controller: newPinController,
                    decoration: const InputDecoration(
                      labelText: 'New PIN',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                  TextField(
                    controller: confirmPinController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New PIN',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          final currentPin = currentPinController.text.trim();
                          final newPin = newPinController.text.trim();
                          final confirmPin = confirmPinController.text.trim();

                          // Basic validation
                          if (currentPin.length != 6 ||
                              newPin.length != 6 ||
                              confirmPin.length != 6) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter 6-digit PINs'),
                              ),
                            );
                            return;
                          }
                          if (newPin != confirmPin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'New PIN and confirm PIN do not match',
                                ),
                              ),
                            );
                            return;
                          }
                          if (currentPin == newPin) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'New PIN must be different from current PIN',
                                ),
                              ),
                            );
                            return;
                          }

                          setState(() => isSubmitting = true);
                          try {
                            // Retrieve current staff phone from provider or stored prefs
                            final provider = context.read<StaffProvider>();
                            final currentStaff = provider.allStaff.isNotEmpty
                                ? provider.allStaff.first
                                : null;
                            final phone = currentStaff?.phone;

                            if (phone == null || phone.isEmpty) {
                              throw Exception(
                                'Unable to determine current staff phone',
                              );
                            }

                            final authService = AuthService();
                            final success = await authService.changeStaffPin(
                              phoneNumber: phone,
                              currentPin: currentPin,
                              newPin: newPin,
                            );

                            if (success) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PIN changed successfully'),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Failed to change PIN'),
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: ${e.toString()}')),
                            );
                          } finally {
                            setState(() => isSubmitting = false);
                          }
                        },
                  child: const Text('Update PIN'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help & Support'),
        content: const Text(
          'For assistance, please contact your administrator or HR department.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _LiveWorkTimerContainer extends StatefulWidget {
  final String staffId;
  const _LiveWorkTimerContainer({required this.staffId});

  @override
  State<_LiveWorkTimerContainer> createState() =>
      _LiveWorkTimerContainerState();
}

class _LiveWorkTimerContainerState extends State<_LiveWorkTimerContainer> {
  Duration _serverOffset = Duration.zero;
  static const int _standardHours = 8;

  @override
  void initState() {
    super.initState();
    _initOffset();
  }

  Future<void> _initOffset() async {
    final offset = await AttendanceService.estimateServerOffset();
    if (mounted) {
      setState(() {
        _serverOffset = offset;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Attendance?>(
      stream: AttendanceService.streamTodayAttendance(widget.staffId),
      builder: (context, snapshot) {
        final attendance = snapshot.data;
        final isActive =
            attendance?.isCheckedIn == true && attendance?.checkInTime != null;
        if (!isActive) {
          return const SizedBox.shrink();
        }
        final startUtc = attendance!.checkInTime!.toUtc();
        return _LiveWorkTimer(
          attendance: attendance,
          startUtc: startUtc,
          serverOffset: _serverOffset,
          standardHours: _standardHours,
        );
      },
    );
  }
}

class _LiveWorkTimer extends StatefulWidget {
  final Attendance attendance;
  final DateTime startUtc;
  final Duration serverOffset;
  final int standardHours;
  const _LiveWorkTimer({
    required this.attendance,
    required this.startUtc,
    required this.serverOffset,
    required this.standardHours,
  });

  @override
  State<_LiveWorkTimer> createState() => _LiveWorkTimerState();
}

class _LiveWorkTimerState extends State<_LiveWorkTimer> {
  late final Stream<int> _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Stream<int>.periodic(const Duration(seconds: 1), (i) => i);
  }

  String _format(Duration d) {
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return 'Working: $hours:$minutes:$seconds';
  }

  Color _progressColor(double p) {
    if (p < 0.75) return Colors.green;
    if (p < 1.0) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final standardSeconds = widget.standardHours * 3600;
    return StreamBuilder<int>(
      stream: _ticker,
      builder: (context, _) {
        final nowUtc = DateTime.now().toUtc().add(widget.serverOffset);
        final elapsed = nowUtc.difference(widget.startUtc);
        final progress = (elapsed.inSeconds / standardSeconds).clamp(0.0, 1.5);

        // Consistent formatting with list view
        final a = widget.attendance;
        final statusText = displayTextForStatus(a.status, record: a);
        final dateText = DateFormat('EEEE, MMM d').format(a.date);
        final checkInStr = a.checkInTime != null
            ? DateFormat('HH:mm').format(a.checkInTime!)
            : '--:--';
        final checkOutStr = a.checkOutTime != null
            ? DateFormat('HH:mm').format(a.checkOutTime!)
            : '--:--';

        // Minute-accurate elapsed summary
        final elapsedMinutes = elapsed.inMinutes;
        String elapsedSummary() {
          final hours = elapsedMinutes ~/ 60;
          final minutes = elapsedMinutes % 60;
          if (hours == 0) return '$minutes minute${minutes == 1 ? '' : 's'}';
          if (minutes == 0) return '$hours hour${hours == 1 ? '' : 's'}';
          return '$hours hour${hours == 1 ? '' : 's'} $minutes minute${minutes == 1 ? '' : 's'}';
        }

        // Discrepancy check: only when a checkout exists
        final expectedMinutes =
            (a.checkInTime != null && a.checkOutTime != null)
                ? exactMinutesBetween(a.checkInTime!, a.checkOutTime!)
                : null;
        final hasDiscrepancy = expectedMinutes != null &&
            (expectedMinutes - elapsedMinutes).abs() > 1;

        // From home chip based on geofence flag (if available)
        final fromHome = a.isWithinGeofence == true;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _format(elapsed),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 8,
                value: progress > 1.0 ? 1.0 : progress,
                color: _progressColor(progress),
                backgroundColor: Colors.grey[300],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              progress < 0.75
                  ? 'Keep going toward ${widget.standardHours}h'
                  : (progress < 1.0
                      ? 'Approaching ${widget.standardHours}h'
                      : 'Exceeded ${widget.standardHours}h'),
              style: TextStyle(fontSize: 12, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            // Consistent status line matching list view
            Text(
              statusText,
              style: TextStyle(color: Colors.green[700], fontSize: 14),
            ),
            const SizedBox(height: 6),
            // Breakdown by date/time periods
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                  dateText,
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                ),
                const Spacer(),
                if (fromHome)
                  Chip(
                    label: const Text('Home'),
                    backgroundColor: Colors.green[50],
                  )
                else if (a.isWithinGeofence == false)
                  Chip(
                    label: const Text('Away'),
                    backgroundColor: Colors.orange[50],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.login, size: 16, color: Colors.green[600]),
                const SizedBox(width: 6),
                Text(
                  'Check In: $checkInStr',
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                ),
                const SizedBox(width: 16),
                Icon(Icons.logout, size: 16, color: Colors.orange[600]),
                const SizedBox(width: 6),
                Text(
                  'Check Out: $checkOutStr',
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.blue[600]),
                const SizedBox(width: 6),
                Text(
                  'Elapsed: ${elapsedSummary()}',
                  style: TextStyle(color: Colors.grey[800], fontSize: 13),
                ),
              ],
            ),
            if (hasDiscrepancy) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.error_outline, size: 16, color: Colors.red[600]),
                  const SizedBox(width: 6),
                  Text(
                    'Discrepancy: expected ${formatDetailedDuration(Duration(minutes: expectedMinutes))}',
                    style: TextStyle(color: Colors.red[700], fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
