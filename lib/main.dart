import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/settings_screen.dart';

void main() {
  runApp(const RaqeebApp());
}

// الألوان المشتركة بين الوضعين
class RaqeebColors {
  static const militaryGreen = Color(0xFF6F8862);
  static const alertRed = Color(0xFFB83F45);

  static Color background(bool isDark) =>
      isDark ? const Color(0xFF111A1D) : const Color(0xFFF5F6F1);

  static Color card(bool isDark) =>
      isDark ? const Color(0xFF1C2A2D) : Colors.white;

  static Color primaryText(bool isDark) =>
      isDark ? const Color(0xFFF1F5ED) : const Color(0xFF1D3027);

  static Color secondaryText(bool isDark) =>
      isDark ? const Color(0xFFAAB8AA) : const Color(0xFF647568);

  static Color bottomBar(bool isDark) =>
      isDark ? const Color(0xFF101E1C) : const Color(0xFFE7ECE4);
}

// مسؤول عن تغيير مظهر التطبيق كاملًا
class RaqeebApp extends StatefulWidget {
  const RaqeebApp({super.key});

  @override
  State<RaqeebApp> createState() => _RaqeebAppState();
}

class _RaqeebAppState extends State<RaqeebApp> {
  bool isDarkMode = true;

@override
void initState() {
  super.initState();
  loadTheme();
}

// استرجاع المظهر المحفوظ
Future<void> loadTheme() async {
  final prefs = await SharedPreferences.getInstance();

  if (!mounted) return;

  setState(() {
    isDarkMode = prefs.getBool('isDarkMode') ?? true;
  });
}

// تغيير المظهر وحفظ الاختيار
Future<void> changeTheme(bool value) async {
  setState(() {
    isDarkMode = value;
  });

  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('isDarkMode', value);
}

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'رقيب',
      debugShowCheckedModeBanner: false,
      themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: RaqeebColors.background(false),
        colorScheme: ColorScheme.fromSeed(
          seedColor: RaqeebColors.militaryGreen,
          brightness: Brightness.light,
          surface: RaqeebColors.card(false),
        ),
      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: RaqeebColors.background(true),
        colorScheme: ColorScheme.fromSeed(
          seedColor: RaqeebColors.militaryGreen,
          brightness: Brightness.dark,
          surface: RaqeebColors.card(true),
        ),
      ),

      home: MainNavigation(
        isDarkMode: isDarkMode,
        onThemeChanged: changeTheme,
      ),
    );
  }
}

class MainNavigation extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const MainNavigation({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final barColor = RaqeebColors.bottomBar(isDark);

    final pages = <Widget>[
      const HomeScreen(),
      const PlaceholderPage(title: 'السجل'),
      const PlaceholderPage(title: 'التنبيهات'),
      const ProfileScreen(),
      SettingsScreen(
        isDarkMode: isDark,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: IndexedStack(
          index: selectedIndex,
          children: pages,
        ),
        bottomNavigationBar: BottomAppBar(
          color: barColor,
          height: 78,
          padding: EdgeInsets.zero,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.home_outlined, 'الرئيسية', 0),
              _navItem(Icons.history_rounded, 'السجل', 1),

              // زر التنبيهات الأحمر البارز
              Transform.translate(
                offset: const Offset(0, -14),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedIndex = 2;
                    });
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: RaqeebColors.alertRed,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: barColor,
                            width: 4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x33000000),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.notifications_active_rounded,
                          color: Colors.white,
                          size: 27,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'التنبيهات',
                        style: TextStyle(
                          color: RaqeebColors.primaryText(isDark),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _navItem(Icons.person_outline_rounded, 'حسابي', 3),
              _navItem(Icons.settings_outlined, 'الإعدادات', 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index) {
    final isSelected = selectedIndex == index;
    final isDark = widget.isDarkMode;

    return InkWell(
      onTap: () {
        setState(() {
          selectedIndex = index;
        });
      },
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? (isDark
                      ? const Color(0xFF9DB68C)
                      : const Color(0xFF425E3D))
                  : RaqeebColors.secondaryText(isDark),
              size: 24,
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? RaqeebColors.primaryText(isDark)
                    : RaqeebColors.secondaryText(isDark),
                fontSize: 10,
                fontWeight:
                    isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// صفحات مؤقتة للسجل والتنبيهات
class PlaceholderPage extends StatelessWidget {
  final String title;

  const PlaceholderPage({
    super.key,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: RaqeebColors.background(isDark),
      appBar: AppBar(
        title: Text(title),
        centerTitle: true,
        backgroundColor: RaqeebColors.background(isDark),
        foregroundColor: RaqeebColors.primaryText(isDark),
      ),
      body: Center(
        child: Text(
          'سيتم تطوير هذه الصفحة لاحقًا',
          style: TextStyle(
            color: RaqeebColors.secondaryText(isDark),
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
