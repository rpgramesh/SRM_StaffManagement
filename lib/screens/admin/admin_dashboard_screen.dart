import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import '../../services/auth_service.dart';
import '../../widgets/permission_guard.dart';
import '../../widgets/navigation/admin_bottom_navigation.dart';
import 'staff_migration_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const AdminHomeTab(),
    const StaffManagementTab(),
    const AnalyticsTab(),
    const ReportsTab(),
  ];

  final List<String> _titles = [
    'Admin Dashboard',
    'Staff Management',
    'Analytics',
    'Reports',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.red[700],
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
      bottomNavigationBar: AdminBottomNavigation(
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
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      } catch (e) {
        print('Error during admin logout: $e');
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil(
            '/',
            (route) => false,
          );
        }
      }
    }
  }
}

class AdminHomeTab extends StatelessWidget {
  const AdminHomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        final dashboardData = provider.dashboardData;
        
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
                        backgroundColor: Colors.red[700],
                        child: const Icon(
                          Icons.admin_panel_settings,
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Welcome, Admin',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Today is ${DateFormat('EEEE, MMMM d, y').format(DateTime.now())}',
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
              const SizedBox(height: 16),
              
              // Quick Stats
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Total Staff',
                      '${dashboardData['totalStaff'] ?? 0}',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'Present Today',
                      '${dashboardData['presentToday'] ?? 0}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard(
                      'Absent Today',
                      '${dashboardData['absentToday'] ?? 0}',
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatCard(
                      'On Leave',
                      '${dashboardData['onLeave'] ?? 0}',
                      Icons.event_busy,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Recent Activity
              const Text(
                'Recent Activity',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildActivityItem(
                        'New staff member added',
                        'John Doe joined as Waiter',
                        Icons.person_add,
                        Colors.green,
                        '2 hours ago',
                      ),
                      const Divider(),
                      _buildActivityItem(
                        'Schedule updated',
                        'Weekly roster for next week published',
                        Icons.schedule,
                        Colors.blue,
                        '4 hours ago',
                      ),
                      const Divider(),
                      _buildActivityItem(
                        'Leave request',
                        'Sarah Smith requested leave for tomorrow',
                        Icons.event_busy,
                        Colors.orange,
                        '6 hours ago',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              
              // Quick Actions
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: PermissionGuard(
                      permission: 'modify_staff_data',
                      child: _buildActionCard(
                        'Add Staff',
                        Icons.person_add,
                        Colors.blue,
                        () => Navigator.pushNamed(context, '/add-staff'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PermissionGuard(
                      permission: 'view_reports',
                      child: _buildActionCard(
                        'View Reports',
                        Icons.assessment,
                        Colors.green,
                        () => Navigator.pushNamed(context, '/reports'),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: PermissionGuard(
                      permission: 'manage_schedules',
                      child: _buildActionCard(
                        'Schedule',
                        Icons.schedule,
                        Colors.purple,
                        () => Navigator.pushNamed(context, '/schedule'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: PermissionGuard(
                      permission: 'view_all_attendance',
                      child: _buildActionCard(
                        'Attendance',
                        Icons.fact_check,
                        Colors.orange,
                        () => Navigator.pushNamed(context, '/staff-attendance'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityItem(String title, String subtitle, IconData icon, Color color, String time) {
    return Row(
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Text(
          time,
          style: TextStyle(
            color: Colors.grey[500],
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildActionCard(String title, IconData icon, Color color, VoidCallback onTap) {
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
}

class StaffManagementTab extends StatelessWidget {
  const StaffManagementTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        final staffList = provider.allStaff.where((s) => s.isActive).toList();
        
        return Column(
          children: [
            // Header with Add Button and Migration
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Staff Members (${staffList.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                         children: [
                           PermissionGuard(
                             permission: 'access_migration',
                             child: ElevatedButton.icon(
                               onPressed: () {
                                 Navigator.push(
                                   context,
                                   MaterialPageRoute(
                                     builder: (context) => const StaffMigrationScreen(),
                                   ),
                                 );
                               },
                               icon: const Icon(Icons.sync),
                               label: const Text('Migration'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.orange[700],
                                 foregroundColor: Colors.white,
                               ),
                             ),
                           ),
                           const SizedBox(width: 8),
                           PermissionGuard(
                             permission: 'modify_staff_data',
                             child: ElevatedButton.icon(
                               onPressed: () => Navigator.pushNamed(context, '/add-staff'),
                               icon: const Icon(Icons.add),
                               label: const Text('Add Staff'),
                               style: ElevatedButton.styleFrom(
                                 backgroundColor: Colors.red[700],
                                 foregroundColor: Colors.white,
                               ),
                             ),
                           ),
                         ],
                       ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Staff List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: staffList.length,
                itemBuilder: (context, index) {
                  final staff = staffList[index];
                  final isCheckedIn = provider.checkInStatus[staff.id] ?? false;
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getRoleColor(staff.role),
                        child: Text(
                          staff.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        staff.name,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${staff.role} • ${staff.department}'),
                          Row(
                            children: [
                              Icon(
                                isCheckedIn ? Icons.check_circle : Icons.cancel,
                                size: 16,
                                color: isCheckedIn ? Colors.green : Colors.red,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isCheckedIn ? 'Present' : 'Absent',
                                style: TextStyle(
                                  color: isCheckedIn ? Colors.green : Colors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              Navigator.pushNamed(
                                context,
                                '/edit-staff',
                                arguments: staff,
                              );
                              break;
                            case 'delete':
                              _showDeleteDialog(context, staff, provider);
                              break;
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(Icons.edit, size: 16),
                                SizedBox(width: 8),
                                Text('Edit'),
                              ],
                            ),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, size: 16, color: Colors.red),
                                SizedBox(width: 8),
                                Text('Delete', style: TextStyle(color: Colors.red)),
                              ],
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
        );
      },
    );
  }

  Color _getRoleColor(String role) {
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

  void _showDeleteDialog(BuildContext context, Staff staff, StaffProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Staff'),
        content: Text('Are you sure you want to delete ${staff.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.deleteStaff(staff.id);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        final staffList = provider.allStaff;
        
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
              
              // Role Distribution Chart
              Card(
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
                      SizedBox(
                        height: 200,
                        child: _buildRoleDistributionChart(staffList),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Department Distribution
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Department Distribution',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      ..._buildDepartmentStats(staffList),
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

  Widget _buildRoleDistributionChart(List<Staff> staffList) {
    final roleDistribution = <String, int>{};
    
    for (final staff in staffList) {
      roleDistribution[staff.role] = (roleDistribution[staff.role] ?? 0) + 1;
    }
    
    if (roleDistribution.isEmpty) {
      return const Center(
        child: Text('No data available'),
      );
    }
    
    return PieChart(
      PieChartData(
        sections: roleDistribution.entries.map((entry) {
          final color = _getRoleColor(entry.key);
          return PieChartSectionData(
            value: entry.value.toDouble(),
            title: '${entry.key}\n${entry.value}',
            color: color,
            radius: 80,
            titleStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }).toList(),
        centerSpaceRadius: 40,
        sectionsSpace: 2,
      ),
    );
  }

  List<Widget> _buildDepartmentStats(List<Staff> staffList) {
    final departmentDistribution = <String, int>{};
    
    for (final staff in staffList) {
      departmentDistribution[staff.department] = (departmentDistribution[staff.department] ?? 0) + 1;
    }
    
    return departmentDistribution.entries.map((entry) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(entry.key),
            Chip(
              label: Text('${entry.value}'),
              backgroundColor: Colors.blue[100],
            ),
          ],
        ),
      );
    }).toList();
  }

  Color _getRoleColor(String role) {
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

class ReportsTab extends StatelessWidget {
  const ReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        final staffList = provider.allStaff;
        final dashboardData = provider.dashboardData;
        
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Staff Reports',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              
              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Total Staff',
                      '${dashboardData['totalStaff'] ?? 0}',
                      Icons.people,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'Present',
                      '${dashboardData['presentToday'] ?? 0}',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      'Absent',
                      '${dashboardData['absentToday'] ?? 0}',
                      Icons.cancel,
                      Colors.red,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildSummaryCard(
                      'On Leave',
                      '${dashboardData['onLeave'] ?? 0}',
                      Icons.event_busy,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Attendance Table
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Today\'s Attendance',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Department')),
                            DataColumn(label: Text('Status')),
                          ],
                          rows: staffList.map((staff) {
                            final isCheckedIn = provider.checkInStatus[staff.id] ?? false;
                            return DataRow(cells: [
                              DataCell(Text(staff.name)),
                              DataCell(Text(staff.role)),
                              DataCell(Text(staff.department)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isCheckedIn ? Colors.green : Colors.red,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    isCheckedIn ? 'Present' : 'Absent',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
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

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}