import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../providers/staff_provider.dart';
import '../../models/staff.dart';

class StaffScheduleScreen extends StatefulWidget {
  const StaffScheduleScreen({super.key});

  @override
  State<StaffScheduleScreen> createState() => _StaffScheduleScreenState();
}

class _StaffScheduleScreenState extends State<StaffScheduleScreen> {
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<StaffProvider>().loadScheduleForDate(_selectedDay);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Staff Schedule'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showAddScheduleDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportCSVForSelectedDay(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshSchedule(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildCalendar(),
          const SizedBox(height: 8),
          Expanded(
            child: _buildScheduleList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 365)),
          focusedDay: _focusedDay,
          calendarFormat: _calendarFormat,
          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
            context.read<StaffProvider>().loadScheduleForDate(selectedDay);
          },
          onFormatChanged: (format) {
            setState(() {
              _calendarFormat = format;
            });
          },
          onPageChanged: (focusedDay) {
            _focusedDay = focusedDay;
          },
          calendarStyle: CalendarStyle(
            selectedDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              shape: BoxShape.circle,
            ),
            todayDecoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
          headerStyle: const HeaderStyle(
            formatButtonVisible: false,
            titleCentered: true,
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleList() {
    return Consumer<StaffProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final schedule = provider.scheduleList;
        
        if (schedule.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No shifts scheduled for ${_formatDate(_selectedDay)}',
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _showAddScheduleDialog(context),
                  child: const Text('Add Schedule'),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: schedule.length,
          itemBuilder: (context, index) {
            return _buildScheduleCard(context, schedule[index]);
          },
        );
      },
    );
  }

  Widget _buildScheduleCard(BuildContext context, Map<String, dynamic> schedule) {
    final staffId = schedule['staffId'] ?? '';
    final staff = context.watch<StaffProvider>().allStaff.firstWhere(
      (s) => s.id == staffId,
      orElse: () => Staff(
        id: '',
        name: 'Unknown Staff',
        email: '',
        role: 'Unknown',
        department: 'Unknown',
        phone: '',
        hireDate: DateTime.now(),
        salary: 0,
        hourlyRate: 0,
      ),
    );

    final startTime = schedule['startTime']?.toDate() ?? DateTime.now();
    final endTime = schedule['endTime']?.toDate() ?? DateTime.now();
    final notes = schedule['notes'] ?? '';

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
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        '${_formatTime(startTime)} - ${_formatTime(endTime)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  if (notes.isNotEmpty)
                    Text(
                      notes,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                ],
              ),
            ),
            PopupMenuButton(
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit'),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ],
              onSelected: (value) {
                if (value == 'edit') {
                  _showEditScheduleDialog(context, schedule);
                } else if (value == 'delete') {
                  _showDeleteConfirmation(context, schedule);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showAddScheduleDialog(BuildContext context) {
    final provider = context.read<StaffProvider>();
    Staff? selectedStaff;
    TimeOfDay? startTime;
    TimeOfDay? endTime;
    final notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Schedule'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Staff>(
                  decoration: const InputDecoration(
                    labelText: 'Staff Member',
                    border: OutlineInputBorder(),
                  ),
                  initialValue: selectedStaff,
                  items: provider.allStaff.map((staff) => DropdownMenuItem(
                    value: staff,
                    child: Text(staff.name),
                  )).toList(),
                  onChanged: (staff) => setState(() => selectedStaff = staff),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(startTime?.format(context) ?? 'Select time'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now(),
                    );
                    if (time != null) {
                      setState(() => startTime = time);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Time'),
                  subtitle: Text(endTime?.format(context) ?? 'Select time'),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay.now().replacing(hour: TimeOfDay.now().hour + 8),
                    );
                    if (time != null) {
                      setState(() => endTime = time);
                    }
                  },
                ),
                TextField(
                  controller: notesController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedStaff == null || startTime == null || endTime == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all required fields')),
                  );
                  return;
                }

                try {
                  final startDateTime = DateTime(
                    _selectedDay.year,
                    _selectedDay.month,
                    _selectedDay.day,
                    startTime!.hour,
                    startTime!.minute,
                  );
                  final endDateTime = DateTime(
                    _selectedDay.year,
                    _selectedDay.month,
                    _selectedDay.day,
                    endTime!.hour,
                    endTime!.minute,
                  );

                  await provider.addSchedule(
                    staffId: selectedStaff!.id,
                    date: _selectedDay,
                    startTime: startDateTime,
                    endTime: endDateTime,
                    notes: notesController.text,
                  );

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Schedule added successfully')),
                  );
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              },
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditScheduleDialog(BuildContext context, Map<String, dynamic> schedule) {
    // Implementation for edit dialog would be similar to add dialog
    // with pre-filled values
  }

  void _showDeleteConfirmation(BuildContext context, Map<String, dynamic> schedule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Schedule'),
        content: const Text('Are you sure you want to delete this schedule?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await context.read<StaffProvider>().deleteSchedule(schedule['id'] as String, _selectedDay);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Schedule deleted')),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to delete: $e')),
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

  void _exportCSVForSelectedDay(BuildContext context) {
    final provider = context.read<StaffProvider>();
    final rows = <List<String>>[];
    rows.add(['Schedule ID','Staff ID','Staff Name','Role','Department','Date','Start','End','Notes']);
    for (final s in provider.scheduleList) {
      final staffId = s['staffId'] ?? '';
      final staff = provider.allStaff.firstWhere(
        (st) => st.id == staffId,
        orElse: () => Staff(
          id: '',
          name: 'Unknown',
          email: '',
          role: 'Unknown',
          department: 'Unknown',
          phone: '',
          hireDate: DateTime.now(),
          salary: 0,
          hourlyRate: 0,
        ),
      );
      final date = (s['date'] as DateTime? ?? DateTime.now());
      final start = ((s['startTime'] as Timestamp?)?.toDate()) ?? (s['startTime'] as DateTime? ?? DateTime.now());
      final end = ((s['endTime'] as Timestamp?)?.toDate()) ?? (s['endTime'] as DateTime? ?? DateTime.now());
      final notes = (s['notes'] ?? '').toString();
      rows.add([
        (s['id'] ?? '').toString(),
        staffId,
        staff.name,
        staff.role,
        staff.department,
        _formatDate(date),
        _formatTime(start),
        _formatTime(end),
        notes,
      ]);
    }
    final csv = rows.map((r) => r.map(_escapeCsv).join(',')).join('\n');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('CSV for ${_formatDate(_selectedDay)}'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(csv),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: csv));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('CSV copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  String _escapeCsv(String input) {
    final needsQuotes = input.contains(',') || input.contains('\n') || input.contains('"');
    var out = input.replaceAll('"', '""');
    return needsQuotes ? '"$out"' : out;
  }

  void _refreshSchedule() {
    context.read<StaffProvider>().loadScheduleForDate(_selectedDay);
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