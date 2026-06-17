import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../const/colors.dart';

class CheckInOutScreen extends StatefulWidget {
  const CheckInOutScreen({super.key});

  @override
  State<CheckInOutScreen> createState() => _CheckInOutScreenState();
}

class _CheckInOutScreenState extends State<CheckInOutScreen> {
  String? _currentUserId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentStaffId();
  }

  Future<void> _loadCurrentStaffId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('currentStaffId');
      print('DEBUG: Loading staff ID from SharedPreferences: $staffId');
      
      // Also check all stored keys for debugging
      final allKeys = prefs.getKeys();
      print('DEBUG: All SharedPreferences keys: $allKeys');
      
      setState(() {
        _currentUserId = staffId;
      });
      print('DEBUG: Set _currentUserId to: $_currentUserId');
    } catch (e) {
      print('Error loading current staff ID: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUserId == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Check In/Out'),
          backgroundColor: AppColor.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(
          child: Text('Please log in to access attendance features'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check In/Out'),
        backgroundColor: AppColor.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: StreamBuilder<Attendance?>(
        stream: AttendanceService.streamTodayAttendance(_currentUserId!),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
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

          final attendance = snapshot.data;
          final isCheckedIn = attendance?.checkOutTime == null && attendance?.checkInTime != null;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatusCard(attendance, isCheckedIn),
                const SizedBox(height: 24),
                _buildActionButton(attendance, isCheckedIn),
                const SizedBox(height: 24),
                if (attendance != null) _buildTodaysSummary(attendance),
                const SizedBox(height: 24),
                _buildQuickStats(),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(Attendance? attendance, bool isCheckedIn) {
    final now = DateTime.now();
    
    return Card(
      elevation: 4,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: isCheckedIn 
                ? [Colors.green.shade400, Colors.green.shade600]
                : [Colors.grey.shade400, Colors.grey.shade600],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            Icon(
              isCheckedIn ? Icons.work : Icons.work_off,
              size: 64,
              color: Colors.white,
            ),
            const SizedBox(height: 16),
            Text(
              isCheckedIn ? 'Checked In' : 'Not Checked In',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDateTime(now),
              style: const TextStyle(
                fontSize: 16,
                color: Colors.white70,
              ),
            ),
            if (isCheckedIn && attendance?.checkInTime != null) ...<Widget>[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Started at ${_formatTime(attendance!.checkInTime!)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(Attendance? attendance, bool isCheckedIn) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isLoading ? null : () => _handleCheckInOut(isCheckedIn),
        style: ElevatedButton.styleFrom(
          backgroundColor: isCheckedIn ? Colors.red : Colors.green,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isLoading
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
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isCheckedIn ? 'Check Out' : 'Check In',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTodaysSummary(Attendance attendance) {
    final workingHours = attendance.totalHours;
    final checkInTime = attendance.checkInTime;
    final checkOutTime = attendance.checkOutTime;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Check In',
                    checkInTime != null ? _formatTime(checkInTime) : '--:--',
                    Icons.login,
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    'Check Out',
                    checkOutTime != null ? _formatTime(checkOutTime) : '--:--',
                    Icons.logout,
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSummaryItem(
              'Working Hours',
              '${workingHours.toStringAsFixed(1)} hours',
              Icons.access_time,
              AppColor.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStats() {
    return FutureBuilder<Map<String, dynamic>>(
      future: AttendanceService.getWeeklyAttendance(_currentUserId!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final stats = snapshot.data!;
        final weeklyHours = stats['totalHours'] ?? 0.0;
        final daysWorked = stats['daysWorked'] ?? 0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This Week',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryItem(
                        'Days Worked',
                        '$daysWorked days',
                        Icons.calendar_today,
                        Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryItem(
                        'Total Hours',
                        '${weeklyHours.toStringAsFixed(1)}h',
                        Icons.schedule,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleCheckInOut(bool isCheckedIn) async {
    print('DEBUG: _handleCheckInOut called with isCheckedIn: $isCheckedIn');
    print('DEBUG: _currentUserId: $_currentUserId');
    
    if (_currentUserId == null) {
      _showErrorMessage('No staff ID found. Please log in again.');
      return;
    }
    
    setState(() {
      _isLoading = true;
    });

    try {
      Map<String, dynamic> result;
      
      if (isCheckedIn) {
        print('DEBUG: Attempting check out for staff ID: $_currentUserId');
        result = await AttendanceService.checkOut(_currentUserId!);
      } else {
        print('DEBUG: Attempting check in for staff ID: $_currentUserId');
        result = await AttendanceService.checkIn(_currentUserId!);
      }

      print('DEBUG: AttendanceService result: $result');

      if (result['success'] == true) {
        _showSuccessMessage(
          isCheckedIn ? 'Checked out successfully!' : 'Checked in successfully!',
        );
      } else {
        _showErrorMessage(result['message'] ?? 'Operation failed');
      }
    } catch (e) {
      print('DEBUG: Exception in _handleCheckInOut: $e');
      _showErrorMessage('Error: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final day = days[dateTime.weekday - 1];
    final month = months[dateTime.month - 1];
    final time = _formatTime(dateTime);
    
    return '$day, $month ${dateTime.day} • $time';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}