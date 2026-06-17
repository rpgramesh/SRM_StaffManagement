import 'package:flutter/material.dart';
import '../../services/staff_service.dart';
import 'package:intl/intl.dart';

class WeeklyScheduleScreen extends StatefulWidget {
  const WeeklyScheduleScreen({super.key});

  @override
  State<WeeklyScheduleScreen> createState() => _WeeklyScheduleScreenState();
}

class _WeeklyScheduleScreenState extends State<WeeklyScheduleScreen> {
  late DateTime _currentWeekStart;
  final StaffService _staffService = StaffService();

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(DateTime.now());
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday - 1));
  }

  String _getWeekRange() {
    final endDate = _currentWeekStart.add(const Duration(days: 6));
    return '${DateFormat('MMM d').format(_currentWeekStart)} - ${DateFormat('MMM d, yyyy').format(endDate)}';
  }

  List<DateTime> _getWeekDays() {
    return List.generate(7, (index) => _currentWeekStart.add(Duration(days: index)));
  }

  void _navigateWeek(bool forward) {
    setState(() {
      _currentWeekStart = forward
          ? _currentWeekStart.add(const Duration(days: 7))
          : _currentWeekStart.subtract(const Duration(days: 7));
    });
  }

  void _showShiftDialog(DateTime date, {Map<String, dynamic>? existingShift}) {
    TimeOfDay startTime = existingShift?['startTime'] as TimeOfDay? ?? const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime = existingShift?['endTime'] as TimeOfDay? ?? const TimeOfDay(hour: 16, minute: 0);
    String role = existingShift?['role'] as String? ?? 'General';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('${existingShift != null ? 'Edit' : 'Add'} Shift'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(
                    labelText: 'Role',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Front of House', child: Text('Front of House')),
                    DropdownMenuItem(value: 'Kitchen Staff', child: Text('Kitchen Staff')),
                    DropdownMenuItem(value: 'Bar Staff', child: Text('Bar Staff')),
                    DropdownMenuItem(value: 'Cleaning Crew', child: Text('Cleaning Crew')),
                  ],
                  onChanged: (value) => setState(() => role = value!),
                ),
                const SizedBox(height: 16),
                ListTile(
                  title: const Text('Start Time'),
                  subtitle: Text(startTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: startTime,
                    );
                    if (time != null) {
                      setState(() => startTime = time);
                    }
                  },
                ),
                ListTile(
                  title: const Text('End Time'),
                  subtitle: Text(endTime.format(context)),
                  trailing: const Icon(Icons.access_time),
                  onTap: () async {
                    final time = await showTimePicker(
                      context: context,
                      initialTime: endTime,
                    );
                    if (time != null) {
                      setState(() => endTime = time);
                    }
                  },
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
              onPressed: () {
                final shiftData = {
                  'date': date,
                  'startTime': startTime,
                  'endTime': endTime,
                  'role': role,
                };
                Navigator.pop(context, shiftData);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    ).then((result) {
      if (result != null) {
        _saveShift(result);
      }
    });
  }

  void _saveShift(Map<String, dynamic> shiftData) async {
    try {
      final date = shiftData['date'] as DateTime;
      final startTime = shiftData['startTime'] as TimeOfDay;
      final endTime = shiftData['endTime'] as TimeOfDay;
      final role = shiftData['role'] as String;

      final startDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        startTime.hour,
        startTime.minute,
      );

      final endDateTime = DateTime(
        date.year,
        date.month,
        date.day,
        endTime.hour,
        endTime.minute,
      );

      await _staffService.addSchedule(
        staffId: 'temp_staff_id', // In real app, this would be selected staff
        date: date,
        startTime: startDateTime,
        endTime: endDateTime,
        notes: role,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Shift saved successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving shift: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Weekly Schedule'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _navigateWeek(false),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _navigateWeek(true),
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Week of ${_getWeekRange()}',
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
              itemCount: _getWeekDays().length,
              itemBuilder: (context, index) {
                final date = _getWeekDays()[index];
                final dayName = DateFormat('EEEE').format(date);
                final dayNumber = DateFormat('d').format(date);
                
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                dayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                'Day $dayNumber',
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                '8:00 AM – 4:00 PM',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Colors.blue),
                          onPressed: () => _showShiftDialog(date),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.1),
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
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton.icon(
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Schedule published successfully')),
            );
          },
          icon: const Icon(Icons.calendar_today),
          label: const Text('Publish Schedule'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}