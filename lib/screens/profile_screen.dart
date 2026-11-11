import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../raqeeb_ui.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _saving = false;

  Future<void> _editName() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final controller = TextEditingController(text: user.displayName ?? '');
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'اسم الضابط', 'Officer name')),
        content: TextField(
          controller: controller,
          maxLength: 60,
          autofocus: true,
          decoration: InputDecoration(
              hintText: tr(context, 'اكتب اسم الضابط', 'Enter officer name')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr(context, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) Navigator.pop(dialogContext, name);
            },
            child: Text(tr(context, 'حفظ', 'Save')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (updated == null || !mounted) return;
    setState(() => _saving = true);
    try {
      await user.updateDisplayName(updated);
      await user.reload();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'تم حفظ اسم العرض', 'Display name saved')),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tr(context, 'تعذر حفظ الاسم', 'Could not save the name')),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    final displayName = user?.displayName?.trim();
    final shownName = displayName == null || displayName.isEmpty
        ? tr(context, 'لم تتم إضافة البيانات', 'No information added')
        : displayName;
    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      appBar: AppBar(title: Text(tr(context, 'الملف الشخصي', 'Profile')),
          centerTitle: true),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          Center(child: Container(width: 100, height: 100,
            decoration: BoxDecoration(color: RaqeebColors.subtle(dark),
                shape: BoxShape.circle, border: Border.all(color: accent, width: 2)),
            child: Icon(Icons.person_rounded, size: 56, color: accent))),
          const SizedBox(height: 18),
          Text(tr(context, 'حساب الضابط', 'Officer Account'),
              textAlign: TextAlign.center,
              style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text(tr(context, 'معلومات الحساب والجهاز المرتبط',
                  'Account details and linked device'),
              textAlign: TextAlign.center,
              style: TextStyle(color: secondary, fontSize: 13)),
          const SizedBox(height: 35),
          _heading(context, Icons.badge_outlined,
              tr(context, 'المعلومات الشخصية', 'Personal Information'), accent, text),
          const SizedBox(height: 16),
          _item(Icons.person_outline_rounded, tr(context, 'اسم الضابط', 'Officer Name'),
              shownName,
              dark, card, border, accent, text, secondary),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: _saving ? null : _editName,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(tr(context, 'تعديل اسم العرض', 'Edit display name')),
            ),
          ),
          _item(Icons.badge_outlined, tr(context, 'الرقم الوظيفي', 'Employee ID'),
              tr(context, 'لم تتم إضافة البيانات', 'No information added'),
              dark, card, border, accent, text, secondary),
          _item(Icons.email_outlined, tr(context, 'البريد الإلكتروني', 'Email Address'),
              user?.email ?? tr(context, 'لم تتم إضافة البيانات', 'No information added'),
              dark, card, border, accent, text, secondary),
          const SizedBox(height: 22),
          _heading(context, Icons.videocam_outlined,
              tr(context, 'الجهاز المرتبط', 'Linked Device'), accent, text),
          const SizedBox(height: 16),
          _item(Icons.videocam_outlined, tr(context, 'كاميرا رقيب', 'Raqeeb Camera'),
              tr(context, 'لا يوجد جهاز مرتبط', 'No linked device'),
              dark, card, border, accent, text, secondary),
        ],
      )),
    );
  }

  Widget _heading(BuildContext context, IconData icon, String title,
      Color accent, Color text) => Row(children: [
    Icon(icon, color: accent, size: 22),
    const SizedBox(width: 10),
    Text(title, style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold)),
  ]);

  Widget _item(IconData icon, String title, String value, bool dark,
      Color card, Color border, Color accent, Color text, Color secondary) =>
      Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 19),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border)),
        child: Row(children: [
          Container(width: 45, height: 45,
            decoration: BoxDecoration(color: RaqeebColors.subtle(dark),
                borderRadius: BorderRadius.circular(13)),
            child: Icon(icon, color: accent, size: 24)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: secondary, fontSize: 12)),
            const SizedBox(height: 6),
            Text(value, style: TextStyle(color: text, fontSize: 15,
                fontWeight: FontWeight.w600)),
          ])),
        ]),
      );
}
