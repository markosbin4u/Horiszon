import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prayer_times.dart';

/// Everything the player can change, kept between launches.
class AppSettings extends ChangeNotifier {
  AppSettings(this._prefs) {
    _load();
  }

  final SharedPreferences _prefs;

  static const _kLatitude = 'latitude';
  static const _kLongitude = 'longitude';
  static const _kPlace = 'place';
  static const _kMethod = 'method';
  static const _kHanafi = 'hanafi_asr';
  static const _kAdhan = 'adhan_enabled';
  static const _kNotify = 'notify_enabled';
  static const _kPreReminder = 'pre_reminder_minutes';
  static const _kAdhanPrayers = 'adhan_prayers';
  static const _kDark = 'dark_mode';

  /// Batna, Algeria: what the app starts with before it has a GPS fix.
  double latitude = 35.5559;
  double longitude = 6.1741;
  String place = 'باتنة، الجزائر';
  CalcMethod method = CalcMethod.mwl;
  bool hanafiAsr = false;
  bool adhanEnabled = true;
  bool notifyEnabled = true;

  /// How many minutes before a prayer a reminder is shown (0 turns it off).
  int preReminderMinutes = 10;

  /// The prayers the adhan plays for.
  Set<String> adhanPrayers = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};

  bool darkMode = true;

  /// True once a real location has been saved (otherwise the place is the fallback).
  bool get hasLocation => _prefs.getBool('has_location') ?? false;

  void _load() {
    latitude = _prefs.getDouble(_kLatitude) ?? latitude;
    longitude = _prefs.getDouble(_kLongitude) ?? longitude;
    place = _prefs.getString(_kPlace) ?? place;
    final methodName = _prefs.getString(_kMethod);
    method = CalcMethod.values.firstWhere(
      (m) => m.name == methodName,
      orElse: () => CalcMethod.mwl,
    );
    hanafiAsr = _prefs.getBool(_kHanafi) ?? hanafiAsr;
    adhanEnabled = _prefs.getBool(_kAdhan) ?? adhanEnabled;
    notifyEnabled = _prefs.getBool(_kNotify) ?? notifyEnabled;
    preReminderMinutes = _prefs.getInt(_kPreReminder) ?? preReminderMinutes;
    darkMode = _prefs.getBool(_kDark) ?? darkMode;
    final adhan = _prefs.getStringList(_kAdhanPrayers);
    if (adhan != null) adhanPrayers = adhan.toSet();
  }

  Future<void> setLocation(double lat, double lng, String label) async {
    latitude = lat;
    longitude = lng;
    place = label;
    notifyListeners();
    await _prefs.setDouble(_kLatitude, lat);
    await _prefs.setDouble(_kLongitude, lng);
    await _prefs.setString(_kPlace, label);
    await _prefs.setBool('has_location', true);
  }

  Future<void> setMethod(CalcMethod value) async {
    method = value;
    notifyListeners();
    await _prefs.setString(_kMethod, value.name);
  }

  Future<void> setHanafiAsr(bool value) async {
    hanafiAsr = value;
    notifyListeners();
    await _prefs.setBool(_kHanafi, value);
  }

  Future<void> setAdhanEnabled(bool value) async {
    adhanEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kAdhan, value);
  }

  Future<void> setNotifyEnabled(bool value) async {
    notifyEnabled = value;
    notifyListeners();
    await _prefs.setBool(_kNotify, value);
  }

  Future<void> setPreReminder(int minutes) async {
    preReminderMinutes = minutes;
    notifyListeners();
    await _prefs.setInt(_kPreReminder, minutes);
  }

  Future<void> setAdhanPrayer(String prayer, bool on) async {
    if (on) {
      adhanPrayers.add(prayer);
    } else {
      adhanPrayers.remove(prayer);
    }
    notifyListeners();
    await _prefs.setStringList(_kAdhanPrayers, adhanPrayers.toList());
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    notifyListeners();
    await _prefs.setBool(_kDark, value);
  }
}
