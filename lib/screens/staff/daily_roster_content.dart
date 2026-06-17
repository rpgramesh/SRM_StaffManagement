import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../services/shifts_service.dart';
import '../../models/shift.dart';

/// Embeddable Daily Roster content for use inside dashboard tabs.
/// Mirrors the functionality of DailyRosterScreen without its own Scaffold/AppBar.
class DailyRosterContent extends StatefulWidget {
  const DailyRosterContent({super.key});

  @override
  State<DailyRosterContent> createState() => _DailyRosterContentState();
}

class _DailyRosterContentState extends State<DailyRosterContent>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  bool _showTeamRoster = true; // default to Team Roster like the mock
  final ShiftsService _shiftsService = ShiftsService();

  @override
  void initState() {
    super.initState();
    // Ensure provider has staff data for role titles and current staff Id
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = Provider.of<StaffProvider>(context, listen: false);
      // Initialize loads staff, dashboard data, and current staff
      provider.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final staffProvider = Provider.of<StaffProvider>(context);
    final isToday = _isSameDay(_selectedDate, DateTime.now());
    final dateLabel =
        _formatHeaderDate(context, _selectedDate, isToday: isToday);

    return Column(
      children: [
        // Date header with arrows
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate =
                        _selectedDate.subtract(const Duration(days: 1));
                  });
                },
              ),
              Text(
                dateLabel,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_forward_ios, size: 18),
                onPressed: () {
                  setState(() {
                    _selectedDate = _selectedDate.add(const Duration(days: 1));
                  });
                },
              ),
            ],
          ),
        ),

        // Segmented toggle: My Roster / Team Roster
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              children: [
                _buildSegmentButton(context,
                    label: 'My Roster', selected: !_showTeamRoster, onTap: () {
                  setState(() {
                    _showTeamRoster = false;
                  });
                }),
                _buildSegmentButton(context,
                    label: 'Team Roster', selected: _showTeamRoster, onTap: () {
                  setState(() {
                    _showTeamRoster = true;
                  });
                }),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        Expanded(
          child: _showTeamRoster
              ? _buildTeamRoster(context, staffProvider)
              : _buildMyRoster(context, staffProvider),
        ),
      ],
    );
  }

  String _formatTimeRange(BuildContext context, DateTime start, DateTime end) {
    final localizations = MaterialLocalizations.of(context);
    final from = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start),
        alwaysUse24HourFormat: false);
    final to = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end),
        alwaysUse24HourFormat: false);
    return '$from - $to';
  }

  Widget _buildSegmentButton(BuildContext context,
      {required String label,
      required bool selected,
      required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: selected ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTeamRoster(BuildContext context, StaffProvider staffProvider) {
    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return StreamBuilder<List<Shift>>(
      stream: _shiftsService.getDepartmentShifts(
        staffProvider.currentStaff?.department ?? 'All',
        startOfDay,
        endOfDay,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState('Failed to load team roster', snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final shifts = (snapshot.data ?? [])
            .where((s) => _isSameDay(s.date, _selectedDate))
            .toList();

        if (shifts.isEmpty) {
          return _emptyState('No team schedules for this day');
        }
        // Responsive table view for Team Roster
        return LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 600;
            if (isNarrow) {
              // Use list for narrow screens
              return ListView.builder(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: shifts.length,
                itemBuilder: (context, index) {
                  final shift = shifts[index];
                  return _ShiftCard(
                    shift: shift,
                    role: shift.role,
                    status: _computeStatus(shift, _selectedDate),
                  );
                },
              );
            }

            // Table for wider screens
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('Staff')),
                  DataColumn(label: Text('Role')),
                  DataColumn(label: Text('Time')),
                  DataColumn(label: Text('Location')),
                  DataColumn(label: Text('Status')),
                ],
                rows: shifts.map((s) {
                  final time = _formatTimeRange(context, s.startTime, s.endTime);
                  return DataRow(cells: [
                    DataCell(Text(s.staffName.isNotEmpty ? s.staffName : 'Unknown')),
                    DataCell(Text(s.role.isNotEmpty ? s.role : '—')),
                    DataCell(Text(time)),
                    DataCell(Text(s.location ?? '—')),
                    DataCell(Text(_computeStatus(s, _selectedDate))),
                  ]);
                }).toList(),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildMyRoster(BuildContext context, StaffProvider staffProvider) {
    final staffId =
        staffProvider.currentStaffId ?? staffProvider.currentStaff?.id;
    if (staffId == null || staffId.isEmpty) {
      return _emptyState('No staff selected');
    }

    final startOfDay =
        DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return StreamBuilder<List<Shift>>(
      stream: _shiftsService.getShiftsForStaffByDateRange(
          staffId, startOfDay, endOfDay),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _errorState('Failed to load your roster', snapshot.error);
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final shifts = (snapshot.data ?? [])
            .where((s) => _isSameDay(s.date, _selectedDate))
            .toList();

        if (shifts.isEmpty) {
          return _emptyState('No shifts scheduled');
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: shifts.length,
          itemBuilder: (context, index) {
            final shift = shifts[index];
            return _ShiftCard(
              shift: shift,
              role: shift.role,
              status: _computeStatus(shift, _selectedDate),
            );
          },
        );
      },
    );
  }

  // Helpers
  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatHeaderDate(BuildContext context, DateTime date,
      {bool isToday = false}) {
    final weekdayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final weekday = weekdayNames[date.weekday - 1];
    final monthNames = [
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
    final month = monthNames[date.month - 1];
    final day = date.day;
    final year = date.year;
    final todayPrefix = isToday ? 'Today, ' : '';
    return '$todayPrefix$weekday, $month $day, $year';
  }

  String _computeStatus(Shift shift, DateTime selectedDate) {
    if (shift.date.isAfter(DateTime.now())) {
      return 'Upcoming';
    }
    // Example logic; in a real app, use attendance/check-in state
    return 'Completed';
  }

  Widget _emptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy, size: 48, color: Colors.grey[500]),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: Colors.grey[600])),
        ],
      ),
    );
  }

  Widget _errorState(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              error?.toString() ?? 'Unknown error',
              style: TextStyle(color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                // Attempt a soft refresh by re-triggering build
                setState(() {});
              },
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final String role;
  final String status;

  const _ShiftCard({
    required this.shift,
    required this.role,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade100,
          child: const Icon(Icons.schedule, color: Colors.blue),
        ),
        title: Text(
            _formatTimeRange(context, shift.startTime, shift.endTime)),
        subtitle: Text(role),
        trailing: Text(status, style: TextStyle(color: Colors.grey.shade700)),
      ),
    );
  }

  String _formatTimeRange(BuildContext context, DateTime start, DateTime end) {
    final localizations = MaterialLocalizations.of(context);
    final from = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start),
        alwaysUse24HourFormat: false);
    final to = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end),
        alwaysUse24HourFormat: false);
    return '$from - $to';
  }
}
