import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/staff_provider.dart';
import '../../services/shifts_service.dart';
import '../../models/shift.dart';
import 'daily_roster_content.dart';

class DailyRosterScreen extends StatefulWidget {
  const DailyRosterScreen({super.key});

  @override
  State<DailyRosterScreen> createState() => _DailyRosterScreenState();
}

class _DailyRosterScreenState extends State<DailyRosterScreen>
    with SingleTickerProviderStateMixin {
  final DateTime _selectedDate = DateTime.now();
  final bool _showTeamRoster = true; // default to Team Roster like the mock
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
    // Wrapper screen: use the shared content widget so
    // deep links to /daily_roster show the same UI but with its own AppBar.
    return Scaffold(
      appBar: AppBar(
        title: Text('Daily Roster'),
      ),
      body: const DailyRosterContent(),
    );
  }

  Widget _buildSegmentButton(BuildContext context,
      {required String label, required bool selected, required VoidCallback onTap}) {
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
    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return StreamBuilder<List<Shift>>(
      stream: _shiftsService.getDepartmentShifts(
        staffProvider.currentStaff?.department ?? 'All',
        startOfDay,
        endOfDay,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final shifts = (snapshot.data ?? [])
            .where((s) => _isSameDay(s.date, _selectedDate))
            .toList();

        if (shifts.isEmpty) {
          return _emptyState('No team schedules for this day');
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

  Widget _buildMyRoster(BuildContext context, StaffProvider staffProvider) {
    final staffId = staffProvider.currentStaffId ?? staffProvider.currentStaff?.id;
    if (staffId == null || staffId.isEmpty) {
      return _emptyState('No staff selected');
    }

    final startOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    final endOfDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, 23, 59, 59);

    return StreamBuilder<List<Shift>>(
      stream: _shiftsService.getShiftsForStaffByDateRange(staffId, startOfDay, endOfDay),
      builder: (context, snapshot) {
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
              role: staffProvider.currentStaff?.role ?? shift.role,
              status: _computeStatus(shift, _selectedDate),
            );
          },
        );
      },
    );
  }

  Widget _emptyState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.event_busy, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            Text(
              message,
              style: TextStyle(color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatHeaderDate(BuildContext context, DateTime date, {required bool isToday}) {
    final materialLocalizations = MaterialLocalizations.of(context);
    final fullDate = materialLocalizations.formatFullDate(date);
    return isToday ? 'Today, $fullDate' : fullDate;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  _ShiftStatus _computeStatus(Shift shift, DateTime forDay) {
    final now = DateTime.now();
    final isTargetToday = _isSameDay(forDay, now);
    if (!isTargetToday) {
      if (forDay.isBefore(DateTime(now.year, now.month, now.day))) {
        return const _ShiftStatus('Completed', Colors.grey);
      } else {
        return const _ShiftStatus('Upcoming', Colors.orange);
      }
    }

    if (now.isBefore(shift.startTime)) {
      return const _ShiftStatus('Upcoming', Colors.orange);
    }
    if (now.isAfter(shift.endTime)) {
      return const _ShiftStatus('Completed', Colors.grey);
    }
    return const _ShiftStatus('On Duty', Colors.blue);
  }
}

class _ShiftCard extends StatelessWidget {
  final Shift shift;
  final String role;
  final _ShiftStatus status;

  const _ShiftCard({
    required this.shift,
    required this.role,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, color: Colors.grey),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        shift.staffName.isNotEmpty ? shift.staffName : 'Unknown',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      if (role.isNotEmpty)
                        Text(
                          role,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Shift row with status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 4,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.blue,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.isNotEmpty ? role : 'Shift',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        _formatTimeRange(context, shift.startTime, shift.endTime),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      if (shift.location != null && shift.location!.isNotEmpty)
                        Text(
                          shift.location!,
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                Text(
                  status.label,
                  style: TextStyle(color: status.color, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeRange(BuildContext context, DateTime start, DateTime end) {
    final localizations = MaterialLocalizations.of(context);
    final from = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(start), alwaysUse24HourFormat: false);
    final to = localizations.formatTimeOfDay(TimeOfDay.fromDateTime(end), alwaysUse24HourFormat: false);
    return '$from - $to';
  }
}

class _ShiftStatus {
  final String label;
  final Color color;
  const _ShiftStatus(this.label, this.color);
}
