import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/schedule.dart';
import '../../services/schedule_service.dart';
import '../../const/colors.dart';

class ViewScheduleScreen extends StatefulWidget {
  const ViewScheduleScreen({super.key});

  @override
  State<ViewScheduleScreen> createState() => _ViewScheduleScreenState();
}

class _ViewScheduleScreenState extends State<ViewScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScheduleService _scheduleService = ScheduleService();
  DateTime _selectedDate = DateTime.now();
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadCurrentStaffId();
  }

  Future<void> _loadCurrentStaffId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString('currentStaffId');
      setState(() {
        _currentUserId = staffId;
      });
    } catch (e) {
      print('Error loading current staff ID: $e');
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Schedule'),
        backgroundColor: AppColor.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Today', icon: Icon(Icons.today)),
            Tab(text: 'Week', icon: Icon(Icons.view_week)),
            Tab(text: 'Month', icon: Icon(Icons.calendar_month)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTodayView(),
          _buildWeekView(),
          _buildMonthView(),
        ],
      ),
    );
  }

  Widget _buildTodayView() {
    if (_currentUserId == null) {
      return const Center(
        child: Text('Please log in to view your schedule'),
      );
    }

    return StreamBuilder<List<Schedule>>(
      stream: _scheduleService.getSchedulesForStaff(_currentUserId!),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final schedules = snapshot.data ?? [];
        final todaySchedules = schedules.where((schedule) => schedule.isToday).toList();

        if (todaySchedules.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.free_breakfast, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No shifts scheduled for today',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Enjoy your day off!',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: todaySchedules.length,
          itemBuilder: (context, index) {
            return _buildScheduleCard(todaySchedules[index]);
          },
        );
      },
    );
  }

  Widget _buildWeekView() {
    if (_currentUserId == null) {
      return const Center(
        child: Text('Please log in to view your schedule'),
      );
    }

    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return Column(
      children: [
        _buildWeekSelector(),
        Expanded(
          child: StreamBuilder<List<Schedule>>(
            stream: _scheduleService.getSchedulesByDateRange(
              _currentUserId!,
              startOfWeek,
              endOfWeek,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final schedules = snapshot.data ?? [];
              return _buildWeeklyScheduleGrid(schedules, startOfWeek);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMonthView() {
    if (_currentUserId == null) {
      return const Center(
        child: Text('Please log in to view your schedule'),
      );
    }

    final startOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
    final endOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);

    return Column(
      children: [
        _buildMonthSelector(),
        Expanded(
          child: StreamBuilder<List<Schedule>>(
            stream: _scheduleService.getSchedulesByDateRange(
              _currentUserId!,
              startOfMonth,
              endOfMonth,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('Error: ${snapshot.error}'),
                );
              }

              final schedules = snapshot.data ?? [];
              return _buildMonthlyCalendar(schedules, startOfMonth);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildScheduleCard(Schedule schedule) {
    final isUpcoming = schedule.isUpcoming;
    final duration = schedule.durationInHours;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              width: 4,
              color: _getShiftTypeColor(schedule.shiftType),
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: _getShiftTypeColor(schedule.shiftType).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      schedule.shiftType.name.toUpperCase(),
                      style: TextStyle(
                        color: _getShiftTypeColor(schedule.shiftType),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (isUpcoming)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'UPCOMING',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    '${_formatTime(schedule.startTime)} - ${_formatTime(schedule.endTime)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${duration.toStringAsFixed(1)}h',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              if (schedule.location != null) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      schedule.location!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
              if (schedule.notes?.isNotEmpty == true) ...<Widget>[
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.note, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        schedule.notes!,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeekSelector() {
    final startOfWeek = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.subtract(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            '${_formatDate(startOfWeek)} - ${_formatDate(endOfWeek)}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = _selectedDate.add(const Duration(days: 7));
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month - 1);
              });
            },
            icon: const Icon(Icons.chevron_left),
          ),
          Text(
            _formatMonth(_selectedDate),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _selectedDate = DateTime(_selectedDate.year, _selectedDate.month + 1);
              });
            },
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyScheduleGrid(List<Schedule> schedules, DateTime startOfWeek) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: 7,
      itemBuilder: (context, index) {
        final date = startOfWeek.add(Duration(days: index));
        final daySchedules = schedules.where((s) => 
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day
        ).toList();

        return _buildDayCard(date, daySchedules);
      },
    );
  }

  Widget _buildMonthlyCalendar(List<Schedule> schedules, DateTime startOfMonth) {
    final daysInMonth = DateTime(startOfMonth.year, startOfMonth.month + 1, 0).day;
    
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 0.8,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: daysInMonth,
      itemBuilder: (context, index) {
        final date = DateTime(startOfMonth.year, startOfMonth.month, index + 1);
        final daySchedules = schedules.where((s) => 
          s.date.year == date.year &&
          s.date.month == date.month &&
          s.date.day == date.day
        ).toList();

        return _buildCalendarDay(date, daySchedules);
      },
    );
  }

  Widget _buildDayCard(DateTime date, List<Schedule> schedules) {
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _getDayName(date.weekday),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isToday ? AppColor.primary : null,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isToday ? AppColor.primary : Colors.grey[600],
                  ),
                ),
                const Spacer(),
                if (schedules.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColor.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${schedules.length}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColor.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            if (schedules.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              ...schedules.map((schedule) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _getShiftTypeColor(schedule.shiftType),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${_formatTime(schedule.startTime)} - ${_formatTime(schedule.endTime)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              )),
            ] else ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'No shifts',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarDay(DateTime date, List<Schedule> schedules) {
    final isToday = DateTime.now().day == date.day &&
        DateTime.now().month == date.month &&
        DateTime.now().year == date.year;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        color: isToday ? AppColor.primary.withOpacity(0.1) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                color: isToday ? AppColor.primary : null,
              ),
            ),
            const SizedBox(height: 2),
            if (schedules.isNotEmpty)
              Expanded(
                child: Column(
                  children: schedules.take(2).map((schedule) => Container(
                    width: double.infinity,
                    height: 8,
                    margin: const EdgeInsets.only(bottom: 1),
                    decoration: BoxDecoration(
                      color: _getShiftTypeColor(schedule.shiftType),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  )).toList(),
                ),
              ),
            if (schedules.length > 2)
              Text(
                '+${schedules.length - 2}',
                style: const TextStyle(fontSize: 8),
              ),
          ],
        ),
      ),
    );
  }

  Color _getShiftTypeColor(ShiftType shiftType) {
    switch (shiftType) {
      case ShiftType.morning:
        return Colors.orange;
      case ShiftType.afternoon:
        return Colors.blue;
      case ShiftType.evening:
        return Colors.purple;
      case ShiftType.night:
        return Colors.indigo;
      case ShiftType.fullDay:
        return Colors.green;
    }
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}';
  }

  String _formatMonth(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday - 1];
  }
}