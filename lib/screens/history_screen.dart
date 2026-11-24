import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final Set<String> _expandedIds = <String>{};

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

  DateTime? _localDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String _date(Object? value) {
    final date = _localDate(value);
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}-${two(date.month)}-${date.year}';
  }

  String _clock(BuildContext context, Object? value) {
    final date = _localDate(value);
    if (date == null) return '—';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minutes = date.minute.toString().padLeft(2, '0');
    final marker = date.hour < 12 ? tr(context, 'ص', 'AM') : tr(context, 'م', 'PM');
    return '$hour:$minutes $marker';
  }

  String _dateAndTime(BuildContext context, Object? value) {
    if (_localDate(value) == null) return '—';
    return '${_date(value)} • ${_clock(context, value)}';
  }

  String _shortId(String eventId) {
    if (eventId.isEmpty) return '—';
    return eventId.length <= 8 ? eventId.toUpperCase() : eventId.substring(0, 8).toUpperCase();
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(label, textAlign: TextAlign.start,
              style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(value, textAlign: TextAlign.start,
              style: TextStyle(color: RaqeebColors.text(dark), fontSize: 14,
                fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _card(Map<String, dynamic> incident) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final eventId = incident['eventId']?.toString() ?? '';
    final deviceId = incident['deviceId']?.toString() ?? '—';
    final available = incident['videoAvailable'] == true;
    final expanded = _expandedIds.contains(eventId);
    final busy = _dismissingIds.contains(eventId);
    final green = dark ? const Color(0xFF9AB89B) : const Color(0xFF426B4C);
    final buttonGreen = dark ? const Color(0xFF3F8059) : const Color(0xFF426B4C);
    final background = dark ? const Color(0xFF1D2D26) : Theme.of(context).colorScheme.surface;

    final videoButton = SizedBox(
      height: 46,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: !available || eventId.isEmpty || busy ? null : () => _openVideo(eventId),
        style: FilledButton.styleFrom(
          backgroundColor: buttonGreen,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RaqeebColors.secondary(dark).withValues(alpha: 0.13),
          disabledForegroundColor: RaqeebColors.secondary(dark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: Icon(available ? Icons.play_circle_outline_rounded : Icons.videocam_off_outlined,
          size: 19),
        label: Text(available
            ? tr(context, 'مشاهدة الفيديو', 'View Video')
            : tr(context, 'لا يوجد تسجيل', 'No Recording')),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: background,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: green.withValues(alpha: dark ? 0.32 : 0.24)),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: green, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                mouseCursor: SystemMouseCursors.click,
                borderRadius: BorderRadius.circular(12),
                onTap: eventId.isEmpty ? null : () {
                  setState(() {
                    if (expanded) {
                      _expandedIds.remove(eventId);
                    } else {
                      _expandedIds.add(eventId);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        Icon(Icons.verified_outlined, color: green, size: 26),
                        const SizedBox(width: 10),
                        Expanded(child: Text(
                          _threatName(context, incident['detectionType']),
                          style: TextStyle(color: RaqeebColors.text(dark), fontSize: 17,
                            fontWeight: FontWeight.w700),
                        )),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                          decoration: BoxDecoration(
                            color: green.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(tr(context, 'مؤكد', 'Confirmed'),
                            style: TextStyle(color: green, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 6),
                        Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                          color: green, size: 27),
                      ]),
                      if (!expanded) ...[
                        const SizedBox(height: 12),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text('${tr(context, 'رقم الحادث', 'Incident ID')}: ${_shortId(eventId)}',
                            textAlign: TextAlign.start,
                            style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 13)),
                        ),
                        const SizedBox(height: 7),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(_date(incident['createdAt']), textAlign: TextAlign.start,
                            style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 13)),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: green.withValues(alpha: 0.20)),
                const SizedBox(height: 12),
                Text(tr(context, 'رقم الحادث الكامل', 'Full Incident ID'),
                  style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 12)),
                const SizedBox(height: 6),
                Text(eventId, textAlign: TextAlign.start,
                  style: TextStyle(color: RaqeebColors.text(dark),
                    fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 6),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: eventId.isEmpty ? null : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final message = tr(context, 'تم نسخ رقم الحادث', 'Incident ID copied');
                      await Clipboard.setData(ClipboardData(text: eventId));
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(content: Text(message)));
                    },
                    style: TextButton.styleFrom(foregroundColor: green),
                    icon: const Icon(Icons.copy_rounded, size: 17),
                    label: Text(tr(context, 'نسخ الرقم', 'Copy ID')),
                  ),
                ),
                _detailRow(context, tr(context, 'نوع التهديد', 'Threat Type'),
                  _threatName(context, incident['detectionType'])),
                _detailRow(context, tr(context, 'تاريخ الحادث', 'Incident Date'),
                  _date(incident['createdAt'])),
                _detailRow(context, tr(context, 'وقت الاكتشاف', 'Detection Time'),
                  _clock(context, incident['createdAt'])),
                _detailRow(context, tr(context, 'اسم الجهاز', 'Device Name'), deviceId),
                _detailRow(context, tr(context, 'حالة الحادث', 'Incident Status'),
                  tr(context, 'مؤكد', 'Confirmed')),
                _detailRow(context, tr(context, 'وقت الاطلاع', 'Viewed At'),
                  _dateAndTime(context, incident['readAt'])),
                const SizedBox(height: 4),
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: PopupMenuButton<String>(
                    tooltip: tr(context, 'المزيد من الخيارات', 'More options'),
                    enabled: eventId.isNotEmpty && !busy,
                    icon: Icon(Icons.more_vert_rounded, color: RaqeebColors.secondary(dark)),
                    onSelected: (value) {
                      if (value == 'dismiss') _dismissIncident(eventId);
                    },
                    itemBuilder: (menuContext) => [
                      PopupMenuItem<String>(
                        value: 'dismiss',
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          const Icon(Icons.close_rounded, color: Color(0xFFB83B3B)),
                          const SizedBox(width: 8),
                          Text(tr(menuContext, 'استبعاد الحادث', 'Dismiss Incident'),
                            style: const TextStyle(color: Color(0xFFB83B3B))),
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: green.withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              videoButton,
            ],
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
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(tr(context, 'تعذر تحميل سجل الحوادث', 'Could not load incident history')),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh),
                    label: Text(tr(context, 'إعادة المحاولة', 'Retry')),
                  ),
                ]),
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
                subtitle: tr(context,
                  'ستظهر الحوادث هنا بعد الاطلاع عليها من التنبيهات.',
                  'Incidents will appear here after being marked as viewed from Alerts.'),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              children: items.map(_card).toList(),
            ),
          );
        },
      ),
    );
  }
}
