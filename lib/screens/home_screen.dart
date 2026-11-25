import 'dart:async';
import 'alerts_screen.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
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
  late Future<List<Map<String, dynamic>>> _recentAlertsFuture;

  void _refreshRecentAlerts() {
    if (!mounted) return;
    setState(() {
      _recentAlertsFuture = _fetchRecentAlerts();
    });
  }

  String _formatIncidentTime(dynamic raw, BuildContext context) {
    if (raw is! String || raw.isEmpty) return '—';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final date = parsed.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final period = date.hour < 12
        ? tr(context, 'ص', 'AM')
        : tr(context, 'م', 'PM');
    return '${two(date.day)}-${two(date.month)}-${date.year} • '
        '$hour:${two(date.minute)} $period';
  }
  static const String statusUrl =
      'https://raqeebserver.onrender.com/officer/device-status';

  @override
  void initState() {
    super.initState();
    _recentAlertsFuture = _fetchRecentAlerts();
    checkDeviceStatus();
    _statusTimer = Timer.periodic(const Duration(seconds: 30), (_) => checkDeviceStatus());
  }

Future<List<Map<String, dynamic>>> _fetchRecentAlerts() async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw Exception('not_signed_in');
  }

  final token = await user.getIdToken();

  if (token == null || token.isEmpty) {
    throw Exception('missing_token');
  }

  final response = await http.get(
    Uri.parse('https://raqeebserver.onrender.com/incidents'),
    headers: {
      'Authorization': 'Bearer $token',
      'Accept': 'application/json',
    },
  ).timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw Exception('server_error_${response.statusCode}');
  }

  final decoded = jsonDecode(response.body);

  if (decoded is! Map<String, dynamic> ||
      decoded['success'] != true ||
      decoded['incidents'] is! List) {
    throw const FormatException('Invalid incidents response');
  }

  final incidents = (decoded['incidents'] as List)
      .whereType<Map<String, dynamic>>()
      .where((incident) {
        final status =
            incident['status']?.toString() ?? 'confirmed';

        return status == 'confirmed' &&
            incident['readAt'] == null;
      })
      .toList();

  incidents.sort((a, b) {
    final first = a['createdAt']?.toString() ?? '';
    final second = b['createdAt']?.toString() ?? '';
    return second.compareTo(first);
  });

  return incidents.take(2).toList();
}

  bool _checkingDeviceStatus = false;

  Future<void> checkDeviceStatus() async {
    if (_checkingDeviceStatus) return;
    _checkingDeviceStatus = true;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw StateError('not_signed_in');
      final token = await user.getIdToken();
      if (token == null || token.isEmpty) throw StateError('missing_token');
      final response = await http.get(
        Uri.parse(statusUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) throw StateError('status_error');
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> ||
          data['success'] != true || data['online'] is! bool) {
        throw const FormatException('Invalid device status response');
      }
      final nextStatus = data['online'] == true ? 'online' : 'offline';
      if (mounted && deviceStatus != nextStatus) {
        setState(() => deviceStatus = nextStatus);
      }
    } catch (_) {
      if (mounted && deviceStatus != 'error') {
        setState(() => deviceStatus = 'error');
      }
    } finally {
      _checkingDeviceStatus = false;
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
              child: Image.asset('assets/images/raqeeb_logo_icon.png', fit: BoxFit.contain)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(tr(context, 'رقيب', 'Raqeeb'),
                  style: TextStyle(color: text, fontSize: 24, fontWeight: FontWeight.bold)),
              Text(tr(context, 'نظام المراقبة الذكي', 'Intelligent Monitoring System'),
                  style: TextStyle(color: secondary, fontSize: 12)),
            ])),
            
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
            IconButton(
              tooltip: tr(context, 'تحديث التنبيهات', 'Refresh alerts'),
              onPressed: _refreshRecentAlerts,
              icon: Icon(Icons.refresh_rounded, color: accent, size: 25),
            ),
          ]),
          const SizedBox(height: 14),

FutureBuilder<List<Map<String, dynamic>>>(
  future: _recentAlertsFuture,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Text(
        tr(context, 'تعذر تحميل التنبيهات', 'Could not load alerts'),
        style: TextStyle(color: RaqeebColors.secondary(dark)),
      );
    }

    final latest = snapshot.data ?? [];

    if (latest.isEmpty) {
      return EmptyIncidents(
        icon: Icons.verified_user_outlined,
        title: tr(context, 'لا توجد تنبيهات حاليًا', 'No alerts at the moment'),
        subtitle: tr(
          context,
          'ستظهر التنبيهات هنا عند اكتشاف تهديد',
          'Alerts will appear here when a threat is detected',
        ),
      );
    }

    return Column(
      children: latest.map((incident) {
        final type = incident['detectionType']?.toString() ?? 'weapon';
        final createdAt = incident['createdAt']?.toString() ?? '';
        final eventId = incident['eventId']?.toString() ?? '';

        return Card(
          child: ListTile(
            leading: Icon(
              Icons.warning_amber_rounded,
              color: RaqeebColors.danger(dark),
            ),
            title: Text(
              type == 'knife'
                  ? tr(context, 'اكتشاف سكين', 'Knife detected')
                  : type == 'pistol' || type == 'gun'
                      ? tr(context, 'اكتشاف سلاح ناري', 'Firearm detected')
                      : tr(context, 'اكتشاف سلاح', 'Weapon detected'),
            ),
            subtitle: Text(_formatIncidentTime(createdAt, context)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              if (eventId.isNotEmpty) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const AlertsScreen(),
                  ),
                ).then((_) => _refreshRecentAlerts());
              }
            },
          ),
        );
      }).toList(),
    );
  },
),

        ],
      )),
    );
  }
}
