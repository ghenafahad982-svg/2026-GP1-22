import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import '../incident_store.dart';
import 'incident_widgets.dart';
import '../raqeeb_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String deviceStatus = 'checking';
  Timer? _statusTimer;
  // Keep the original Firebase emulator endpoint for local testing.
  static const String statusUrl =
      'http://192.168.100.135:5001/raqeeb-gp1/us-central1/getDeviceStatus';

  @override
  void initState() {
    super.initState();
    checkDeviceStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 5), (_) => checkDeviceStatus());
  }

  Future<void> checkDeviceStatus() async {
    try {
      final response = await http.get(Uri.parse(statusUrl))
          .timeout(const Duration(seconds: 4));
      if (!mounted) return;
      setState(() {
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          deviceStatus = data['status'] == 'online' ? 'online' : 'offline';
        } else {
          deviceStatus = 'error';
        }
      });
    } catch (_) {
      if (mounted) setState(() => deviceStatus = 'error');
    }
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final text = RaqeebColors.text(dark);
    final secondary = RaqeebColors.secondary(dark);
    final accent = RaqeebColors.accent(dark);
    final card = RaqeebColors.card(dark);
    final border = RaqeebColors.border(dark);
    final checking = deviceStatus == 'checking';
    final error = deviceStatus == 'error';
    final online = deviceStatus == 'online';
    final statusLabel = checking
        ? tr(context, 'جاري التحقق', 'Checking')
        : error
            ? tr(context, 'تعذر التحقق', 'Unavailable')
            : online
                ? tr(context, 'متصل', 'Online')
                : tr(context, 'غير متصل', 'Offline');
    final statusColor = checking || error
        ? RaqeebColors.warning(dark)
        : online ? accent : RaqeebColors.danger(dark);
    final statusMessage = checking
        ? tr(context, 'جاري التحقق من اتصال الجهاز', 'Checking device connectivity')
        : error
            ? tr(context, 'تعذر الوصول إلى السيرفر', 'Could not reach the server')
            : online
                ? tr(context, 'جهاز رقيب متصل بالسيرفر', 'Raqeeb device is connected to the server')
                : tr(context, 'جهاز رقيب غير متصل بالسيرفر', 'Raqeeb device is disconnected from the server');

    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 20),
        children: [
          Row(children: [
            Container(width: 56, height: 56, padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
              child: Image.asset('assets/images/raqeeb_logo.png', fit: BoxFit.contain)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, 'رقيب', 'Raqeeb'),
                  style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(tr(context, 'نظام المراقبة الذكي', 'Intelligent Monitoring System'),
                  style: TextStyle(color: secondary, fontSize: 12)),
            ])),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.shield_outlined, color: accent, size: 25)),
          ]),
          const SizedBox(height: 36),
          
StreamBuilder<User?>(
  stream: FirebaseAuth.instance.userChanges(),
  builder: (context, authSnapshot) {
    final user = authSnapshot.data;

    if (user == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('Users')
          .doc(user.uid)
          .snapshots(),
      builder: (context, userSnapshot) {
        final data = userSnapshot.data?.data();
        

        final firestoreName =
            (data?['name'] as String?)?.trim();

        final authName = user.displayName?.trim();

        final name = (firestoreName != null &&
                firestoreName.isNotEmpty)
            ? firestoreName
            : (authName != null && authName.isNotEmpty)
                ? authName
                : null;

        return Text(
          name != null
              ? tr(context, 'مرحبًا بك، $name', 'Welcome, $name')
              : tr(context, 'مرحبًا بك', 'Welcome'),
          style: TextStyle(
            color: text,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        );
      },
    );
  },
),

          const SizedBox(height: 12),
          Text(tr(context, 'لوحة المتابعة', 'Dashboard'),
              style: TextStyle(color: text, fontSize: 25, fontWeight: FontWeight.bold)),
          const SizedBox(height: 7),
          Text(tr(context, 'متابعة حالة الجهاز والتنبيهات', 'Monitor device status and alerts'),
              style: TextStyle(color: secondary, fontSize: 13)),
          const SizedBox(height: 26),
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(22),
                border: Border.all(color: border)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: RaqeebColors.subtle(dark),
                      borderRadius: BorderRadius.circular(15)),
                  child: Icon(Icons.videocam_rounded, color: accent, size: 27)),
                const SizedBox(width: 14),
                Expanded(child: Text(tr(context, 'حالة الجهاز', 'Device Status'),
                    style: TextStyle(color: text, fontSize: 18, fontWeight: FontWeight.bold))),
                Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: RaqeebColors.subtle(dark),
                        borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.circle, color: statusColor, size: 8),
                      const SizedBox(width: 7),
                      Text(statusLabel, style: TextStyle(color: statusColor,
                          fontSize: 12, fontWeight: FontWeight.w600)),
                    ])),
              ]),
              const SizedBox(height: 20),
              Container(padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(color: RaqeebColors.subtle(dark),
                    borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: accent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(statusMessage,
                      style: TextStyle(color: secondary, fontSize: 13))),
                ])),
            ]),
          ),
          const SizedBox(height: 30),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr(context, 'آخر التنبيهات', 'Recent Alerts'),
                style: TextStyle(color: text, fontSize: 19, fontWeight: FontWeight.bold)),
            Icon(Icons.notifications_none_rounded, color: accent, size: 25),
          ]),
          const SizedBox(height: 14),
          AnimatedBuilder(
            animation: IncidentStore.instance,
            builder: (context, _) {
              final latest = IncidentStore.instance.items.take(2).toList();
              if (latest.isEmpty) {
                return EmptyIncidents(
                  icon: Icons.verified_user_outlined,
                  title: tr(context, 'لا توجد تنبيهات حالياً', 'No alerts at the moment'),
                  subtitle: tr(context, 'ستظهر التنبيهات هنا عند اكتشاف تهديد',
                      'Alerts will appear here when a threat is detected'),
                );
              }
              return Column(
                children: latest.map((incident) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: IncidentCard(incident: incident),
                )).toList(),
              );
            },
          ),
        ],
      )),
    );
  }
}
