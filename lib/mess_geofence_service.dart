import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';


class MessGeofenceService {
  // 🔴 CHANGE THESE TO REAL MESS COORDINATES
  static const double messLat = 25.4904908;
  static const double messLng = 81.8632980;
  static const double messRadius = 200; // meters

  static StreamSubscription<Position>? _subscription;
  static bool? _lastInsideState;

  /// Start listening to location updates
  static void start(String uid) {
    _subscription ??= Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((position) async {
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        messLat,
        messLng,
      );

      final inside = distance <= messRadius;

      // Avoid unnecessary Firestore writes
      if (_lastInsideState == inside) return;
      _lastInsideState = inside;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .update({
        'insideMess': inside,
        'lastMessUpdate': DateTime.now().toIso8601String(),
      });
    });
  }

  /// Stop listening when page is closed
  static void stop() {
    _subscription?.cancel();
    _subscription = null;
    _lastInsideState = null;
  }
}
