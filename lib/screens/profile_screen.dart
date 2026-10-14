
import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const militaryGreen = Color(0xFF6F8862);

  @override
  Widget build(BuildContext context) {
    // معرفة المظهر المختار من الإعدادات
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

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

    final iconBackground = isDark
        ? const Color(0xFF2B3B35)
        : const Color(0xFFEAF0E7);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        appBar: AppBar(
          title: Text(
            'الملف الشخصي',
            style: TextStyle(
              color: primaryText,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          backgroundColor: background,
          elevation: 0,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 24,
            ),
            children: [
              // Profile header
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: militaryGreen,
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 56,
                    color: militaryGreen,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'حساب الضابط',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: primaryText,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'معلومات الحساب والجهاز المرتبط',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 35),

              // Personal information heading
              Row(
                children: [
                  const Icon(
                    Icons.badge_outlined,
                    color: militaryGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'المعلومات الشخصية',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _profileItem(
                Icons.person_outline_rounded,
                'اسم الضابط',
                'لم تتم إضافة البيانات',
                cardColor,
                primaryText,
                secondaryText,
                borderColor,
                iconBackground,
              ),

              _profileItem(
                Icons.badge_outlined,
                'الرقم الوظيفي',
                'لم تتم إضافة البيانات',
                cardColor,
                primaryText,
                secondaryText,
                borderColor,
                iconBackground,
              ),

              _profileItem(
                Icons.email_outlined,
                'البريد الإلكتروني',
                'لم تتم إضافة البيانات',
                cardColor,
                primaryText,
                secondaryText,
                borderColor,
                iconBackground,
              ),

              const SizedBox(height: 22),

              // Connected device heading
              Row(
                children: [
                  const Icon(
                    Icons.videocam_outlined,
                    color: militaryGreen,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'الجهاز المرتبط',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              _profileItem(
                Icons.videocam_outlined,
                'كاميرا رقيب',
                'لا يوجد جهاز مرتبط',
                cardColor,
                primaryText,
                secondaryText,
                borderColor,
                iconBackground,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _profileItem(
    IconData icon,
    String title,
    String value,
    Color cardColor,
    Color primaryText,
    Color secondaryText,
    Color borderColor,
    Color iconBackground,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(
        horizontal: 17,
        vertical: 19,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: militaryGreen,
              size: 24,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  value,
                  style: TextStyle(
                    color: primaryText,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
