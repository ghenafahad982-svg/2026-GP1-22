
import 'package:flutter/material.dart';
import '../raqeeb_ui.dart';

class EmptyIncidents extends StatelessWidget {
  const EmptyIncidents({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dark =
        Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 42,
        horizontal: 22,
      ),
      decoration: BoxDecoration(
        color: RaqeebColors.card(dark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: RaqeebColors.border(dark),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 42,
            color: RaqeebColors.accent(dark),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RaqeebColors.text(dark),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: RaqeebColors.secondary(dark),
            ),
          ),
        ],
      ),
    );
  }
}
