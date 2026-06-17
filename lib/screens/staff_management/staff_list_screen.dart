import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';
import 'staff_detail_screen.dart';
import 'add_staff_screen.dart';
import '../../widgets/permission_guard.dart';

class StaffListScreen extends StatefulWidget {
  const StaffListScreen({super.key});

  @override
  State<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends State<StaffListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaffProvider>().loadStaff();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff List'),
        elevation: 0,
        actions: [
          PermissionGuard(
            permission: 'modify_staff_data',
            child: IconButton(
              icon: const Icon(Icons.person_add),
              onPressed: () => _navigateToAddStaff(context),
            ),
          ),
        ],
      ),
      body: Consumer<StaffProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.staffList.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              _buildSearchAndFilterBar(context, provider),
              Expanded(
                child: _buildStaffList(context, provider),
              ),
            ],
          );
        },
      ),
      floatingActionButton: PermissionGuard(
        permission: 'modify_staff_data',
        child: FloatingActionButton(
          onPressed: () => _navigateToAddStaff(context),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilterBar(BuildContext context, StaffProvider provider) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'Search staff...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: provider.setSearchQuery,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    hintText: 'Filter by department',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  initialValue: provider.filterDepartment.isEmpty ? null : provider.filterDepartment,
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('All Departments'),
                    ),
                    ...provider.departments.map((dept) => DropdownMenuItem(
                      value: dept,
                      child: Text(dept),
                    )),
                  ],
                  onChanged: (value) => provider.setDepartmentFilter(value ?? ''),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: provider.clearFilters,
                tooltip: 'Clear filters',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStaffList(BuildContext context, StaffProvider provider) {
    if (provider.staffList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No staff found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (provider.searchQuery.isNotEmpty || provider.filterDepartment.isNotEmpty)
              TextButton(
                onPressed: provider.clearFilters,
                child: const Text('Clear filters'),
              ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: provider.staffList.length,
      itemBuilder: (context, index) {
        final staff = provider.staffList[index];
        return _buildStaffCard(context, staff);
      },
    );
  }

  Widget _buildStaffCard(BuildContext context, Staff staff) {
    final isCheckedIn = context.watch<StaffProvider>().checkInStatus[staff.id] ?? false;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getAvatarColor(staff.role),
          child: Text(
            staff.name[0].toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        title: Text(
          staff.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${staff.role} • ${staff.department}'),
            Text(
              staff.email,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isCheckedIn ? Colors.green : Colors.grey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isCheckedIn ? 'In' : 'Out',
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => _navigateToStaffDetail(context, staff),
            ),
          ],
        ),
        onTap: () => _navigateToStaffDetail(context, staff),
      ),
    );
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

  void _navigateToAddStaff(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddStaffScreen()),
    );
  }

  void _navigateToStaffDetail(BuildContext context, Staff staff) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StaffDetailScreen(staffId: staff.id),
      ),
    );
  }
}