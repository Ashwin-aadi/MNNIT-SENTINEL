import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'attendance.dart';

class ClassGeofenceService {
  // --------------------------------------------------
  // PUBLIC STATE (USED BY UI)
  // --------------------------------------------------

  static final ValueNotifier<bool> isInsideClass =
  ValueNotifier<bool>(false);

  static final ValueNotifier<int> minutesInsideClass =
  ValueNotifier<int>(0);

  static Map<String, String>? activeClass;

  // --------------------------------------------------
  // NOTIFICATIONS
  // --------------------------------------------------

  static final FlutterLocalNotificationsPlugin _notifications =
  FlutterLocalNotificationsPlugin();

  static bool _notificationsReady = false;

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

  // --------------------------------------------------
  // BIOMETRIC AUTH
  // --------------------------------------------------

  static final LocalAuthentication _auth = LocalAuthentication();
  static bool _biometricVerified = false;

  static Future<bool> _authenticate() async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: 'Confirm your presence in class',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
      );

      await _log(
        ok ? 'BIOMETRIC_OK' : 'BIOMETRIC_FAIL',
        ok ? 'Fingerprint verified' : 'Fingerprint failed',
      );

      return ok;
    } catch (e) {
      await _log('BIOMETRIC_ERROR', e.toString());
      return false;
    }
  }

  // --------------------------------------------------
  // TEST COORDINATES (CHANGE LATER)
  // --------------------------------------------------

  static const double gsLat = 25.4904908;
  static const double gsLng = 81.8632980;
  static const double gsRadius = 10.0;

  static const double labLat = 25.4904908;
  static const double labLng = 81.8632980;
  static const double labRadius = 10.0;

  static const double nlhLat = 25.4904908;
  static const double nlhLng = 81.8632980;
  static const double nlhRadius = 10.0;

  // --------------------------------------------------
  // INTERNAL STATE
  // --------------------------------------------------

  static StreamSubscription<Position>? _posSub;
  static bool _inside = false;
  static DateTime? _insideSince;

  // --------------------------------------------------
  // START TRACKING (CALLED FROM AttendancePage)
  // --------------------------------------------------

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
    _biometricVerified = false;
    _inside = false;
    _insideSince = null;
    minutesInsideClass.value = 0;
    isInsideClass.value = false;

    final geo = _resolveGeofence(cls['room']!);

    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings:
      const LocationSettings(accuracy: LocationAccuracy.high),
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
          'Inside Class',
          'You are inside ${cls['subject']}',
        );

        await _log('ENTER', 'Entered class geofence');
      }

      if (!nowInside && _inside) {
        _inside = false;
        isInsideClass.value = false;
        _insideSince = null;
        minutesInsideClass.value = 0;

        await _notify(
          'Outside Class',
          'You left ${cls['subject']}',
        );

        await _log('EXIT', 'Exited class geofence');
      }

      if (_inside && _insideSince != null) {
        minutesInsideClass.value =
            DateTime.now().difference(_insideSince!).inMinutes;
      }
    });
  }

  // --------------------------------------------------
  // MANUAL ATTENDANCE (BUTTON)
  // --------------------------------------------------

  static Future<String> markMePresent() async {
    if (activeClass == null) {
      return 'No active class';
    }

    if (!isInsideClass.value) {
      await _log(
        'ATTENDANCE_BLOCKED',
        'User tried outside class',
      );
      return 'You are outside the class';
    }

    if (!_biometricVerified) {
      final ok = await _authenticate();
      if (!ok) return 'Fingerprint verification failed';
      _biometricVerified = true;
    }

    await _markAttendance();
    await _notify(
      'Attendance Marked',
      '${activeClass!['subject']} recorded',
    );

    await _log(
      'ATTENDANCE_MARKED',
      'Attendance marked manually',
    );

    return 'Attendance marked successfully';
  }

  // --------------------------------------------------
  // ATTENDANCE WRITE
  // --------------------------------------------------

  static Future<void> _markAttendance() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || activeClass == null) return;

    final subjectCode =
    _extractSubjectCode(activeClass!['subject']!);

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

  static String _extractSubjectCode(String subject) {
    final match = RegExp(r'[A-Z]{3}\d{5}').firstMatch(subject);
    return match?.group(0) ?? subject;
  }

  // --------------------------------------------------
  // LOGGING
  // --------------------------------------------------

  static Future<void> _log(String type, String details) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || activeClass == null) return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('attendance_logs')
        .add({
      'type': type,
      'subject': activeClass!['subject'],
      'room': activeClass!['room'],
      'details': details,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  // --------------------------------------------------
  // GEOFENCE RESOLUTION
  // --------------------------------------------------

  static Map<String, double> _resolveGeofence(String room) {
    final r = room.toLowerCase();

    if (r.contains('lab')) {
      return {'lat': labLat, 'lng': labLng, 'radius': labRadius};
    }

    if (r.contains('gs')) {
      return {'lat': gsLat, 'lng': gsLng, 'radius': gsRadius};
    }

    return {'lat': nlhLat, 'lng': nlhLng, 'radius': nlhRadius};
  }

  // --------------------------------------------------
  // CLASS RETURN FUNCTION
  // --------------------------------------------------

  static Map<String, String>? getCurrentOrNextClass({
    required String section,
    required String semester,
  }) {
    if (semester != "2") return null;

    final normalized = section.substring(0, 1).toUpperCase();
    final today = _today();

    final schedule =
    AttendancePage.evenData[normalized]?[today];

    if (schedule == null || schedule.isEmpty) return null;

    final now = TimeOfDay.now();
    final nowMin = now.hour * 60 + now.minute;

    for (final c in schedule) {
      final parts = c['time']!.split("-");
      final start = _parse(parts[0]);
      final end = _parse(parts[1]);

      final sMin = start.hour * 60 + start.minute;
      final eMin = end.hour * 60 + end.minute;

      if (nowMin >= sMin && nowMin <= eMin) {
        return c;
      }
    }

    return schedule.first;
  }

  static String _today() {
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

  static TimeOfDay _parse(String t) {
    final p = t.split(":");
    return TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
  }
}
