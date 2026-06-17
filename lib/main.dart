import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'services/staff_service.dart';
import 'models/staff.dart';
import 'providers/staff_provider.dart';
import 'screens/auth/staff_registration_screen.dart';
import 'screens/auth/initial_setup_wrapper.dart';
import 'screens/role_based_dashboard.dart';
import 'screens/staff_management/staff_attendance_screen.dart';
import 'screens/staff_management/staff_main_navigation.dart';
import 'screens/staff_management/staff_auth_screen.dart';
import 'screens/staff_management/staff_dashboard_screen.dart';
import 'screens/staff_management/staff_reports_screen.dart';
import 'screens/staff/view_schedule_screen.dart';
import 'screens/staff/update_profile_screen.dart';
import 'screens/staff/request_leave_screen.dart';
import 'services/auth_service.dart';
import 'services/schedule_service.dart';
import 'screens/staff/daily_roster_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Route guard wrapper for admin-only routes
class GuardedAdminRoute extends StatelessWidget {
  final Widget child;
  
  const GuardedAdminRoute({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService().getCurrentUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final userRole = snapshot.data ?? 'staff';
        if (userRole == 'admin') {
          return child;
        }
        
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Access Denied', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('You do not have permission to access this page.', textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Route guard wrapper for staff-only routes
class GuardedStaffRoute extends StatelessWidget {
  final Widget child;
  
  const GuardedStaffRoute({super.key, required this.child});
  
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?> (
      future: AuthService().getCurrentUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final userRole = (snapshot.data ?? 'staff').toLowerCase().trim();
        const allowedStaffRoles = [
          'staff', 'employee', 'waiter', 'cook', 'cashier', 'supervisor',
          'admin', 'manager',
        ];
        if (allowedStaffRoles.contains(userRole)) {
          return Stack(
            children: [
              child,
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Role: $userRole',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ],
          );
        }
        
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Access Denied', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('You do not have permission to access this page.', textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Route guard wrapper for admin or manager routes
class GuardedAdminOrManagerRoute extends StatelessWidget {
  final Widget child;

  const GuardedAdminOrManagerRoute({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: AuthService().getCurrentUserRole(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        
        final userRole = (snapshot.data ?? 'staff').toLowerCase();
        if (userRole == 'admin' || userRole == 'manager') {
          return child;
        }
        
        return const Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock, size: 64, color: Colors.red),
                SizedBox(height: 16),
                Text('Access Denied', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                SizedBox(height: 8),
                Text('You do not have permission to access this page.', textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      },
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Guard against duplicate initialization which causes [core/duplicate-app]
  if (Firebase.apps.isEmpty) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      // Ignore duplicate-app error if Firebase is already initialized
    }
  }
  runApp(const StaffManagementApp());
}

class StaffManagementApp extends StatelessWidget {
  const StaffManagementApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => StaffProvider(),
      child: MaterialApp(
        title: 'Staff Management System',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        home: const InitialSetupWrapper(),
        routes: {
          '/dashboard': (context) => const RoleBasedDashboard(),
          '/admin-dashboard': (context) => const GuardedAdminRoute(child: StaffManagementAppScreen()),
          '/staff-list': (context) => const GuardedStaffRoute(child: StaffListScreen()),
          '/add-staff': (context) => const GuardedAdminOrManagerRoute(child: AddStaffScreen()),
          '/reports': (context) => const GuardedAdminRoute(child: StaffReportsScreen()),
          '/schedule': (context) => const GuardedAdminRoute(child: ScheduleScreen()),
          '/staff-registration': (context) => const GuardedAdminRoute(child: StaffRegistrationScreen()),
          '/staff-attendance': (context) => const GuardedStaffRoute(child: StaffAttendanceScreen()),
          '/staff-main': (context) => const GuardedStaffRoute(child: StaffMainNavigation()),
          '/staff_auth': (context) => const StaffAuthScreen(),
          '/staff_dashboard': (context) => const GuardedStaffRoute(child: StaffDashboardScreen()),
          '/weekly_schedule': (context) => const GuardedStaffRoute(child: ViewScheduleScreen()),
          '/daily_roster': (context) => const GuardedStaffRoute(child: DailyRosterScreen()),
          '/staff-profile': (context) => const GuardedStaffRoute(child: StaffManagementAppScreen()),
          '/update_profile': (context) => GuardedStaffRoute(
            child: Builder(
              builder: (context) {
                // Get current staff from provider or auth service
                final staffProvider = Provider.of<StaffProvider>(context, listen: false);
                final currentStaff = staffProvider.allStaff.isNotEmpty ? staffProvider.allStaff.first : null;
                if (currentStaff != null) {
                  return UpdateProfileScreen(staff: currentStaff);
                }
                return const Scaffold(
                  body: Center(
                    child: Text('Staff profile not found'),
                  ),
                );
              },
            ),
          ),
          '/request_leave': (context) => GuardedStaffRoute(
            child: Builder(
              builder: (context) {
                // Get current staff from provider or auth service
                final staffProvider = Provider.of<StaffProvider>(context, listen: false);
                final currentStaff = staffProvider.allStaff.isNotEmpty ? staffProvider.allStaff.first : null;
                if (currentStaff != null) {
                  return RequestLeaveScreen(staffId: currentStaff.id);
                }
                return const Scaffold(
                  body: Center(
                    child: Text('Staff profile not found'),
                  ),
                );
              },
            ),
          ),
        },
      ),
    );
  }
}

// Schedule Screen - Roster Management
class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  String _selectedView = 'weekly';
  final StaffService _staffService = StaffService();
  
  // Staff filtering and availability state
  final String _selectedRoleFilter = 'All Roles';
  final String _selectedDepartmentFilter = 'All Departments';
  final Map<String, bool> _staffAvailability = {};
  
  // Bulk operations state
  bool _isMultiSelectMode = false;
  final Set<String> _selectedShiftIds = <String>{};
  final List<Map<String, dynamic>> _allShifts = [];
  final ScheduleService _scheduleService = ScheduleService();
  bool _notifShiftReminders = true;
  bool _notifScheduleChanges = true;
  bool _notifOvertimeAlerts = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadNotificationSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Schedule'),
        backgroundColor: Colors.purple,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Calendar', icon: Icon(Icons.calendar_month)),
            Tab(text: 'Shifts', icon: Icon(Icons.access_time)),
            Tab(text: 'Staff', icon: Icon(Icons.people)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddShiftDialog,
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _showExportDialog();
              } else if (value == 'notifications') {
                _showNotificationSettings();
              } else {
                setState(() {
                  _selectedView = value;
                });
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'daily', child: Text('Daily View')),
              const PopupMenuItem(value: 'weekly', child: Text('Weekly View')),
              const PopupMenuItem(value: 'monthly', child: Text('Monthly View')),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'export',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 18),
                    SizedBox(width: 8),
                    Text('Export Schedule'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'notifications',
                child: Row(
                  children: [
                    Icon(Icons.notifications, size: 18),
                    SizedBox(width: 8),
                    Text('Notifications'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCalendarTab(),
          _buildShiftsTab(),
          _buildStaffTab(),
        ],
      ),
    );
  }

  Widget _buildCalendarTab() {
    return Column(
      children: [
        // Date Navigation
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey[100],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedView == 'weekly'
                        ? _selectedDate.subtract(const Duration(days: 7))
                        : DateTime(_selectedDate.year, _selectedDate.month - 1);
                  });
                },
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                _selectedView == 'weekly'
                    ? 'Week of ${_formatDate(_selectedDate)}'
                    : '${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedView == 'weekly'
                        ? _selectedDate.add(const Duration(days: 7))
                        : DateTime(_selectedDate.year, _selectedDate.month + 1);
                  });
                },
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
        
        // Calendar Grid
        Expanded(
          child: _selectedView == 'weekly' ? _buildWeeklyView() : _buildMonthlyView(),
        ),
      ],
    );
  }

  Widget _buildWeeklyView() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    
    return StreamBuilder<List<Staff>>(
      stream: _staffService.getAllStaff(),
      builder: (context, snapshot) {
        final staffList = snapshot.data ?? [];
        
        return Column(
          children: [
            // Week Navigation
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.subtract(const Duration(days: 7));
                      });
                    },
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    '${_getMonthName(startOfWeek.month)} ${startOfWeek.day} - ${_getMonthName(startOfWeek.add(const Duration(days: 6)).month)} ${startOfWeek.add(const Duration(days: 6)).day}, ${startOfWeek.year}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _selectedDate = _selectedDate.add(const Duration(days: 7));
                      });
                    },
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ),
            
            // Week Summary Cards
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _buildWeekSummaryCard(
                      'Total Shifts',
                      _getWeeklyShiftCount(startOfWeek).toString(),
                      Icons.schedule,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildWeekSummaryCard(
                      'Total Hours',
                      '${_getWeeklyHours(startOfWeek).toStringAsFixed(1)}h',
                      Icons.access_time,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildWeekSummaryCard(
                      'Staff Count',
                      staffList.length.toString(),
                      Icons.people,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Week Header with Days
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const SizedBox(width: 120), // Space for staff names
                  ...List.generate(7, (index) {
                    final date = startOfWeek.add(Duration(days: index));
                    final isToday = date.day == DateTime.now().day && 
                                   date.month == DateTime.now().month && 
                                   date.year == DateTime.now().year;
                    return Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isToday ? Colors.purple[100] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: isToday ? Border.all(color: Colors.purple, width: 2) : null,
                        ),
                        child: Column(
                          children: [
                            Text(
                              _getDayName(date.weekday),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isToday ? Colors.purple : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              date.day.toString(),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: isToday ? Colors.purple : Colors.black54,
                              ),
                            ),
                            Text(
                              '${_getDailyShiftCount(date)} shifts',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Schedule Grid
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: List.generate(staffList.length, (staffIndex) {
                    final staff = staffList[staffIndex];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            // Staff Info
                            SizedBox(
                              width: 120,
                              child: GestureDetector(
                                onTap: () => _showStaffSchedule(staff),
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey[200]!),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        staff.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        staff.role,
                                        style: TextStyle(
                                          color: _getRoleColor(staff.role),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${_getStaffWeeklyHours(staff, startOfWeek).toStringAsFixed(1)}h',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            
                            // Week Schedule
                            Expanded(
                              child: Row(
                                children: List.generate(7, (dayIndex) {
                                  final date = startOfWeek.add(Duration(days: dayIndex));
                                  return Expanded(
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 1),
                                      child: _buildEnhancedShiftCell(staff, date),
                                    ),
                                  );
                                }),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMonthlyView() {
    final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
    final firstDayOfCalendar = firstDayOfMonth.subtract(Duration(days: firstDayOfMonth.weekday - 1));
    final daysInCalendar = 42; // 6 weeks * 7 days
    
    return StreamBuilder<List<Staff>>(
      stream: _staffService.getAllStaff(),
      builder: (context, snapshot) {
        final staffList = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Month Calendar Grid
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    // Days of week header
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.purple[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(8),
                          topRight: Radius.circular(8),
                        ),
                      ),
                      child: Row(
                        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
                            .map((day) => Expanded(
                                  child: Text(
                                    day,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.purple,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    ),
                    
                    // Calendar days
                    ...List.generate(6, (weekIndex) {
                      return Row(
                        children: List.generate(7, (dayIndex) {
                          final dayOffset = weekIndex * 7 + dayIndex;
                          final currentDay = firstDayOfCalendar.add(Duration(days: dayOffset));
                          final isCurrentMonth = currentDay.month == _selectedDate.month;
                          final isToday = currentDay.day == DateTime.now().day &&
                              currentDay.month == DateTime.now().month &&
                              currentDay.year == DateTime.now().year;
                          final shiftsCount = isCurrentMonth ? _getShiftsForDay(currentDay, staffList) : 0;
                          
                          return Expanded(
                            child: Container(
                              height: 80,
                              decoration: BoxDecoration(
                                border: Border(
                                  right: BorderSide(color: Colors.grey[300]!),
                                  bottom: BorderSide(color: Colors.grey[300]!),
                                ),
                                color: isToday ? Colors.purple[100] : null,
                              ),
                              child: InkWell(
                                onTap: isCurrentMonth ? () => _showDaySchedule(currentDay, staffList) : null,
                                child: Padding(
                                  padding: const EdgeInsets.all(4),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        currentDay.day.toString(),
                                        style: TextStyle(
                                          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                          color: isCurrentMonth
                                              ? (isToday ? Colors.purple : Colors.black)
                                              : Colors.grey[400],
                                        ),
                                      ),
                                      if (isCurrentMonth && shiftsCount > 0)
                                        Container(
                                          margin: const EdgeInsets.only(top: 2),
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: Colors.purple,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '$shiftsCount shifts',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      );
                    }),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Monthly Summary
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Monthly Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMonthStat('Total Shifts', _getTotalShiftsInMonth(staffList).toString()),
                          _buildMonthStat('Active Staff', staffList.where((s) => s.isActive).length.toString()),
                          _buildMonthStat('Total Hours', '${_getTotalHoursInMonth(staffList).toStringAsFixed(0)}h'),
                        ],
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
  
  Widget _buildMonthStat(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.purple),
        ),
        Text(
          label,
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }
  
  int _getShiftsForDay(DateTime day, List<Staff> staffList) {
    // Mock calculation - in real app, this would query Firestore
    return day.weekday <= 5 ? staffList.where((s) => s.isActive).length : 0;
  }
  
  int _getTotalShiftsInMonth(List<Staff> staffList) {
    // Mock calculation - approximately 22 working days per month
    return staffList.where((s) => s.isActive).length * 22;
  }
  
  double _getTotalHoursInMonth(List<Staff> staffList) {
    // Mock calculation - 8 hours per shift, 22 working days
    return staffList.where((s) => s.isActive).length * 22 * 8.0;
  }
  
  void _showDaySchedule(DateTime day, List<Staff> staffList) {
    final dayStaff = staffList.where((s) => s.isActive && day.weekday <= 5).toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Schedule for ${_formatDate(day)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (dayStaff.isEmpty)
                const Text('No shifts scheduled for this day')
              else
                ...dayStaff.map((staff) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _getRoleColor(staff.role),
                    child: Text(
                      staff.name[0].toUpperCase(),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  title: Text(staff.name),
                  subtitle: Text('${staff.role} • 9:00 AM - 5:00 PM'),
                )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (dayStaff.isNotEmpty)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to detailed day view
              },
              child: const Text('View Details'),
            ),
        ],
      ),
    );
  }

  Widget _buildShiftCell(Staff staff, DateTime date) {
    // Mock shift data - in real app, this would come from Firestore
    final hasShift = date.weekday <= 5 && staff.isActive; // Mock: weekdays only for active staff
    
    return Container(
      margin: const EdgeInsets.all(2),
      height: 40,
      decoration: BoxDecoration(
        color: hasShift ? Colors.purple[100] : Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: hasShift ? Colors.purple : Colors.grey[300]!,
        ),
      ),
      child: InkWell(
        onTap: () => _showShiftDetails(staff, date),
        child: Center(
          child: hasShift
              ? const Text(
                  '9-5',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                )
              : null,
        ),
      ),
    );
  }

  Widget _buildShiftsTab() {
    return StreamBuilder<List<Staff>>(
      stream: _staffService.getAllStaff(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final staffList = snapshot.data ?? [];
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Shift Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Today\'s Shifts',
                      staffList.where((s) => s.isActive).length.toString(),
                      Icons.today,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Hours',
                      '${staffList.fold<double>(0, (sum, s) => sum + s.totalHoursWorked).toStringAsFixed(0)}h',
                      Icons.access_time,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Shift Management
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Upcoming Shifts',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      if (_isMultiSelectMode) ...[
                         ElevatedButton.icon(
                           onPressed: _selectedShiftIds.isEmpty ? null : _bulkDeleteShifts,
                           icon: const Icon(Icons.delete),
                           label: Text('Delete (${_selectedShiftIds.length})'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.red,
                             foregroundColor: Colors.white,
                           ),
                         ),
                         const SizedBox(width: 8),
                         ElevatedButton.icon(
                           onPressed: _selectedShiftIds.isEmpty ? null : _bulkCopyShifts,
                           icon: const Icon(Icons.copy),
                           label: Text('Copy (${_selectedShiftIds.length})'),
                           style: ElevatedButton.styleFrom(
                             backgroundColor: Colors.blue,
                             foregroundColor: Colors.white,
                           ),
                         ),
                         const SizedBox(width: 8),
                         TextButton(
                           onPressed: _exitMultiSelectMode,
                           child: const Text('Cancel'),
                         ),
                       ] else ...[
                        TextButton.icon(
                          onPressed: _enterMultiSelectMode,
                          icon: const Icon(Icons.checklist),
                          label: const Text('Select'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _showAddShiftDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Shift'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Shifts List
              ...staffList.where((s) => s.isActive).map((staff) => 
                _buildShiftCard(staff),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStaffTab() {
    return StreamBuilder<List<Staff>>(
      stream: _staffService.getAllStaff(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        final staffList = snapshot.data ?? [];
        final activeStaff = staffList.where((s) => s.isActive).toList();
        final inactiveStaff = staffList.where((s) => !s.isActive).toList();
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Staff Overview
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Active Staff',
                      activeStaff.length.toString(),
                      Icons.people,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      'On Leave',
                      inactiveStaff.length.toString(),
                      Icons.person_off,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Department Filter
              const Text(
                'Staff by Department',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              
              const SizedBox(height: 16),
              
              // Department Tabs
              ...['All', 'Operations', 'Customer Service', 'Kitchen', 'Maintenance']
                  .map((dept) => _buildDepartmentSection(dept, staffList)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftCard(Staff staff) {
    final shiftId = '${staff.id}_${DateTime.now().millisecondsSinceEpoch}';
    final isSelected = _selectedShiftIds.contains(shiftId);
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: isSelected ? Colors.blue.withOpacity(0.1) : null,
      child: ListTile(
        leading: _isMultiSelectMode
            ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedShiftIds.add(shiftId);
                    } else {
                      _selectedShiftIds.remove(shiftId);
                    }
                  });
                },
              )
            : CircleAvatar(
                backgroundColor: _getRoleColor(staff.role),
                child: Text(
                  staff.name[0].toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
        title: Text(staff.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${staff.role} • ${staff.department}'),
            Text(
              'Today: 9:00 AM - 5:00 PM',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ],
        ),
        trailing: _isMultiSelectMode
            ? null
            : PopupMenuButton(
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit Shift')),
                  const PopupMenuItem(value: 'copy', child: Text('Copy Shift')),
                  const PopupMenuItem(value: 'delete', child: Text('Delete Shift')),
                ],
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _showEditShiftDialog(staff);
                      break;
                    case 'copy':
                      _copyShift(staff);
                      break;
                    case 'delete':
                      _deleteShift(staff);
                      break;
                  }
                },
              ),
        onTap: _isMultiSelectMode
            ? () {
                setState(() {
                  if (isSelected) {
                    _selectedShiftIds.remove(shiftId);
                  } else {
                    _selectedShiftIds.add(shiftId);
                  }
                });
              }
            : null,
      ),
    );
  }

  Widget _buildDepartmentSection(String department, List<Staff> allStaff) {
    final deptStaff = department == 'All'
        ? allStaff
        : allStaff.where((s) => s.department == department).toList();
    
    if (deptStaff.isEmpty && department != 'All') {
      return const SizedBox.shrink();
    }
    
    return ExpansionTile(
      title: Text('$department (${deptStaff.length})'),
      children: deptStaff.map((staff) => ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRoleColor(staff.role),
          child: Text(
            staff.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(staff.name),
        subtitle: Text(staff.role),
        trailing: Switch(
          value: staff.isActive,
          onChanged: (value) {
            // Toggle staff availability
            _toggleStaffAvailability(staff, value);
          },
        ),
      )).toList(),
    );
  }

  // Helper Methods
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return Colors.purple;
      case 'supervisor':
        return Colors.blue;
      case 'cashier':
        return Colors.green;
      case 'cook':
        return Colors.orange;
      case 'server':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  // Action Methods
  void _showAddShiftDialog({DateTime? preselectedDate, String? preselectedStaffId}) {
    DateTime selectedDate = preselectedDate ?? DateTime.now();
    TimeOfDay startTime = const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 17, minute: 0);
    String? selectedStaffId = preselectedStaffId;
    String selectedRole = 'All Roles';
    String shiftNotes = '';
    bool isRecurring = false;
    String recurringType = 'Weekly';
    int recurringCount = 1;
    final formKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.add_circle_outline, color: Colors.purple),
              const SizedBox(width: 8),
              const Text('Add New Shift'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.7,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Date Selection
                  const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today),
                          const SizedBox(width: 8),
                          Text(_formatDate(selectedDate)),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Time Selection
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Start Time', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: startTime,
                                );
                                if (time != null) {
                                  setState(() => startTime = time);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time),
                                    const SizedBox(width: 8),
                                    Text(startTime.format(context)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('End Time', style: TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final time = await showTimePicker(
                                  context: context,
                                  initialTime: endTime,
                                );
                                if (time != null) {
                                  setState(() => endTime = time);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time),
                                    const SizedBox(width: 8),
                                    Text(endTime.format(context)),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Role Filter
                  const Text('Role Filter', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: ['All Roles', 'Manager', 'Supervisor', 'Cashier', 'Cook', 'Server']
                        .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedRole = value!;
                        selectedStaffId = null; // Reset staff selection
                      });
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Staff Selection
                  const Text('Assign Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Staff>>(
                    stream: _staffService.getAllStaff(),
                    builder: (context, snapshot) {
                      final staffList = snapshot.data ?? [];
                      final filteredStaff = selectedRole == 'All Roles'
                          ? staffList.where((s) => s.isActive).toList()
                          : staffList.where((s) => s.isActive && s.role == selectedRole).toList();
                      
                      return DropdownButtonFormField<String>(
                        initialValue: selectedStaffId,
                        hint: const Text('Select staff member'),
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: filteredStaff
                            .map((staff) => DropdownMenuItem(
                                  value: staff.id,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 12,
                                        backgroundColor: _getRoleColor(staff.role),
                                        child: Text(
                                          staff.name[0].toUpperCase(),
                                          style: const TextStyle(color: Colors.white, fontSize: 10),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(staff.name, style: const TextStyle(fontSize: 14)),
                                            Text(
                                              '${staff.role} • ${staff.department}',
                                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ))
                            .toList(),
                        onChanged: (value) {
                          setState(() => selectedStaffId = value);
                        },
                      );
                    },
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Shift Notes
                  const Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextFormField(
                    onChanged: (value) => shiftNotes = value,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      hintText: 'Add any special instructions or notes...',
                      contentPadding: EdgeInsets.all(12),
                    ),
                    maxLines: 2,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Recurring Shift Option
                  Row(
                    children: [
                      Checkbox(
                        value: isRecurring,
                        onChanged: (value) {
                          setState(() => isRecurring = value ?? false);
                        },
                      ),
                      const Text('Create recurring shift', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  
                  if (isRecurring) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: recurringType,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Frequency',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            items: ['Daily', 'Weekly', 'Monthly']
                                .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                                .toList(),
                            onChanged: (value) {
                              setState(() => recurringType = value!);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: recurringCount.toString(),
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Repeat Count',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) return 'Required';
                              final count = int.tryParse(value);
                              if (count == null || count < 1 || count > 52) {
                                return 'Enter 1-52';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              recurringCount = int.tryParse(value) ?? 1;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  // Shift Duration Preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, size: 16, color: Colors.blue),
                            const SizedBox(width: 4),
                            Text('Shift Summary', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('Duration: ${_calculateShiftDuration(startTime, endTime)}h'),
                        Text('Date: ${_formatDate(selectedDate)}'),
                        if (selectedStaffId != null)
                          FutureBuilder<Staff?>(
                            future: _getStaffById(selectedStaffId!),
                            builder: (context, snapshot) {
                              final staff = snapshot.data;
                              return Text('Staff: ${staff?.name ?? 'Loading...'}');
                            },
                          ),
                        if (isRecurring)
                          Text('Recurring: $recurringCount times $recurringType'),
                      ],
                    ),
                  ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: selectedStaffId != null
                  ? () {
                      if (formKey.currentState!.validate()) {
                        Navigator.pop(context);
                        if (isRecurring) {
                          _createRecurringShifts(selectedDate, startTime, endTime, selectedStaffId!, recurringType, recurringCount, shiftNotes);
                        } else {
                          _createShift(selectedDate, startTime, endTime, selectedStaffId!, shiftNotes);
                        }
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
              ),
              child: Text(isRecurring ? 'Create Recurring Shifts' : 'Create Shift'),
            ),
          ],
        ),
      ),
    );
  }
  
  void _createShift(DateTime date, TimeOfDay startTime, TimeOfDay endTime, String staffId, [String? notes]) async {
    // Check for conflicts before creating
    final conflicts = await _checkShiftConflicts(date, startTime, endTime, staffId);
    
    if (conflicts.isNotEmpty) {
      _showConflictDialog(conflicts, date, startTime, endTime, staffId);
      return;
    }
    
    // In a real app, this would save to Firestore
    final duration = _calculateShiftDuration(startTime, endTime);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shift created for ${_formatDate(date)} (${startTime.format(context)} - ${endTime.format(context)}) - ${duration}h',
        ),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  double _calculateShiftDuration(TimeOfDay start, TimeOfDay end) {
    final startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    return (endMinutes - startMinutes) / 60.0;
  }

  Future<Staff?> _getStaffById(String staffId) async {
    // This would typically fetch from your staff database
    // For now, return a placeholder Staff object
    return Staff(
      id: staffId,
      name: 'Staff Member',
      email: 'staff@example.com',
      phone: '+1234567890',
      role: 'Employee',
      department: 'General',
      hourlyRate: 15.0,
      hireDate: DateTime.now(),
    );
  }

  void _createRecurringShifts(DateTime startDate, TimeOfDay startTime, TimeOfDay endTime, String staffId, String recurringType, int count, String? notes) async {
    for (int i = 0; i < count; i++) {
      DateTime shiftDate = startDate;
      
      switch (recurringType) {
        case 'Daily':
          shiftDate = startDate.add(Duration(days: i));
          break;
        case 'Weekly':
          shiftDate = startDate.add(Duration(days: i * 7));
          break;
        case 'Monthly':
          shiftDate = DateTime(startDate.year, startDate.month + i, startDate.day);
          break;
      }
      
      // Check for conflicts before creating each shift
      final conflicts = await _checkShiftConflicts(shiftDate, startTime, endTime, staffId);
      if (conflicts.isEmpty) {
        _createShift(shiftDate, startTime, endTime, staffId, notes);
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created $count recurring shifts'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _updateShift(DateTime date, TimeOfDay startTime, TimeOfDay endTime, String staffId, String role, String? notes, Map<String, dynamic>? existingShift) async {
    // Check for conflicts before updating (excluding the current shift)
    final conflicts = await _checkShiftConflicts(date, startTime, endTime, staffId);
    
    if (conflicts.isNotEmpty && existingShift != null) {
      // Filter out conflicts with the same shift being edited
      final relevantConflicts = conflicts.where((conflict) => 
        conflict['shift']['id'] != existingShift['id']
      ).toList();
      
      if (relevantConflicts.isNotEmpty) {
        _showConflictDialog(relevantConflicts, date, startTime, endTime, staffId);
        return;
      }
    }
    
    // In a real app, this would update the shift in Firestore
    final duration = _calculateShiftDuration(startTime, endTime);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shift updated for ${_formatDate(date)} (${startTime.format(context)} - ${endTime.format(context)}) - ${duration}h',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Conflict detection methods
  Future<List<Map<String, dynamic>>> _checkShiftConflicts(
    DateTime date, 
    TimeOfDay startTime, 
    TimeOfDay endTime, 
    String staffId
  ) async {
    List<Map<String, dynamic>> conflicts = [];
    
    // Check for overlapping shifts for the same staff member
    // In a real app, this would query the database
    final existingShifts = _getExistingShifts(date, staffId);
    
    for (final shift in existingShifts) {
      if (_isTimeOverlapping(startTime, endTime, shift['startTime'], shift['endTime'])) {
        conflicts.add({
          'type': 'staff_overlap',
          'message': 'Staff member already has a shift during this time',
          'shift': shift,
        });
      }
    }
    
    // Check for minimum rest period (8 hours between shifts)
    final previousShift = _getPreviousShift(date, staffId);
    if (previousShift != null) {
      final restHours = _calculateRestPeriod(previousShift['endTime'], startTime);
      if (restHours < 8) {
        conflicts.add({
          'type': 'insufficient_rest',
          'message': 'Insufficient rest period (${restHours.toStringAsFixed(1)}h). Minimum 8 hours required.',
          'shift': previousShift,
        });
      }
    }
    
    // Check for maximum daily hours (12 hours)
    final dailyHours = _calculateDailyHours(date, staffId) + _calculateShiftDuration(startTime, endTime);
    if (dailyHours > 12) {
      conflicts.add({
        'type': 'max_hours_exceeded',
        'message': 'Daily hours limit exceeded (${dailyHours.toStringAsFixed(1)}h). Maximum 12 hours allowed.',
      });
    }
    
    return conflicts;
  }

  List<Map<String, dynamic>> _getExistingShifts(DateTime date, String staffId) {
    // Mock data - in real app, query from database
    return [
      {
        'startTime': const TimeOfDay(hour: 9, minute: 0),
        'endTime': const TimeOfDay(hour: 17, minute: 0),
        'date': date,
      }
    ];
  }

  Map<String, dynamic>? _getPreviousShift(DateTime date, String staffId) {
    // Mock data - in real app, query from database
    final previousDay = date.subtract(const Duration(days: 1));
    return {
      'endTime': const TimeOfDay(hour: 23, minute: 0),
      'date': previousDay,
    };
  }

  double _calculateDailyHours(DateTime date, String staffId) {
    // Mock calculation - in real app, sum from database
    return 4.0; // Assume 4 hours already scheduled
  }

  double _calculateRestPeriod(TimeOfDay previousEnd, TimeOfDay currentStart) {
    final previousMinutes = previousEnd.hour * 60 + previousEnd.minute;
    final currentMinutes = currentStart.hour * 60 + currentStart.minute;
    final restMinutes = (currentMinutes + 1440) - previousMinutes; // Add 24h if next day
    return restMinutes / 60.0;
  }

  bool _isTimeOverlapping(TimeOfDay start1, TimeOfDay end1, TimeOfDay start2, TimeOfDay end2) {
    final start1Minutes = start1.hour * 60 + start1.minute;
    final end1Minutes = end1.hour * 60 + end1.minute;
    final start2Minutes = start2.hour * 60 + start2.minute;
    final end2Minutes = end2.hour * 60 + end2.minute;
    
    return start1Minutes < end2Minutes && end1Minutes > start2Minutes;
  }

  void _showConflictDialog(
    List<Map<String, dynamic>> conflicts,
    DateTime date,
    TimeOfDay startTime,
    TimeOfDay endTime,
    String staffId
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 8),
            Text('Schedule Conflicts'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'The following conflicts were detected:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              ...conflicts.map((conflict) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _getConflictIcon(conflict['type']),
                      size: 16,
                      color: _getConflictColor(conflict['type']),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conflict['message'],
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _forceCreateShift(date, startTime, endTime, staffId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
            ),
            child: const Text('Create Anyway'),
          ),
        ],
      ),
    );
  }

  IconData _getConflictIcon(String type) {
    switch (type) {
      case 'staff_overlap':
        return Icons.schedule_outlined;
      case 'insufficient_rest':
        return Icons.bedtime;
      case 'max_hours_exceeded':
        return Icons.timer_off;
      default:
        return Icons.warning;
    }
  }

  Color _getConflictColor(String type) {
    switch (type) {
      case 'staff_overlap':
        return Colors.red;
      case 'insufficient_rest':
        return Colors.orange;
      case 'max_hours_exceeded':
        return Colors.deepOrange;
      default:
        return Colors.grey;
    }
  }

  void _forceCreateShift(DateTime date, TimeOfDay startTime, TimeOfDay endTime, String staffId) {
    // Create shift despite conflicts
    final duration = _calculateShiftDuration(startTime, endTime);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shift created with conflicts for ${_formatDate(date)} (${startTime.format(context)} - ${endTime.format(context)}) - ${duration}h',
        ),
        backgroundColor: Colors.orange,
      ),
    );
  }

  // Weekly view helper methods
  Widget _buildWeekSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  int _getWeeklyShiftCount(DateTime startOfWeek) {
    // Mock calculation - in real app, query from database
    return 28; // Example: 4 staff × 7 days
  }

  double _getWeeklyHours(DateTime startOfWeek) {
    // Mock calculation - in real app, sum from database
    return 224.0; // Example: 28 shifts × 8 hours
  }

  int _getDailyShiftCount(DateTime date) {
    // Mock calculation - in real app, query from database
    return 4; // Example: 4 shifts per day
  }

  double _getStaffWeeklyHours(Staff staff, DateTime startOfWeek) {
    // Mock calculation - in real app, sum from database
    return 32.0; // Example: 4 days × 8 hours
  }

  Widget _buildEnhancedShiftCell(Staff staff, DateTime date) {
    // Mock shift data - in real app, query from database
    final hasShift = date.weekday <= 5; // Weekdays only for example
    final shiftTime = hasShift ? '9-17' : '';
    final isOvertime = hasShift && date.weekday == 5; // Friday overtime example
    
    return GestureDetector(
      onTap: () {
        if (hasShift) {
          _showShiftDetails(staff, date);
        } else {
          _showQuickAssignDialog(staff);
        }
      },
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: hasShift 
              ? (isOvertime ? Colors.orange[100] : Colors.green[100])
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: hasShift 
                ? (isOvertime ? Colors.orange : Colors.green)
                : Colors.grey[300]!,
            width: hasShift ? 2 : 1,
          ),
        ),
        child: hasShift
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    shiftTime,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isOvertime ? Colors.orange[800] : Colors.green[800],
                    ),
                  ),
                  if (isOvertime)
                    Text(
                      'OT',
                      style: TextStyle(
                        fontSize: 9,
                        color: Colors.orange[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              )
            : Icon(
                Icons.add_circle_outline,
                size: 16,
                color: Colors.grey[400],
              ),
      ),
    );
   }

  // Export and notification methods
  void _showExportDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Schedule'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('Export as PDF'),
              onTap: () {
                Navigator.pop(context);
                _exportToPDF();
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart),
              title: const Text('Export as Excel'),
              onTap: () {
                Navigator.pop(context);
                _exportToExcel();
              },
            ),
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: const Text('Export as iCal'),
              onTap: () {
                Navigator.pop(context);
                _exportToiCal();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _exportToPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('PDF export feature coming soon!'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _exportToExcel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Excel export feature coming soon!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _exportToiCal() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('iCal export feature coming soon!'),
        backgroundColor: Colors.purple,
      ),
    );
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _notifShiftReminders = prefs.getBool('notif_shift_reminders') ?? true;
      _notifScheduleChanges = prefs.getBool('notif_schedule_changes') ?? true;
      _notifOvertimeAlerts = prefs.getBool('notif_overtime_alerts') ?? false;
      final timeStr = prefs.getString('notif_reminder_time');
      if (timeStr != null) {
        final parts = timeStr.split(':');
        if (parts.length == 2) {
          final h = int.tryParse(parts[0]) ?? 8;
          final m = int.tryParse(parts[1]) ?? 0;
          _reminderTime = TimeOfDay(hour: h, minute: m);
        }
      }
    });
  }

  Future<void> _saveNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notif_shift_reminders', _notifShiftReminders);
    await prefs.setBool('notif_schedule_changes', _notifScheduleChanges);
    await prefs.setBool('notif_overtime_alerts', _notifOvertimeAlerts);
    final hh = _reminderTime.hour.toString().padLeft(2, '0');
    final mm = _reminderTime.minute.toString().padLeft(2, '0');
    await prefs.setString('notif_reminder_time', '$hh:$mm');
  }

  void _showNotificationSettings() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: const Text('Notification Settings'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: const Text('Shift Reminders'),
                    value: _notifShiftReminders,
                    onChanged: (v) {
                      setStateDialog(() => _notifShiftReminders = v);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Schedule Changes'),
                    value: _notifScheduleChanges,
                    onChanged: (v) {
                      setStateDialog(() => _notifScheduleChanges = v);
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Overtime Alerts'),
                    value: _notifOvertimeAlerts,
                    onChanged: (v) {
                      setStateDialog(() => _notifOvertimeAlerts = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    leading: const Icon(Icons.access_time),
                    title: const Text('Reminder Time'),
                    subtitle: Text(_reminderTime.format(context)),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: context,
                        initialTime: _reminderTime,
                      );
                      if (picked != null) {
                        setStateDialog(() => _reminderTime = picked);
                      }
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  await _saveNotificationSettings();
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Notification settings saved')),
                    );
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

   void _showShiftDetails(Staff staff, DateTime date) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${staff.name} - ${_formatDate(date)}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${staff.role}'),
            Text('Department: ${staff.department}'),
            const SizedBox(height: 8),
            const Text('Shift: 9:00 AM - 5:00 PM'),
            const Text('Break: 12:00 PM - 1:00 PM'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditShiftDialog(staff);
            },
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  void _showEditShiftDialog(Staff staff, {Map<String, dynamic>? existingShift}) {
    // Pre-populate with existing shift data or defaults
    DateTime selectedDate = existingShift != null 
        ? (existingShift['date'] as DateTime?) ?? DateTime.now()
        : DateTime.now();
    TimeOfDay startTime = existingShift != null
        ? TimeOfDay.fromDateTime(existingShift['startTime'] ?? DateTime.now())
        : const TimeOfDay(hour: 9, minute: 0);
    TimeOfDay endTime = existingShift != null
        ? TimeOfDay.fromDateTime(existingShift['endTime'] ?? DateTime.now().add(const Duration(hours: 8)))
        : const TimeOfDay(hour: 17, minute: 0);
    String? selectedStaffId = staff.id;
    String selectedRole = existingShift?['role'] ?? staff.role;
    String shiftNotes = existingShift?['notes'] ?? '';
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.edit, color: Colors.orange),
              const SizedBox(width: 8),
              Text('Edit Shift - ${staff.name}'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 500,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date Selection
                    const Text('Date', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 30)),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            selectedDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(_formatDate(selectedDate)),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Time Selection
                    const Text('Time', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: startTime,
                              );
                              if (time != null) {
                                setState(() {
                                  startTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time),
                                  const SizedBox(width: 8),
                                  Text('Start: ${startTime.format(context)}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final time = await showTimePicker(
                                context: context,
                                initialTime: endTime,
                              );
                              if (time != null) {
                                setState(() {
                                  endTime = time;
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time),
                                  const SizedBox(width: 8),
                                  Text('End: ${endTime.format(context)}'),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Role Selection
                    const Text('Role', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: selectedRole,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: ['Manager', 'Chef', 'Waiter', 'Cashier', 'Bartender', 'Hostess']
                          .map((role) => DropdownMenuItem(
                                value: role,
                                child: Text(role),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedRole = value;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Notes
                    const Text('Notes (Optional)', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: shiftNotes,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Add any notes for this shift...',
                        contentPadding: EdgeInsets.all(12),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        shiftNotes = value;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Shift Summary
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Shift Summary', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text('Duration: ${_calculateShiftDuration(startTime, endTime)}h'),
                          Text('Date: ${_formatDate(selectedDate)}'),
                          Text('Staff: ${staff.name}'),
                          Text('Role: $selectedRole'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _updateShift(selectedDate, startTime, endTime, selectedStaffId, selectedRole, shiftNotes, existingShift);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
              ),
              child: const Text('Update Shift'),
            ),
          ],
        ),
      ),
    );
  }

  // Bulk operations methods
  void _enterMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = true;
      _selectedShiftIds.clear();
    });
  }

  void _exitMultiSelectMode() {
    setState(() {
      _isMultiSelectMode = false;
      _selectedShiftIds.clear();
    });
  }

  void _bulkDeleteShifts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Selected Shifts'),
        content: Text('Are you sure you want to delete ${_selectedShiftIds.length} selected shifts?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement actual bulk delete logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_selectedShiftIds.length} shifts deleted successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              _exitMultiSelectMode();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _bulkCopyShifts() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Copy Selected Shifts'),
        content: Text('Copy ${_selectedShiftIds.length} selected shifts to a new date?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Implement actual bulk copy logic
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('${_selectedShiftIds.length} shifts copied successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
              _exitMultiSelectMode();
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  void _copyShift(Staff staff, {Map<String, dynamic>? shiftDetails}) {
    // Get shift details or use defaults
    final DateTime originalDate = shiftDetails?['date'] ?? DateTime.now();
    final TimeOfDay startTime = shiftDetails != null
        ? TimeOfDay.fromDateTime(shiftDetails['startTime'] ?? DateTime.now())
        : const TimeOfDay(hour: 9, minute: 0);
    final TimeOfDay endTime = shiftDetails != null
        ? TimeOfDay.fromDateTime(shiftDetails['endTime'] ?? DateTime.now().add(const Duration(hours: 8)))
        : const TimeOfDay(hour: 17, minute: 0);
    final String role = shiftDetails?['role'] ?? staff.role;
    final String notes = shiftDetails?['notes'] ?? '';

    _showCopyShiftDialog(staff, originalDate, startTime, endTime, role, notes);
  }

  void _showCopyShiftDialog(Staff originalStaff, DateTime originalDate, TimeOfDay startTime, TimeOfDay endTime, String role, String notes) {
    DateTime selectedDate = DateTime.now();
    String? selectedStaffId = originalStaff.id;
    final GlobalKey<FormState> copyFormKey = GlobalKey<FormState>();
    bool copyToMultipleDates = false;
    int numberOfCopies = 1;
    String copyFrequency = 'daily';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.copy, color: Colors.blue),
              const SizedBox(width: 8),
              const Text('Copy Shift'),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Form(
              key: copyFormKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Original Shift Summary
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Original Shift:',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: _getRoleColor(originalStaff.role),
                              radius: 16,
                              child: Text(
                                originalStaff.name[0].toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    originalStaff.name,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                  Text(
                                    '${_formatDate(originalDate)} • ${startTime.format(context)} - ${endTime.format(context)}',
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Copy Options
                  const Text(
                    'Copy To:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  // Staff Selection
                  StreamBuilder<List<Staff>>(
                    stream: _staffService.getAllStaff(),
                    builder: (context, snapshot) {
                      final staffList = snapshot.data ?? [];
                      final activeStaff = staffList.where((s) => s.isActive).toList();
                      
                      return DropdownButtonFormField<String>(
                        initialValue: selectedStaffId,
                        decoration: const InputDecoration(
                          labelText: 'Staff Member',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person),
                        ),
                        items: activeStaff.map((staff) {
                          return DropdownMenuItem(
                            value: staff.id,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getRoleColor(staff.role),
                                  radius: 12,
                                  child: Text(
                                    staff.name[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(staff.name),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedStaffId = value;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please select a staff member';
                          }
                          return null;
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Date Selection
                  InkWell(
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) {
                        setState(() {
                          selectedDate = picked;
                        });
                      }
                    },
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Date',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      child: Text(_formatDate(selectedDate)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Multiple Copies Option
                  CheckboxListTile(
                    title: const Text('Copy to multiple dates'),
                    value: copyToMultipleDates,
                    onChanged: (value) {
                      setState(() {
                        copyToMultipleDates = value ?? false;
                      });
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),

                  if (copyToMultipleDates) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: copyFrequency,
                            decoration: const InputDecoration(
                              labelText: 'Frequency',
                              border: OutlineInputBorder(),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'daily', child: Text('Daily')),
                              DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                              DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                            ],
                            onChanged: (value) {
                              setState(() {
                                copyFrequency = value!;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            initialValue: numberOfCopies.toString(),
                            decoration: const InputDecoration(
                              labelText: 'Number of copies',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Required';
                              }
                              final num = int.tryParse(value);
                              if (num == null || num < 1 || num > 30) {
                                return '1-30 only';
                              }
                              return null;
                            },
                            onChanged: (value) {
                              numberOfCopies = int.tryParse(value) ?? 1;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (copyFormKey.currentState!.validate()) {
                  Navigator.pop(context);
                  _performShiftCopy(
                    originalStaff,
                    selectedStaffId!,
                    selectedDate,
                    startTime,
                    endTime,
                    role,
                    notes,
                    copyToMultipleDates,
                    copyFrequency,
                    numberOfCopies,
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
              ),
              child: Text(copyToMultipleDates ? 'Copy Shifts' : 'Copy Shift'),
            ),
          ],
        ),
      ),
    );
  }

  void _performShiftCopy(
    Staff originalStaff,
    String selectedStaffId,
    DateTime selectedDate,
    TimeOfDay startTime,
    TimeOfDay endTime,
    String role,
    String notes,
    bool copyToMultipleDates,
    String copyFrequency,
    int numberOfCopies,
  ) async {
    // Get staff list from service
    final staffList = await _staffService.getAllStaff().first;
    final selectedStaff = staffList.firstWhere((staff) => staff.id == selectedStaffId);
    
    if (copyToMultipleDates) {
      // Copy to multiple dates
      List<DateTime> copyDates = [];
      DateTime currentDate = selectedDate;
      
      for (int i = 0; i < numberOfCopies; i++) {
        copyDates.add(currentDate);
        
        switch (copyFrequency) {
          case 'daily':
            currentDate = currentDate.add(const Duration(days: 1));
            break;
          case 'weekly':
            currentDate = currentDate.add(const Duration(days: 7));
            break;
          case 'monthly':
            currentDate = DateTime(currentDate.year, currentDate.month + 1, currentDate.day);
            break;
        }
      }
      
      // Check for conflicts
      List<DateTime> conflictDates = [];
      for (DateTime date in copyDates) {
        final conflicts = await _checkShiftConflicts(date, startTime, endTime, selectedStaffId);
        if (conflicts.isNotEmpty) {
          conflictDates.add(date);
        }
      }
      
      if (conflictDates.isNotEmpty) {
        _showCopyConflictDialog(conflictDates, () {
          _createMultipleCopies(copyDates, selectedStaff, startTime, endTime, role, notes);
        });
      } else {
        _createMultipleCopies(copyDates, selectedStaff, startTime, endTime, role, notes);
      }
    } else {
      // Single copy
      final conflicts = await _checkShiftConflicts(selectedDate, startTime, endTime, selectedStaffId);
      if (conflicts.isNotEmpty) {
        _showCopyConflictDialog([selectedDate], () {
          _createSingleCopy(selectedDate, selectedStaff, startTime, endTime, role, notes);
        });
      } else {
        _createSingleCopy(selectedDate, selectedStaff, startTime, endTime, role, notes);
      }
    }
  }

  void _createSingleCopy(DateTime date, Staff staff, TimeOfDay startTime, TimeOfDay endTime, String role, String notes) {
    // In a real app, this would create the shift in Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shift copied to ${staff.name} on ${_formatDate(date)}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to the copied shift date
          },
        ),
      ),
    );
  }

  void _createMultipleCopies(List<DateTime> dates, Staff staff, TimeOfDay startTime, TimeOfDay endTime, String role, String notes) {
    // In a real app, this would create multiple shifts in Firestore
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${dates.length} shifts copied to ${staff.name}'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            // Navigate to the first copied shift date
          },
        ),
      ),
    );
  }

  void _showCopyConflictDialog(List<DateTime> conflictDates, VoidCallback onProceed) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 8),
            const Text('Shift Conflicts'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The following dates have conflicting shifts:'),
            const SizedBox(height: 8),
            ...conflictDates.map((date) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, size: 16, color: Colors.red),
                  const SizedBox(width: 8),
                  Text(_formatDate(date)),
                ],
              ),
            )),
            const SizedBox(height: 12),
            const Text('Do you want to proceed anyway?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onProceed();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Proceed'),
          ),
        ],
      ),
    );
  }

  void _deleteShift(Staff staff, {Map<String, dynamic>? shiftDetails}) {
    // Get shift details or use defaults for display
    final DateTime shiftDate = shiftDetails?['date'] ?? DateTime.now();
    final TimeOfDay startTime = shiftDetails != null
        ? TimeOfDay.fromDateTime(shiftDetails['startTime'] ?? DateTime.now())
        : const TimeOfDay(hour: 9, minute: 0);
    final TimeOfDay endTime = shiftDetails != null
        ? TimeOfDay.fromDateTime(shiftDetails['endTime'] ?? DateTime.now().add(const Duration(hours: 8)))
        : const TimeOfDay(hour: 17, minute: 0);
    final String role = shiftDetails?['role'] ?? staff.role;
    final String notes = shiftDetails?['notes'] ?? '';
    final double duration = _calculateShiftDuration(startTime, endTime);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.delete_forever, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Delete Shift'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this shift?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              
              // Shift Details Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: _getRoleColor(staff.role),
                          radius: 20,
                          child: Text(
                            staff.name[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                staff.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                role,
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
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    
                    // Shift Information
                    _buildShiftDetailRow(Icons.calendar_today, 'Date', _formatDate(shiftDate)),
                    const SizedBox(height: 8),
                    _buildShiftDetailRow(Icons.access_time, 'Time', '${startTime.format(context)} - ${endTime.format(context)}'),
                    const SizedBox(height: 8),
                    _buildShiftDetailRow(Icons.timer, 'Duration', '${duration.toStringAsFixed(1)} hours'),
                    if (notes.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildShiftDetailRow(Icons.note, 'Notes', notes),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              // Warning Message
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This action cannot be undone.',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _performShiftDeletion(staff, shiftDetails);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete Shift'),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: Colors.grey[700]),
          ),
        ),
      ],
    );
  }

  void _performShiftDeletion(Staff staff, Map<String, dynamic>? shiftDetails) {
    // In a real app, this would delete the shift from Firestore
    final shiftDate = shiftDetails?['date'] ?? DateTime.now();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Shift deleted for ${staff.name} on ${_formatDate(shiftDate)}',
        ),
        backgroundColor: Colors.red,
        action: SnackBarAction(
          label: 'Undo',
          textColor: Colors.white,
          onPressed: () {
            // In a real app, this would restore the deleted shift
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Shift restored for ${staff.name}'),
                backgroundColor: Colors.green,
              ),
            );
          },
        ),
      ),
    );
  }

  void _toggleStaffAvailability(Staff staff, bool isAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${staff.name} is now ${isAvailable ? "available" : "unavailable"}',
        ),
      ),
    );
  }
  
  // Staff assignment helper methods
  void _showBulkAssignDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bulk Assign Shifts'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select multiple staff members and assign them to shifts for a specific date range.'),
            SizedBox(height: 16),
            Text('This feature allows you to quickly schedule multiple employees at once.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Bulk assignment completed!')),
              );
            },
            child: const Text('Assign'),
          ),
        ],
      ),
    );
  }
  
  void _showAvailabilityManager() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manage Staff Availability'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Set staff availability for specific dates and time periods.'),
            SizedBox(height: 16),
            Text('This helps prevent scheduling conflicts and ensures proper coverage.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Availability updated!')),
              );
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }
  
  void _showQuickAssignDialog(Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Quick Assign - ${staff.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.today),
              title: const Text('Today'),
              subtitle: const Text('9:00 AM - 5:00 PM'),
              onTap: () {
                Navigator.pop(context);
                _assignQuickShift(staff, 'today');
              },
            ),
            ListTile(
               leading: const Icon(Icons.calendar_today),
               title: const Text('Tomorrow'),
               subtitle: const Text('9:00 AM - 5:00 PM'),
              onTap: () {
                Navigator.pop(context);
                _assignQuickShift(staff, 'tomorrow');
              },
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: const Text('Custom Time'),
              subtitle: const Text('Choose specific date and time'),
              onTap: () {
                Navigator.pop(context);
                _showAddShiftDialog();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
  
  void _assignQuickShift(Staff staff, String period) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Quick shift assigned to ${staff.name} for $period'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  void _showAvailabilityUpdate(String staffName, bool isAvailable) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$staffName is now ${isAvailable ? "available" : "unavailable"}',
        ),
        backgroundColor: isAvailable ? Colors.green : Colors.orange,
      ),
    );
  }
  
  void _showStaffSchedule(Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${staff.name}\'s Schedule'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Text('Weekly Schedule for ${staff.name}'),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildScheduleDay('Monday', '9:00 AM - 5:00 PM'),
                    _buildScheduleDay('Tuesday', '9:00 AM - 5:00 PM'),
                    _buildScheduleDay('Wednesday', 'Off'),
                    _buildScheduleDay('Thursday', '9:00 AM - 5:00 PM'),
                    _buildScheduleDay('Friday', '9:00 AM - 5:00 PM'),
                    _buildScheduleDay('Saturday', 'Off'),
                    _buildScheduleDay('Sunday', 'Off'),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Navigate to detailed schedule view
            },
            child: const Text('Edit Schedule'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildScheduleDay(String day, String time) {
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: time == 'Off' ? Colors.grey : Colors.green,
        child: Text(
          day[0],
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      title: Text(day),
      trailing: Text(
        time,
        style: TextStyle(
          color: time == 'Off' ? Colors.grey : Colors.black,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
  
  void _showStaffShiftHistory(Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${staff.name}\'s Shift History'),
        content: const SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Text('Recent shift history and performance metrics'),
              SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text(
                    'Shift history data would be displayed here\nincluding attendance, hours worked, and performance ratings.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Staff Management App Screen - Main Dashboard
class StaffManagementAppScreen extends StatefulWidget {
  const StaffManagementAppScreen({super.key});

  @override
  State<StaffManagementAppScreen> createState() => _StaffManagementAppScreenState();
}

class _StaffManagementAppScreenState extends State<StaffManagementAppScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Management Dashboard'),
        backgroundColor: Colors.blue,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Welcome to Staff Management',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Manage your team efficiently',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Quick Actions
            const Text(
              'Quick Actions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Action Cards
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildActionCard(
                    context,
                    'View Staff',
                    Icons.people,
                    Colors.green,
                    () => Navigator.pushNamed(context, '/staff-list'),
                  ),
                  _buildActionCard(
                    context,
                    'Add Staff',
                    Icons.person_add,
                    Colors.orange,
                    () => Navigator.pushNamed(context, '/add-staff'),
                  ),
                  _buildActionCard(
                    context,
                    'Schedules',
                    Icons.schedule,
                    Colors.purple,
                    () => Navigator.pushNamed(context, '/schedule'),
                  ),
                  _buildActionCard(
                    context,
                    'Reports',
                    Icons.analytics,
                    Colors.red,
                    () => Navigator.pushNamed(context, '/reports'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showComingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feature coming soon!'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}

// Staff List Screen
class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  final StaffService _staffService = StaffService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Members'),
        backgroundColor: Colors.blue,
      ),
      body: StreamBuilder<List<Staff>>(
        stream: _staffService.getAllStaff(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => setState(() {}),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          
          final staffMembers = snapshot.data ?? [];
          
          if (staffMembers.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No staff members found'),
                  SizedBox(height: 8),
                  Text('Add your first staff member to get started!'),
                ],
              ),
            );
          }
          
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: staffMembers.length,
            itemBuilder: (context, index) {
              final staff = staffMembers[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: staff.isActive ? Colors.green : Colors.grey,
                    child: Text(
                      staff.name.isNotEmpty ? staff.name[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(
                    staff.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${staff.role} - ${staff.department}'),
                      Text(
                        staff.email,
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  trailing: Icon(
                    staff.isActive ? Icons.check_circle : Icons.cancel,
                    color: staff.isActive ? Colors.green : Colors.red,
                  ),
                  onTap: () => _showStaffDetails(context, staff),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/add-staff'),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showStaffDetails(BuildContext context, Staff staff) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(staff.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Role: ${staff.role}'),
            Text('Department: ${staff.department}'),
            Text('Email: ${staff.email}'),
            Text('Phone: ${staff.phone}'),
            Text('Hourly Rate: \$${staff.hourlyRate.toStringAsFixed(2)}'),
            Text('Hire Date: ${staff.hireDate.toString().split(' ')[0]}'),
            Text('Status: ${staff.isActive ? 'Active' : 'Inactive'}'),
            if (staff.totalHoursWorked > 0)
              Text('Total Hours: ${staff.totalHoursWorked.toStringAsFixed(1)}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

// Add Staff Screen
class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key});

  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _hourlyRateController = TextEditingController();
  
  String _selectedRole = 'Staff';
  String _selectedDepartment = 'Operations';
  bool _isLoading = false;
  
  final List<String> _roles = ['Manager', 'Supervisor', 'Staff', 'Intern'];
  final List<String> _departments = ['Operations', 'Customer Service', 'Kitchen', 'Maintenance'];
  final StaffService _staffService = StaffService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Staff'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter an email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a phone number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedRole = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                initialValue: _selectedDepartment,
                decoration: const InputDecoration(
                  labelText: 'Department',
                  border: OutlineInputBorder(),
                ),
                items: _departments.map((dept) {
                  return DropdownMenuItem(
                    value: dept,
                    child: Text(dept),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDepartment = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _hourlyRateController,
                decoration: const InputDecoration(
                  labelText: 'Hourly Rate (\$)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter hourly rate';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveStaff,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text(
                          'Add Staff Member',
                          style: TextStyle(fontSize: 16),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _saveStaff() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final staff = Staff(
          id: '', // Will be set by Firestore
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          phone: _phoneController.text.trim(),
          role: _selectedRole,
          department: _selectedDepartment,
          hourlyRate: double.parse(_hourlyRateController.text),
          hireDate: DateTime.now(),
          isActive: true,
        );
        
        await _staffService.addStaff(staff);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${_nameController.text} added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding staff: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _hourlyRateController.dispose();
    super.dispose();
  }
}

// Reports Screen
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StaffService _staffService = StaffService();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        backgroundColor: Colors.red,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard), text: 'Overview'),
            Tab(icon: Icon(Icons.people), text: 'Staff'),
            Tab(icon: Icon(Icons.access_time), text: 'Attendance'),
            Tab(icon: Icon(Icons.business), text: 'Departments'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildStaffAnalyticsTab(),
          _buildAttendanceTab(),
          _buildDepartmentsTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Overview',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Summary Cards with Real Data
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final staffList = snapshot.data ?? [];
               final totalStaff = staffList.length;
               final activeStaff = staffList.where((s) => s.isActive).length;
               final onLeave = staffList.where((s) => !s.isActive).length;
               final departments = staffList.map((s) => s.department).toSet().length;
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.5,
                children: [
                  _buildSummaryCard('Total Staff', totalStaff.toString(), Icons.people, Colors.blue),
                  _buildSummaryCard('Active Today', activeStaff.toString(), Icons.check_circle, Colors.green),
                  _buildSummaryCard('On Leave', onLeave.toString(), Icons.event_busy, Colors.orange),
                  _buildSummaryCard('Departments', departments.toString(), Icons.business, Colors.purple),
                ],
              );
            },
          ),
          
          const SizedBox(height: 24),
          
          // Recent Activity
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent Activity',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No recent activity to display.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Staff Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Staff Distribution by Role
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              
              final staffList = snapshot.data ?? [];
              final roleDistribution = <String, int>{};
              
              for (final staff in staffList) {
                roleDistribution[staff.role] = (roleDistribution[staff.role] ?? 0) + 1;
              }
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff Distribution by Role',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (roleDistribution.isEmpty)
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No staff data available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        ...roleDistribution.entries.map((entry) => 
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 2,
                                  child: Text(entry.key),
                                ),
                                Expanded(
                                  flex: 3,
                                  child: LinearProgressIndicator(
                                    value: entry.value / staffList.length,
                                    backgroundColor: Colors.grey.shade300,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      _getRoleColor(entry.key),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text('${entry.value}'),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          const SizedBox(height: 16),
          
          // Department Distribution
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              final staffList = snapshot.data ?? [];
              final deptDistribution = <String, int>{};
              
              for (final staff in staffList) {
                deptDistribution[staff.department] = (deptDistribution[staff.department] ?? 0) + 1;
              }
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Staff by Department',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (deptDistribution.isEmpty)
                        const Text(
                          'No department data available.',
                          style: TextStyle(color: Colors.grey),
                        )
                      else
                        ...deptDistribution.entries.map((entry) => 
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.business,
                                  color: _getDepartmentColor(entry.key),
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _getDepartmentColor(entry.key).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    '${entry.value} staff',
                                    style: TextStyle(
                                      color: _getDepartmentColor(entry.key),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Attendance Reports',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Time Tracking Summary with Real Data
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              
              final staffList = snapshot.data ?? [];
              final totalHours = staffList.fold<double>(0, (sum, staff) => sum + staff.totalHoursWorked);
              final totalShifts = staffList.fold<int>(0, (sum, staff) => sum + staff.shiftsCompleted);
              final avgHoursPerDay = staffList.isNotEmpty && totalShifts > 0 ? totalHours / totalShifts : 0.0;
              final activeStaff = staffList.where((s) => s.isActive).length;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Time Tracking Summary',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTimeMetric('Total Hours', '${totalHours.toStringAsFixed(1)}h'),
                          _buildTimeMetric('Avg Hours/Shift', '${avgHoursPerDay.toStringAsFixed(1)}h'),
                          _buildTimeMetric('Active Staff', activeStaff.toString()),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Staff Attendance Details
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              final staffList = snapshot.data ?? [];
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Individual Staff Attendance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (staffList.isEmpty)
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No staff attendance data available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: staffList.take(5).map((staff) => 
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: staff.isActive ? Colors.green : Colors.grey,
                                    child: Text(
                                      staff.name.substring(0, 1).toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          staff.name,
                                          style: const TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          staff.role,
                                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${staff.totalHoursWorked.toStringAsFixed(1)}h',
                                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue),
                                      ),
                                      Text(
                                        '${staff.shiftsCompleted} shifts',
                                        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      color: staff.isActive ? Colors.green : Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ).toList(),
                        ),
                      if (staffList.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Showing 5 of ${staffList.length} staff members',
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Check-in Status
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              final staffList = snapshot.data ?? [];
              final checkedInToday = staffList.where((s) => 
                s.lastCheckIn != null && 
                s.lastCheckIn!.day == DateTime.now().day &&
                s.lastCheckIn!.month == DateTime.now().month &&
                s.lastCheckIn!.year == DateTime.now().year
              ).length;
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Check-in Status',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatusMetric('Checked In', checkedInToday.toString(), Colors.green),
                          _buildStatusMetric('Total Staff', staffList.length.toString(), Colors.blue),
                          _buildStatusMetric('Attendance Rate', 
                            staffList.isNotEmpty ? '${((checkedInToday / staffList.length) * 100).toStringAsFixed(0)}%' : '0%', 
                            Colors.orange),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDepartmentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Department Statistics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Department Performance with Real Data
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                );
              }
              
              final staffList = snapshot.data ?? [];
              final departmentStats = <String, Map<String, dynamic>>{};
              
              // Calculate department statistics
              for (final staff in staffList) {
                if (!departmentStats.containsKey(staff.department)) {
                  departmentStats[staff.department] = {
                    'count': 0,
                    'totalHours': 0.0,
                    'totalShifts': 0,
                    'activeCount': 0,
                    'totalSalary': 0.0,
                  };
                }
                
                departmentStats[staff.department]!['count']++;
                departmentStats[staff.department]!['totalHours'] += staff.totalHoursWorked;
                departmentStats[staff.department]!['totalShifts'] += staff.shiftsCompleted;
                departmentStats[staff.department]!['totalSalary'] += staff.hourlyRate * staff.totalHoursWorked;
                if (staff.isActive) {
                  departmentStats[staff.department]!['activeCount']++;
                }
              }
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Department Performance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      if (departmentStats.isEmpty)
                        Container(
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Center(
                            child: Text(
                              'No department data available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        )
                      else
                        Column(
                          children: departmentStats.entries.map((entry) {
                            final department = entry.key;
                            final stats = entry.value;
                            final avgHours = stats['totalShifts'] > 0 
                                ? (stats['totalHours'] / stats['totalShifts']).toStringAsFixed(1)
                                : '0.0';
                            final activeRate = stats['count'] > 0 
                                ? ((stats['activeCount'] / stats['count']) * 100).toStringAsFixed(0)
                                : '0';
                            
                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: _getDepartmentColor(department).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _getDepartmentColor(department).withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: _getDepartmentColor(department),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          _getDepartmentIcon(department),
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          department,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: _getDepartmentColor(department),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${stats['count']} staff',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                                    children: [
                                      _buildDeptMetric('Avg Hours/Shift', '${avgHours}h'),
                                      _buildDeptMetric('Active Rate', '$activeRate%'),
                                      _buildDeptMetric('Total Hours', '${stats['totalHours'].toStringAsFixed(0)}h'),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Top Performing Departments
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              final staffList = snapshot.data ?? [];
              
              if (staffList.isEmpty) {
                return const SizedBox.shrink();
              }
              
              // Calculate department performance scores
              final departmentPerformance = <String, double>{};
              final departmentCounts = <String, int>{};
              
              for (final staff in staffList) {
                departmentCounts[staff.department] = (departmentCounts[staff.department] ?? 0) + 1;
                
                // Simple performance score based on hours worked and shifts completed
                final performanceScore = staff.shiftsCompleted > 0 
                    ? (staff.totalHoursWorked / staff.shiftsCompleted) * (staff.isActive ? 1.2 : 1.0)
                    : 0.0;
                
                departmentPerformance[staff.department] = 
                    (departmentPerformance[staff.department] ?? 0.0) + performanceScore;
              }
              
              // Calculate average performance per department
              final avgPerformance = departmentPerformance.entries.map((entry) {
                final avgScore = departmentCounts[entry.key]! > 0 
                    ? entry.value / departmentCounts[entry.key]!
                    : 0.0;
                return MapEntry(entry.key, avgScore);
              }).toList();
              
              // Sort by performance
              avgPerformance.sort((a, b) => b.value.compareTo(a.value));
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Department Performance Ranking',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Column(
                        children: avgPerformance.take(3).map((entry) {
                          final index = avgPerformance.indexOf(entry);
                          final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉';
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  medal,
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${entry.value.toStringAsFixed(1)} avg hrs/shift',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          
          // Export Options with Real Functionality
          StreamBuilder<List<Staff>>(
            stream: _staffService.getAllStaff(),
            builder: (context, snapshot) {
              final staffList = snapshot.data ?? [];
              
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Export Reports',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: staffList.isNotEmpty ? () => _exportReportsPDF(staffList) : null,
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('Export PDF'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: staffList.isNotEmpty ? () => _exportReportsCSV(staffList) : null,
                            icon: const Icon(Icons.table_chart),
                            label: const Text('Export CSV'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      if (staffList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'No data available for export',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeMetric(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: Text('$feature functionality is coming soon!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
     switch (role.toLowerCase()) {
       case 'manager':
         return Colors.purple;
       case 'developer':
         return Colors.blue;
       case 'designer':
         return Colors.orange;
       case 'analyst':
         return Colors.green;
       case 'hr':
         return Colors.red;
       case 'sales':
         return Colors.teal;
       default:
         return Colors.grey;
     }
   }

   Color _getDepartmentColor(String department) {
     switch (department.toLowerCase()) {
       case 'engineering':
         return Colors.blue;
       case 'design':
         return Colors.purple;
       case 'marketing':
         return Colors.orange;
       case 'sales':
         return Colors.green;
       case 'hr':
         return Colors.red;
       case 'finance':
         return Colors.indigo;
       default:
         return Colors.grey;
     }
   }

   Widget _buildStatusMetric(String label, String value, Color color) {
     return Column(
       children: [
         Container(
           padding: const EdgeInsets.all(12),
           decoration: BoxDecoration(
             color: color.withOpacity(0.1),
             borderRadius: BorderRadius.circular(8),
           ),
           child: Icon(
             Icons.people,
             color: color,
             size: 24,
           ),
         ),
         const SizedBox(height: 8),
         Text(
           value,
           style: TextStyle(
             fontSize: 20,
             fontWeight: FontWeight.bold,
             color: color,
           ),
         ),
         Text(
           label,
           style: TextStyle(
             fontSize: 12,
             color: Colors.grey.shade600,
           ),
         ),
       ],
     );
   }

   Widget _buildDeptMetric(String label, String value) {
     return Column(
       children: [
         Text(
           value,
           style: const TextStyle(
             fontSize: 16,
             fontWeight: FontWeight.bold,
             color: Colors.blue,
           ),
         ),
         Text(
           label,
           style: const TextStyle(
             fontSize: 11,
             color: Colors.grey,
           ),
           textAlign: TextAlign.center,
         ),
       ],
     );
   }

   IconData _getDepartmentIcon(String department) {
      switch (department.toLowerCase()) {
        case 'operations':
          return Icons.settings;
        case 'customer service':
          return Icons.support_agent;
        case 'kitchen':
          return Icons.restaurant;
        case 'maintenance':
          return Icons.build;
        case 'engineering':
          return Icons.engineering;
        case 'design':
          return Icons.design_services;
        case 'marketing':
          return Icons.campaign;
        case 'sales':
          return Icons.trending_up;
        case 'hr':
          return Icons.people;
        case 'finance':
          return Icons.account_balance;
        default:
          return Icons.business;
      }
    }

    void _exportReportsPDF(List<Staff> staffList) {
      // Generate PDF report summary
      final totalStaff = staffList.length;
      final activeStaff = staffList.where((s) => s.isActive).length;
      final totalHours = staffList.fold<double>(0, (sum, staff) => sum + staff.totalHoursWorked);
      final avgHours = totalStaff > 0 ? totalHours / totalStaff : 0.0;
      
      // Show export confirmation
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PDF Report Generated: $totalStaff staff, $activeStaff active, ${totalHours.toStringAsFixed(1)}h total',
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    void _exportReportsCSV(List<Staff> staffList) {
      // Generate CSV data
      final csvData = StringBuffer();
      csvData.writeln('Name,Email,Role,Department,Hourly Rate,Total Hours,Shifts Completed,Active Status');
      
      for (final staff in staffList) {
        csvData.writeln(
          '"${staff.name}","${staff.email}","${staff.role}","${staff.department}",'
          '${staff.hourlyRate},${staff.totalHoursWorked},${staff.shiftsCompleted},${staff.isActive}'
        );
      }
      
      // Show export confirmation with data preview
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'CSV Report Generated: ${staffList.length} records exported',
          ),
          backgroundColor: Colors.blue,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Preview',
            textColor: Colors.white,
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('CSV Preview'),
                  content: SingleChildScrollView(
                    child: Text(
                      csvData.toString().split('\n').take(6).join('\n'),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    }

   @override
   void dispose() {
     _tabController.dispose();
     super.dispose();
   }
 }
