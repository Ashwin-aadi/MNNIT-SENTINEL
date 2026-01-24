import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'attendance.dart';

class ClassGeofenceService {
  static final ValueNotifier<bool> isInsideClass =
  ValueNotifier<bool>(false);

  static final ValueNotifier<int> minutesInsideClass =
  ValueNotifier<int>(0);

  static final ValueNotifier<int> verificationSecondsLeft =
  ValueNotifier<int>(0);

  static final ValueNotifier<bool> isVerifiedForThisClass =
  ValueNotifier<bool>(false);

  static Map<String, String>? activeClass;

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static bool _notificationsReady = false;

  static final LocalAuthentication _auth = LocalAuthentication();

  static StreamSubscription<Position>? _posSub;
  static Timer? _verifyTimer;
  static Timer? _minuteTimer;

  static bool _inside = false;
  static DateTime? _insideSince;

  static const int requiredMinutes = 50;
  static const int verifyWindowSeconds = 30;

  static const Map<String, Map<String, double>> classroomGeofences = {
    "GS4": {"lat": 25.4904908, "lng": 81.8632980, "radius": 10},
    "GS5": {"lat": 25.4904910, "lng": 81.8632990, "radius": 10},
    "GS8": {"lat": 25.4904920, "lng": 81.8633000, "radius": 10},
    "NLH1": {"lat": 25.4904930, "lng": 81.8633010, "radius": 10},
    "NLH2": {"lat": 25.4904940, "lng": 81.8633020, "radius": 10},
    "CCTF Lab": {"lat": 25.4904950, "lng": 81.8633030, "radius": 10},
    "Lab": {"lat": 25.4904960, "lng": 81.8633040, "radius": 10},
  };

  static Future<void> initNotifications() async {
    if (_notificationsReady) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notifications.initialize(settings);
    _notificationsReady = true;
  }

  static Future<void> _notify(String title, String body) async {
    await initNotifications();
    const androidDetails = AndroidNotificationDetails(
      'class_geofence',
      'Class Attendance',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _notifications.show(
      1001,
      title,
      body,
      const NotificationDetails(android: androidDetails),
    );
  }

  static Future<void> start({
    required String section,
    required String semester,
  }) async {
    await initNotifications();

    final cls = getCurrentOrNextClass(
      section: section,
      semester: semester,
    );

    if (cls == null) return;

    activeClass = cls;
    isInsideClass.value = false;
    minutesInsideClass.value = 0;
    verificationSecondsLeft.value = 0;
    isVerifiedForThisClass.value = false;
    _inside = false;
    _insideSince = null;

    final geo = _resolveGeofence(cls['room']!);
    if (geo == null) return;

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).listen((pos) async {
      final distance = Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        geo['lat']!,
        geo['lng']!,
      );

      final nowInside = distance <= geo['radius']!;

      if (nowInside && !_inside) {
        _inside = true;
        isInsideClass.value = true;
        _insideSince = DateTime.now();
        minutesInsideClass.value = 0;

        await _notify(
          'Verify Entry',
          'Verify fingerprint within 30 seconds',
        );

        verificationSecondsLeft.value = verifyWindowSeconds;

        _verifyTimer?.cancel();
        _verifyTimer = Timer.periodic(
          const Duration(seconds: 1),
              (t) {
            verificationSecondsLeft.value--;
            if (verificationSecondsLeft.value <= 0) {
              t.cancel();
            }
          },
        );

        _minuteTimer?.cancel();
        _minuteTimer = Timer.periodic(
          const Duration(minutes: 1),
              (_) {
            if (_insideSince != null) {
              minutesInsideClass.value =
                  DateTime.now().difference(_insideSince!).inMinutes;
            }
          },
        );
      }

      if (!nowInside && _inside) {
        _inside = false;
        isInsideClass.value = false;
        _insideSince = null;
        minutesInsideClass.value = 0;
        verificationSecondsLeft.value = 0;
        isVerifiedForThisClass.value = false;

        _verifyTimer?.cancel();
        _minuteTimer?.cancel();

        await _notify(
          'Exited Class',
          'You left ${cls['subject']}',
        );
      }
    });
  }

  static Future<String> markMePresent() async {
    if (activeClass == null) return 'No active class';

    if (!isInsideClass.value) {
      return 'You are outside the class';
    }

    if (!isVerifiedForThisClass.value) {
      if (verificationSecondsLeft.value <= 0) {
        return 'Verification window expired';
      }

      final ok = await _auth.authenticate(
        localizedReason: 'Verify entry to class',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      if (!ok) return 'Fingerprint verification failed';

      isVerifiedForThisClass.value = true;
      verificationSecondsLeft.value = 0;
      _verifyTimer?.cancel();
    }

    if (minutesInsideClass.value < requiredMinutes) {
      return 'Stay ${requiredMinutes - minutesInsideClass.value} more minutes';
    }

    await _markAttendance();

    await _notify(
      'Attendance Marked',
      '${activeClass!['subject']} recorded',
    );

    return 'Attendance marked successfully';
  }

  static Future<void> _markAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || activeClass == null) return;

    final subjectCode =
    RegExp(r'[A-Z]{3}\d{5}').firstMatch(activeClass!['subject']!)?.group(0);

    if (subjectCode == null) return;

    final today =
        "${DateTime.now().year}-${DateTime.now().month}-${DateTime.now().day}";

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attendance')
        .doc(subjectCode);

    final snap = await ref.get();
    final data = snap.data();

    if (data != null && data['lastMarkedDate'] == today) return;

    await ref.set({
      'attendedClasses': (data?['attendedClasses'] ?? 0) + 1,
      'totalClasses': (data?['totalClasses'] ?? 0) + 1,
      'lastMarkedDate': today,
    }, SetOptions(merge: true));
  }

  static Map<String, double>? _resolveGeofence(String room) {
    for (final entry in classroomGeofences.entries) {
      if (room.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  static Map<String, String>? getCurrentOrNextClass({
    required String section,
    required String semester,
  }) {
    if (semester != "2") return null;

    final normalized = section.substring(0, 1).toUpperCase();
    final today = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday"
    ][DateTime.now().weekday - 1];

    final schedule = AttendancePage.evenData[normalized]?[today];
    if (schedule == null || schedule.isEmpty) return null;

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;

    for (final c in schedule) {
      final parts = c['time']!.split("-");
      final start = _parse(parts[0]);
      final end = _parse(parts[1]);

      final sMin = start.hour * 60 + start.minute;
      final eMin = end.hour * 60 + end.minute;

      if (nowMin >= sMin && nowMin <= eMin) return c;
    }

    return schedule.first;
  }

  static TimeOfDay _parse(String t) {
    final p = t.split(":");
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }
}
