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
  final Set<String> _dismissingIds = <String>{};

  @override
  void initState() {
    super.initState();
    _history = _loadHistory();
  }

  Future<void> _refresh() async {
    final next = _loadHistory();
    setState(() => _history = next);
    try {
      await next;
    } catch (_) {
      // The FutureBuilder displays the error and retry action.
    }
  }

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
      headers: {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      },
    ).timeout(const Duration(seconds: 90));

    if (response.statusCode != 200) {
      throw StateError('server_error_${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic> ||
        decoded['success'] != true ||
        decoded['incidents'] is! List) {
      throw const FormatException('Invalid incidents response');
    }

    final items = (decoded['incidents'] as List)
        .whereType<Map<String, dynamic>>()
        .where((incident) =>
            incident['status'] == 'confirmed' && incident['readAt'] != null)
        .toList();

    items.sort((a, b) {
      final aDate = DateTime.tryParse(a['readAt']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['readAt']?.toString() ?? '');
      if (aDate == null && bDate == null) return 0;
      if (aDate == null) return 1;
      if (bDate == null) return -1;
      return bDate.compareTo(aDate);
    });
    return items;
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
      case 'test':
        return tr(context, 'حادث اختباري', 'Test incident');
      default:
        return tr(context, 'حادث أمني', 'Security incident');
    }
  }

  String _formatTime(Object? value) {
    if (value is! String || value.isEmpty) return '—';
    final date = DateTime.tryParse(value)?.toLocal();
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}-${two(date.month)}-${date.year} '
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
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
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

  Future<void> _dismissIncident(String eventId) async {
    if (eventId.isEmpty || _dismissingIds.contains(eventId)) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, 'استبعاد الحادث', 'Dismiss incident')),
        content: Text(tr(
          dialogContext,
          'هل تريد استبعاد هذا الحادث من السجل؟ سيبقى محفوظًا في السيرفر لأغراض المراجعة.',
          'Remove this incident from history? Its record will remain on the server for auditing.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(dialogContext, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB4232B)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(dialogContext, 'استبعاد', 'Dismiss')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _dismissingIds.add(eventId));
    try {
      final token = await _token();
      final response = await http.post(
        Uri.parse('$_baseUrl/incidents/${Uri.encodeComponent(eventId)}/action'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({'action': 'dismiss'}),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw StateError('dismiss_failed_${response.statusCode}');
      }
      final data = jsonDecode(response.body);
      if (data is! Map<String, dynamic> || data['success'] != true) {
        throw const FormatException('Invalid dismiss response');
      }

      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context,
            'تم استبعاد الحادث من السجل', 'Incident dismissed from history'))),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context,
            'تعذر استبعاد الحادث. حاولي مرة أخرى.',
            'Could not dismiss the incident. Please try again.'))),
      );
    } finally {
      if (mounted) setState(() => _dismissingIds.remove(eventId));
    }
  }

  Future<void> _showDetails(Map<String, dynamic> incident) async {
    final dark = Theme.of(context).brightness == Brightness.dark;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.verified_outlined, color: RaqeebColors.accent(dark)),
            const SizedBox(width: 10),
            Expanded(child: Text(_threatName(dialogContext, incident['detectionType']))),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detailRow(dialogContext, 'الحالة', 'Status',
                    tr(dialogContext, 'مؤكد', 'Confirmed')),
                _detailRow(dialogContext, 'الجهاز', 'Device',
                    incident['deviceId']?.toString() ?? '—'),
                _detailRow(dialogContext, 'وقت الاكتشاف', 'Detected at',
                    _formatTime(incident['createdAt'])),
                _detailRow(dialogContext, 'وقت الاطلاع', 'Opened at',
                    _formatTime(incident['readAt'])),
                _detailRow(dialogContext, 'نسبة الثقة', 'Confidence',
                    _confidence(incident['confidence'])),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(tr(dialogContext, 'إغلاق', 'Close')),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String arabicLabel,
    String englishLabel,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr(context, arabicLabel, englishLabel),
              style: TextStyle(fontSize: 12,
                  color: RaqeebColors.secondary(
                      Theme.of(context).brightness == Brightness.dark))),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> incident) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventId = incident['eventId']?.toString() ?? '';
    final available = incident['videoAvailable'] == true;
    final busy = _dismissingIds.contains(eventId);
    final accent = RaqeebColors.accent(dark);
    final danger = const Color(0xFFB4232B);
    final background = RaqeebColors.card(dark);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: RaqeebColors.border(dark)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          mouseCursor: SystemMouseCursors.click,
          onTap: () => _showDetails(incident),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.verified_outlined, color: accent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _threatName(context, incident['detectionType']),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: RaqeebColors.text(dark),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: RaqeebColors.subtle(dark),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        tr(context, 'مؤكد', 'Confirmed'),
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  '${tr(context, 'وقت الاكتشاف', 'Detected at')}: '
                  '${_formatTime(incident['createdAt'])}',
                  style: TextStyle(color: RaqeebColors.secondary(dark)),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr(context, 'وقت الاطلاع', 'Opened at')}: '
                  '${_formatTime(incident['readAt'])}',
                  style: TextStyle(color: RaqeebColors.secondary(dark)),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.touch_app_outlined,
                        size: 16, color: RaqeebColors.secondary(dark)),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        tr(context, 'اضغط لعرض التفاصيل', 'Tap to view details'),
                        style: TextStyle(
                          color: RaqeebColors.secondary(dark),
                          fontSize: 12,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_left_rounded,
                        color: RaqeebColors.secondary(dark)),
                  ],
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 360;
                    final dismissButton = OutlinedButton.icon(
                      onPressed: eventId.isEmpty || busy
                          ? null
                          : () => _dismissIncident(eventId),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: danger,
                        side: BorderSide(color: danger.withValues(alpha: 0.7)),
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: busy
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.close_rounded),
                      label: Text(tr(context, 'استبعاد', 'Dismiss')),
                    );
                    final videoButton = FilledButton.icon(
                      onPressed: !available || eventId.isEmpty
                          ? null
                          : () => _openVideo(eventId),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: Icon(available
                          ? Icons.play_circle_outline
                          : Icons.videocam_off_outlined),
                      label: Text(available
                          ? tr(context, 'مشاهدة التسجيل', 'View Recording')
                          : tr(context, 'لا يوجد تسجيل', 'No Recording')),
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [videoButton, const SizedBox(height: 8), dismissButton],
                      );
                    }
                    return Row(
                      children: [
                        Expanded(child: dismissButton),
                        const SizedBox(width: 12),
                        Expanded(child: videoButton),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(context, 'تعذر تحميل سجل الحوادث',
                        'Could not load incident history')),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: Text(tr(context, 'إعادة المحاولة', 'Retry')),
                    ),
                  ],
                ),
              ),
            );
          }
          final items = snapshot.data ?? [];
          if (items.isEmpty) {
            return Padding(
              padding: const EdgeInsets.all(18),
              child: EmptyIncidents(
                icon: Icons.history_rounded,
                title: tr(context, 'السجل فارغ', 'History is empty'),
                subtitle: tr(
                  context,
                  'ستظهر الحوادث هنا بعد فتح تفاصيلها من التنبيهات.',
                  'Incidents will appear here after you open their details from Alerts.',
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              children: [
                Text(
                  tr(context, 'الحوادث المؤكدة', 'Confirmed incidents'),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: RaqeebColors.text(dark),
                  ),
                ),
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
