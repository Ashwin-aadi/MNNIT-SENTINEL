import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';

import 'welcome_page.dart';
import 'signup_page.dart';
import 'check_email_page.dart';
import 'get_started_page.dart';
import 'sign_in_page.dart';
import 'auth_gate.dart';

/// =======================
/// GLOBAL STATE (UI ISOLATE)
/// =======================
ValueNotifier<String> geofenceStatus =
ValueNotifier<String>('Status: Unknown');

String? _pendingStatus;
int? _pendingTimestamp;

const int ALERT_TIMEOUT_SECONDS = 30;

final FlutterLocalNotificationsPlugin _localNotifications =
FlutterLocalNotificationsPlugin();

/// =======================
/// DEVICE ID
/// =======================
Future<String> getDeviceId() async {
  final info = DeviceInfoPlugin();
  final android = await info.androidInfo;
  return android.id ?? 'unknown_device';
}

/// =======================
/// MAIN
/// =======================
@pragma('vm:entry-point')
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  const androidInit =
  AndroidInitializationSettings('@mipmap/ic_launcher');
  await _localNotifications.initialize(
    const InitializationSettings(android: androidInit),
  );

  FlutterForegroundTask.initCommunicationPort();

  FlutterForegroundTask.addTaskDataCallback((data) async {
    if (data is Map && data['type'] == 'STATUS') {
      final prefs = await SharedPreferences.getInstance();

      _pendingStatus = data['status'];
      _pendingTimestamp = data['timestamp'];

      await prefs.setString('pending_status', _pendingStatus!);
      await prefs.setInt('pending_timestamp', _pendingTimestamp!);

      geofenceStatus.value = _pendingStatus!;
    }
  });

  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'geofence_service',
      channelName: 'Geofence Monitoring',
      channelDescription: 'Tracks geofence status',
      channelImportance: NotificationChannelImportance.HIGH,
      priority: NotificationPriority.HIGH,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.once(),
      allowWakeLock: true,
      allowWifiLock: true,
    ),
  );

  runApp(const MyApp());
}

/// =======================
/// APP ROOT
/// =======================
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MNNIT-SENTINEL',
      debugShowCheckedModeBanner: false,
      home: AuthGate(),
      routes: {
        '/signin': (_) => const SignInPage(),
        '/signup': (_) => const SignUpPage(),
      },
    );
  }
}

/// =======================
/// HOME PAGE
/// =======================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.initCommunicationPort();
    _restorePending();
  }

  Future<void> _restorePending() async {
    final prefs = await SharedPreferences.getInstance();
    _pendingStatus = prefs.getString('pending_status');
    if (_pendingStatus != null) {
      geofenceStatus.value = _pendingStatus!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MNNIT-SENTINEL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<String>(
              valueListenable: geofenceStatus,
              builder: (_, value, __) => Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _startService,
              child: const Text('Start Geofence Service'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _verifyFace,
              child: const Text('Scan Face ID & Register'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startService() async {
    if (await FlutterForegroundTask.isRunningService) return;
    await FlutterForegroundTask.startService(
      notificationTitle: 'Geofence Active',
      notificationText: 'Monitoring location',
      callback: _startCallback,
    );
  }

  Future<void> _verifyFace() async {
    if (_pendingStatus == null) return;

    final auth = LocalAuthentication();
    final ok = await auth.authenticate(
      localizedReason: 'Verify identity',
      options: const AuthenticationOptions(
        biometricOnly: true,
        stickyAuth: true,
      ),
    );
    if (!ok) return;

    final deviceId = await getDeviceId();

    await FirebaseFirestore.instance.collection('geofence_events').add({
      'deviceId': deviceId,
      'status': _pendingStatus,
      'timestamp': FieldValue.serverTimestamp(),
      'verified': true,
    });

    FlutterForegroundTask.sendDataToTask({'type': 'VERIFIED'});
    geofenceStatus.value = 'Registered: $_pendingStatus';
  }
}

/// =======================
/// BACKGROUND ENTRY
/// =======================
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(GeoTaskHandler());
}

/// =======================
/// BACKGROUND HANDLER
/// =======================
class GeoTaskHandler extends TaskHandler {
  bool? _inside;
  Timer? _timer;
  bool _verified = false;
  int? _eventTimestamp;

  static const double lat = 25.4904908;
  static const double lng = 81.8632980;
  static const double radius = 10.0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp();

    final last = await Geolocator.getLastKnownPosition();
    if (last != null) _check(last);

    Geolocator.getPositionStream(
      locationSettings:
      const LocationSettings(accuracy: LocationAccuracy.high),
    ).listen(_check);
  }

  @override
  void onReceiveData(dynamic data) {
    if (data is Map && data['type'] == 'VERIFIED') {
      _verified = true;
      _timer?.cancel();

      FlutterForegroundTask.updateService(
        notificationTitle: 'Geofence Status',
        notificationText: 'Verified successfully',
      );
    }
  }

  void _check(Position pos) {
    final distance = Geolocator.distanceBetween(
      pos.latitude,
      pos.longitude,
      lat,
      lng,
    );

    final inside = distance <= radius;
    if (_inside == inside) return;
    _inside = inside;

    final status =
    inside ? 'ENTERED_GEOFENCE' : 'EXITED_GEOFENCE';

    _verified = false;
    _timer?.cancel();
    _eventTimestamp = DateTime.now().millisecondsSinceEpoch;

    FlutterForegroundTask.sendDataToMain({
      'type': 'STATUS',
      'status': status,
      'timestamp': _eventTimestamp,
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (_verified) {
        timer.cancel();
        return;
      }

      final elapsed =
          (DateTime.now().millisecondsSinceEpoch - _eventTimestamp!) ~/ 1000;

      final remaining = ALERT_TIMEOUT_SECONDS - elapsed;

      if (remaining > 0) {
        FlutterForegroundTask.updateService(
          notificationTitle: 'Geofence Status',
          notificationText: '$status | Verify in $remaining sec',
        );
      } else {
        timer.cancel();

        final deviceId = await getDeviceId();
        await FirebaseFirestore.instance.collection('alerts').add({
          'deviceId': deviceId,
          'status': status,
          'timestamp': FieldValue.serverTimestamp(),
          'verified': false,
        });

        FlutterForegroundTask.updateService(
          notificationTitle: 'Geofence Status',
          notificationText: 'Verification failed',
        );
      }
    });
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _timer?.cancel();
  }
}
