import 'dart:math' as math;

/// Prayer-time mathematics (the standard astronomical method: solar declination and
/// equation of time from a low-precision solar position, then hour angles for each
/// prayer's sun depression).
///
/// No package does this: the formulas are short, well known, and keeping them here means
/// they are unit-testable in plain Dart with no platform channels.
library;

double _sin(double degrees) => math.sin(degrees * math.pi / 180.0);
double _cos(double degrees) => math.cos(degrees * math.pi / 180.0);
double _tan(double degrees) => math.tan(degrees * math.pi / 180.0);
double _asin(double x) => math.asin(x) * 180.0 / math.pi;
double _acos(double x) => math.acos(x) * 180.0 / math.pi;
double _atan(double x) => math.atan(x) * 180.0 / math.pi;
double _atan2(double y, double x) => math.atan2(y, x) * 180.0 / math.pi;

/// The inverse cotangent, in degrees. Asr's shadow ratio is a cotangent, so this is not
/// the same as `1 / atan(x)`: `arccot` is `atan(1 / x)`, and `x` can be below 1.
double _acot(double x) => 90.0 - _atan(x);

/// `a` brought into `[0, 360)`.
double fixAngle(double a) {
  final r = a - 360.0 * (a / 360.0).floorToDouble();
  return r < 0 ? r + 360.0 : r;
}

/// `a` brought into `[0, 24)`.
double fixHour(double a) {
  final r = a - 24.0 * (a / 24.0).floorToDouble();
  return r < 0 ? r + 24.0 : r;
}

/// Astronomical Julian date for the given calendar date at 0h UT.
double julianDate(int year, int month, int day) {
  var y = year;
  var m = month;
  if (m <= 2) {
    y -= 1;
    m += 12;
  }
  final a = (y / 100.0).floorToDouble();
  final b = 2 - a + (a / 4.0).floorToDouble();
  return (365.25 * (y + 4716)).floorToDouble() +
      (30.6001 * (m + 1)).floorToDouble() +
      day +
      b -
      1524.5;
}

/// The sun's declination and the equation of time (in hours) at a Julian date.
({double declination, double equationOfTime}) sunPosition(double jd) {
  final d = jd - 2451545.0;
  final g = fixAngle(357.529 + 0.98560028 * d);
  final q = fixAngle(280.459 + 0.98564736 * d);
  final l = fixAngle(q + 1.915 * _sin(g) + 0.020 * _sin(2 * g));
  final e = 23.439 - 0.00000036 * d;
  final rightAscension = fixHour(_atan2(_cos(e) * _sin(l), _cos(l)) / 15.0);
  final declination = _asin(_sin(e) * _sin(l));
  final equationOfTime = q / 15.0 - rightAscension;
  return (declination: declination, equationOfTime: equationOfTime);
}

/// How the Fajr and Isha twilight angles are taken, and how Asr is measured.
enum CalcMethod {
  /// Muslim World League: Fajr 18°, Isha 17°. The default.
  mwl('رابطة العالم الإسلامي', 18.0, 17.0, 1.0),

  /// Umm al-Qura, Makkah: Fajr 18.5°, Isha fixed 90 minutes after Maghrib.
  ummAlQura('أم القرى (مكة)', 18.5, null, 1.0),

  /// Egyptian General Authority of Survey: Fajr 19.5°, Isha 17.5°.
  egyptian('الهيئة المصرية العامة للمساحة', 19.5, 17.5, 1.0),

  /// University of Islamic Sciences, Karachi: Fajr 18°, Isha 18°.
  karachi('جامعة العلوم الإسلامية (كراتشي)', 18.0, 18.0, 1.0),

  /// Algerian Ministry of Religious Affairs: Fajr 18°, Isha 17°.
  algeria('وزارة الشؤون الدينية الجزائرية', 18.0, 17.0, 1.0);

  const CalcMethod(this.label, this.fajrAngle, this.ishaAngle, this.asrFactor);

  final String label;
  final double fajrAngle;

  /// The Isha twilight angle, or null when Isha is a fixed offset from Maghrib.
  final double? ishaAngle;

  /// 1.0 for the majority (Shafi'i) school, 2.0 for the Hanafi school.
  final double asrFactor;

  /// Minutes between Maghrib and Isha, for a method that fixes it.
  int? get ishaMinutes {
    return this == CalcMethod.ummAlQura ? 90 : null;
  }
}

/// The six prayer times of one day, as hours since local midnight (fractional).
class PrayerTimes {
  const PrayerTimes({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.date,
  });

  final double? fajr;
  final double? sunrise;
  final double? dhuhr;
  final double? asr;
  final double? maghrib;
  final double? isha;

  /// The civil date these belong to (local).
  final DateTime date;

  /// Every prayer in order, skipping one the sun never reaches.
  List<({String name, double hour})> get ordered {
    final all = <({String name, double hour})>[];
    void add(String name, double? hour) {
      if (hour != null) all.add((name: name, hour: hour));
    }

    add('fajr', fajr);
    add('sunrise', sunrise);
    add('dhuhr', dhuhr);
    add('asr', asr);
    add('maghrib', maghrib);
    add('isha', isha);
    return all;
  }
}

/// Computes prayer times for a place and a date.
class PrayerCalculator {
  PrayerCalculator({
    required this.latitude,
    required this.longitude,
    required this.timeZoneOffsetHours,
    required this.method,
    this.hanafiAsr = false,
  });

  /// Degrees north (negative for south).
  final double latitude;

  /// Degrees east (negative for west).
  final double longitude;

  /// Local UTC offset in hours, as the device reports it (1.0 for Algeria).
  final double timeZoneOffsetHours;

  final CalcMethod method;

  /// The Hanafi school measures Asr at twice the shadow (`2` instead of `1`).
  final bool hanafiAsr;

  double get _asrFactor => hanafiAsr ? 2.0 : method.asrFactor;

  double _midDay(double t, double jd) {
    final eq = sunPosition(jd + t / 24.0).equationOfTime;
    return fixHour(12.0 - eq);
  }

  /// The hour angle that the sun reaches `angle` degrees below the horizon, or null when
  /// it never does at this latitude (a polar summer or winter).
  double? _sunAngleTime(double angle, double t, double jd, {required bool beforeNoon}) {
    final declination = sunPosition(jd + t / 24.0).declination;
    final noon = _midDay(t, jd);
    final numerator = -_sin(angle) - _sin(declination) * _sin(latitude);
    final denominator = _cos(declination) * _cos(latitude);
    final x = numerator / denominator;
    if (x < -1.0 || x > 1.0) return null;
    final hourAngle = _acos(x) / 15.0;
    return beforeNoon ? noon - hourAngle : noon + hourAngle;
  }

  double _asr(double t, double jd) {
    final declination = sunPosition(jd + t / 24.0).declination;
    // The sun's depression at Asr: the shadow is `factor` times the object plus the
    // noon shadow.
    final angle = -_acot(_asrFactor + _tan((latitude - declination).abs()));
    // Asr is always after noon, so the sun is descending through that angle.
    return _sunAngleTime(angle, t, jd, beforeNoon: false) ?? 0.0;
  }

  /// The times for `date` (its year, month and day are used; the time is ignored).
  PrayerTimes forDate(DateTime date) {
    final jd = julianDate(date.year, date.month, date.day) - longitude / (15.0 * 24.0);

    double? local(double? hour) {
      if (hour == null) return null;
      return fixHour(hour + timeZoneOffsetHours - longitude / 15.0);
    }

    final fajr = local(_sunAngleTime(method.fajrAngle, 5, jd, beforeNoon: true));
    final sunrise = local(_sunAngleTime(0.833, 6, jd, beforeNoon: true));
    final dhuhr = local(_midDay(12, jd));
    final asr = local(_asr(13, jd));
    final maghrib = local(_sunAngleTime(0.833, 18, jd, beforeNoon: false));

    double? isha;
    final angle = method.ishaAngle;
    if (angle != null) {
      isha = local(_sunAngleTime(angle, 18, jd, beforeNoon: false));
    } else if (maghrib != null) {
      // A method with a fixed interval (Umm al-Qura keeps 90 minutes).
      isha = fixHour(maghrib + (method.ishaMinutes ?? 90) / 60.0);
    }

    return PrayerTimes(
      fajr: fajr,
      sunrise: sunrise,
      dhuhr: dhuhr,
      asr: asr,
      maghrib: maghrib,
      isha: isha,
      date: DateTime(date.year, date.month, date.day),
    );
  }
}
