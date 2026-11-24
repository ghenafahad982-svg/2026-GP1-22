import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../raqeeb_ui.dart';
import 'incident_video_player_page.dart';
import 'incident_widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _baseUrl = 'https://raqeebserver.onrender.com';
  late Future<List<Map<String, dynamic>>> _history;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  void _refresh() {
setState(() {
  _history = _loadHistory();
});  }

  Future<String> _token() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('not_signed_in');
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) throw StateError('missing_token');
    return token;
  }

  Future<List<Map<String, dynamic>>> _loadHistory() async {
    final token = await _token();
    final response = await http.get(
      Uri.parse('$_baseUrl/incidents'),
      headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
    ).timeout(const Duration(seconds: 90));
    if (response.statusCode != 200) {
      throw StateError('server_error_${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true || decoded['incidents'] is! List) {
      throw const FormatException('Invalid incidents response');
    }
    return (decoded['incidents'] as List)
        .whereType<Map<String, dynamic>>()
        .where((incident) =>
            incident['status'] == 'confirmed' &&
            incident['readAt'] != null)
        .toList();
  }

  String _threatName(BuildContext context, Object? value) {
    switch ((value ?? '').toString().toLowerCase()) {
      case 'knife':
        return tr(context, 'اكتشاف سكين', 'Knife detected');
      case 'gun':
      case 'handgun':
      case 'pistol':
        return tr(context, 'اكتشاف سلاح ناري', 'Firearm detected');
      case 'weapon':
        return tr(context, 'اكتشاف سلاح', 'Weapon detected');
      default:
        return tr(context, 'حادث أمني', 'Security incident');
    }
  }

  String _formatTime(Object? value) {
    if (value is! String || value.isEmpty) return '—';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year}-${two(date.month)}-${two(date.day)} '
        '${two(date.hour)}:${two(date.minute)}';
  }

  String _confidence(Object? value) {
    if (value is! num || value < 0 || value > 1) return '—';
    return '${(value * 100).toStringAsFixed(0)}%';
  }

  Future<void> _openVideo(String eventId) async {
    try {
      final token = await _token();
      final response = await http.get(
        Uri.parse('$_baseUrl/incidents/${Uri.encodeComponent(eventId)}/video-url'),
        headers: {'Authorization': 'Bearer $token', 'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) throw StateError('video_unavailable');
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['success'] != true ||
          decoded['signedUrl'] is! String ||
          (decoded['signedUrl'] as String).isEmpty) {
        throw const FormatException('Invalid video response');
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => IncidentVideoPlayerPage(
            videoUrl: decoded['signedUrl'] as String,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context,
          'تعذر فتح تسجيل الحادث', 'Could not open incident recording'))),
      );
    }
  }

  Widget _card(Map<String, dynamic> incident) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventId = incident['eventId']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: RaqeebColors.card(dark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: RaqeebColors.border(dark)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.verified_outlined, color: RaqeebColors.accent(dark)),
              const SizedBox(width: 8),
              Expanded(child: Text(
                _threatName(context, incident['detectionType']),
                style: TextStyle(fontWeight: FontWeight.bold,
                    fontSize: 17, color: RaqeebColors.text(dark)),
              )),
              Text(tr(context, 'مؤكد', 'Confirmed'),
                  style: TextStyle(color: RaqeebColors.accent(dark))),
            ]),
            const SizedBox(height: 12),
            Text('${tr(context, 'الجهاز', 'Device')}: ${incident['deviceId'] ?? '—'}'),
            const SizedBox(height: 5),
            Text('${tr(context, 'وقت الاكتشاف', 'Detected at')}: '
                '${_formatTime(incident['createdAt'])}'),
            const SizedBox(height: 5),
            Text('${tr(context, 'وقت الاطلاع', 'Opened at')}: '
                '${_formatTime(incident['readAt'])}'),
            const SizedBox(height: 5),
            Text('${tr(context, 'نسبة الثقة', 'Confidence')}: '
                '${_confidence(incident['confidence'])}'),
            if (incident['videoAvailable'] == true && eventId.isNotEmpty) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openVideo(eventId),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(tr(context, 'مشاهدة التسجيل', 'View Recording')),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      appBar: AppBar(
        centerTitle: true,
        title: Text(tr(context, 'سجل الحوادث', 'Incident History')),
        actions: [
          IconButton(
            tooltip: tr(context, 'تحديث', 'Refresh'),
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _history,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(tr(context, 'تعذر تحميل سجل الحوادث',
                    'Could not load incident history')),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh),
                  label: Text(tr(context, 'إعادة المحاولة', 'Retry')),
                ),
              ]),
            ));
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: EmptyIncidents(
                icon: Icons.history_rounded,
                title: tr(context, 'السجل فارغ', 'History is empty'),
                subtitle: tr(context,
                    'ستظهر الحوادث هنا بعد فتح تفاصيلها من التنبيهات.',
                    'Incidents will appear here after you open their details from Alerts.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              _refresh();
              await _history;
            },
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              children: [
                Text(tr(context, 'الحوادث المؤكدة', 'Confirmed incidents'),
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                        color: RaqeebColors.text(dark))),
                const SizedBox(height: 14),
                ...items.map(_card),
              ],
            ),
          );
        },
      ),
    );
  }
}
