import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../raqeeb_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.themePreference,
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
  final bool isDarkMode;
  final String themePreference;
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
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isSigningOut = false;

  Future<void> _logout() async {
    if (_isSigningOut) return;
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'تسجيل الخروج', 'Sign Out')),
        content: Text(tr(context,
            'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            'Are you sure you want to sign out?')),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false),
              child: Text(tr(context, 'إلغاء', 'Cancel'))),
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(tr(context, 'تسجيل الخروج', 'Sign Out'))),
        ],
      ),
    );
    if (!mounted || shouldLogout != true) return;
    setState(() => _isSigningOut = true);
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'تعذر تسجيل الخروج، يرجى المحاولة مرة أخرى',
            'Could not sign out. Please try again')),
        backgroundColor: RaqeebColors.lightDanger,
      ));
      }
    } finally {
      if (mounted) setState(() => _isSigningOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.isDarkMode;
    final text = RaqeebColors.text(dark);
    final secondary = RaqeebColors.secondary(dark);
    final accent = RaqeebColors.accent(dark);
    final card = RaqeebColors.card(dark);
    final border = RaqeebColors.border(dark);

    Widget heading(IconData icon, String label) => Row(children: [
      Icon(icon, color: accent),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(color: text, fontSize: 18,
          fontWeight: FontWeight.bold)),
    ]);

    Widget panel(Widget child) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border)),
      child: child,
    );

    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      appBar: AppBar(title: Text(tr(context, 'الإعدادات', 'Settings')), centerTitle: true),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          heading(Icons.tune_rounded, tr(context, 'التفضيلات', 'Preferences')),
          const SizedBox(height: 16),
          panel(Row(children: [
            Icon(Icons.language_rounded, color: accent),
            const SizedBox(width: 14),
            Expanded(child: Text(tr(context, 'لغة التطبيق', 'App Language'),
                style: TextStyle(color: text, fontSize: 15,
                    fontWeight: FontWeight.w600))),
            DropdownButton<String>(
              value: widget.languageCode,
              dropdownColor: card, underline: const SizedBox.shrink(),
              style: TextStyle(color: text),
              items: const [
                DropdownMenuItem(value: 'ar', child: Text('العربية')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (value) { if (value != null) widget.onLanguageChanged(value); },
            ),
          ])),
          const SizedBox(height: 14),
          panel(Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Icon(widget.isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
                  color: accent, size: 25),
              const SizedBox(width: 14),
              Expanded(child: Text(tr(context, 'مظهر التطبيق', 'Appearance'),
                  style: TextStyle(color: text, fontSize: 15,
                      fontWeight: FontWeight.w600))),
              DropdownButton<String>(
                value: widget.themePreference,
                dropdownColor: card, underline: const SizedBox.shrink(),
                style: TextStyle(color: text),
                items: [
                  DropdownMenuItem(value: 'automatic',
                      child: Text(tr(context, 'تلقائي', 'Automatic'))),
                  DropdownMenuItem(value: 'light',
                      child: Text(tr(context, 'فاتح', 'Light'))),
                  DropdownMenuItem(value: 'dark',
                      child: Text(tr(context, 'داكن', 'Dark'))),
                ],
                onChanged: (value) { if (value != null) widget.onThemeChanged(value); },
              ),
            ]),
            const SizedBox(height: 6),
            Text(tr(context,
                'التلقائي: حسب الشروق والغروب اليومي في موقعك أو المدينة المختارة.',
                'Automatic: follows daily sunrise and sunset for your location or selected city.'),
                style: TextStyle(color: secondary, fontSize: 12)),
            if (widget.themePreference == 'automatic') ...[
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.location_on_outlined, color: accent),
                const SizedBox(width: 10),
                Expanded(child: Text(tr(context, 'مصدر الموقع', 'Location source'),
                    style: TextStyle(color: text))),
                DropdownButton<String>(
                  value: widget.locationMode, dropdownColor: card,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: text),
                  items: [
                    DropdownMenuItem(value: 'device',
                        child: Text(tr(context, 'موقع الجوال', 'Phone GPS'))),
                    DropdownMenuItem(value: 'city',
                        child: Text(tr(context, 'اختيار مدينة', 'Choose city'))),
                  ],
                  onChanged: (value) {
                    if (value != null) widget.onLocationModeChanged(value);
                  },
                ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(
                  widget.locationMode == 'city'
                      ? tr(context, 'المدينة المختارة', 'Selected city')
                      : widget.gpsAvailable
                          ? tr(context, 'تم تحديد الموقع', 'Location acquired')
                          : tr(context,
                              'تعذّر تحديد موقع الجوال؛ نستخدم المدينة الاحتياطية',
                              'GPS unavailable: using fallback city'),
                  style: TextStyle(color: secondary, fontSize: 12),
                )),
                if (widget.locationMode == 'device')
                  IconButton(
                    tooltip: tr(context, 'إعادة محاولة تحديد الموقع', 'Retry GPS'),
                    icon: Icon(Icons.refresh_rounded, color: accent),
                    onPressed: widget.onRetryLocation,
                  ),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: Text(
                  widget.locationMode == 'city'
                      ? tr(context, 'المدينة', 'City')
                      : tr(context, 'المدينة الاحتياطية', 'Fallback city'),
                  style: TextStyle(color: text),
                )),
                DropdownButton<String>(
                  value: widget.fallbackCity, dropdownColor: card,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(color: text),
                  items: [
                    DropdownMenuItem(value: 'riyadh',
                        child: Text(tr(context, 'الرياض', 'Riyadh'))),
                    DropdownMenuItem(value: 'jeddah',
                        child: Text(tr(context, 'جدة', 'Jeddah'))),
                    DropdownMenuItem(value: 'dammam',
                        child: Text(tr(context, 'الدمام', 'Dammam'))),
                    DropdownMenuItem(value: 'makkah',
                        child: Text(tr(context, 'مكة', 'Makkah'))),
                    DropdownMenuItem(value: 'madinah',
                        child: Text(tr(context, 'المدينة المنورة', 'Madinah'))),
                  ],
                  onChanged: (value) {
                    if (value != null) widget.onFallbackCityChanged(value);
                  },
                ),
              ]),
            ],
          ])),
          const SizedBox(height: 34),
          heading(Icons.info_outline_rounded, tr(context, 'حول التطبيق', 'About')),
          const SizedBox(height: 16),
          Container(width: double.infinity, padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border)),
            child: Column(children: [
              Image.asset('assets/images/raqeeb_logo.png', height: 100),
              const SizedBox(height: 18),
              Text(tr(context, 'رقيب', 'Raqeeb'), style: TextStyle(color: text,
                  fontSize: 25, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr(context, 'نظام المراقبة الذكي', 'Intelligent Monitoring System'),
                  style: TextStyle(color: accent, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Divider(color: border),
              const SizedBox(height: 14),
              Text(tr(context,
                  'نظام ذكي لمساعدة ضباط الشرطة في اكتشاف التهديدات والتنبيه إليها باستخدام تقنيات الذكاء الاصطناعي.',
                  'An intelligent system supporting security officers in detecting threats and receiving AI-powered alerts.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: secondary, fontSize: 13, height: 1.8)),
            ]),
          ),
          const SizedBox(height: 34),
          heading(Icons.account_circle_outlined, tr(context, 'الحساب', 'Account')),
          const SizedBox(height: 16),
          SizedBox(height: 58, child: OutlinedButton.icon(
            onPressed: _isSigningOut ? null : _logout,
            icon: _isSigningOut
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(Icons.logout_rounded, color: RaqeebColors.danger(dark)),
            label: Text(_isSigningOut
                ? tr(context, 'جارٍ تسجيل الخروج...', 'Signing out...')
                : tr(context, 'تسجيل الخروج', 'Sign Out'),
                style: TextStyle(color: RaqeebColors.danger(dark),
                    fontSize: 16, fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(backgroundColor: card,
                side: BorderSide(color: border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
          )),
          const SizedBox(height: 24),
        ],
      )),
    );
  }
}
