import 'package:intl/intl.dart';

class ClassInfo {
  final String subject;
  final String room;
  final DateTime start;
  final DateTime end;
  final bool isOngoing;

  ClassInfo({
    required this.subject,
    required this.room,
    required this.start,
    required this.end,
    required this.isOngoing,
  });
}

class ClassScheduleHelper {
  /// Parses "09:00-10:00" into DateTime range
  static DateTime _timeToday(String time) {
    final parts = time.split(':');
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  /// Returns current or next class
  static ClassInfo? getCurrentOrNextClass({
    required String section, // A1, A2, B1 etc
    required String semester,
    required Map<String, Map<String, List<Map<String, String>>>> timetable,
  }) {
    if (semester != '2') return null;

    final now = DateTime.now();
    final today = DateFormat('EEEE').format(now);

    final baseSection = section.substring(0, 1); // A1 → A

    final daySchedule = timetable[baseSection]?[today];
    if (daySchedule == null) return null;

    for (final entry in daySchedule) {
      final timeRange = entry['time']!;
      final subject = entry['subject']!;
      final room = entry['room']!;

      // Filter by section (A = A1+A2)
      if (subject.contains('A') &&
          !subject.contains(section) &&
          !subject.contains('(A+B)')) {
        continue;
      }

      final times = timeRange.split('-');
      final start = _timeToday(times[0]);
      final end = _timeToday(times[1]);

      if (now.isAfter(start) && now.isBefore(end)) {
        return ClassInfo(
          subject: subject,
          room: room,
          start: start,
          end: end,
          isOngoing: true,
        );
      }

      if (now.isBefore(start)) {
        return ClassInfo(
          subject: subject,
          room: room,
          start: start,
          end: end,
          isOngoing: false,
        );
      }
    }

    return null;
  }
}
