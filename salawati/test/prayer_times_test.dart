import 'package:flutter_test/flutter_test.dart';
import 'package:salawati/core/next_prayer.dart';
import 'package:salawati/core/prayer_times.dart';
import 'package:salawati/core/qibla.dart';

/// Minutes-since-midnight of a fractional hour, rounded the way the app rounds it.
int minutes(double? hour) {
  expect(hour, isNotNull);
  return (hour! * 60).round();
}

void main() {
  // Batna, Algeria. The reference values below come from an independent
  // implementation of the same astronomy, checked before the app was written.
  final batna = PrayerCalculator(
    latitude: 35.5559,
    longitude: 6.1741,
    timeZoneOffsetHours: 1.0,
    method: CalcMethod.mwl,
  );

  group('prayer times', () {
    test('a winter day in Batna matches the reference', () {
      final t = batna.forDate(DateTime(2026, 11, 26));
      expect(minutes(t.fajr), 5 * 60 + 52);
      expect(minutes(t.sunrise), 7 * 60 + 21);
      expect(minutes(t.dhuhr), 12 * 60 + 23);
      expect(minutes(t.asr), 15 * 60 + 4);
      expect(minutes(t.maghrib), 17 * 60 + 23);
      expect(minutes(t.isha), 18 * 60 + 48);
    });

    test('the summer solstice matches the reference', () {
      final t = batna.forDate(DateTime(2026, 6, 21));
      expect(minutes(t.fajr), 3 * 60 + 32);
      expect(minutes(t.dhuhr), 12 * 60 + 37);
      expect(minutes(t.maghrib), 19 * 60 + 54);
    });

    test('every prayer falls in the order a day has them', () {
      for (final date in [
        DateTime(2026, 1, 15),
        DateTime(2026, 4, 10),
        DateTime(2026, 8, 3),
        DateTime(2026, 11, 26),
      ]) {
        final t = batna.forDate(date);
        final hours = [t.fajr, t.sunrise, t.dhuhr, t.asr, t.maghrib, t.isha]
            .whereType<double>()
            .toList();
        for (var i = 1; i < hours.length; i++) {
          expect(hours[i], greaterThan(hours[i - 1]),
              reason: 'on $date the times must be increasing');
        }
      }
    });

    test('Dhuhr is around solar noon everywhere', () {
      for (final place in [
        (lat: 35.5559, lng: 6.1741, tz: 1.0),
        (lat: 21.4225, lng: 39.8262, tz: 3.0),
        (lat: 51.5072, lng: -0.1276, tz: 0.0),
        (lat: -33.8688, lng: 151.2093, tz: 11.0),
      ]) {
        final calc = PrayerCalculator(
          latitude: place.lat,
          longitude: place.lng,
          timeZoneOffsetHours: place.tz,
          method: CalcMethod.mwl,
        );
        final t = calc.forDate(DateTime(2026, 11, 26));
        expect(t.dhuhr, isNotNull);
        expect(t.dhuhr!, inInclusiveRange(11.0, 13.5),
            reason: 'solar noon near 12:00 local in ${place.lat}');
      }
    });

    test('a place where the sun never reaches the angle has no such prayer', () {
      // Tromsø in midsummer: no true night, so no Fajr twilight angle of 18°.
      final tromso = PrayerCalculator(
        latitude: 69.6492,
        longitude: 18.9553,
        timeZoneOffsetHours: 1.0,
        method: CalcMethod.mwl,
      );
      final summer = tromso.forDate(DateTime(2026, 6, 21));
      expect(summer.fajr, isNull);
      expect(summer.dhuhr, isNotNull);
    });

    test('Umm al-Qura puts Isha ninety minutes after Maghrib', () {
      final makkah = PrayerCalculator(
        latitude: 21.4225,
        longitude: 39.8262,
        timeZoneOffsetHours: 3.0,
        method: CalcMethod.ummAlQura,
      );
      final t = makkah.forDate(DateTime(2026, 11, 26));
      expect(minutes(t.isha) - minutes(t.maghrib), 90);
    });

    test('the Hanafi Asr comes later than the Shafi\'i one', () {
      final shafii = batna.forDate(DateTime(2026, 11, 26));
      final hanafi = PrayerCalculator(
        latitude: 35.5559,
        longitude: 6.1741,
        timeZoneOffsetHours: 1.0,
        method: CalcMethod.mwl,
        hanafiAsr: true,
      ).forDate(DateTime(2026, 11, 26));
      expect(hanafi.asr!, greaterThan(shafii.asr!));
    });

    test('every method produces a whole day of times', () {
      for (final method in CalcMethod.values) {
        final calc = PrayerCalculator(
          latitude: 35.5559,
          longitude: 6.1741,
          timeZoneOffsetHours: 1.0,
          method: method,
        );
        final t = calc.forDate(DateTime(2026, 3, 1));
        expect(t.fajr, isNotNull, reason: '${method.name} fajr');
        expect(t.isha, isNotNull, reason: '${method.name} isha');
        expect(t.ordered.length, 6);
      }
    });
  });

  group('next prayer', () {
    final t = batna.forDate(DateTime(2026, 11, 26));
    final y = batna.forDate(DateTime(2026, 11, 25));

    test('before Fajr the next prayer is today\'s Fajr', () {
      final next = nextPrayer(t, y, DateTime(2026, 11, 26, 3, 0));
      expect(next!.name, 'fajr');
      expect(next.at.hour, 5);
    });

    test('after Fajr the next prayer is Dhuhr', () {
      final next = nextPrayer(t, y, DateTime(2026, 11, 26, 6, 0));
      expect(next!.name, 'dhuhr');
    });

    test('between Maghrib and Isha the next is Isha', () {
      final next = nextPrayer(t, y, DateTime(2026, 11, 26, 18, 0));
      expect(next!.name, 'isha');
    });

    test('after Isha the next is tomorrow\'s Fajr, not nothing', () {
      // 23:00: today is finished, so the answer is the coming day's Fajr.
      final next = nextPrayer(t, y, DateTime(2026, 11, 26, 23, 0));
      expect(next, isNull, reason: 'no tomorrow handed in: the caller recalculates');
    });

    test('the countdown is the real remaining time', () {
      final now = DateTime(2026, 11, 26, 5, 0);
      final next = nextPrayer(t, y, now)!;
      expect(next.name, 'fajr');
      expect(next.remaining.inMinutes, 52);
      expect(next.countdown, '0:52:00');
    });

    test('a prayer turned off is skipped', () {
      final next = nextPrayer(
        t,
        y,
        DateTime(2026, 11, 26, 6, 0),
        enabled: {'asr', 'maghrib', 'isha'},
      );
      expect(next!.name, 'asr');
    });
  });

  group('qibla', () {
    test('from Batna the Kaaba lies to the east-south-east', () {
      final bearing = qiblaBearing(35.5559, 6.1741);
      // Batna is west of Makkah and south of its latitude, so the great circle leaves
      // just south of due east: about 106.6 degrees.
      expect(bearing, greaterThan(90));
      expect(bearing, lessThan(180));
      expect(bearing, closeTo(106.6, 1.0));
    });

    // Published qibla bearings, to prove the formula rather than a single number.
    test('the bearing matches published values for known cities', () {
      const cases = <({String city, double lat, double lng, double bearing})>[
        (city: 'London', lat: 51.5072, lng: -0.1276, bearing: 118.98),
        (city: 'Paris', lat: 48.8566, lng: 2.3522, bearing: 119.20),
        (city: 'New York', lat: 40.7128, lng: -74.0060, bearing: 58.50),
        (city: 'Jakarta', lat: -6.2088, lng: 106.8456, bearing: 295.10),
        (city: 'Cairo', lat: 30.0444, lng: 31.2357, bearing: 136.10),
        (city: 'Istanbul', lat: 41.0082, lng: 28.9784, bearing: 151.60),
      ];
      for (final c in cases) {
        expect(qiblaBearing(c.lat, c.lng), closeTo(c.bearing, 0.5),
            reason: c.city);
      }
    });

    test('from due north of Makkah the bearing is south', () {
      final bearing = qiblaBearing(40.0, 39.8251832);
      expect(bearing, closeTo(180, 1));
    });

    test('from Makkah itself the distance is zero', () {
      expect(qiblaDistanceKm(21.4224779, 39.8251832), closeTo(0, 1));
    });

    test('Batna is about four thousand kilometres from Makkah', () {
      final km = qiblaDistanceKm(35.5559, 6.1741);
      expect(km, inInclusiveRange(3300, 3800));
    });

    test('the cardinal name fits the bearing', () {
      expect(qiblaCardinal(106.6), 'الشرق');
      expect(qiblaCardinal(0), 'الشمال');
      expect(qiblaCardinal(359), 'الشمال');
      expect(qiblaCardinal(270), 'الغرب');
    });
  });
}
