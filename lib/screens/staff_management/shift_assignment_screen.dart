import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';

class ShiftAssignmentScreen extends StatefulWidget {
  final DateTime date;

  const ShiftAssignmentScreen({super.key, required this.date});

  @override
  State<ShiftAssignmentScreen> createState() => _ShiftAssignmentScreenState();
}

class _ShiftAssignmentScreenState extends State<ShiftAssignmentScreen> {
  final List<Map<String, dynamic>> _shiftRoles = [
    {
      'title': 'Front of House',
      'icon': Icons.restaurant,
      'timeRange': '8:00 AM – 4:00 PM',
      'color': Colors.blue,
    },
    {
      'title': 'Kitchen Staff',
      'icon': Icons.kitchen,
      'timeRange': '10:00 AM – 6:00 PM',
      'color': Colors.orange,
    },
    {
      'title': 'Bar Staff',
      'icon': Icons.local_bar,
      'timeRange': '12:00 PM – 8:00 PM',
      'color': Colors.purple,
    },
    {
      'title': 'Cleaning Crew',
      'icon': Icons.cleaning_services,
      'timeRange': '4:00 PM – 12:00 AM',
      'color': Colors.green,
    },
  ];

  void _showStaffAssignmentDialog(String role, String timeRange) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign $role'),
        content: Consumer<StaffProvider>(
          builder: (context, provider, child) {
            if (provider.allStaff.isEmpty) {
              return const Text('No staff members available');
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Select staff for $timeRange'),
                const SizedBox(height: 16),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: provider.allStaff.length,
                    itemBuilder: (context, index) {
                      final staff = provider.allStaff[index];
                      return ListTile(
                        title: Text(staff.name),
                        subtitle: Text(staff.department),
                        onTap: () {
                          _assignStaff(staff, role, timeRange);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
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

  void _assignStaff(Staff staff, String role, String timeRange) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${staff.name} assigned to $role ($timeRange)'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Shift Assignment'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('EEEE, MMMM d, yyyy').format(widget.date),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _shiftRoles.length,
              itemBuilder: (context, index) {
                final role = _shiftRoles[index];
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: role['color'].withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            role['icon'],
                            color: role['color'],
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                role['title'],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                role['timeRange'],
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _showStaffAssignmentDialog(
                            role['title'],
                            role['timeRange'],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: role['color'],
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                          ),
                          child: const Text('Assign'),
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
          currentIndex: 2,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people),
              label: 'Roster',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person),
              label: 'Staff',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.analytics),
              label: 'Reports',
            ),
          ],
        ),
      ),
    );
  }
}