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
  static const _kAdhanPrayers = 'adhan_prayers';
  static const _kDark = 'dark_mode';

  /// Batna, Algeria: what the app starts with before it has a GPS fix.
  double latitude = 35.5559;
  double longitude = 6.1741;
  String place = 'باتنة، الجزائر';
  CalcMethod method = CalcMethod.mwl;
  bool hanafiAsr = false;
  bool adhanEnabled = true;

  /// The prayers the adhan plays for.
  Set<String> adhanPrayers = {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'};

  /// Dark by default: the app is mostly used at dawn and at night.
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
