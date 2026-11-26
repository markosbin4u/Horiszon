import 'dart:math' as math;

/// The direction of the Kaaba from anywhere on Earth (the initial great-circle bearing,
/// on a spherical Earth: accurate well within a degree, which is finer than a phone's
/// magnetometer).
library;

/// Kaaba coordinates: 21°25'21.0"N, 39°49'34.0"E.
const double kaabaLatitude = 21.4224779;
const double kaabaLongitude = 39.8251832;

double _radians(double degrees) => degrees * math.pi / 180.0;
double _degrees(double radians) => radians * 180.0 / math.pi;

/// The compass bearing to the Kaaba, in degrees clockwise from true north (`[0, 360)`).
double qiblaBearing(double latitude, double longitude) {
  final phi1 = _radians(latitude);
  final phi2 = _radians(kaabaLatitude);
  final deltaLambda = _radians(kaabaLongitude - longitude);
  final y = math.sin(deltaLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(deltaLambda);
  final bearing = _degrees(math.atan2(y, x));
  return (bearing + 360.0) % 360.0;
}

/// The great-circle distance to the Kaaba in kilometres (haversine).
double qiblaDistanceKm(double latitude, double longitude) {
  const earthRadiusKm = 6371.0088;
  final phi1 = _radians(latitude);
  final phi2 = _radians(kaabaLatitude);
  final dPhi = _radians(kaabaLatitude - latitude);
  final dLambda = _radians(kaabaLongitude - longitude);
  final a = math.sin(dPhi / 2) * math.sin(dPhi / 2) +
      math.cos(phi1) * math.cos(phi2) * math.sin(dLambda / 2) * math.sin(dLambda / 2);
  return 2 * earthRadiusKm * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// A short Arabic name for the bearing, as a person would give it.
String qiblaCardinal(double bearing) {
  const names = [
    'الشمال',
    'شمال شرقي',
    'الشرق',
    'جنوب شرقي',
    'الجنوب',
    'جنوب غربي',
    'الغرب',
    'شمال غربي',
  ];
  // 22.5° sectors, centred on each name.
  final index = (((bearing % 360) + 22.5) ~/ 45) % 8;
  return names[index];
}
