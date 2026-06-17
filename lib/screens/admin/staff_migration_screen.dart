import 'package:flutter/material.dart';
import '../../services/staff_migration_service.dart';

class StaffMigrationScreen extends StatefulWidget {
  const StaffMigrationScreen({super.key});

  @override
  State<StaffMigrationScreen> createState() => _StaffMigrationScreenState();
}

class _StaffMigrationScreenState extends State<StaffMigrationScreen> {
  bool _isLoading = false;
  String _status = '';
  List<Map<String, dynamic>> _staffAccounts = [];

  @override
  void initState() {
    super.initState();
    _loadStaffAccounts();
  }

  Future<void> _loadStaffAccounts() async {
    try {
      final accounts = await StaffMigrationService.getAllStaffAccounts();
      setState(() {
        _staffAccounts = accounts;
      });
    } catch (e) {
      setState(() {
        _status = 'Error loading staff accounts: $e';
      });
    }
  }

  Future<void> _runMigration() async {
    setState(() {
      _isLoading = true;
      _status = 'Starting migration...';
    });

    try {
      await StaffMigrationService.migrateStaffToAccounts();
      setState(() {
        _status = 'Migration completed successfully!';
      });
      
      // Reload staff accounts
      await _loadStaffAccounts();
      
    } catch (e) {
      setState(() {
        _status = 'Migration failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Migration'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Staff Account Migration',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This will add authentication PINs to existing staff members in the staff collection. Each staff member will get a default PIN based on their phone number.',
                      style: TextStyle(color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: _isLoading ? null : _runMigration,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Run Migration'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: _loadStaffAccounts,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                          ),
                          child: const Text('Refresh'),
                        ),
                      ],
                    ),
                    if (_status.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _status.contains('Error') || _status.contains('failed')
                              ? Colors.red[50]
                              : Colors.green[50],
                          border: Border.all(
                            color: _status.contains('Error') || _status.contains('failed')
                                ? Colors.red
                                : Colors.green,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _status,
                          style: TextStyle(
                            color: _status.contains('Error') || _status.contains('failed')
                                ? Colors.red[700]
                                : Colors.green[700],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Staff Accounts (${_staffAccounts.length})',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _staffAccounts.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No staff accounts found',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Run migration to create staff accounts',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _staffAccounts.length,
                      itemBuilder: (context, index) {
                        final account = _staffAccounts[index];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.blue,
                              child: Text(
                                account['name']?.substring(0, 1).toUpperCase() ?? 'S',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            title: Text(account['name'] ?? 'Unknown'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Phone: ${account['phoneNumber'] ?? 'N/A'}'),
                                Text('Role: ${account['role'] ?? 'N/A'}'),
                                Text('Department: ${account['department'] ?? 'N/A'}'),
                              ],
                            ),
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: account['isActive'] == true
                                    ? Colors.green[100]
                                    : Colors.red[100],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                account['isActive'] == true ? 'Active' : 'Inactive',
                                style: TextStyle(
                                  color: account['isActive'] == true
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            isThreeLine: true,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}