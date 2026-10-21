
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onThemeChanged;

  const SettingsScreen({
    super.key,
    required this.isDarkMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const militaryGreen = Color(0xFF6F8862);
  static const alertRed = Color(0xFFB83F45);

  String selectedLanguage = 'العربية';
  bool _isSigningOut = false;

  // Sign out using Firebase Authentication
  Future<void> _logout() async {
    if (_isSigningOut) return;

    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            title: const Text('تسجيل الخروج'),
            content: const Text(
              'هل أنت متأكد من رغبتك في تسجيل الخروج؟',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('إلغاء'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                child: const Text(
                  'تسجيل الخروج',
                  style: TextStyle(color: alertRed),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (!mounted || shouldLogout != true) return;

    setState(() {
      _isSigningOut = true;
    });

    try {
      await FirebaseAuth.instance.signOut();

      // main.dart listens to authStateChanges()
      // and automatically returns to LoginScreen.

    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تعذر تسجيل الخروج، يرجى المحاولة مرة أخرى',
          ),
          backgroundColor: alertRed,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;

    final background = isDark
        ? const Color(0xFF111A1D)
        : const Color(0xFFF5F6F1);

    final cardColor = isDark
        ? const Color(0xFF1C2A2D)
        : Colors.white;

    final primaryText = isDark
        ? const Color(0xFFF1F5ED)
        : const Color(0xFF1D3027);

    final secondaryText = isDark
        ? const Color(0xFFAAB8AA)
        : const Color(0xFF647568);

    final borderColor = isDark
        ? const Color(0xFF34443D)
        : const Color(0xFFDCE4D9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(
            'الإعدادات',
            style: TextStyle(
              color: primaryText,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: background,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.tune_rounded,
                    color: militaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'التفضيلات',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Language selection
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.language_rounded,
                      color: militaryGreen,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'لغة التطبيق',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: selectedLanguage,
                      dropdownColor: cardColor,
                      underline: const SizedBox(),
                      style: TextStyle(color: primaryText),
                      items: const [
                        DropdownMenuItem(
                          value: 'العربية',
                          child: Text('العربية'),
                        ),
                        DropdownMenuItem(
                          value: 'English',
                          child: Text('English'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            selectedLanguage = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Theme selection
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: militaryGreen,
                      size: 25,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'مظهر التطبيق',
                        style: TextStyle(
                          color: primaryText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    DropdownButton<bool>(
                      value: isDark,
                      dropdownColor: cardColor,
                      underline: const SizedBox(),
                      style: TextStyle(color: primaryText),
                      items: const [
                        DropdownMenuItem(
                          value: true,
                          child: Text('داكن'),
                        ),
                        DropdownMenuItem(
                          value: false,
                          child: Text('فاتح'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          widget.onThemeChanged(value);
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 34),

              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: militaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'حول التطبيق',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/images/raqeeb_logo.png',
                      height: 100,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'رقيب',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'نظام المراقبة الذكي',
                      style: TextStyle(
                        color: militaryGreen,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Divider(color: borderColor),
                    const SizedBox(height: 14),
                    Text(
                      'نظام ذكي لمساعدة ضباط الشرطة في اكتشاف '
                      'التهديدات والتنبيه إليها باستخدام تقنيات '
                      'الذكاء الاصطناعي.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 13,
                        height: 1.8,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 34),

              // Account section
              Row(
                children: [
                  const Icon(
                    Icons.account_circle_outlined,
                    color: militaryGreen,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الحساب',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Firebase Logout button
              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: _isSigningOut ? null : _logout,
                  icon: _isSigningOut
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            color: alertRed,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.logout_rounded,
                          color: alertRed,
                        ),
                  label: Text(
                    _isSigningOut
                        ? 'جارٍ تسجيل الخروج...'
                        : 'تسجيل الخروج',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: alertRed,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: cardColor,
                    side: BorderSide(
                      color: borderColor,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
