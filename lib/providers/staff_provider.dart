import 'package:flutter/foundation.dart';
import '../models/staff.dart';
import '../services/staff_service.dart';
import '../services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class StaffProvider with ChangeNotifier {
  final StaffService _staffService = StaffService();
  
  List<Staff> _staffList = [];
  List<Staff> _filteredStaffList = [];
  Map<String, dynamic> _dashboardData = {};
  List<Map<String, dynamic>> _todayAttendance = [];
  List<Map<String, dynamic>> _scheduleList = [];
  Map<String, bool> _checkInStatus = {};
  
  // Single source of truth: current staff (for home and attendance screens)
  Staff? _currentStaff;
  String? _currentStaffId;
  bool _currentStaffLoading = false;
  String? _syncWarning; // Set when we detect mismatches across screens
  
  bool _isLoading = false;
  String _error = '';
  String _searchQuery = '';
  String _filterDepartment = '';

  // Getters
  List<Staff> get staffList => _filteredStaffList;
  List<Staff> get allStaff => _staffList;
  Map<String, dynamic> get dashboardData => _dashboardData;
  List<Map<String, dynamic>> get todayAttendance => _todayAttendance;
  List<Map<String, dynamic>> get scheduleList => _scheduleList;
  Map<String, bool> get checkInStatus => _checkInStatus;
  bool get isLoading => _isLoading;
  String get error => _error;
  String get searchQuery => _searchQuery;
  String get filterDepartment => _filterDepartment;
  
  // Current staff getters
  Staff? get currentStaff => _currentStaff;
  String? get currentStaffId => _currentStaffId;
  bool get isCurrentStaffLoading => _currentStaffLoading;
  String? get syncWarning => _syncWarning;

  // Initialize provider
  Future<void> initialize() async {
    await loadStaff();
    await loadDashboardData();
    await loadTodayAttendance();
    await loadCheckInStatus();
    await initializeCurrentStaff();
  }

  // Populate demo data
  Future<void> populateDemoData() async {
    _setLoading(true);
    try {
      await _staffService.populateDemoData();
      await loadStaff();
      await loadDashboardData();
      await loadTodayAttendance();
      await loadCheckInStatus();
      _setError('');
    } catch (e) {
      _setError('Failed to populate demo data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Stream subscriptions to manage Firestore listeners lifecycle
  StreamSubscription<List<Staff>>? _staffSub;
  StreamSubscription<Map<String, dynamic>>? _dashboardSub;
  StreamSubscription<List<Map<String, dynamic>>>? _todayAttendanceSub;
  StreamSubscription<Map<String, bool>>? _checkInStatusSub;
  StreamSubscription<Staff?>? _currentStaffSub;

  // Initialize current staff ID and subscribe to real-time staff document
  Future<void> initializeCurrentStaff() async {
    _setCurrentStaffLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedStaffId = prefs.getString('currentStaffId');
      final savedPhone = prefs.getString('currentStaffPhone');

      String? resolvedId = savedStaffId;

      // Resolve by phone if id not present
      if ((resolvedId == null || resolvedId.isEmpty) && savedPhone != null && savedPhone.isNotEmpty) {
        final staffData = await AuthService().getStaffByPhone(savedPhone);
        final sid = staffData?['id']?.toString();
        if (sid != null && sid.isNotEmpty) {
          resolvedId = sid;
          await prefs.setString('currentStaffId', sid);
        }
      }

      // Final fallback: Firebase user UID
      if (resolvedId == null || resolvedId.isEmpty) {
        final user = AuthService.getCurrentUser();
        resolvedId = user?.uid;
      }

      if (resolvedId != null && resolvedId.isNotEmpty) {
        await setCurrentStaffId(resolvedId);
      } else {
        debugPrint('StaffProvider: Unable to resolve current staff id');
      }
    } catch (e) {
      _setError('Failed to initialize current staff: $e');
      debugPrint('StaffProvider initializeCurrentStaff error: $e');
    } finally {
      _setCurrentStaffLoading(false);
    }
  }

  Future<void> setCurrentStaffId(String staffId) async {
    if (_currentStaffId == staffId && _currentStaffSub != null) {
      return; // Already subscribed
    }
    _currentStaffId = staffId;
    await _currentStaffSub?.cancel();
    try {
      _currentStaffSub = _staffService.getStaffStream(staffId).listen((staff) {
        _currentStaff = staff;
        _syncWarning = null; // Clear warnings when fresh data arrives
        notifyListeners();
      }, onError: (error) {
        _setError('Current staff stream error: $error');
        debugPrint('StaffProvider current staff stream error: $error');
      });
    } catch (e) {
      _setError('Failed to subscribe to current staff: $e');
      debugPrint('StaffProvider setCurrentStaffId subscribe error: $e');
    }
  }

  // Validate that provided staffId matches the current one and set warning
  void validateCurrentStaffId(String? otherId, {String source = 'unknown'}) {
    if (_currentStaffId == null || otherId == null) return;
    if (_currentStaffId != otherId) {
      _syncWarning = 'Data mismatch detected from $source. Using profile: ${_currentStaff?.name ?? _currentStaffId}';
    } else {
      _syncWarning = null;
    }
    notifyListeners();
  }

  // Load all staff
  Future<void> loadStaff() async {
    _setLoading(true);
    try {
      // Cancel existing subscription before creating a new one
      await _staffSub?.cancel();
      _staffSub = _staffService.getAllStaff().listen((staffList) {
        _staffList = staffList;
        _applyFilters();
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load staff: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load staff by department
  Future<void> loadStaffByDepartment(String department) async {
    _setLoading(true);
    try {
      await _staffSub?.cancel();
      _staffSub = _staffService.getStaffByDepartment(department).listen((staffList) {
        _staffList = staffList;
        _applyFilters();
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load staff: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Load dashboard data - Real-time updates
  Future<void> loadDashboardData() async {
    try {
      await _dashboardSub?.cancel();
      _dashboardSub = _staffService.getStaffDashboardData().listen((data) {
        _dashboardData = data;
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load dashboard data: $e');
    }
  }

  // Load today's attendance
  Future<void> loadTodayAttendance() async {
    try {
      await _todayAttendanceSub?.cancel();
      _todayAttendanceSub = _staffService.getTodayAttendance().listen((attendance) {
        _todayAttendance = attendance;
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load attendance: $e');
    }
  }

  // Load check-in status for all staff - Real-time updates
  Future<void> loadCheckInStatus() async {
    try {
      await _checkInStatusSub?.cancel();
      _checkInStatusSub = _staffService.getAllCheckInStatus().listen((statusMap) {
        _checkInStatus = statusMap;
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load check-in status: $e');
    }
  }

  // Check-in staff
  Future<void> checkInStaff(String staffId) async {
    _setLoading(true);
    clearError();
    try {
      await _staffService.checkIn(staffId);
      _checkInStatus[staffId] = true;
      await loadTodayAttendance();
      await loadDashboardData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to check in: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Check-out staff
  Future<void> checkOutStaff(String staffId) async {
    _setLoading(true);
    clearError();
    try {
      await _staffService.checkOut(staffId);
      _checkInStatus[staffId] = false;
      await loadTodayAttendance();
      await loadDashboardData();
      notifyListeners();
    } catch (e) {
      _setError('Failed to check out: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Add new staff
  Future<void> addStaff(Staff staff) async {
    _setLoading(true);
    try {
      await _staffService.addStaff(staff);
      await loadStaff();
      _setError('');
    } catch (e) {
      _setError('Failed to add staff: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Update staff
  Future<void> updateStaff(Staff staff) async {
    _setLoading(true);
    try {
      await _staffService.updateStaff(staff);
      await loadStaff();
      _setError('');
    } catch (e) {
      _setError('Failed to update staff: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Delete staff
  Future<void> deleteStaff(String staffId) async {
    _setLoading(true);
    try {
      await _staffService.deleteStaff(staffId);
      await loadStaff();
      _setError('');
    } catch (e) {
      _setError('Failed to delete staff: $e');
    } finally {
      _setLoading(false);
    }
  }

  // Get staff by ID
  Future<Staff?> getStaff(String staffId) async {
    try {
      return await _staffService.getStaff(staffId);
    } catch (e) {
      _setError('Failed to get staff: $e');
      return null;
    }
  }

  // Get attendance history
  Future<List<Map<String, dynamic>>> getAttendanceHistory(
    String staffId, {
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      return await _staffService.getAttendanceHistory(
        staffId,
        startDate: startDate,
        endDate: endDate,
      );
    } catch (e) {
      _setError('Failed to get attendance history: $e');
      return [];
    }
  }

  // Schedule management
  Future<void> addSchedule({
    required String staffId,
    required DateTime date,
    required DateTime startTime,
    required DateTime endTime,
    String? notes,
  }) async {
    try {
      await _staffService.addSchedule(
        staffId: staffId,
        date: date,
        startTime: startTime,
        endTime: endTime,
        notes: notes,
      );
      await loadScheduleForDate(date);
    } catch (e) {
      _setError('Failed to add schedule: $e');
    }
  }

  Future<void> deleteSchedule(String scheduleId, DateTime date) async {
    try {
      await _staffService.deleteSchedule(scheduleId);
      await loadScheduleForDate(date);
    } catch (e) {
      _setError('Failed to delete schedule: $e');
    }
  }

  Future<void> loadScheduleForDate(DateTime date) async {
    try {
      _staffService.getScheduleForDate(date).listen((schedule) {
        _scheduleList = schedule;
        notifyListeners();
      });
    } catch (e) {
      _setError('Failed to load schedule: $e');
    }
  }

  // Search and filter functionality
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  void setDepartmentFilter(String department) {
    _filterDepartment = department;
    _applyFilters();
  }

  void clearFilters() {
    _searchQuery = '';
    _filterDepartment = '';
    _applyFilters();
  }

  void _applyFilters() {
    _filteredStaffList = _staffList.where((staff) {
      final matchesSearch = _searchQuery.isEmpty ||
          staff.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          staff.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          staff.role.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesDepartment = _filterDepartment.isEmpty ||
          staff.department == _filterDepartment;

      return matchesSearch && matchesDepartment;
    }).toList();
    notifyListeners();
  }

  // Helper methods
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setCurrentStaffLoading(bool loading) {
    _currentStaffLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  // Get departments list
  List<String> get departments {
    final departments = _staffList.map((staff) => staff.department).toSet();
    return departments.toList()..sort();
  }

  // Get roles list
  List<String> get roles {
    final roles = _staffList.map((staff) => staff.role).toSet();
    return roles.toList()..sort();
  }

  // Clear all active Firestore listeners (e.g., on logout)
  Future<void> clearListeners() async {
    await _staffSub?.cancel();
    await _dashboardSub?.cancel();
    await _todayAttendanceSub?.cancel();
    await _checkInStatusSub?.cancel();
    await _currentStaffSub?.cancel();
    _staffSub = null;
    _dashboardSub = null;
    _todayAttendanceSub = null;
    _checkInStatusSub = null;
    _currentStaffSub = null;
  }

  // Add new staff
  // DUPLICATE BLOCK REMOVED

  @override
  void dispose() {
    // Cancel subscriptions to avoid memory leaks
    _staffSub?.cancel();
    _dashboardSub?.cancel();
    _todayAttendanceSub?.cancel();
    _checkInStatusSub?.cancel();
    _currentStaffSub?.cancel();
    super.dispose();
  }
}
