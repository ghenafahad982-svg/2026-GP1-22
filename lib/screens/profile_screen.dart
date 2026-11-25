import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../raqeeb_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final result = value.toString().trim();
    return result.isEmpty ? null : result;
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = RaqeebColors.text(dark);
    final secondary = RaqeebColors.secondary(dark);
    final accent = RaqeebColors.accent(dark);
    final card = RaqeebColors.card(dark);
    final border = RaqeebColors.border(dark);
    final user = FirebaseAuth.instance.currentUser;
    final missing = tr(context, 'لم تتم إضافة البيانات', 'No information added');

    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      appBar: AppBar(
        title: Text(tr(context, 'الملف الشخصي', 'Profile')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: user == null
              ? null
              : FirebaseFirestore.instance
                  .collection('Users')
                  .doc(user.uid)
                  .snapshots(),
          builder: (context, snapshot) {
            final loading = user != null &&
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
            final failed = snapshot.hasError;
            final profile = snapshot.data?.data() ?? <String, dynamic>{};

            // Match the Home screen: Users/{uid}.name, then Auth displayName.
            final name = _nonEmpty(profile['name']) ??
                _nonEmpty(user?.displayName) ??
                missing;
            final employeeId = _nonEmpty(profile['employeeId']) ??
                _nonEmpty(profile['employeeNumber']) ??
                missing;
            final email = _nonEmpty(profile['email']) ??
                _nonEmpty(user?.email) ??
                missing;
            // Server-side officer/device association uses this exact field.
            final deviceId = _nonEmpty(profile['deviceId']);

            final unavailable = failed
                ? tr(context, 'تعذر تحميل البيانات', 'Could not load information')
                : loading
                    ? tr(context, 'جارٍ التحميل...', 'Loading...')
                    : null;

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                _heading(
                  context,
                  Icons.badge_outlined,
                  tr(context, 'المعلومات الشخصية', 'Personal Information'),
                  accent,
                  text,
                ),
                const SizedBox(height: 16),
                _item(
                  Icons.person_outline_rounded,
                  tr(context, 'اسم الضابط', 'Officer Name'),
                  unavailable ?? name,
                  dark, card, border, accent, text, secondary,
                ),
                _item(
                  Icons.badge_outlined,
                  tr(context, 'الرقم الوظيفي', 'Employee ID'),
                  unavailable ?? employeeId,
                  dark, card, border, accent, text, secondary,
                ),
                _item(
                  Icons.email_outlined,
                  tr(context, 'البريد الإلكتروني', 'Email Address'),
                  // Authentication email remains usable if Firestore is unavailable.
                  _nonEmpty(user?.email) ?? (unavailable ?? email),
                  dark, card, border, accent, text, secondary,
                ),
                const SizedBox(height: 22),
                _heading(
                  context,
                  Icons.videocam_outlined,
                  tr(context, 'الجهاز المرتبط', 'Linked Device'),
                  accent,
                  text,
                ),
                const SizedBox(height: 16),
                _item(
                  Icons.videocam_outlined,
                  tr(context, 'كاميرا رقيب', 'Raqeeb Camera'),
                  unavailable ??
                      deviceId ??
                      tr(context, 'لا يوجد جهاز مرتبط', 'No linked device'),
                  dark, card, border, accent, text, secondary,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _heading(BuildContext context, IconData icon, String title,
          Color accent, Color text) =>
      Row(children: [
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 10),
        Text(title,
            style: TextStyle(
                color: text, fontSize: 18, fontWeight: FontWeight.bold)),
      ]);

  Widget _item(IconData icon, String title, String value, bool dark,
          Color card, Color border, Color accent, Color text, Color secondary) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 19),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: RaqeebColors.subtle(dark),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: accent, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: secondary, fontSize: 12)),
                const SizedBox(height: 6),
                Text(value,
                    style: TextStyle(
                        color: text,
                        fontSize: 15,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ]),
      );
}
