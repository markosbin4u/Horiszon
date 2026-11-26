import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/next_prayer.dart';
import 'core/prayer_times.dart';
import 'core/qibla.dart';
import 'data/adhkar.dart';
import 'data/duas.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = AppSettings(prefs);
  runApp(SalaatiApp(settings: settings));
}

class SalaatiApp extends StatelessWidget {
  const SalaatiApp({super.key, required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'صلواتي',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.dark),
      home: HomePage(settings: settings),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF0E7C66),
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Amiri',
      scaffoldBackgroundColor: scheme.surface,
    );
  }
}

/// Where the app is, which method it uses, and the times it computed: the one object the
/// screens listen to.
class AppState extends ChangeNotifier {
  AppState(this.settings) {
    latitude = settings.latitude;
    longitude = settings.longitude;
    place = settings.place;
    method = settings.method;
    recalculate();
  }

  final AppSettings settings;

  bool loading = false;
  String? error;
  late double latitude;
  late double longitude;
  late String place;
  late CalcMethod method;

  PrayerTimes? today;
  PrayerTimes? yesterday;

  DateTime now = DateTime.now();
  Timer? _ticker;

  void start() {
    _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
      now = DateTime.now();
      final today = this.today;
      if (today != null &&
          (now.day != today.date.day || now.month != today.date.month)) {
        recalculate();
      }
      notifyListeners();
    });
    // A saved location is used at once; GPS only asks again when there is none.
    if (settings.hasLocation) {
      notifyListeners();
    } else {
      locate();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  /// Asks Android for the position (and permission, the first time).
  Future<void> locate() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        error = 'خدمة الموقع مغلقة. شغّلها من إعدادات الهاتف.';
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        error = 'لم يُسمح بالوصول إلى الموقع. يمكنك إدخال المدينة يدوياً.';
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 25),
        ),
      );
      latitude = position.latitude;
      longitude = position.longitude;
      place = await _placeName(latitude, longitude);
      await settings.setLocation(latitude, longitude, place);
      recalculate();
    } catch (e) {
      error = 'تعذّر تحديد الموقع: $e';
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<String> _placeName(double lat, double lng) async {
    try {
      final marks = await placemarkFromCoordinates(lat, lng);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final parts = <String>[
          if ((m.locality ?? '').isNotEmpty) m.locality!,
          if ((m.country ?? '').isNotEmpty) m.country!,
        ];
        if (parts.isNotEmpty) return parts.join('، ');
      }
    } catch (_) {
      // Offline, or no geocoder on the device: coordinates are still a fine label.
    }
    return '${lat.toStringAsFixed(3)}، ${lng.toStringAsFixed(3)}';
  }

  Future<void> setManual(double lat, double lng, String label) async {
    latitude = lat;
    longitude = lng;
    place = label;
    await settings.setLocation(lat, lng, label);
    recalculate();
  }

  Future<void> setMethod(CalcMethod value) async {
    method = value;
    await settings.setMethod(value);
    recalculate();
  }

  void recalculate() {
    final offset = DateTime.now().timeZoneOffset.inMinutes / 60.0;
    final calc = PrayerCalculator(
      latitude: latitude,
      longitude: longitude,
      timeZoneOffsetHours: offset,
      method: method,
      hanafiAsr: settings.hanafiAsr,
    );
    final nowLocal = DateTime.now();
    today = calc.forDate(nowLocal);
    yesterday = calc.forDate(nowLocal.subtract(const Duration(days: 1)));
    notifyListeners();
  }

  NextPrayer? get next =>
      today == null || yesterday == null
          ? null
          : nextPrayer(today!, yesterday!, DateTime.now(),
              enabled: settings.adhanPrayers.isEmpty
                  ? const {'fajr', 'dhuhr', 'asr', 'maghrib', 'isha'}
                  : settings.adhanPrayers);

  double get qibla => qiblaBearing(latitude, longitude);
  double get distanceToKaaba => qiblaDistanceKm(latitude, longitude);
}

/// Plays a bundled adhan file. It stops on its own when the clip ends.
class AdhanPlayer {
  AdhanPlayer();

  final AudioPlayer _player = AudioPlayer();

  Future<void> play() async {
    try {
      await _player.stop();
      await _player.play(AssetSource('adhan.mp3'));
    } catch (e) {
      // A missing or unreadable clip must never break prayer times.
      debugPrint('adhan could not play: $e');
    }
  }

  Future<void> stop() => _player.stop();

  void dispose() {
    _player.dispose();
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.settings});

  final AppSettings settings;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AppState state;
  late final TabController _tabs;
  late final AdhanPlayer _adhan;
  final Set<String> _announced = {};

  @override
  void initState() {
    super.initState();
    state = AppState(widget.settings);
    _tabs = TabController(length: 4, vsync: this);
    _adhan = AdhanPlayer();
    state.addListener(_onTick);
    state.start();
  }

  /// Plays the adhan once, as each prayer's moment passes.
  void _onTick() {
    final today = state.today;
    if (today == null || !widget.settings.adhanEnabled) return;
    for (final entry in today.ordered) {
      if (!widget.settings.adhanPrayers.contains(entry.name)) continue;
      final at = timeOfDay(today.date, entry.hour);
      final key = '${entry.name}-${today.date.day}';
      final elapsed = DateTime.now().difference(at).inSeconds;
      if (elapsed >= 0 && elapsed < 2 && _announced.add(key)) {
        _adhan.play();
      }
    }
  }

  @override
  void dispose() {
    state.removeListener(_onTick);
    _tabs.dispose();
    _adhan.dispose();
    state.dispose();
    super.dispose();
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SettingsPage(state: state, settings: widget.settings),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('صلواتي'),
          centerTitle: true,
          actions: [
            IconButton(
              onPressed: state.locate,
              icon: const Icon(Icons.my_location),
              tooltip: 'تحديد موقعي',
            ),
            IconButton(
              onPressed: _openSettings,
              icon: const Icon(Icons.settings),
              tooltip: 'الإعدادات',
            ),
          ],
          bottom: TabBar(
            controller: _tabs,
            tabs: const [
              Tab(text: 'المواقيت'),
              Tab(text: 'القبلة'),
              Tab(text: 'الأذكار'),
              Tab(text: 'الأدعية'),
            ],
          ),
        ),
        body: AnimatedBuilder(
          animation: state,
          builder: (context, _) => TabBarView(
            controller: _tabs,
            children: [
              PrayerTimePage(state: state),
              QiblaPage(state: state),
              const AdhkarPage(),
              const DuaPage(),
            ],
          ),
        ),
      ),
    );
  }
}

/// The times, the countdown to the next prayer, and the place they are for.
class PrayerTimePage extends StatelessWidget {
  const PrayerTimePage({super.key, required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = state.today;
    if (today == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final next = state.next;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.place, size: 18),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        state.place,
                        style: theme.textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(arabicDate(DateTime.now()),
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 14),
                if (next != null) ...[
                  Text('الصلاة القادمة',
                      style: theme.textTheme.bodyMedium),
                  Text(next.arabicName,
                      style: theme.textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    next.countdown,
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text('متبقٍ حتى ${formatHour(next.at)}',
                      style: theme.textTheme.bodySmall),
                ] else
                  Text('لا توجد صلاة قادمة اليوم',
                      style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        if (state.error != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: 8),
                  Expanded(child: Text(state.error!)),
                ],
              ),
            ),
          ),
        for (final entry in today.ordered)
          _PrayerTile(
            name: entry.name,
            hour: entry.hour,
            isNext: next?.name == entry.name,
          ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'طريقة الحساب: ${state.method.label}',
            style: theme.textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

String formatHour(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(at.hour)}:${two(at.minute)}';
}

String arabicDate(DateTime date) {
  const months = [
    'جانفي', 'فيفري', 'مارس', 'أفريل', 'ماي', 'جوان',
    'جويلية', 'أوت', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class _PrayerTile extends StatelessWidget {
  const _PrayerTile({required this.name, required this.hour, this.isNext = false});

  final String name;
  final double hour;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final prayer = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'].contains(name);
    final minutes = (hour * 60).round();
    String two(int v) => v.toString().padLeft(2, '0');
    final time = '${two((minutes ~/ 60) % 24)}:${two(minutes % 60)}';

    return Card(
      elevation: isNext ? 3 : 0,
      color: isNext
          ? theme.colorScheme.primary.withValues(alpha: 0.18)
          : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: ListTile(
        leading: Icon(
          prayer
              ? (name == 'fajr' ? Icons.nightlight_round : Icons.access_time_filled)
              : Icons.wb_sunny,
          color: theme.colorScheme.primary,
        ),
        title: Text(
          prayerNames[name] ?? name,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: prayer ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        trailing: Text(
          time,
          style: theme.textTheme.titleLarge?.copyWith(
            fontFeatures: const [FontFeature.tabularFigures()],
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// The qibla compass: the Kaaba's bearing against the phone's magnetic heading.
class QiblaPage extends StatefulWidget {
  const QiblaPage({super.key, required this.state});

  final AppState state;

  @override
  State<QiblaPage> createState() => _QiblaPageState();
}

class _QiblaPageState extends State<QiblaPage> {
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  String? _error;

  @override
  void initState() {
    super.initState();
    final events = FlutterCompass.events;
    if (events == null) {
      _error = 'هذا الهاتف لا يملك بوصلة.';
      return;
    }
    _sub = events.listen(
      (event) {
        if (!mounted) return;
        setState(() {
          _heading = event.heading;
          _error = null;
        });
      },
      onError: (Object e) {
        if (mounted) setState(() => _error = 'تعذّر قراءة البوصلة: $e');
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final qibla = widget.state.qibla;
    final heading = _heading;
    var delta = 0.0;
    var aligned = false;
    if (heading != null) {
      delta = (qibla - heading) % 360;
      if (delta > 180) delta -= 360;
      if (delta < -180) delta += 360;
      aligned = delta.abs() < 8;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text('اتجاه القبلة من ${widget.state.place}',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: 6),
                Text('${qibla.toStringAsFixed(1)}°',
                    style: theme.textTheme.displaySmall
                        ?.copyWith(color: theme.colorScheme.primary)),
                Text(qiblaCardinal(qibla), style: theme.textTheme.titleLarge),
                const SizedBox(height: 6),
                Text(
                  'المسافة إلى الكعبة: ${widget.state.distanceToKaaba.toStringAsFixed(0)} كم',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_error != null)
          Card(
            color: theme.colorScheme.errorContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, textAlign: TextAlign.center),
            ),
          )
        else
          Center(
            child: SizedBox(
              width: 290,
              height: 290,
              child: CustomPaint(
                painter: _CompassPainter(
                  heading: heading,
                  qibla: qibla,
                  aligned: aligned,
                  color: theme.colorScheme.primary,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.mosque,
                          size: 46,
                          color: aligned
                              ? const Color(0xFF2E7D32)
                              : theme.colorScheme.primary),
                      const SizedBox(height: 6),
                      SizedBox(
                        width: 130,
                        child: Text(
                          aligned
                              ? 'أنت تواجه القبلة'
                              : (heading == null
                                  ? 'جارٍ قراءة البوصلة...'
                                  : 'أدر الهاتف ${delta > 0 ? "يميناً" : "يساراً"} '
                                      '${delta.abs().toStringAsFixed(0)}°'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            'أمسك الهاتف أفقياً وأبعده عن المعادن. إن كانت القراءة غير مستقرة حرّكه على شكل '
            'الرقم ٨ لمعايرة البوصلة.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _CompassPainter extends CustomPainter {
  _CompassPainter({
    required this.heading,
    required this.qibla,
    required this.aligned,
    required this.color,
  });

  final double? heading;
  final double qibla;
  final bool aligned;
  final Color color;

  static const _pi = 3.141592653589793;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 20;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = color.withValues(alpha: 0.35);
    canvas.drawCircle(center, radius, ring);

    final headingValue = heading ?? 0;

    void letter(String text, double degrees, Color tint) {
      final angle = (degrees - headingValue) * _pi / 180 - _pi / 2;
      final at = center +
          Offset((radius - 16) * math.cos(angle), (radius - 16) * math.sin(angle));
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(color: tint, fontSize: 15, fontWeight: FontWeight.bold),
        ),
        textDirection: TextDirection.rtl,
      )..layout();
      painter.paint(
          canvas, at - Offset(painter.width / 2, painter.height / 2));
    }

    letter('ش', 0, color);
    letter('ق', 90, color.withValues(alpha: 0.5));
    letter('ج', 180, color.withValues(alpha: 0.5));
    letter('غ', 270, color.withValues(alpha: 0.5));

    final tint = aligned ? const Color(0xFF2E7D32) : color;
    final needle = Paint()
      ..color = tint
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final angle = (qibla - headingValue) * _pi / 180 - _pi / 2;
    final tip = center +
        Offset((radius - 46) * math.cos(angle), (radius - 46) * math.sin(angle));
    canvas.drawLine(center, tip, needle);
    canvas.drawCircle(tip, 7, Paint()..color = tint);
  }

  @override
  bool shouldRepaint(covariant _CompassPainter old) =>
      old.heading != heading || old.qibla != qibla || old.aligned != aligned;
}

/// The remembrance, grouped, with how many times each is said.
class AdhkarPage extends StatelessWidget {
  const AdhkarPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: adhkarGroups.length,
      itemBuilder: (context, index) {
        final group = adhkarGroups[index];
        return Card(
          child: ExpansionTile(
            title: Text(group.title,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Text(group.subtitle),
            children: [
              for (final item in group.items)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SelectableText(item.text,
                          style: const TextStyle(fontSize: 17, height: 1.9)),
                      if (item.note != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(item.note!,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context).colorScheme.primary)),
                        ),
                      if (item.repeat > 1)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Chip(
                              label: Text('× ${item.repeat}'),
                              visualDensity: VisualDensity.compact,
                            ),
                          ),
                        ),
                      const Divider(height: 22),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// The supplications, searchable.
class DuaPage extends StatefulWidget {
  const DuaPage({super.key});

  @override
  State<DuaPage> createState() => _DuaPageState();
}

class _DuaPageState extends State<DuaPage> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? duas
        : duas
            .where((d) =>
                d.title.contains(_query) ||
                d.occasion.contains(_query) ||
                d.text.contains(_query))
            .toList();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: const InputDecoration(
              hintText: 'ابحث في الأدعية...',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: filtered.length,
            itemBuilder: (context, index) {
              final dua = filtered[index];
              return Card(
                child: ExpansionTile(
                  title: Text(dua.title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(dua.occasion),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SelectableText(dua.text,
                              style: const TextStyle(fontSize: 17, height: 2)),
                          if (dua.source != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Text(dua.source!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          Theme.of(context).colorScheme.primary)),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// The settings screen: location, calculation method, adhan, reminders.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.state, required this.settings});

  final AppState state;
  final AppSettings settings;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  /// The cities offered for a manual choice, with their coordinates.
  static const _cities = <({String name, double lat, double lng})>[
    (name: 'باتنة، الجزائر', lat: 35.5559, lng: 6.1741),
    (name: 'الجزائر العاصمة', lat: 36.7538, lng: 3.0588),
    (name: 'قسنطينة', lat: 36.3650, lng: 6.6147),
    (name: 'سطيف', lat: 36.1898, lng: 5.4108),
    (name: 'بسكرة', lat: 34.8500, lng: 5.7333),
    (name: 'ورقلة', lat: 31.9494, lng: 5.3256),
    (name: 'عنابة', lat: 36.9000, lng: 7.7667),
    (name: 'تلمسان', lat: 34.8783, lng: -1.3150),
    (name: 'وهران', lat: 35.6971, lng: -0.6308),
    (name: 'بشار', lat: 31.6167, lng: -2.2167),
    (name: 'تمنراست', lat: 22.7850, lng: 5.5228),
    (name: 'مكة المكرمة', lat: 21.4225, lng: 39.8262),
    (name: 'المدينة المنورة', lat: 24.4672, lng: 39.6111),
    (name: 'القاهرة', lat: 30.0444, lng: 31.2357),
    (name: 'تونس', lat: 36.8065, lng: 10.1815),
    (name: 'الرباط', lat: 34.0209, lng: -6.8416),
  ];

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('الإعدادات')),
        body: AnimatedBuilder(
          animation: Listenable.merge([settings, widget.state]),
          builder: (context, _) => ListView(
            children: [
              const _SectionHeader('الموقع'),
              ListTile(
                leading: const Icon(Icons.place),
                title: Text(widget.state.place),
                subtitle: Text(
                    '${widget.state.latitude.toStringAsFixed(3)}، ${widget.state.longitude.toStringAsFixed(3)}'),
                trailing: FilledButton.tonalIcon(
                  onPressed: widget.state.loading
                      ? null
                      : () async {
                          await widget.state.locate();
                          if (context.mounted) setState(() {});
                        },
                  icon: widget.state.loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, size: 18),
                  label: const Text('GPS'),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.location_city),
                title: const Text('اختيار مدينة يدوياً'),
                trailing: DropdownButton<({String name, double lat, double lng})>(
                  hint: const Text('المدينة'),
                  items: <DropdownMenuItem<({String name, double lat, double lng})>>[
                    for (final city in _cities)
                      DropdownMenuItem<({String name, double lat, double lng})>(
                          value: city, child: Text(city.name)),
                  ],
                  onChanged: (city) async {
                    if (city == null) return;
                    await widget.state.setManual(city.lat, city.lng, city.name);
                    if (context.mounted) setState(() {});
                  },
                ),
              ),
              const _SectionHeader('الحساب'),
              ListTile(
                leading: const Icon(Icons.calculate),
                title: const Text('طريقة الحساب'),
                trailing: DropdownButton<CalcMethod>(
                  value: widget.state.method,
                  items: [
                    for (final method in CalcMethod.values)
                      DropdownMenuItem(value: method, child: Text(method.label)),
                  ],
                  onChanged: (method) async {
                    if (method == null) return;
                    await widget.state.setMethod(method);
                    if (context.mounted) setState(() {});
                  },
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.wb_twilight),
                title: const Text('العصر على المذهب الحنفي'),
                subtitle: const Text('المذهب الشافعي (الجمهور) هو الافتراضي'),
                value: settings.hanafiAsr,
                onChanged: (on) async {
                  await settings.setHanafiAsr(on);
                  widget.state.recalculate();
                },
              ),
              const _SectionHeader('الأذان والتنبيه'),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up),
                title: const Text('تشغيل الأذان'),
                subtitle: const Text('عند دخول وقت الصلاة والتطبيق مفتوح'),
                value: settings.adhanEnabled,
                onChanged: (on) async {
                  await settings.setAdhanEnabled(on);
                  if (context.mounted) setState(() {});
                },
              ),
              for (final prayer in prayerOrder)
                SwitchListTile(
                  contentPadding: const EdgeInsets.only(right: 32, left: 16),
                  dense: true,
                  title: Text('أذان ${prayerNames[prayer]}'),
                  value: settings.adhanPrayers.contains(prayer),
                  onChanged: settings.adhanEnabled
                      ? (on) => settings.setAdhanPrayer(prayer, on)
                      : null,
                ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('الحد الأدنى للتنبيه'),
                trailing: Text('${settings.preReminderMinutes}'),
              ),
              const _SectionHeader('عن التطبيق'),
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('صلواتي'),
                subtitle: Text(
                    'مواقيت الصلاة والأذان والقبلة والأذكار. يعمل بدون إنترنت.'),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
