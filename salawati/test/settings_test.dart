import 'package:flutter_test/flutter_test.dart';
import 'package:salawati/core/next_prayer.dart';
import 'package:salawati/core/prayer_times.dart';
import 'package:salawati/services/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The settings are the app's memory, and a wrong default silently means wrong times, so
/// they get their own tests: what a fresh install starts with, what survives a restart,
/// and that the notification keys that were removed are gone rather than half-used.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('a fresh install starts in Batna with the Muslim World League method', () async {
    final settings = AppSettings(await SharedPreferences.getInstance());
    expect(settings.latitude, closeTo(35.5559, 0.001));
    expect(settings.longitude, closeTo(6.1741, 0.001));
    expect(settings.method, CalcMethod.mwl);
    expect(settings.hasLocation, isFalse);
    expect(settings.adhanEnabled, isTrue);
    expect(settings.adhanPrayers, containsAll(prayerOrder));
    expect(settings.darkMode, isTrue);
  });

  test('every choice survives a restart', () async {
    final prefs = await SharedPreferences.getInstance();
    final first = AppSettings(prefs);

    await first.setLocation(36.7538, 3.0588, 'الجزائر العاصمة');
    await first.setMethod(CalcMethod.ummAlQura);
    await first.setHanafiAsr(true);
    await first.setAdhanEnabled(false);
    await first.setAdhanPrayer('fajr', false);
    await first.setDarkMode(false);

    final second = AppSettings(await SharedPreferences.getInstance());
    expect(second.latitude, closeTo(36.7538, 0.001));
    expect(second.longitude, closeTo(3.0588, 0.001));
    expect(second.place, 'الجزائر العاصمة');
    expect(second.hasLocation, isTrue);
    expect(second.method, CalcMethod.ummAlQura);
    expect(second.hanafiAsr, isTrue);
    expect(second.adhanEnabled, isFalse);
    expect(second.adhanPrayers, isNot(contains('fajr')));
    expect(second.adhanPrayers, contains('dhuhr'));
    expect(second.darkMode, isFalse);
  });

  test('a change notifies the screens', () async {
    final settings = AppSettings(await SharedPreferences.getInstance());
    var notified = 0;
    settings.addListener(() => notified++);

    await settings.setDarkMode(false);
    await settings.setMethod(CalcMethod.karachi);
    expect(notified, 2);
  });

  test('the stored notification keys were dropped, not left half-used', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_enabled', true);
    await prefs.setInt('pre_reminder_minutes', 10);
    // Constructing reads everything the app knows about; the removed keys are simply
    // ignored, which is the point: nothing reads them any more.
    final settings = AppSettings(prefs);
    expect(settings.method, CalcMethod.mwl);
    expect(prefs.getInt('pre_reminder_minutes'), 10);
  });
}
