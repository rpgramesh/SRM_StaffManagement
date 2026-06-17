import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';

class StaffAttendanceScreen extends StatefulWidget {
  const StaffAttendanceScreen({super.key});

  @override
  State<StaffAttendanceScreen> createState() => _StaffAttendanceScreenState();
}

class _StaffAttendanceScreenState extends State<StaffAttendanceScreen> {
  String? _currentStaffId;
  Staff? _currentStaff;
  bool _isLoading = true;
  Attendance? _todayAttendance;
  bool _isProcessing = false;
  Timer? _timer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Initialize current staff via provider (single source of truth)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<StaffProvider>();
      provider.initializeCurrentStaff();
      // Validate against any stored ID to surface mismatch banner
      _validateStoredId();
    });
    _startTimer();
  }

  Future<void> _validateStoredId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final storedId = prefs.getString('currentStaffId');
      context
          .read<StaffProvider>()
          .validateCurrentStaffId(storedId, source: 'SharedPreferences');
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _currentTime = DateTime.now();
      });
    });
  }

  Future<void> _loadCurrentStaff() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStaffId = prefs.getString('currentStaffId');
      final savedPhone = prefs.getString('currentStaffPhone');

      Staff? staff;
      String? staffId;

      // Prefer persisted staffId from prior staff PIN login
      if (savedStaffId != null && savedStaffId.isNotEmpty) {
        staff = await context.read<StaffProvider>().getStaff(savedStaffId);
        staffId = savedStaffId;
      }

      // Fallback: resolve by phone to get staffId, then fetch Staff
      if (staff == null && savedPhone != null && savedPhone.isNotEmpty) {
        final staffData = await AuthService().getStaffByPhone(savedPhone);
        final sid = staffData?['id']?.toString();
        if (sid != null && sid.isNotEmpty) {
          staff = await context.read<StaffProvider>().getStaff(sid);
          staffId = sid;
          await prefs.setString('currentStaffId', sid);
        }
      }

      // Final fallback: use authenticated Firebase user UID
      if (staff == null) {
        final user = AuthService.getCurrentUser();
        if (user != null) {
          staff = await context.read<StaffProvider>().getStaff(user.uid);
          staffId = user.uid;
        }
      }

      // Load today's attendance when staffId is known
      Attendance? attendance;
      if (staffId != null) {
        try {
          attendance = await AttendanceService.getTodayAttendance(staffId);
        } catch (_) {}
      }

      setState(() {
        _currentStaffId = staffId;
        _currentStaff = staff;
        _todayAttendance = attendance;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _handleCheckIn() async {
    final provider = context.read<StaffProvider>();
    final staffId = provider.currentStaffId;
    if (staffId == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      debugPrint('Attendance: check-in for ${provider.currentStaff?.name} ($staffId)');
      final result = await AttendanceService.checkIn(staffId);
      if (result['success'] == true) {
        final attendance = await AttendanceService.getTodayAttendance(staffId);
        setState(() {
          _todayAttendance = attendance;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully checked in!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('❌ Failed to check in. You may already be checked in.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to check in: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _handleCheckOut() async {
    final provider = context.read<StaffProvider>();
    final staffId = provider.currentStaffId;
    if (staffId == null || _isProcessing) return;

    setState(() {
      _isProcessing = true;
    });

    try {
      debugPrint('Attendance: check-out for ${provider.currentStaff?.name} ($staffId)');
      final result = await AttendanceService.checkOut(staffId);
      if (result['success'] == true) {
        final attendance = await AttendanceService.getTodayAttendance(staffId);
        setState(() {
          _todayAttendance = attendance;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Successfully checked out!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  '❌ Failed to check out. Please make sure you are checked in.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Failed to check out: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<StaffProvider>();
    if (provider.isCurrentStaffLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (provider.currentStaff == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Attendance'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: const Center(
          child: Text(
            'Staff information not found',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Attendance',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: StreamBuilder<Attendance?>(
        stream: provider.currentStaffId != null
            ? AttendanceService.streamTodayAttendance(provider.currentStaffId!)
            : null,
        builder: (context, attendanceSnapshot) {
          final todayAttendance = attendanceSnapshot.data ?? _todayAttendance;
          final isCheckedIn = todayAttendance?.isCheckedIn ?? false;
          final checkInTime = todayAttendance?.checkInTime;
          final checkOutTime = todayAttendance?.checkOutTime;

          return RefreshIndicator(
            onRefresh: () async {
              await provider.initializeCurrentStaff();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeCard(),
                  const SizedBox(height: 16),
                  _buildSyncWarningBanner(),
                  const SizedBox(height: 8),
                  _buildStaffInfoCard(),
                  const SizedBox(height: 16),
                  _buildAttendanceCard(isCheckedIn, checkInTime, checkOutTime),
                  const SizedBox(height: 16),
                  _buildTodaySummaryCard(todayAttendance),
                  const SizedBox(height: 16),
                  _buildWeeklyProgressCard(),
                  const SizedBox(height: 100), // Space for bottom navigation
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[600]!, Colors.blue[400]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}',
            style: const TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_getDayName(_currentTime.weekday)}, ${_getMonthName(_currentTime.month)} ${_currentTime.day}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffInfoCard() {
    final provider = context.watch<StaffProvider>();
    final staff = provider.currentStaff!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: Colors.blue[100],
            child: Text(
              staff.name.isNotEmpty
                  ? staff.name[0].toUpperCase()
                  : 'S',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue[600],
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  staff.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ID: ${staff.id}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  staff.role,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(
      bool isCheckedIn, DateTime? checkInTime, DateTime? checkOutTime) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTimeSlot(
                'Check In',
                checkInTime != null
                    ? '${checkInTime.hour.toString().padLeft(2, '0')}:${checkInTime.minute.toString().padLeft(2, '0')}'
                    : '--:--',
                Icons.login,
                Colors.green,
              ),
              Container(
                height: 40,
                width: 1,
                color: Colors.grey[300],
              ),
              _buildTimeSlot(
                'Check Out',
                checkOutTime != null
                    ? '${checkOutTime.hour.toString().padLeft(2, '0')}:${checkOutTime.minute.toString().padLeft(2, '0')}'
                    : '--:--',
                Icons.logout,
                Colors.orange,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _isProcessing
                  ? null
                  : (isCheckedIn ? _handleCheckOut : _handleCheckIn),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isCheckedIn ? Colors.orange[600] : Colors.green[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isProcessing
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isCheckedIn ? Icons.logout : Icons.login,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isCheckedIn ? 'Check Out' : 'Check In',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlot(String label, String time, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          time,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildTodaySummaryCard(Attendance? todayAttendance) {
    final duration = todayAttendance?.formattedDuration ?? '0h 0m';
    final status = todayAttendance?.statusDisplayText() ?? 'Not Started';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Today\'s Summary',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSummaryItem('Duration', duration, Icons.access_time),
              _buildSummaryItem('Status', status, Icons.check_circle),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(
            icon,
            color: Colors.blue[600],
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyProgressCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Weekly Progress',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '24/40h',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: 0.6,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(Colors.blue[600]!),
            minHeight: 8,
          ),
        ],
      ),
    );
  }

  // Banner to warn about data mismatches between screens
  Widget _buildSyncWarningBanner() {
    final provider = context.watch<StaffProvider>();
    final warning = provider.syncWarning;
    if (warning == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber[300]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              warning,
              style: TextStyle(color: Colors.amber[900]),
            ),
          ),
        ],
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    return days[weekday - 1];
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }
}
