import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'class_geofence_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  static const Map<String, String> subjectNameToCode = {
    "Data Structures": "CSN12101",
    "Mathematics-II": "MAN12104",
    "Programming Paradigms": "CSN12102",
  };

  static const Map<String, Map<String, List<Map<String, String>>>> evenData = {
    "A": {
      "Monday": [
        {"time": "09:00-11:00", "subject": "HSN12600(P)A1 / CYN12501(P)A2", "room": "GS4"},
        {"time": "14:00-15:00", "subject": "CSN12401*(L)", "room": "NLH1"},
        {"time": "16:00-17:00", "subject": "CYN12501(T)", "room": "NLH2(A+B)"}
      ],
      "Tuesday": [
        {"time": "09:00-10:00", "subject": "CYN12501(L)", "room": "NLH2(A+B)"},
        {"time": "10:00-11:00", "subject": "MAN12104(L)A", "room": "GS8"},
        {"time": "14:00-15:00", "subject": "IDN12600(L)A", "room": "NLH1"},
        {"time": "15:00-16:00", "subject": "CSN12101(L)A", "room": "GS8"}
      ],
      "Wednesday": [
        {"time": "08:00-09:00", "subject": "HSN12600(L)A", "room": "GS8"},
        {"time": "10:00-11:00", "subject": "MAN12104(L)A", "room": "GS7"},
        {"time": "14:00-16:00", "subject": "CSN12101(P)A1", "room": "CCTF Lab"}
      ],
      "Thursday": [
        {"time": "09:00-10:00", "subject": "CSN12101(L)A", "room": "GS8"},
        {"time": "14:00-15:00", "subject": "CSN12102(L)A", "room": "GS5"},
        {"time": "16:00-17:00", "subject": "HSN12600(L)A", "room": "NLH2"}
      ],
      "Saturday": [
        {"time": "08:38-9:38", "subject": "MAN12104(L)A", "room": "GS5"},
        {"time": "11:00-12:00", "subject": "HSN12600(P)A2", "room": "Lab"},
        {"time": "14:00-15:00", "subject": "IDN12600(L)A", "room": "NLH1"}
      ]
    },
    "B": {
      "Monday": [
        {"time": "09:00-10:00", "subject": "HSN12600(L)B", "room": "GS4"},
        {"time": "10:00-11:00", "subject": "MAN12104(L)B", "room": "GS4"},
        {"time": "11:00-13:00", "subject": "HSN12600(P)B1", "room": "Lab"}
      ],
      "Tuesday": [
        {"time": "08:00-10:00", "subject": "CYN12501(P)B2 / CSN12101(P)B1", "room": "CCTF"},
        {"time": "14:00-15:00", "subject": "CSN12102(L)B", "room": "GS7"}
      ],
      "Wednesday": [
        {"time": "08:00-09:00", "subject": "CSN12102(L)B", "room": "GS7"},
        {"time": "09:00-11:00", "subject": "CYN12501(P)B1 / HSN12600(P)B2", "room": "Lab"},
        {"time": "11:00-12:00", "subject": "CSN12101(L)B", "room": "GS8"}
      ],
      "Thursday": [
        {"time": "14:00-15:00", "subject": "MAN12104(L)B", "room": "GS5"},
        {"time": "16:00-18:00", "subject": "CSN12101(P)B2", "room": "CCTF"}
      ],
      "Friday": [
        {"time": "08:00-09:00", "subject": "MAN12104(L)B", "room": "GS3"},
        {"time": "10:00-11:00", "subject": "HSN12600(L)B", "room": "GS8"},
        {"time": "11:00-12:00", "subject": "IDN12600(L)B", "room": "NLH1"}
      ]
    }
  };

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  String _normalizeSection(String s) => s.isNotEmpty ? s[0] : s;

  @override
  void initState() {
    super.initState();
    _startGeofence();
  }

  Future<void> _startGeofence() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = snap.data()!;
    await ClassGeofenceService.start(
      section: data['section'],
      semester: data['semester'],
    );
  }

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

  List<String> _extractSubjectCodesForSection(String section) {
    final normalized = _normalizeSection(section);
    final set = <String>{};
    final data = AttendancePage.evenData[normalized];
    if (data == null) return [];
    for (final day in data.values) {
      for (final cls in day) {
        final raw = cls['subject']!;
        final parts = raw.split("/");
        for (final p in parts) {
          final code = RegExp(r'[A-Z]{3}\d{5}').firstMatch(p);
          if (code != null) set.add(code.group(0)!);
        }
      }
    }
    return set.toList();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      appBar: AppBar(title: const Text("Attendance")),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final userData = userSnap.data!.data() as Map<String, dynamic>;
          final section = _normalizeSection(userData['section']);
          final semester = userData['semester'];

          if (semester != "2") {
            return const Center(child: Text("Attendance not available"));
          }

          final today = _today();
          final schedule = AttendancePage.evenData[section]?[today] ?? [];
          final ongoing = schedule.where((c) => _isTimeBetween(c['time']!)).toList();
          final upcoming = schedule.where((c) => _isUpcoming(c['time']!)).toList();
          final subjectCodes = _extractSubjectCodesForSection(section);

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .collection('attendance')
                .snapshots(),
            builder: (context, attSnap) {
              if (!attSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final attendanceDocs = attSnap.data!.docs;
              Map<String, Map<String, int>> attendanceMap = {};

              for (var doc in attendanceDocs) {
                final data = doc.data() as Map<String, dynamic>;
                attendanceMap[doc.id] = {
                  'attended': data['attendedClasses'] ?? 0,
                  'total': data['totalClasses'] ?? 0,
                };
              }

              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: ClassGeofenceService.isInsideClass,
                      builder: (_, inside, __) {
                        return ValueListenableBuilder<int>(
                          valueListenable: ClassGeofenceService.minutesInsideClass,
                          builder: (_, minutes, __) {
                            return Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: inside ? Colors.green.shade100 : Colors.red.shade100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        inside ? "Inside Class" : "Outside Class",
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 4),
                                      inside
                                          ? Text("Minutes inside: $minutes / 50")
                                          : const Text("Enter class to start timer"),
                                    ],
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      final msg = await ClassGeofenceService.markMePresent();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(SnackBar(content: Text(msg)));
                                    },
                                    child: const Text("Mark Me Present"),
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 24),
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
                              style: const TextStyle(fontWeight: FontWeight.bold),
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
                    const Text(
                      "Subject-wise Attendance",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    ...subjectCodes.map((code) {
                      final record = attendanceMap[code];
                      final attended = record?['attended'] ?? 0;
                      final total = record?['total'] ?? 0;
                      final percent = total == 0 ? 0 : ((attended / total) * 100).round();

                      return Card(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: ListTile(
                          title: Text(code),
                          subtitle: Text("Attended $attended / $total classes"),
                          trailing: Text(
                            "$percent%",
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _classTile(Map<String, String> c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c['subject']!, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("${c['time']} • ${c['room']}"),
      ],
    );
  }
}

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
