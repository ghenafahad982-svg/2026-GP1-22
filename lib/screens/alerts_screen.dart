
import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../incident_store.dart';
import '../raqeeb_ui.dart';
import 'incident_widgets.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key});

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const String incidentsUrl =
      'https://raqeebserver.onrender.com/incidents';

  late Future<List<Map<String, dynamic>>> _serverIncidents;

  @override
  void initState() {
    super.initState();
    _refreshIncidents();
  }

  void _refreshIncidents() {
    setState(() {
      _serverIncidents = _fetchIncidents();
    });
  }

  Future<List<Map<String, dynamic>>> _fetchIncidents() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('not_signed_in');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('missing_token');
    }

    final response = await http.get(
      Uri.parse(incidentsUrl),
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode == 401) {
      throw Exception('unauthorized');
    }

    if (response.statusCode == 403) {
      throw Exception('forbidden');
    }

    if (response.statusCode != 200) {
      throw Exception('server_error_${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['incidents'] is! List) {
      throw const FormatException('Invalid incidents response');
    }

    return (decoded['incidents'] as List)
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  String _errorMessage(BuildContext context, Object error) {
    final message = error.toString();

    if (message.contains('not_signed_in') ||
        message.contains('missing_token') ||
        message.contains('unauthorized')) {
      return tr(
        context,
        'تعذر التحقق من تسجيل الدخول. سجّلي الدخول مرة أخرى.',
        'Authentication failed. Please sign in again.',
      );
    }

    if (message.contains('forbidden')) {
      return tr(
        context,
        'هذا الحساب غير مخوّل بعرض الحوادث.',
        'This account is not authorized to view incidents.',
      );
    }

    return tr(
      context,
      'تعذر جلب الحوادث من السيرفر. تحققي من الاتصال ثم أعيدي المحاولة.',
      'Could not load incidents. Check your connection and retry.',
    );
  }

  String _threatName(BuildContext context, String type) {
    switch (type.toLowerCase()) {
      case 'knife':
        return tr(context, 'اكتشاف سكين', 'Knife detected');
      case 'gun':
      case 'handgun':
      case 'pistol':
        return tr(context, 'اكتشاف سلاح ناري', 'Firearm detected');
      case 'weapon':
        return tr(context, 'اكتشاف سلاح', 'Weapon detected');
      case 'test':
        return tr(context, 'حادث اختباري', 'Test incident');
      default:
        return type.isEmpty
            ? tr(context, 'حادث غير محدد', 'Unknown incident')
            : type;
    }
  }

  String _incidentTime(dynamic raw) {
    if (raw is! String || raw.isEmpty) return '—';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  Widget _serverIncidentCard(
    BuildContext context,
    Map<String, dynamic> incident,
    bool dark,
  ) {
    final type = incident['detectionType']?.toString() ?? '';
    final status = incident['status']?.toString() ?? 'pending';
    final deviceId = incident['deviceId']?.toString() ?? '—';
    final confidence = incident['confidence'];

    String confidenceText = '—';
    if (confidence is num) {
      confidenceText =
          '${(confidence * 100).clamp(0, 100).toStringAsFixed(0)}%';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: RaqeebColors.background(dark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: RaqeebColors.secondary(dark).withValues(alpha: 0.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _threatName(context, type),
                    style: TextStyle(
                      color: RaqeebColors.text(dark),
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                ),
                Text(
                  status == 'pending'
                      ? tr(context, 'قيد المراجعة', 'Pending')
                      : status == 'confirmed'
                          ? tr(context, 'تم التأكيد', 'Confirmed')
                          : status == 'dismissed'
                              ? tr(context, 'مستبعد', 'Dismissed')
                              : status,
                  style: TextStyle(
                    color: RaqeebColors.secondary(dark),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${tr(context, 'الجهاز', 'Device')}: $deviceId',
              style: TextStyle(color: RaqeebColors.text(dark)),
            ),
            const SizedBox(height: 5),
            Text(
              '${tr(context, 'التوقيت', 'Time')}: '
              '${_incidentTime(incident['createdAt'])}',
              style: TextStyle(color: RaqeebColors.text(dark)),
            ),
            const SizedBox(height: 5),
            Text(
              '${tr(context, 'نسبة الثقة', 'Confidence')}: '
              '$confidenceText',
              style: TextStyle(color: RaqeebColors.text(dark)),
            ),
            const SizedBox(height: 8),
            Text(
              incident['videoAvailable'] == true
                  ? tr(
                      context,
                      'التسجيل محفوظ — ربط المشاهدة قيد التجهيز',
                      'Recording saved — playback integration pending',
                    )
                  : tr(
                      context,
                      'لا يوجد تسجيل متاح',
                      'No recording available',
                    ),
              style: TextStyle(
                color: RaqeebColors.secondary(dark),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final store = IncidentStore.instance;

    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      appBar: AppBar(
        centerTitle: true,
        title: Text(tr(context, 'التنبيهات', 'Alerts')),
        actions: [
          IconButton(
            tooltip: tr(context, 'تحديث', 'Refresh'),
            onPressed: _refreshIncidents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: store,
        builder: (context, _) {
          final demoIncidents = store.newItems;

          return ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            children: [
              Text(
                tr(context, 'التنبيهات من السيرفر', 'Server alerts'),
                style: TextStyle(
                  color: RaqeebColors.text(dark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _serverIncidents,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Column(
                      children: [
                        Text(
                          _errorMessage(context, snapshot.error!),
                          style: TextStyle(
                            color: RaqeebColors.text(dark),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton.icon(
                          onPressed: _refreshIncidents,
                          icon: const Icon(Icons.refresh),
                          label: Text(
                            tr(context, 'إعادة المحاولة', 'Retry'),
                          ),
                        ),
                      ],
                    );
                  }

                  final incidents = snapshot.data ?? [];

                  // Only pending incidents belong in the alerts screen.
                  final pending = incidents.where((incident) {
                    final status =
                        incident['status']?.toString() ?? 'pending';
                    return status == 'pending';
                  }).toList();

                  if (pending.isEmpty) {
                    return EmptyIncidents(
                      icon: Icons.notifications_none_rounded,
                      title: tr(
                        context,
                        'لا توجد حوادث جديدة على السيرفر',
                        'No new server incidents',
                      ),
                      subtitle: tr(
                        context,
                        'تم الاتصال بالسيرفر، لكن لا توجد حوادث بانتظار المراجعة.',
                        'Connected to the server, but no incidents are awaiting review.',
                      ),
                    );
                  }

                  return Column(
                    children: pending
                        .map(
                          (incident) => _serverIncidentCard(
                            context,
                            incident,
                            dark,
                          ),
                        )
                        .toList(),
                  );
                },
              ),

              const SizedBox(height: 24),

              DemoBanner(
                onAdd: () => store.addDemoIncident(),
                onClear: store.items.any((item) => item.isDemo)
                    ? () => _confirmClear(context)
                    : null,
              ),
              const SizedBox(height: 22),
              Text(
                tr(
                  context,
                  'التنبيهات المحلية',
                  'Local alerts',
                ),
                style: TextStyle(
                  color: RaqeebColors.text(dark),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                tr(
                  context,
                  'تنبيهات محفوظة على هذا الجهاز لأغراض الاختبار.',
                  'Alerts stored on this device for testing.',
                ),
                style: TextStyle(
                  color: RaqeebColors.secondary(dark),
                ),
              ),
              const SizedBox(height: 18),
              if (demoIncidents.isEmpty)
                EmptyIncidents(
                  icon: Icons.notifications_none_rounded,
                  title: tr(
                    context,
                    'لا توجد تنبيهات محلية',
                    'No local alerts',
                  ),
                  subtitle: tr(
                    context,
                    'يمكنك إضافة تنبيه تجريبي من الأعلى.',
                    'You can add a demo alert above.',
                  ),
                )
              else
                ...demoIncidents.map(
                  (incident) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: IncidentCard(incident: incident),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          tr(context, 'حذف البيانات التجريبية؟', 'Clear demo data?'),
        ),
        content: Text(
          tr(
            context,
            'سيتم حذف التنبيهات التجريبية فقط من هذا الجهاز.',
            'Only local demo alerts will be removed from this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, 'إلغاء', 'Cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, 'حذف التجريبي', 'Clear demo')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await IncidentStore.instance.clearDemoIncidents();
    }
  }
}
