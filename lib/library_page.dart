import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  // ===============================
  // FIREBASE USER
  // ===============================
  final String? uid = FirebaseAuth.instance.currentUser?.uid;

  // ===============================
  // STATE
  // ===============================
  bool insideLibrary = false;
  bool libraryVerified = false;
  bool checking = false;

  // ===============================
  // LIBRARY GEOFENCE (TEST COORDS)
  // ===============================
  static const double libraryLat = 25.4904908;
  static const double libraryLng = 81.8632980;
  static const double libraryRadius = 10.0;

  // ===============================
  // ISSUED BOOKS (LOCAL)
  // ===============================
  List<Map<String, dynamic>> issuedBooks = [
    {
      "title": "Introduction to Algorithms",
      "issueDate": DateTime.now().subtract(const Duration(days: 2)),
    },
    {
      "title": "Discrete Mathematics",
      "issueDate": DateTime.now().subtract(const Duration(days: 14)),
    },
  ];

  @override
  void initState() {
    super.initState();
    tz.initializeTimeZones();
    _checkInsideLibrary();
  }

  // ===============================
  // CHECK GEOFENCE
  // ===============================
  Future<void> _checkInsideLibrary() async {
    if (uid == null) return;

    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      libraryLat,
      libraryLng,
    );

    final inside = distance <= libraryRadius;

    setState(() {
      insideLibrary = inside;
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'insideLibrary': inside,
      'libraryLastLocationUpdate': DateTime.now().toIso8601String(),
    });
  }

  // ===============================
  // BIOMETRIC + LAPTOP + FIRESTORE
  // ===============================
  Future<void> _verifyLibraryAccess() async {
    if (uid == null) return;

    setState(() {
      checking = true;
    });

    await _checkInsideLibrary();

    if (!insideLibrary) {
      await _logLibraryFailure('OUTSIDE_GEOFENCE');
      setState(() {
        checking = false;
      });
      _snack('You are not inside the library');
      return;
    }

    final auth = LocalAuthentication();
    bool ok = false;

    try {
      ok = await auth.authenticate(
        localizedReason: 'Verify to access Library',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );
    } catch (e) {
      await _logLibraryFailure('BIOMETRIC_ERROR');
    }

    if (!ok) {
      await _logLibraryFailure('BIOMETRIC_FAILED');
      setState(() {
        checking = false;
      });
      _snack('Verification failed');
      return;
    }

    final hasLaptop = await _askLaptopDialog();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'libraryVerified': true,
      'insideLibrary': true,
      'hasLaptop': hasLaptop,
      'libraryVerifiedAt': DateTime.now().toIso8601String(),
    });

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraryLogs')
        .add({
      'type': 'VERIFIED',
      'hasLaptop': hasLaptop,
      'verifiedAt': DateTime.now().toIso8601String(),
    });

    setState(() {
      libraryVerified = true;
      checking = false;
    });

    _snack('Library verified successfully');
  }

  // ===============================
  // FAILURE LOG
  // ===============================
  Future<void> _logLibraryFailure(String reason) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('libraryLogs')
        .add({
      'type': 'FAILED',
      'reason': reason,
      'failedAt': DateTime.now().toIso8601String(),
    });
  }

  // ===============================
  // LAPTOP DIALOG
  // ===============================
  Future<bool> _askLaptopDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Laptop Confirmation'),
        content: const Text('Do you have a laptop with you?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    ) ??
        false;
  }

  // ===============================
  // LIBRARY HOURS
  // ===============================
  String getLibraryHours() {
    final now = DateTime.now();
    if (now.weekday == DateTime.saturday ||
        now.weekday == DateTime.sunday) {
      return "Weekend Hours: 10:00 AM - 06:00 PM";
    }
    return "Weekday Hours: 08:00 AM - 10:00 PM";
  }

  // ===============================
  // BOOK TIMER
  // ===============================
  String getRemainingTime(DateTime issueDate) {
    final deadline = issueDate.add(const Duration(days: 15));
    final remaining = deadline.difference(DateTime.now());

    if (remaining.isNegative) return "Time to return the book !!";

    return "Time remaining: ${remaining.inDays + 1} days";
  }

  // ===============================
  // NOTIFICATION
  // ===============================
  Future<void> _scheduleReturnReminder(
      String title,
      DateTime issueDate,
      ) async {
    final deadline = issueDate.add(const Duration(days: 15));
    final notifications = FlutterLocalNotificationsPlugin();

    await notifications.zonedSchedule(
      deadline.millisecondsSinceEpoch ~/ 1000,
      'Library Book Due',
      'Return "$title" today',
      tz.TZDateTime.from(deadline, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'library_reminder',
          'Library Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
      UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ===============================
  // ADD BOOK
  // ===============================
  void _showAddBookDialog() {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Issued Book"),
        content: TextField(
          controller: controller,
          decoration:
          const InputDecoration(hintText: "Enter book title"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                final now = DateTime.now();
                setState(() {
                  issuedBooks.add({
                    "title": controller.text,
                    "issueDate": now,
                  });
                });
                _scheduleReturnReminder(controller.text, now);
                Navigator.pop(context);
              }
            },
            child: const Text("Add"),
          ),
        ],
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ===============================
  // UI
  // ===============================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("College Library"),
        backgroundColor: Colors.indigo,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              leading: Icon(
                insideLibrary ? Icons.check_circle : Icons.cancel,
                color: insideLibrary ? Colors.green : Colors.red,
              ),
              title: Text(
                insideLibrary
                    ? 'You are inside the Library'
                    : 'You are outside the Library',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .where('insideLibrary', isEqualTo: true)
                  .snapshots(),
              builder: (_, snap) {
                final count = snap.data?.docs.length ?? 0;
                return ListTile(
                  leading: const Icon(Icons.people),
                  title: Text(
                    '$count students currently in library',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              },
            ),

            ElevatedButton.icon(
              onPressed: checking ? null : _verifyLibraryAccess,
              icon: const Icon(Icons.fingerprint),
              label: const Text('Verify Library Access'),
            ),

            const SizedBox(height: 20),

            ListTile(
              leading: const Icon(Icons.access_time),
              title: Text(getLibraryHours()),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "My Issued Books",
                  style:
                  TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _showAddBookDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Add Book"),
                ),
              ],
            ),

            issuedBooks.isEmpty
                ? const Text("No books added yet.")
                : ListView.builder(
              shrinkWrap: true,
              physics:
              const NeverScrollableScrollPhysics(),
              itemCount: issuedBooks.length,
              itemBuilder: (_, i) {
                final book = issuedBooks[i];
                final text =
                getRemainingTime(book['issueDate']);
                final overdue = text.contains("!!");

                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.book),
                    title: Text(book['title']),
                    subtitle: Text(
                      text,
                      style: TextStyle(
                        color: overdue
                            ? Colors.red
                            : Colors.grey,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
