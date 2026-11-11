import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'firebase_options.dart';
import 'raqeeb_ui.dart';
import 'raqeeb_sun_times.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/login_screen.dart';
import 'screens/alerts_screen.dart';
import 'screens/history_screen.dart';
import 'incident_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await IncidentStore.instance.load();
  runApp(const RaqeebApp());
}

class RaqeebApp extends StatefulWidget {
  const RaqeebApp({super.key});
  @override
  State<RaqeebApp> createState() => _RaqeebAppState();
}

class _RaqeebAppState extends State<RaqeebApp> with WidgetsBindingObserver {
  String themePreference = 'automatic';
  String languageCode = 'ar';
  String locationMode = 'device'; // device GPS or selected fallback city
  String fallbackCity = 'riyadh';
  bool _gpsAvailable = false;
  bool _isNightNow = false;
  double _latitude = 24.7136;
  double _longitude = 46.6753;
  bool _isUpdatingLocation = false;

  static const _cities = <String, (double, double)>{
    'riyadh': (24.7136, 46.6753),
    'jeddah': (21.5433, 39.1728),
    'dammam': (26.4207, 50.0888),
    'makkah': (21.3891, 39.8579),
    'madinah': (24.5247, 39.5692),
  };

  Timer? _clockTimer;
  DateTime? _lastLocationRefresh;
  late final Stream<User?> _authStream;

  bool get isDarkMode => themePreference == 'dark' ||
      (themePreference == 'automatic' && _isNightNow);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _authStream = FirebaseAuth.instance.authStateChanges();
    _checkClock();
    _loadSettings();
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkClock();
      if (locationMode == 'device' && themePreference == 'automatic' &&
          (_lastLocationRefresh == null ||
           DateTime.now().difference(_lastLocationRefresh!) >
               const Duration(minutes: 30))) {
        _refreshLocation(requestPermission: false);
      }
    });
  }

  void _setFallbackCoordinates() {
    final city = _cities[fallbackCity] ?? _cities['riyadh']!;
    _latitude = city.$1;
    _longitude = city.$2;
  }

  void _checkClock() {
    bool night;
    try {
      night = RaqeebSunTimes.isNight(DateTime.now(),
          latitude: _latitude, longitude: _longitude);
    } catch (_) {
      night = DateTime.now().hour < 6 || DateTime.now().hour >= 18;
    }
    if (mounted && night != _isNightNow) setState(() => _isNightNow = night);
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final saved = prefs.getString('themePreference');
    final oldManual = prefs.getBool('isDarkMode');
    setState(() {
      themePreference = ['automatic', 'light', 'dark'].contains(saved)
          ? saved! : (oldManual == null ? 'automatic' : (oldManual ? 'dark' : 'light'));
      languageCode = prefs.getString('languageCode') == 'en' ? 'en' : 'ar';
      locationMode = prefs.getString('locationMode') == 'city' ? 'city' : 'device';
      final city = prefs.getString('fallbackCity');
      fallbackCity = _cities.containsKey(city) ? city! : 'riyadh';
      _setFallbackCoordinates();
    });
    _checkClock();
    if (themePreference == 'automatic' && locationMode == 'device') {
      await _refreshLocation(requestPermission: true);
    }
  }

  /// Only foreground location; no continuous GPS, no coordinates uploaded.
  /// On denial/unavailability, the chosen city is used instead.
  Future<void> _refreshLocation({required bool requestPermission}) async {
    if (_isUpdatingLocation || locationMode != 'device') return;
    _isUpdatingLocation = true;
    _lastLocationRefresh = DateTime.now();
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        if (mounted) {
          setState(() {
          _gpsAvailable = false;
          _setFallbackCoordinates();
        });
        }
        _checkClock();
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied && requestPermission) {
        permission = await Geolocator.requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        if (mounted) {
          setState(() {
          _gpsAvailable = false;
          _setFallbackCoordinates();
        });
        }
        _checkClock();
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (!mounted || locationMode != 'device') return;
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _gpsAvailable = true;
      });
      _checkClock();
    } catch (_) {
      if (mounted) {
        setState(() {
          _gpsAvailable = false;
          _setFallbackCoordinates();
        });
        _checkClock();
      }
    } finally {
      _isUpdatingLocation = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClock();
      if (locationMode == 'device' && themePreference == 'automatic') {
        _refreshLocation(requestPermission: false);
      }
    }
  }

  Future<void> _changeTheme(String selection) async {
    if (!['automatic', 'light', 'dark'].contains(selection)) return;
    setState(() => themePreference = selection);
    _checkClock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themePreference', selection);
    if (selection == 'automatic' && locationMode == 'device') {
      await _refreshLocation(requestPermission: true);
    }
  }

  Future<void> _changeLocationMode(String selection) async {
    if (selection != 'city' && selection != 'device') return;
    setState(() {
      locationMode = selection;
      if (selection == 'city') {
        _gpsAvailable = false;
        _setFallbackCoordinates();
      }
    });
    _checkClock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('locationMode', selection);
    if (selection == 'device') await _refreshLocation(requestPermission: true);
  }

  Future<void> _changeFallbackCity(String city) async {
    if (!_cities.containsKey(city)) return;
    setState(() {
      fallbackCity = city;
      if (locationMode == 'city' || !_gpsAvailable) _setFallbackCoordinates();
    });
    _checkClock();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fallbackCity', city);
  }

  Future<void> _changeLanguage(String lang) async {
    if (lang != 'ar' && lang != 'en') return;
    setState(() => languageCode = lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('languageCode', lang);
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = isDarkMode;
    final en = languageCode == 'en';
    return MaterialApp(
      title: 'Raqeeb',
      debugShowCheckedModeBanner: false,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      theme: _theme(false),
      darkTheme: _theme(true),
      builder: (context, child) => RaqeebLanguage(
        isEnglish: en,
        child: Directionality(
          textDirection: en ? TextDirection.ltr : TextDirection.rtl,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: _authStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          if (snapshot.hasError) {
            return Scaffold(
              body: Center(child: Text(tr(context,
                  'تعذر التحقق من حالة تسجيل الدخول',
                  'Could not verify sign-in status'))),
            );
          }
          return snapshot.data == null
              ? const LoginScreen()
              : MainNavigation(
                  themePreference: themePreference,
                  isDarkMode: dark,
                  onThemeChanged: _changeTheme,
                  languageCode: languageCode,
                  onLanguageChanged: _changeLanguage,
                  locationMode: locationMode,
                  fallbackCity: fallbackCity,
                  gpsAvailable: _gpsAvailable,
                  onLocationModeChanged: _changeLocationMode,
                  onFallbackCityChanged: _changeFallbackCity,
                  onRetryLocation: () => _refreshLocation(requestPermission: true),
                );
        },
      ),
    );
  }

  ThemeData _theme(bool dark) {
    final accent = RaqeebColors.accent(dark);
    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: RaqeebColors.background(dark),
      colorScheme: ColorScheme.fromSeed(
        seedColor: accent,
        brightness: dark ? Brightness.dark : Brightness.light,
        surface: RaqeebColors.card(dark),
        primary: accent,
        onPrimary: dark ? const Color(0xFF112018) : Colors.white,
        error: RaqeebColors.danger(dark),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: RaqeebColors.background(dark),
        foregroundColor: RaqeebColors.text(dark),
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({
    super.key,
    required this.themePreference,
    required this.isDarkMode,
    required this.onThemeChanged,
    required this.languageCode,
    required this.onLanguageChanged,
    required this.locationMode,
    required this.fallbackCity,
    required this.gpsAvailable,
    required this.onLocationModeChanged,
    required this.onFallbackCityChanged,
    required this.onRetryLocation,
  });
  final String themePreference;
  final bool isDarkMode;
  final ValueChanged<String> onThemeChanged;
  final String languageCode;
  final ValueChanged<String> onLanguageChanged;
  final String locationMode;
  final String fallbackCity;
  final bool gpsAvailable;
  final ValueChanged<String> onLocationModeChanged;
  final ValueChanged<String> onFallbackCityChanged;
  final VoidCallback onRetryLocation;

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final bg = RaqeebColors.bottomBar(dark);
    final pages = <Widget>[
      const HomeScreen(),
      const HistoryScreen(),
      const AlertsScreen(),
      const ProfileScreen(),
      SettingsScreen(
        isDarkMode: dark,
        themePreference: widget.themePreference,
        onThemeChanged: widget.onThemeChanged,
        languageCode: widget.languageCode,
        onLanguageChanged: widget.onLanguageChanged,
        locationMode: widget.locationMode,
        fallbackCity: widget.fallbackCity,
        gpsAvailable: widget.gpsAvailable,
        onLocationModeChanged: widget.onLocationModeChanged,
        onFallbackCityChanged: widget.onFallbackCityChanged,
        onRetryLocation: widget.onRetryLocation,
      ),
    ];
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: pages),
      bottomNavigationBar: BottomAppBar(
        color: bg,
        height: 78,
        padding: EdgeInsets.zero,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _navItem(Icons.home_outlined, tr(context, 'الرئيسية', 'Home'), 0),
            _navItem(Icons.history_rounded, tr(context, 'السجل', 'History'), 1),
            Transform.translate(
              offset: const Offset(0, -14),
              child: GestureDetector(
                onTap: () => setState(() => selectedIndex = 2),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: dark ? const Color(0xFF862B2B) : RaqeebColors.lightDanger,
                      shape: BoxShape.circle,
                      border: Border.all(color: bg, width: 4),
                    ),
                    child: const Icon(Icons.notifications_active_rounded,
                        color: Colors.white, size: 27),
                  ),
                  const SizedBox(height: 2),
                  Text(tr(context, 'التنبيهات', 'Alerts'), style: TextStyle(
                      color: RaqeebColors.text(dark), fontSize: 10)),
                ]),
              ),
            ),
            _navItem(Icons.person_outline_rounded, tr(context, 'حسابي', 'Profile'), 3),
            _navItem(Icons.settings_outlined, tr(context, 'الإعدادات', 'Settings'), 4),
          ],
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final dark = widget.isDarkMode;
    final selected = selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => selectedIndex = index),
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 64,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon,
              color: selected ? RaqeebColors.accent(dark) : RaqeebColors.secondary(dark),
              size: 24),
          const SizedBox(height: 5),
          Text(label, style: TextStyle(
              color: selected ? RaqeebColors.text(dark) : RaqeebColors.secondary(dark),
              fontSize: 10, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
        ]),
      ),
    );
  }
}

// Existing History/Alerts placeholders preserved until incident API is ready.
class PlaceholderPage extends StatelessWidget {
  const PlaceholderPage({super.key, required this.title});
  final String title;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: Text(title), centerTitle: true),
      body: Center(child: Text(tr(context,
        'سيتم تطوير هذه الصفحة لاحقًا', 'This page will be developed later'),
        style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 16))),
    );
  }
}
