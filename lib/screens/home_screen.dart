
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const militaryGreen = Color(0xFF6F8862);

  @override
  Widget build(BuildContext context) {
    // معرفة المظهر المختار من الإعدادات
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final background = isDark
        ? const Color(0xFF111A1D)
        : const Color(0xFFF5F6F1);

    final cardColor = isDark
        ? const Color(0xFF1C2A2D)
        : Colors.white;

    final primaryText = isDark
        ? const Color(0xFFF2F6F5)
        : const Color(0xFF1D3027);

    final secondaryText = isDark
        ? const Color(0xFFAAB7B0)
        : const Color(0xFF647568);

    final innerCardColor = isDark
        ? const Color(0xFF101F1C)
        : const Color(0xFFF0F3EC);

    final borderColor = isDark
        ? militaryGreen.withValues(alpha: 0.35)
        : const Color(0xFFDCE4D9);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 22,
              vertical: 20,
            ),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Image.asset(
                      'assets/images/raqeeb_logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'رقيب',
                          style: TextStyle(
                            color: primaryText,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'نظام المراقبة الذكي',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.shield_outlined,
                      color: militaryGreen,
                      size: 25,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              Text(
                'لوحة المتابعة',
                style: TextStyle(
                  color: primaryText,
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 7),

              Text(
                'متابعة حالة الجهاز والتنبيهات',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 13,
                ),
              ),

              const SizedBox(height: 26),

              // Device status
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: militaryGreen.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.videocam_rounded,
                            color: militaryGreen,
                            size: 27,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Text(
                            'حالة الجهاز',
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF3B3430)
                                : const Color(0xFFF4E8DD),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.circle,
                                color: Color(0xFFC48A66),
                                size: 8,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'غير متصل',
                                style: TextStyle(
                                  color: isDark
                                      ? const Color(0xFFF3E8DE)
                                      : const Color(0xFF80543A),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: innerCardColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline_rounded,
                            color: militaryGreen,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'لم يتم الاتصال بكاميرا رقيب بعد',
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Alerts heading
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'آخر التنبيهات',
                    style: TextStyle(
                      color: primaryText,
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.notifications_none_rounded,
                    color: militaryGreen,
                    size: 25,
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 32,
                  horizontal: 20,
                ),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: militaryGreen,
                      size: 38,
                    ),

                    const SizedBox(height: 14),

                    Text(
                      'لا توجد تنبيهات حالياً',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      'ستظهر التنبيهات هنا عند اكتشاف تهديد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
