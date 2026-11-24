
import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'incident_video_player_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

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
  final Set<String> _expandedIds = <String>{};
  final Set<String> _busyIds = <String>{};

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

  Future<void> _openIncidentVideo(String eventId) async {
    if (_busyIds.contains(eventId)) return;
    setState(() => _busyIds.add(eventId));
    try {
      // A signed URL must be available before we consider the video opened.
      final videoUrl = await _fetchVideoUrl(eventId);
      if (!mounted) return;

      // Start playback, then mark read. Opening a card alone never marks read.
      unawaited(Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => IncidentVideoPlayerPage(videoUrl: videoUrl),
        ),
      ).then((_) {}));

      try {
        await _updateIncidentAction(eventId, 'open');
        if (mounted) _refreshIncidents();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(
            context,
            'تم فتح الفيديو لكن تعذر نقل الحادث إلى السجل. أعيدي المحاولة.',
            'Video opened, but the incident could not be moved to History. Try again.',
          ))),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(
          context,
          'تعذر فتح تسجيل الحادث',
          'Could not open incident recording',
        ))),
      );
    } finally {
      if (mounted) setState(() => _busyIds.remove(eventId));
    }
  }

  Future<void> _confirmDismiss(String eventId) async {
    if (eventId.isEmpty || _busyIds.contains(eventId)) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(dialogContext, 'استبعاد الحادث', 'Dismiss incident')),
        content: Text(tr(
          dialogContext,
          'هل تريد استبعاد هذا الحادث؟ سيختفي من التنبيهات والسجل، مع الاحتفاظ ببياناته في النظام.',
          'Dismiss this incident? It will disappear from Alerts and History, but its data will remain stored.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(dialogContext, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFB83B3B)),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(dialogContext, 'استبعاد', 'Dismiss')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busyIds.add(eventId));
    try {
      await _dismissIncident(eventId);
    } finally {
      if (mounted) setState(() => _busyIds.remove(eventId));
    }
  }

Future<void> _updateIncidentAction(
  String eventId,
  String action,
) async {
  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    throw Exception('not_signed_in');
  }

  final token = await user.getIdToken();

  if (token == null || token.isEmpty) {
    throw Exception('missing_token');
  }

  final uri = Uri.parse(
    'https://raqeebserver.onrender.com/incidents/'
    '${Uri.encodeComponent(eventId)}/action',
  );

  final response = await http.post(
    uri,
    headers: {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    body: jsonEncode({'action': action}),
  ).timeout(const Duration(seconds: 30));

  if (response.statusCode != 200) {
    throw Exception(
      'incident_action_failed_${response.statusCode}',
    );
  }

  final data = jsonDecode(response.body);

  if (data is! Map<String, dynamic> ||
      data['success'] != true) {
    throw Exception('invalid_action_response');
  }
}

  Future<String> _fetchVideoUrl(String eventId) async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      throw Exception('not_signed_in');
    }

    final token = await user.getIdToken();

    if (token == null || token.isEmpty) {
      throw Exception('missing_token');
    }

    final uri = Uri.parse(
      'https://raqeebserver.onrender.com/incidents/'
      '${Uri.encodeComponent(eventId)}/video-url',
    );

    final response = await http.get(
      uri,
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

    if (response.statusCode == 404) {
      throw Exception('video_unavailable');
    }

    if (response.statusCode != 200) {
      throw Exception('video_server_error_${response.statusCode}');
    }

    final data = jsonDecode(response.body);

    if (data is! Map<String, dynamic> ||
        data['success'] != true ||
        data['signedUrl'] is! String ||
        (data['signedUrl'] as String).isEmpty) {
      throw const FormatException('Invalid video URL response');
    }

    return data['signedUrl'] as String;
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

bool _readingAll = false;

Future<void> _readAllIncidents() async {
  if (_readingAll) return;

  try {
    // Fetch a fresh snapshot of the current unread incidents.
    final incidents = await _fetchIncidents();

    final unread = incidents.where((incident) {
      final status = incident['status']?.toString() ?? 'confirmed';
      return status == 'confirmed' && incident['readAt'] == null;
    }).toList();

    if (!mounted || unread.isEmpty) return;

    final shouldProceed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr(context, 'قراءة الكل', 'Read All')),
        content: Text(
          tr(
            context,
            'هل تريد نقل جميع التنبيهات الحالية إلى السجل؟',
            'Move all current alerts to history?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(tr(context, 'إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(tr(context, 'نقل الكل', 'Move All')),
          ),
        ],
      ),
    );

    if (shouldProceed != true || !mounted) return;

    setState(() => _readingAll = true);

    var failed = 0;

    for (final incident in unread) {
      final eventId = incident['eventId']?.toString() ?? '';
      if (eventId.isEmpty) {
        failed++;
        continue;
      }

      try {
        await _updateIncidentAction(eventId, 'open');
      } catch (_) {
        failed++;
      }
    }

    if (!mounted) return;

    _refreshIncidents();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed == 0
              ? tr(context, 'تم نقل التنبيهات إلى السجل', 'Alerts moved to history')
              : tr(
                  context,
                  'تعذر نقل بعض التنبيهات، يرجى المحاولة مجددًا',
                  'Some alerts could not be moved. Please try again.',
                ),
        ),
      ),
    );
  } catch (_) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(context, 'تعذر قراءة التنبيهات', 'Could not load alerts'),
        ),
      ),
    );
  } finally {
    if (mounted) {
      setState(() => _readingAll = false);
    }
  }
}

Future<void> _dismissIncident(String eventId) async {
  try {
    await _updateIncidentAction(eventId, 'dismiss');

    if (!mounted) return;

    _refreshIncidents();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(context, 'تم استبعاد التنبيه', 'Alert dismissed'),
        ),
      ),
    );
  } catch (error) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            context,
            'تعذر استبعاد التنبيه. حاولي مرة أخرى.',
            'Could not dismiss the alert. Please try again.',
          ),
        ),
      ),
    );
  }
}

  DateTime? _localDate(Object? value) {
    if (value is! String) return null;
    return DateTime.tryParse(value)?.toLocal();
  }

  String _incidentDate(Object? value) {
    final date = _localDate(value);
    if (date == null) return '—';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}-${two(date.month)}-${date.year}';
  }

  String _incidentClock(Object? value, BuildContext context) {
    final date = _localDate(value);
    if (date == null) return '—';
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    final marker = date.hour < 12
        ? tr(context, 'ص', 'AM')
        : tr(context, 'م', 'PM');
    return '$hour:$minute $marker';
  }

  String _shortId(String eventId) =>
      eventId.length <= 8 ? eventId : eventId.substring(0, 8).toUpperCase();

  Widget _infoRow(BuildContext context, String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              label,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: RaqeebColors.secondary(dark),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              value,
              textAlign: TextAlign.start,
              style: TextStyle(
                color: RaqeebColors.text(dark),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _serverIncidentCard(
    BuildContext context,
    Map<String, dynamic> incident,
    bool dark,
  ) {
    final eventId = incident['eventId']?.toString() ?? '';
    final type = incident['detectionType']?.toString() ?? '';
    final deviceId = incident['deviceId']?.toString() ?? '—';
    final videoAvailable = incident['videoAvailable'] == true;
    final expanded = _expandedIds.contains(eventId);
    final busy = _busyIds.contains(eventId);
    final green = dark ? const Color(0xFF3F8059) : const Color(0xFF426B4C);
    final red = dark ? const Color(0xFFEB8587) : const Color(0xFFB83B3B);
    final warning = dark ? const Color(0xFFE28B8E) : const Color(0xFFB83B45);

    final dismissButton = SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: eventId.isEmpty || busy ? null : () => _confirmDismiss(eventId),
        style: OutlinedButton.styleFrom(
          foregroundColor: red,
          side: BorderSide(color: red.withValues(alpha: 0.8)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: const Icon(Icons.close_rounded, size: 19),
        label: Text(tr(context, 'استبعاد', 'Dismiss')),
      ),
    );

    final videoButton = SizedBox(
      height: 46,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: !videoAvailable || eventId.isEmpty || busy
            ? null : () => _openIncidentVideo(eventId),
        style: FilledButton.styleFrom(
          backgroundColor: green,
          foregroundColor: Colors.white,
          disabledBackgroundColor: RaqeebColors.secondary(dark).withValues(alpha: 0.13),
          disabledForegroundColor: RaqeebColors.secondary(dark),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: Icon(
          videoAvailable ? Icons.play_circle_outline_rounded : Icons.videocam_off_outlined,
          size: 19,
        ),
        label: Text(
          videoAvailable
              ? tr(context, 'مشاهدة الفيديو', 'View Video')
              : tr(context, 'لا يوجد تسجيل', 'No Recording'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: dark ? const Color(0xFF1D2D26) : Theme.of(context).colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: warning.withValues(alpha: dark ? 0.30 : 0.22)),
      ),
      child: Container(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: warning, width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(12),
                mouseCursor: SystemMouseCursors.click,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, color: warning, size: 26),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_threatName(context, type),
                              style: TextStyle(
                                color: RaqeebColors.text(dark),
                                fontSize: 17, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                            decoration: BoxDecoration(
                              color: warning.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(tr(context, 'مؤكد', 'Confirmed'),
                              style: TextStyle(color: warning, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                            color: warning, size: 27),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (!expanded) ...[
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            '${tr(context, 'رقم الحادث', 'Incident ID')}: ${_shortId(eventId)}',
                            textAlign: TextAlign.start,
                            style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 7),
                        Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Text(
                            _incidentDate(incident['createdAt']),
                            textAlign: TextAlign.start,
                            style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 13),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                const SizedBox(height: 4),
                Divider(color: warning.withValues(alpha: 0.18)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    tr(context, 'رقم الحادث الكامل', 'Full Incident ID'),
                    textAlign: TextAlign.start,
                    style: TextStyle(
                      color: RaqeebColors.secondary(dark), fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: SelectableText(
                        eventId,
                        textAlign: TextAlign.start,
                        style: TextStyle(
                          color: RaqeebColors.text(dark),
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      tooltip: tr(context, 'نسخ رقم الحادث', 'Copy incident ID'),
                      onPressed: eventId.isEmpty ? null : () async {
                        await Clipboard.setData(ClipboardData(text: eventId));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(tr(
                            context, 'تم نسخ رقم الحادث', 'Incident ID copied',
                          ))),
                        );
                      },
                      icon: Icon(Icons.copy_rounded, color: green, size: 20),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _infoRow(context, tr(context, 'نوع التهديد', 'Threat type'), _threatName(context, type)),
                _infoRow(context, tr(context, 'تاريخ الحادث', 'Incident date'), _incidentDate(incident['createdAt'])),
                _infoRow(context, tr(context, 'الوقت', 'Time'), _incidentClock(incident['createdAt'], context)),
                _infoRow(context, tr(context, 'اسم الجهاز', 'Device name'), deviceId),
                _infoRow(context, tr(context, 'حالة الحادث', 'Incident status'), tr(context, 'مؤكد', 'Confirmed')),
              ],
              const SizedBox(height: 12),
              Divider(height: 1, color: warning.withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 390) {
                  return Column(children: [
                    videoButton,
                    const SizedBox(height: 9),
                    dismissButton,
                  ]);
                }
                return Row(children: [
                  Expanded(child: dismissButton),
                  const SizedBox(width: 10),
                  Expanded(child: videoButton),
                ]);
              }),
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
      backgroundColor: dark ? const Color(0xFF14211B) : const Color(0xFFFFF7F6),
      appBar: AppBar(
        centerTitle: true,
        title: Text(tr(context, 'التنبيهات', 'Alerts')),
        actions: [
          TextButton.icon(
            onPressed: _readingAll ? null : _readAllIncidents,
            icon: const Icon(Icons.done_all_rounded),
            label: Text(tr(context, 'قراءة الكل', 'Read All')),
          ),
          IconButton(
            tooltip: tr(context, 'تحديث', 'Refresh'),
            onPressed: _refreshIncidents,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _serverIncidents,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(32),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Column(children: [
                  Text(_errorMessage(context, snapshot.error!),
                    style: TextStyle(color: RaqeebColors.text(dark)),
                    textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _refreshIncidents,
                    icon: const Icon(Icons.refresh),
                    label: Text(tr(context, 'إعادة المحاولة', 'Retry')),
                  ),
                ]);
              }
              final incidents = snapshot.data ?? [];
              final unread = incidents.where((incident) =>
                (incident['status']?.toString() ?? 'confirmed') == 'confirmed' &&
                incident['readAt'] == null,
              ).toList();
              if (unread.isEmpty) {
                return EmptyIncidents(
                  icon: Icons.notifications_none_rounded,
                  title: tr(context, 'لا توجد تنبيهات جديدة', 'No new alerts'),
                  subtitle: tr(context,
                    'لا توجد حوادث غير مقروءة حاليًا.',
                    'There are no unread incidents right now.'),
                );
              }
              return Column(children: unread
                .map((incident) => _serverIncidentCard(context, incident, dark))
                .toList());
            },
          ),
        ],
      ),
    );
  }
}
