import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AttendancePage extends StatelessWidget {
  const AttendancePage({super.key});

  // ------------------ TIME TABLE DATA ------------------

  static const Map<String, Map<String, List<Map<String, String>>>> evenData = {
    "A": {
      "Monday": [
        {"time": "09:00-10:00", "subject": "Data Structures", "room": "GS8"},
        {"time": "14:00-15:00", "subject": "Mathematics-II", "room": "GS7"},
      ],
      "Tuesday": [
        {"time": "10:00-11:00", "subject": "Programming Paradigms", "room": "GS5"},
      ],
    },
    "B": {
      "Monday": [
        {"time": "08:00-09:00", "subject": "Mathematics-II", "room": "GS4"},
      ],
    }
  };

  static const Map<String, int> dummyAttendance = {
    "Data Structures": 78,
    "Mathematics-II": 85,
    "Programming Paradigms": 72,
  };

  // ------------------ HELPERS ------------------

  String _today() {
    return [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ][DateTime.now().weekday - 1];
  }

  bool _isTimeBetween(String range) {
    final now = TimeOfDay.now();
    final parts = range.split("-");
    final start = _parse(parts[0]);
    final end = _parse(parts[1]);

    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;
    final endMin = end.hour * 60 + end.minute;

    return nowMin >= startMin && nowMin <= endMin;
  }

  bool _isUpcoming(String range) {
    final now = TimeOfDay.now();
    final start = _parse(range.split("-")[0]);

    final nowMin = now.hour * 60 + now.minute;
    final startMin = start.hour * 60 + start.minute;

    return startMin > nowMin;
  }

  TimeOfDay _parse(String t) {
    final p = t.split(":");
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }

  // ------------------ UI ------------------

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance"),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final section = data['section'];
          final semester = data['semester'];

          if (semester != "2") {
            return const Center(
              child: Text("Attendance not available for this semester"),
            );
          }

          final today = _today();
          final schedule = evenData[section]?[today] ?? [];

          final ongoing = schedule.where((c) => _isTimeBetween(c['time']!)).toList();
          final upcoming = schedule.where((c) => _isUpcoming(c['time']!)).toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // -------- ONGOING / UPCOMING --------

                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                      ),
                      builder: (_) => _UpcomingSheet(upcoming: upcoming),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ongoing.isNotEmpty ? "Ongoing Class" : "Next Class",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (ongoing.isNotEmpty)
                          _classTile(ongoing.first)
                        else if (upcoming.isNotEmpty)
                          _classTile(upcoming.first)
                        else
                          const Text("No classes remaining today"),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // -------- SUBJECT ATTENDANCE --------

                const Text(
                  "Subject-wise Attendance",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),

                ...dummyAttendance.entries.map(
                      (e) => Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      title: Text(e.key),
                      trailing: Text(
                        "${e.value}%",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _classTile(Map<String, String> c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          c['subject']!,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text("${c['time']} • ${c['room']}"),
      ],
    );
  }
}

// ------------------ UPCOMING BOTTOM SHEET ------------------

class _UpcomingSheet extends StatelessWidget {
  final List<Map<String, String>> upcoming;

  const _UpcomingSheet({required this.upcoming});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: upcoming.isEmpty
          ? const Center(child: Text("No upcoming classes"))
          : ListView(
        children: upcoming
            .map(
              (c) => Card(
            child: ListTile(
              title: Text(c['subject']!),
              subtitle: Text("${c['time']} • ${c['room']}"),
            ),
          ),
        )
            .toList(),
      ),
    );
  }
}
