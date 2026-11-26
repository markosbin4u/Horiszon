import 'package:flutter/foundation.dart';

/// What `flutter_compass` gives the app: the magnetic heading in degrees.
class CompassEvent {
  const CompassEvent({required this.heading, this.headingForCamera});

  final double? heading;
  final double? headingForCamera;
}

/// The compass, as far as the app needs it.
///
/// This is a thin wrapper so the qibla screen has one place to read the sensor from; the
/// plugin itself is what talks to Android.
class FlutterCompass {
  static Stream<CompassEvent>? get events => _events;

  static Stream<CompassEvent>? _events;
}
