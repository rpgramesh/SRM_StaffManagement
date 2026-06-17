import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import '../../services/auth_service.dart';

class StaffCheckinScreen extends StatefulWidget {
  const StaffCheckinScreen({super.key});

  @override
  State<StaffCheckinScreen> createState() => _StaffCheckinScreenState();
}

class _StaffCheckinScreenState extends State<StaffCheckinScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Initialize only if authenticated to avoid unauthenticated Firestore listeners
      if (AuthService().currentUser != null) {
        await context.read<StaffProvider>().initialize();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Check-in/Out'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              if (AuthService().currentUser != null) {
                await context.read<StaffProvider>().initialize();
              }
            },
          ),
        ],
      ),
      body: Consumer<StaffProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () async {
              if (AuthService().currentUser != null) {
                await provider.initialize();
              }
            },
            child: Column(
              children: [
                _buildTodayStats(context, provider),
                const SizedBox(height: 16),
                _buildCheckinControls(context, provider),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTodayStats(BuildContext context, StaffProvider provider) {
    final checkedIn = provider.checkInStatus.values.where((v) => v).length;
    final totalStaff = provider.allStaff.length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(context, 'Total Staff', totalStaff.toString(), Icons.people),
          _buildStatItem(context, 'Checked In', checkedIn.toString(), Icons.check_circle),
          _buildStatItem(context, 'Checked Out', (totalStaff - checkedIn).toString(), Icons.logout),
        ],
      ),
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Theme.of(context).primaryColor),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
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

  Widget _buildCheckinControls(BuildContext context, StaffProvider provider) {
    return Expanded(
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: provider.allStaff.length,
        itemBuilder: (context, index) {
          final staff = provider.allStaff[index];
          return _buildStaffCheckinCard(context, staff, provider);
        },
      ),
    );
  }

  Widget _buildStaffCheckinCard(BuildContext context, Staff staff, StaffProvider provider) {
    final isCheckedIn = provider.checkInStatus[staff.id] ?? false;
    final lastCheckTime = _getLastCheckTime(staff);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _getAvatarColor(staff.role),
              child: Text(
                staff.name[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${staff.role} • ${staff.department}',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (lastCheckTime != null)
                    Text(
                      'Last ${isCheckedIn ? 'check-in' : 'check-out'}: $lastCheckTime',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            _buildCheckinButton(context, staff, isCheckedIn, provider),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckinButton(
    BuildContext context,
    Staff staff,
    bool isCheckedIn,
    StaffProvider provider,
  ) {
    return ElevatedButton(
      onPressed: () => _handleCheckinToggle(staff, isCheckedIn, provider),
      style: ElevatedButton.styleFrom(
        backgroundColor: isCheckedIn ? Colors.red : Colors.green,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isCheckedIn ? Icons.logout : Icons.login, size: 16),
          const SizedBox(width: 4),
          Text(isCheckedIn ? 'Check Out' : 'Check In'),
        ],
      ),
    );
  }

  String? _getLastCheckTime(Staff staff) {
    // This would need to be implemented based on actual attendance data
    return null;
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

  Future<void> _handleCheckinToggle(
    Staff staff,
    bool isCheckedIn,
    StaffProvider provider,
  ) async {
    final action = isCheckedIn ? 'check out' : 'check in';
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm $action'),
        content: Text('Are you sure you want to $action ${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(action.toUpperCase()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        if (isCheckedIn) {
          await provider.checkOutStaff(staff.id);
        } else {
          await provider.checkInStaff(staff.id);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${staff.name} ${action}ed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to $action: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}