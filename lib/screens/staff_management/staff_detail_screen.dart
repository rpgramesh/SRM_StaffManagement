import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import 'edit_staff_screen.dart';

class StaffDetailScreen extends StatefulWidget {
  final String staffId;

  const StaffDetailScreen({super.key, required this.staffId});

  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> {
  Staff? _staff;
  List<Map<String, dynamic>> _attendanceHistory = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadStaffData();
    });
  }

  Future<void> _loadStaffData() async {
    final provider = context.read<StaffProvider>();
    final staff = await provider.getStaff(widget.staffId);
    if (staff != null) {
      setState(() {
        _staff = staff;
      });
      
      final attendance = await provider.getAttendanceHistory(
        widget.staffId,
        startDate: DateTime.now().subtract(const Duration(days: 30)),
        endDate: DateTime.now(),
      );
      
      setState(() {
        _attendanceHistory = attendance;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_staff == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_staff!.name),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => _navigateToEditStaff(),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'delete',
                child: Text('Delete Staff'),
              ),
            ],
            onSelected: (value) {
              if (value == 'delete') {
                _showDeleteConfirmation();
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStaffProfileCard(),
            const SizedBox(height: 24),
            _buildQuickStats(),
            const SizedBox(height: 24),
            _buildAttendanceHistory(),
          ],
        ),
      ),
    );
  }

  Widget _buildStaffProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundColor: _getAvatarColor(_staff!.role),
              child: Text(
                _staff!.name[0].toUpperCase(),
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _staff!.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              _staff!.role,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            _buildContactInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildContactInfo() {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.email),
          title: const Text('Email'),
          subtitle: Text(_staff!.email),
        ),
        ListTile(
          leading: const Icon(Icons.phone),
          title: const Text('Phone'),
          subtitle: Text(_staff!.phone),
        ),
        ListTile(
          leading: const Icon(Icons.work),
          title: const Text('Department'),
          subtitle: Text(_staff!.department),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_today),
          title: const Text('Hire Date'),
          subtitle: Text(_formatDate(_staff!.hireDate)),
        ),
        ListTile(
          leading: const Icon(Icons.money),
          title: const Text('Salary'),
          subtitle: Text('A\$${_staff!.salary?.toStringAsFixed(2) ?? '0.00'}/month'),
        ),
      ],
    );
  }

  Widget _buildQuickStats() {
    final attendanceRate = _calculateAttendanceRate();
    final totalHours = _calculateTotalHours();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Quick Stats',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Attendance', '$attendanceRate%', Icons.check_circle, Colors.green),
                _buildStatItem('Total Hours', totalHours.toString(), Icons.timer, Colors.blue),
                _buildStatItem('Late Arrivals', '2', Icons.warning, Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceHistory() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Attendance History (Last 30 Days)',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (_attendanceHistory.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No attendance history found'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _attendanceHistory.length,
                itemBuilder: (context, index) {
                  final record = _attendanceHistory[index];
                  return _buildAttendanceRecord(record);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceRecord(Map<String, dynamic> record) {
    final date = record['date']?.toDate() ?? DateTime.now();
    final checkIn = record['checkIn']?.toDate();
    final checkOut = record['checkOut']?.toDate();
    final status = record['status'] ?? 'Present';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: status == 'Present' ? Colors.green : Colors.red,
        child: Icon(
          status == 'Present' ? Icons.check : Icons.close,
          color: Colors.white,
          size: 20,
        ),
      ),
      title: Text(_formatDate(date)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (checkIn != null)
            Text('Check-in: ${_formatTime(checkIn)}'),
          if (checkOut != null)
            Text('Check-out: ${_formatTime(checkOut)}'),
        ],
      ),
      trailing: Text(status),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, size: 32, color: color),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }

  int _calculateAttendanceRate() {
    if (_attendanceHistory.isEmpty) return 0;
    final presentDays = _attendanceHistory.where((r) => r['status'] == 'Present').length;
    return ((presentDays / _attendanceHistory.length) * 100).round();
  }

  int _calculateTotalHours() {
    // This would calculate actual hours from attendance records
    return _attendanceHistory.length * 8; // Placeholder
  }

  void _navigateToEditStaff() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditStaffScreen(staff: _staff!),
      ),
    ).then((_) {
      _loadStaffData();
    });
  }

  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete ${_staff!.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<StaffProvider>().deleteStaff(_staff!.id);
                Navigator.pop(context);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Staff deleted successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: $e')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  Color _getAvatarColor(String role) {
    switch (role.toLowerCase()) {
      case 'manager':
        return Colors.red;
      case 'supervisor':
        return Colors.orange;
      case 'waiter':
        return Colors.blue;
      case 'cook':
        return Colors.green;
      case 'cashier':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}