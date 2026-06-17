import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../models/attendance.dart';
import '../../services/attendance_service.dart';
import '../../const/colors.dart';
import '../../services/auth_service.dart';
import '../../utils/attendance_utils.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  List<Attendance> _attendanceRecords = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _statusFilter;
  String _period = 'monthly';
  String? _role;
  String? _currentStaffId;
  // Verification timestamps for UI tracing
  final Map<String, DateTime> _verificationTimestamps = {};

  bool get _isAdmin => (_role ?? '').toLowerCase() == 'admin' || (_role ?? '').toLowerCase() == 'manager';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadRoleAndStaff();
    _loadAttendanceHistory();
  }

  Future<void> _loadRoleAndStaff() async {
    final prefs = await SharedPreferences.getInstance();
    final staffId = prefs.getString('currentStaffId');
    final role = await AuthService().getCurrentUserRole() ?? 'staff';
    setState(() {
      _currentStaffId = staffId;
      _role = role;
    });
  }

  Future<void> _loadAttendanceHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('currentStaffId');
      if (staffId != null) {
        final records = await AttendanceService.getAttendanceByDateRange(
          staffId,
          _startDate,
          _endDate,
        );
        final completeRecords = _generateCompleteAttendanceRange(records, _startDate, _endDate);
        final filtered = _statusFilter == null
            ? completeRecords
            : completeRecords.where((r) {
                final status = computeDayStatus(r.date, records);
                return _statusFilter == null || status.toLowerCase() == _statusFilter;
              }).toList();
        setState(() {
          _attendanceRecords = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load attendance history: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  /// Generates a complete attendance range from startDate to endDate,
  /// filling in gaps with placeholder records for days without attendance.
  List<Attendance> _generateCompleteAttendanceRange(
    List<Attendance> existingRecords,
    DateTime startDate,
    DateTime endDate,
  ) {
    final completeRecords = <Attendance>[];
    final recordMap = <String, Attendance>{};
    
    // Create a map of existing records by date string for quick lookup
    for (final record in existingRecords) {
      final dateKey = '${record.date.year}-${record.date.month}-${record.date.day}';
      recordMap[dateKey] = record;
    }
    
    // Generate all dates in the range
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateNormalized = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (currentDate.isBefore(endDateNormalized.add(const Duration(days: 1)))) {
      final dateKey = '${currentDate.year}-${currentDate.month}-${currentDate.day}';
      
      if (recordMap.containsKey(dateKey)) {
        // Use existing record
        completeRecords.add(recordMap[dateKey]!);
      } else {
        // Create placeholder record for gap
        final status = computeDayStatus(currentDate, existingRecords);
        completeRecords.add(Attendance(
          id: 'placeholder_$dateKey',
          staffId: existingRecords.isNotEmpty ? existingRecords.first.staffId : '',
          date: currentDate,
          status: status,
          duration: 0.0,
        ));
      }
      
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    // Sort by date in descending order (most recent first)
    completeRecords.sort((a, b) => b.date.compareTo(a.date));
    
    return completeRecords;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColor.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadAttendanceHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Attendance History',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColor.primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppColor.primary,
          tabs: const [
            Tab(text: 'List View'),
            Tab(text: 'Table'),
            Tab(text: 'Calendar'),
            Tab(text: 'Statistics'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _openFilterSheet,
            tooltip: 'Filter',
          ),
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: _selectDateRange,
            tooltip: 'Select Date Range',
          ),
          if (_isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.download),
              onPressed: _exportCSV,
              tooltip: 'Export CSV',
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              tooltip: 'More Export Options',
              onSelected: (value) {
                switch (value) {
                  case 'verified_csv':
                    _exportVerifiedCSV();
                    break;
                  case 'verified_excel':
                    _exportVerifiedExcel();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'verified_csv', child: Text('Export Verified (CSV)')),
                PopupMenuItem(value: 'verified_excel', child: Text('Export Verified (Excel)')),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.upload_file),
              onPressed: _importCSV,
              tooltip: 'Import CSV',
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          _buildDateRangeHeader(),
          if (_statusFilter != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, size: 16),
                  const SizedBox(width: 8),
                  Text('Status: $_statusFilter'),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setState(() => _statusFilter = null);
                      _loadAttendanceHistory();
                    },
                    child: const Text('Clear'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListView(),
                _buildTableView(),
                _buildCalendarView(),
                _buildStatisticsView(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Compute verification status and discrepancies for a record
  Map<String, dynamic> _verifyAttendance(Attendance a) {
    final discrepancies = <String>[];
    bool verified = true;

    if (a.id.startsWith('placeholder_')) {
      verified = false;
      discrepancies.add('No record');
    } else {
      if (a.checkInTime == null) {
        verified = false;
        discrepancies.add('Missing check-in');
      }
      if (a.checkOutTime == null) {
        verified = false;
        discrepancies.add('Missing check-out');
      }
      if (a.checkInTime != null && a.checkOutTime != null) {
        final mins = exactMinutesBetween(a.checkInTime!, a.checkOutTime!);
        if (mins <= 0) {
          verified = false;
          discrepancies.add('Invalid duration');
        }
      }
      if ((a.status).toLowerCase() == 'late') {
        verified = false;
        discrepancies.add('Late arrival');
      }
      if (a.isWithinGeofence == false) {
        verified = false;
        discrepancies.add('Outside geofence');
      }
    }

    final key = '${a.id}_${DateFormat('yyyy-MM-dd').format(a.date)}';
    _verificationTimestamps[key] = DateTime.now();

    return {
      'verified': verified,
      'discrepancies': discrepancies,
      'verifiedAt': _verificationTimestamps[key],
    };
  }

  Widget _buildTableView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAttendanceHistory, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.table_chart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No attendance records found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Try selecting a different date range', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }

    int verifiedCount = 0;
    int unverifiedCount = 0;
    double totalHours = 0;

    List<DataRow> rows = _attendanceRecords.map((a) {
      final v = _verifyAttendance(a);
      final verified = v['verified'] as bool;
      final discrepancies = (v['discrepancies'] as List<String>);
      final verifiedAt = v['verifiedAt'] as DateTime?;

      if (verified) {
        verifiedCount++;
      } else {
        unverifiedCount++;
      }

      double dayHours = 0;
      if (a.checkInTime != null && a.checkOutTime != null) {
        dayHours = exactMinutesBetween(a.checkInTime!, a.checkOutTime!) / 60.0;
      } else {
        dayHours = a.duration;
      }
      totalHours += dayHours;

      final status = computeDayStatus(a.date, _attendanceRecords.where((r) => !r.id.startsWith('placeholder_')).toList());

      return DataRow(cells: [
        DataCell(Text(DateFormat('EEE, MMM dd').format(a.date))),
        DataCell(Row(children: [
          Icon(
            (status == 'completed' || status == 'present') ? Icons.check_circle :
              status == 'late' ? Icons.access_time :
              status == 'absent' ? Icons.cancel : Icons.info_outline,
            size: 16,
            color: (status == 'completed' || status == 'present') ? Colors.green :
              status == 'late' ? Colors.orange :
              status == 'absent' ? Colors.red : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(status.replaceAll('_', ' ')),
        ])),
        DataCell(Text(a.checkInTime != null ? DateFormat('HH:mm').format(a.checkInTime!) : '—')),
        DataCell(Text(a.checkOutTime != null ? DateFormat('HH:mm').format(a.checkOutTime!) : '—')),
        DataCell(Text(dayHours > 0 ? dayHours.toStringAsFixed(2) : 'N/A')),
        DataCell(Row(children: [
          Icon(verified ? Icons.check : Icons.error_outline, color: verified ? Colors.green : Colors.red, size: 18),
          const SizedBox(width: 6),
          Text(verified ? 'Verified' : 'Needs review', style: TextStyle(color: verified ? Colors.green[700] : Colors.red[700])),
        ])),
        DataCell(
          discrepancies.isEmpty
              ? const Text('—')
              : Wrap(spacing: 6, runSpacing: 4, children: discrepancies.map((d) => Chip(label: Text(d), backgroundColor: Colors.red[50])).toList()),
        ),
        DataCell(Text(verifiedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(verifiedAt) : '—')),
      ]);
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Date')),
                  DataColumn(label: Text('Status')),
                  DataColumn(label: Text('Check In')),
                  DataColumn(label: Text('Check Out')),
                  DataColumn(label: Text('Hours')),
                  DataColumn(label: Text('Verified')),
                  DataColumn(label: Text('Discrepancies')),
                  DataColumn(label: Text('Verified At')),
                ],
                rows: rows,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildStatCard('Verified Days', verifiedCount.toString(), Icons.check_circle, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Needs Review', unverifiedCount.toString(), Icons.error_outline, Colors.orange)),
            ],
          ),
          const SizedBox(height: 12),
          _buildStatCard('Total Hours', totalHours.toStringAsFixed(2), Icons.access_time, Colors.blue, isWide: true),
        ],
      ),
    );
  }

  void _openFilterSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        String? localStatus = _statusFilter;
        return StatefulBuilder(builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Filter by', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                DropdownButton<String>(
                  value: localStatus,
                  hint: const Text('Status'),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'checked_in', child: Text('Checked In')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'late', child: Text('Late')),
                    DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  ],
                  onChanged: (val) => setModalState(() => localStatus = val),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        setState(() => _statusFilter = localStatus);
                        Navigator.pop(context);
                        _loadAttendanceHistory();
                      },
                      child: const Text('Apply'),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () {
                        setState(() => _statusFilter = null);
                        Navigator.pop(context);
                        _loadAttendanceHistory();
                      },
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              ],
            ),
          );
        });
      },
    );
  }

  Future<void> _exportCSV() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('currentStaffId');
      if (staffId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No staff ID found for export')),
        );
        return;
      }
      final csv = await AttendanceService.exportAttendanceToCSV(
        staffId,
        _startDate,
        _endDate,
      );
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('CSV Export'),
          content: SingleChildScrollView(child: Text(csv)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _exportVerifiedCSV() async {
    try {
      final rows = <List<String>>[];
      rows.add(['Date', 'Status', 'Check In', 'Check Out', 'Hours', 'Verified At']);
      for (final a in _attendanceRecords) {
        final v = _verifyAttendance(a);
        if (v['verified'] == true) {
          final hours = (a.checkInTime != null && a.checkOutTime != null)
              ? (exactMinutesBetween(a.checkInTime!, a.checkOutTime!) / 60.0).toStringAsFixed(2)
              : a.duration.toStringAsFixed(2);
          final verifiedAt = (v['verifiedAt'] as DateTime?) != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(v['verifiedAt'] as DateTime)
              : '';
          rows.add([
            DateFormat('yyyy-MM-dd').format(a.date),
            computeDayStatus(a.date, _attendanceRecords),
            a.checkInTime != null ? DateFormat('HH:mm').format(a.checkInTime!) : '',
            a.checkOutTime != null ? DateFormat('HH:mm').format(a.checkOutTime!) : '',
            hours,
            verifiedAt,
          ]);
        }
      }

      final csv = rows.map((r) => r.map(_escapeCsv).join(',')).join('\n');
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verified CSV Export'),
          content: SingleChildScrollView(child: Text(csv)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Verified export failed: ${e.toString()}')),
      );
    }
  }

  String _escapeCsv(String v) {
    if (v.contains(',') || v.contains('\n') || v.contains('"')) {
      return '"${v.replaceAll('"', '""')}"';
    }
    return v;
  }

  Future<void> _exportVerifiedExcel() async {
    try {
      // Generate a simple HTML table compatible with Excel
      final buffer = StringBuffer();
      buffer.writeln('<table border="1">');
      buffer.writeln('<tr><th>Date</th><th>Status</th><th>Check In</th><th>Check Out</th><th>Hours</th><th>Verified At</th></tr>');
      for (final a in _attendanceRecords) {
        final v = _verifyAttendance(a);
        if (v['verified'] == true) {
          final hours = (a.checkInTime != null && a.checkOutTime != null)
              ? (exactMinutesBetween(a.checkInTime!, a.checkOutTime!) / 60.0).toStringAsFixed(2)
              : a.duration.toStringAsFixed(2);
          final verifiedAt = (v['verifiedAt'] as DateTime?) != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(v['verifiedAt'] as DateTime)
              : '';
          buffer.writeln('<tr>');
          buffer.writeln('<td>${DateFormat('yyyy-MM-dd').format(a.date)}</td>');
          buffer.writeln('<td>${computeDayStatus(a.date, _attendanceRecords)}</td>');
          buffer.writeln('<td>${a.checkInTime != null ? DateFormat('HH:mm').format(a.checkInTime!) : ''}</td>');
          buffer.writeln('<td>${a.checkOutTime != null ? DateFormat('HH:mm').format(a.checkOutTime!) : ''}</td>');
          buffer.writeln('<td>$hours</td>');
          buffer.writeln('<td>$verifiedAt</td>');
          buffer.writeln('</tr>');
        }
      }
      buffer.writeln('</table>');

      final htmlContent = buffer.toString();

      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Verified Excel (HTML Table)'),
          content: SingleChildScrollView(child: Text(htmlContent)),
          actions: [
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (kIsWeb) {
                  // Best-effort download for web as .xls
                  // ignore: avoid_web_libraries_in_flutter
                  // Only imported when kIsWeb is true
                }
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Excel export failed: ${e.toString()}')),
      );
    }
  }

  Future<void> _importCSV() async {
    final controller = TextEditingController();
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import CSV'),
        content: TextField(
          controller: controller,
          maxLines: 10,
          decoration: const InputDecoration(hintText: 'Paste CSV here'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Import')),
        ],
      ),
    );
    if (confirmed == true) {
      final result = await AttendanceService.importAttendanceFromCSV(controller.text, overwrite: true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${result['imported'] ?? 0} records')),
      );
      _loadAttendanceHistory();
    }
  }

  Widget _buildAttendanceCard(Attendance attendance) {
    final isPlaceholder = attendance.id.startsWith('placeholder_');
    final checkInTime = attendance.checkInTime;
    final checkOutTime = attendance.checkOutTime;
    // Duration text: show exact minutes when both timestamps exist; otherwise N/A
    final durationText = formatMinutesBetween(checkInTime, checkOutTime, naText: 'N/A');

    // Use the new status logic for consistent display
    final dayStatus = computeDayStatus(attendance.date, _attendanceRecords.where((r) => !r.id.startsWith('placeholder_')).toList());
    final displayText = displayTextForStatus(dayStatus, record: isPlaceholder ? null : attendance);
    
    // Determine colors and icons based on status
    Color statusColor;
    Color bgColor;
    IconData statusIcon;
    
    switch (dayStatus) {
      case 'future':
        statusColor = Colors.grey[600]!;
        bgColor = Colors.grey[100]!;
        statusIcon = Icons.schedule;
        break;
      case 'today_no_record':
        statusColor = Colors.blue[600]!;
        bgColor = Colors.blue[50]!;
        statusIcon = Icons.schedule;
        break;
      case 'absent':
        statusColor = Colors.red[600]!;
        bgColor = Colors.red[50]!;
        statusIcon = Icons.close;
        break;
      case 'present':
      case 'completed':
        statusColor = Colors.green[600]!;
        bgColor = Colors.green[50]!;
        statusIcon = Icons.check_circle;
        break;
      case 'late':
        statusColor = Colors.orange[600]!;
        bgColor = Colors.orange[50]!;
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.grey[600]!;
        bgColor = Colors.grey[100]!;
        statusIcon = Icons.help_outline;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(attendance.date),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Text(displayText, style: TextStyle(color: Colors.grey[700])),
                if (_isAdmin && !isPlaceholder)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'correct') _openCorrectionDialog(attendance);
                      if (value == 'archive') _archiveRecord(attendance);
                    },
                    itemBuilder: (context) => [
                      const PopupMenuItem(value: 'correct', child: Text('Correct Record')),
                      const PopupMenuItem(value: 'archive', child: Text('Archive')),
                    ],
                  ),
              ],
            ),
            if (!isPlaceholder) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTimeInfo(
                      'Check In',
                      checkInTime != null
                          ? DateFormat('HH:mm').format(checkInTime)
                          : 'Not recorded',
                      Icons.login,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildTimeInfo(
                      'Check Out',
                      checkOutTime != null
                          ? DateFormat('HH:mm').format(checkOutTime)
                          : 'Not yet',
                      Icons.logout,
                      checkOutTime != null ? Colors.red : Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.timer, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Duration: $durationText',
                    style: TextStyle(
                      color: Colors.grey[800],
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    attendance.checkInLocation ?? 'Office location',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _openCorrectionDialog(Attendance attendance) async {
    DateTime? newCheckIn = attendance.checkInTime;
    DateTime? newCheckOut = attendance.checkOutTime;
    String status = attendance.status;
    final reasonController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Correct Attendance'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                ListTile(
                  title: const Text('Check In Time'),
                  subtitle: Text(newCheckIn != null ? DateFormat('yyyy-MM-dd HH:mm').format(newCheckIn!) : 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final picked = await _pickDateTime(newCheckIn);
                      if (picked != null) {
                        setState(() => newCheckIn = picked);
                      }
                    },
                  ),
                ),
                ListTile(
                  title: const Text('Check Out Time'),
                  subtitle: Text(newCheckOut != null ? DateFormat('yyyy-MM-dd HH:mm').format(newCheckOut!) : 'Not set'),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () async {
                      final picked = await _pickDateTime(newCheckOut);
                      if (picked != null) {
                        setState(() => newCheckOut = picked);
                      }
                    },
                  ),
                ),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'checked_in', child: Text('Checked In')),
                    DropdownMenuItem(value: 'completed', child: Text('Completed')),
                    DropdownMenuItem(value: 'late', child: Text('Late')),
                    DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  ],
                  onChanged: (val) => status = val ?? status,
                  decoration: const InputDecoration(labelText: 'Status'),
                ),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(labelText: 'Reason'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
          ],
        );
      },
    );

    if (confirmed == true) {
      final updates = <String, dynamic>{
        'checkInTime': newCheckIn,
        'checkOutTime': newCheckOut,
        'status': status,
        'duration': _recomputeDurationHours(newCheckIn, newCheckOut),
      }..removeWhere((key, value) => value == null);

      final result = await AttendanceService.updateAttendanceWithAudit(
        attendance.id,
        updates,
        reason: reasonController.text.isEmpty ? 'Correction' : reasonController.text,
      );

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record updated')));
        _loadAttendanceHistory();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Update failed')),
        );
      }
    }
  }

  double _recomputeDurationHours(DateTime? ci, DateTime? co) {
    if (ci == null || co == null) return 0.0;
    return co.difference(ci).inMinutes / 60.0;
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial ?? DateTime.now()),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _archiveRecord(Attendance attendance) async {
    final result = await AttendanceService.updateAttendanceWithAudit(
      attendance.id,
      {'archived': true},
      reason: 'Archived from UI',
    );
    if (result['success'] == true) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Record archived')));
      _loadAttendanceHistory();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result['message'] ?? 'Archive failed')),
      );
    }
  }

  Widget _buildStatisticsView() {
    if (_attendanceRecords.isEmpty) {
      return const Center(
        child: Text(
          'No data available for statistics',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _currentStaffId != null
          ? AttendanceService.getPeriodSummary(_currentStaffId!, period: _period)
          : Future.value({'records': _attendanceRecords, 'totalHours': _calculateTotalHours()}),
      builder: (context, snapshot) {
        final totalHours = (snapshot.data?['totalHours'] ?? _calculateTotalHours()).toDouble();
        final records = (snapshot.data?['records'] ?? _attendanceRecords) as List<Attendance>;
        final totalDays = records.length;
        final completeDays = records.where((a) => a.checkOutTime != null).length;
        final incompleteDays = totalDays - completeDays;
        final averageHours = totalDays > 0 ? totalHours / totalDays : 0;

        // Build chart bars using exact minutes between timestamps when possible
        double hoursFromRecord(Attendance a) {
          if (a.checkInTime != null && a.checkOutTime != null) {
            return exactMinutesBetween(a.checkInTime!, a.checkOutTime!) / 60.0;
          }
          // Fallback to stored duration hours if timestamps incomplete
          return a.duration;
        }
        final dailyBars = records.map((a) => hoursFromRecord(a)).toList();
        final maxHours = dailyBars.isNotEmpty ? dailyBars.reduce((a, b) => a > b ? a : b) : 0.0;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('Monthly'),
                    selected: _period == 'monthly',
                    onSelected: (_) => setState(() => _period = 'monthly'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Quarterly'),
                    selected: _period == 'quarterly',
                    onSelected: (_) => setState(() => _period = 'quarterly'),
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    label: const Text('Yearly'),
                    selected: _period == 'yearly',
                    onSelected: (_) => setState(() => _period = 'yearly'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Total Days', totalDays.toString(), Icons.calendar_today, AppColor.primary),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Complete Days', completeDays.toString(), Icons.check_circle, Colors.green),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildStatCard('Incomplete Days', incompleteDays.toString(), Icons.warning, Colors.orange),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard('Total Hours', totalHours.toStringAsFixed(1), Icons.access_time, Colors.blue),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildStatCard('Average Hours/Day', averageHours.toStringAsFixed(1), Icons.trending_up, Colors.purple, isWide: true),
              const SizedBox(height: 16),
              const Text('Daily Hours Trend', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: dailyBars.map((h) {
                    final ratio = maxHours > 0 ? h / maxHours : 0;
                    return Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        height: 100.0 * ratio,
                        decoration: BoxDecoration(color: Colors.blue[300], borderRadius: BorderRadius.circular(4)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color, {
    bool isWide = false,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: isWide
            ? Row(
                children: [
                  Icon(icon, color: color, size: 24),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: color, size: 20),
                      const Spacer(),
                    ],
                  ),
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
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDateRangeHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: AppColor.primary, size: 20),
          const SizedBox(width: 8),
          Text(
            '${DateFormat('MMM dd, yyyy').format(_startDate)} - ${DateFormat('MMM dd, yyyy').format(_endDate)}',
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 16,
            ),
          ),
          const Spacer(),
          Text(
            '${_attendanceRecords.length} records',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadAttendanceHistory, child: const Text('Retry')),
          ],
        ),
      );
    }
    if (_attendanceRecords.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('No attendance records found', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
            const SizedBox(height: 8),
            Text('Try selecting a different date range', style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadAttendanceHistory,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _attendanceRecords.length,
        itemBuilder: (context, index) => _buildAttendanceCard(_attendanceRecords[index]),
      ),
    );
  }

  Widget _buildCalendarView() {
    return const Center(
      child: Text(
        'Calendar View\n(Coming Soon)',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 18, color: Colors.grey),
      ),
    );
  }

  Widget _buildTimeInfo(String label, String time, IconData icon, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    return '${hours}h ${minutes}m';
  }

  double _calculateTotalHours() {
    double total = 0;
    for (final attendance in _attendanceRecords) {
      if (attendance.checkInTime != null && attendance.checkOutTime != null) {
        total += exactMinutesBetween(attendance.checkInTime!, attendance.checkOutTime!) / 60.0;
      } else {
        total += attendance.duration; // fallback to stored hours if incomplete
      }
    }
    return total;
  }
}
