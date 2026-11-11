import 'package:flutter/material.dart';

/// Shared, high-contrast Raqeeb palette.
class RaqeebColors {
  static const militaryGreen = Color(0xFF6F8862); // brand identity
  static const lightAccent = Color(0xFF344F3C);
  static const darkAccent = Color(0xFFA8D5AE);
  static const lightDanger = Color(0xFFB3261E);
  static const darkDanger = Color(0xFFFFB4AB);
  static const lightWarning = Color(0xFF8A4B00);
  static const darkWarning = Color(0xFFFFD18A);

  static Color background(bool dark) =>
      dark ? const Color(0xFF121815) : const Color(0xFFF8FAF8);
  static Color card(bool dark) =>
      dark ? const Color(0xFF202A24) : const Color(0xFFFFFFFF);
  static Color text(bool dark) =>
      dark ? const Color(0xFFF1F5F1) : const Color(0xFF17211B);
  static Color secondary(bool dark) =>
      dark ? const Color(0xFFD1DDD2) : const Color(0xFF435449);
  static Color accent(bool dark) => dark ? darkAccent : lightAccent;
  static Color danger(bool dark) => dark ? darkDanger : lightDanger;
  static Color warning(bool dark) => dark ? darkWarning : lightWarning;
  static Color border(bool dark) =>
      dark ? const Color(0xFF526356) : const Color(0xFFCAD6CC);
  static Color subtle(bool dark) =>
      dark ? const Color(0xFF2B382F) : const Color(0xFFEDF2EC);
  static Color bottomBar(bool dark) =>
      dark ? const Color(0xFF1B2620) : const Color(0xFFEAF0EA);
}

/// App-wide language preference. No third-party localization package needed.
class RaqeebLanguage extends InheritedWidget {
  const RaqeebLanguage({super.key, required this.isEnglish, required super.child});
  final bool isEnglish;

  static bool english(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<RaqeebLanguage>()?.isEnglish ?? false;

  @override
  bool updateShouldNotify(RaqeebLanguage oldWidget) =>
      isEnglish != oldWidget.isEnglish;
}

String tr(BuildContext context, String arabic, String english) =>
    RaqeebLanguage.english(context) ? english : arabic;

TextDirection raqeebDirection(BuildContext context) =>
    RaqeebLanguage.english(context) ? TextDirection.ltr : TextDirection.rtl;
