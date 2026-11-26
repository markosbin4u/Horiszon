import 'prayer_times.dart';

/// The prayers a person prays (Sunrise is a time marker, not a prayer).
const List<String> prayerOrder = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

/// The Arabic name of each time of day.
const Map<String, String> prayerNames = {
  'fajr': 'الفجر',
  'sunrise': 'الشروق',
  'dhuhr': 'الظهر',
  'asr': 'العصر',
  'maghrib': 'المغرب',
  'isha': 'العشاء',
};

/// The prayer that comes next, and how long until it.
class NextPrayer {
  const NextPrayer({
    required this.name,
    required this.at,
    required this.remaining,
  });

  final String name;
  final DateTime at;
  final Duration remaining;

  String get arabicName => prayerNames[name] ?? name;

  /// `2:14:09` for two hours, fourteen minutes and nine seconds.
  String get countdown {
    final total = remaining.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return '$hours:${two(minutes)}:${two(seconds)}';
  }
}

/// When a prayer's hour (fractional hours since local midnight) happens on `day`.
DateTime timeOfDay(DateTime day, double hour) {
  // Build from midnight so a daylight-saving change the same day cannot skew it.
  final midnight = DateTime(day.year, day.month, day.day);
  final minutes = (hour * 60.0).round();
  return midnight.add(Duration(minutes: minutes));
}

/// The next prayer after `now`.
///
/// Yesterday's Isha is considered too: after midnight and before today's Fajr, the next
/// prayer is today's Fajr, but if today's Fajr is absent (a polar summer) the answer is
/// the next one that does happen. Returns null only when the place has no times at all.
NextPrayer? nextPrayer(
  PrayerTimes today,
  PrayerTimes yesterday,
  DateTime now, {
  Set<String> enabled = const {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'},
}) {
  final candidates = <NextPrayer>[];

  void consider(PrayerTimes times) {
    for (final name in prayerOrder) {
      if (!enabled.contains(name)) continue;
      final hour = switch (name) {
        'fajr' => times.fajr,
        'dhuhr' => times.dhuhr,
        'asr' => times.asr,
        'maghrib' => times.maghrib,
        'isha' => times.isha,
        _ => null,
      };
      if (hour == null) continue;
      final at = timeOfDay(times.date, hour);
      if (at.isAfter(now)) {
        candidates.add(NextPrayer(name: name, at: at, remaining: at.difference(now)));
      }
    }
  }

  consider(yesterday);
  consider(today);
  if (candidates.isEmpty) return null;
  candidates.sort((a, b) => a.at.compareTo(b.at));
  return candidates.first;
}

/// The prayer whose time is now, if any (the last one that has come and gone today).
String? currentPrayer(PrayerTimes today, DateTime now) {
  String? current;
  for (final name in prayerOrder) {
    final hour = switch (name) {
      'fajr' => today.fajr,
      'dhuhr' => today.dhuhr,
      'asr' => today.asr,
      'maghrib' => today.maghrib,
      'isha' => today.isha,
      _ => null,
    };
    if (hour == null) continue;
    if (!timeOfDay(today.date, hour).isAfter(now)) current = name;
  }
  return current;
}
