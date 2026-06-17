import '../models/attendance.dart';

/// Attendance day status rules and helpers.
///
/// This utility distinguishes between past, present (today), and future dates
/// when deriving the display status for a day in an attendance timeline.
///
/// Rules:
/// - Future dates: never marked as "Absent"; shown as "Upcoming".
/// - Today without a record: not "Absent"; shown as "No activity yet".
/// - Past without a record: marked as "Absent".
/// - If a record exists for the day: use its `status` directly.
///
/// Returned status codes are normalized for UI and testing:
/// - 'future' → Upcoming day (no attendance expected yet)
/// - 'today_no_record' → Today with no check-in/out yet
/// - 'absent' → Past day with no record
/// - Otherwise, the underlying `Attendance.status` (e.g., 'present', 'late', 'completed', etc.)
String computeDayStatus(DateTime day, List<Attendance> records) {
  final today = DateTime.now();
  final startOfDay = DateTime(day.year, day.month, day.day);
  final startOfToday = DateTime(today.year, today.month, today.day);

  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final record = records.firstWhere(
    (r) => isSameDay(r.date, day),
    orElse: () => Attendance(
      id: 'none',
      staffId: '',
      date: startOfDay,
      status: '',
      duration: 0.0,
    ),
  );

  final hasRecord = record.id != 'none';

  if (startOfDay.isAfter(startOfToday)) {
    return 'future';
  }
  if (isSameDay(startOfDay, startOfToday) && !hasRecord) {
    return 'today_no_record';
  }
  if (!hasRecord) {
    return 'absent';
  }

  // Use the attendance record status directly if available
  return record.status;
}

/// Map status codes to user-facing text for list subtitles.
String displayTextForStatus(String status, {Attendance? record}) {
  switch (status) {
    case 'future':
      return 'Upcoming';
    case 'today_no_record':
      return 'No activity yet';
    case 'absent':
      return 'Absent';
    default:
      if (record != null) {
        // Prefer exact minutes based on timestamps when available
        final text = formatMinutesBetween(record.checkInTime, record.checkOutTime,
            naText: 'N/A');
        return '${record.statusDisplayText()} • $text';
      }
      // Fallback for unknown statuses without a record
      return status;
  }
}

/// Convert to local time for accurate, user-facing duration calculations.
DateTime _toLocal(DateTime dt) => dt.isUtc ? dt.toLocal() : dt;

/// Compute exact minutes between two timestamps. Returns 0 if negative.
int exactMinutesBetween(DateTime checkIn, DateTime checkOut) {
  final ci = _toLocal(checkIn);
  final co = _toLocal(checkOut);
  final mins = co.difference(ci).inMinutes;
  return mins < 0 ? 0 : mins;
}

/// Format a duration in a friendly, detailed style.
/// Examples: "45 minutes", "1 hour 30 minutes", "0 minutes".
String formatDetailedDuration(Duration duration) {
  final totalMinutes = duration.inMinutes;
  final minutes = totalMinutes % 60;
  final hours = totalMinutes ~/ 60;

  if (hours == 0) {
    return '$minutes minute${minutes == 1 ? '' : 's'}';
  }
  if (minutes == 0) {
    return '$hours hour${hours == 1 ? '' : 's'}';
  }
  return '$hours hour${hours == 1 ? '' : 's'} $minutes minute${minutes == 1 ? '' : 's'}';
}

/// Format the exact minutes between check-in and check-out.
/// If either timestamp is missing, returns [naText].
String formatMinutesBetween(DateTime? checkIn, DateTime? checkOut, {String naText = 'N/A'}) {
  if (checkIn == null || checkOut == null) return naText;
  final mins = exactMinutesBetween(checkIn, checkOut);
  return formatDetailedDuration(Duration(minutes: mins));
}
