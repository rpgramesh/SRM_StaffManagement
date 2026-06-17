import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';

class StaffReportsScreen extends StatefulWidget {
  const StaffReportsScreen({super.key});

  @override
  State<StaffReportsScreen> createState() => _StaffReportsScreenState();
}

class _StaffReportsScreenState extends State<StaffReportsScreen> {
  String _selectedReport = 'attendance';
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReportData();
    });
  }

  void _loadReportData() {
    // Load report data based on selected report type
    final provider = context.read<StaffProvider>();
    provider.loadDashboardData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Reports'),
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildReportSelector(),
          _buildDateRangeSelector(),
          Expanded(
            child: _buildReportContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildReportSelector() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildReportChoice('attendance', 'Attendance', Icons.check_circle),
          _buildReportChoice('hours', 'Work Hours', Icons.access_time),
          _buildReportChoice('performance', 'Performance', Icons.analytics),
        ],
      ),
    );
  }

  Widget _buildReportChoice(String value, String label, IconData icon) {
    return ChoiceChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: _selectedReport == value,
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedReport = value;
            _loadReportData();
          });
        }
      },
    );
  }

  Widget _buildDateRangeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => _selectDateRange(context),
              child: Text(
                '${_formatDate(_startDate)} - ${_formatDate(_endDate)}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDateRange(context),
          ),
        ],
      ),
    );
  }

  Widget _buildReportContent() {
    switch (_selectedReport) {
      case 'attendance':
        return _buildAttendanceReport();
      case 'hours':
        return _buildHoursReport();
      case 'performance':
        return _buildPerformanceReport();
      default:
        return const Center(child: Text('Select a report type'));
    }
  }

  Widget _buildAttendanceReport() {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        final staffList = provider.allStaff;
        final dashboardData = provider.dashboardData;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryCards(dashboardData),
              const SizedBox(height: 24),
              _buildAttendanceTable(staffList),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    final totalStaff = (data['totalStaff'] as int?) ?? 0;
    final checkedIn = (data['checkedIn'] as int?) ?? 0;
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.5,
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      children: [
        _buildReportCard(
          'Total Staff',
          totalStaff.toString(),
          Icons.people,
          Colors.blue,
        ),
        _buildReportCard(
          'Present Today',
          checkedIn.toString(),
          Icons.check_circle,
          Colors.green,
        ),
        _buildReportCard(
          'Absent Today',
          (totalStaff - checkedIn).toString(),
          Icons.cancel,
          Colors.red,
        ),
        _buildReportCard(
          'Attendance Rate',
          '${(checkedIn / (totalStaff > 0 ? totalStaff : 1) * 100).toStringAsFixed(1)}%',
          Icons.percent,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildAttendanceTable(List<Staff> staffList) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff Attendance Summary',
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
                  DataColumn(label: Text('Last Check-in')),
                ],
                rows: staffList.map((staff) {
                  final isCheckedIn = context.watch<StaffProvider>().checkInStatus[staff.id] ?? false;
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
                          style: const TextStyle(color: Colors.white, fontSize: 12),
                        ),
                      ),
                    ),
                    const DataCell(Text('Today')), // This would need actual data
                  ]);
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursReport() {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHoursSummary(),
              const SizedBox(height: 24),
              _buildHoursChart(),
              const SizedBox(height: 24),
              _buildHoursTable(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHoursSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Work Hours Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Total Hours', '240', Icons.timer),
                _buildSummaryItem('Avg Hours/Staff', '8.5', Icons.person),
                _buildSummaryItem('Overtime', '32', Icons.warning),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursChart() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Weekly Hours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Text('Chart visualization would go here'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHoursTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Individual Hours',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Regular Hours')),
                  DataColumn(label: Text('Overtime')),
                  DataColumn(label: Text('Total')),
                ],
                rows: const [
                  DataRow(cells: [
                    DataCell(Text('John Doe')),
                    DataCell(Text('40')),
                    DataCell(Text('5')),
                    DataCell(Text('45')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('Jane Smith')),
                    DataCell(Text('38')),
                    DataCell(Text('0')),
                    DataCell(Text('38')),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceReport() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPerformanceMetrics(),
          const SizedBox(height: 24),
          _buildPerformanceTable(),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetrics() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Performance Metrics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('Top Performer', 'John Doe', Icons.star),
                _buildSummaryItem('Avg Rating', '4.5/5', Icons.thumb_up),
                _buildSummaryItem('Tasks Completed', '95%', Icons.task),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceTable() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Staff Performance',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Name')),
                  DataColumn(label: Text('Attendance Rate')),
                  DataColumn(label: Text('Hours Worked')),
                  DataColumn(label: Text('Rating')),
                ],
                rows: const [
                  DataRow(cells: [
                    DataCell(Text('John Doe')),
                    DataCell(Text('98%')),
                    DataCell(Text('45')),
                    DataCell(Text('4.8')),
                  ]),
                  DataRow(cells: [
                    DataCell(Text('Jane Smith')),
                    DataCell(Text('95%')),
                    DataCell(Text('38')),
                    DataCell(Text('4.5')),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReportCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
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

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _startDate,
        end: _endDate,
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}