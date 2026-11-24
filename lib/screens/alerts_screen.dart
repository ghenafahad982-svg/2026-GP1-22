
import 'dart:convert';
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

  Future<void> _openIncidentVideo(
    BuildContext context,
    String eventId,
  ) async {
    try {
      final videoUrl = await _fetchVideoUrl(eventId);

      if (!context.mounted) return;

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncidentVideoPlayerPage(
            videoUrl: videoUrl,
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'تعذر فتح تسجيل الحادث',
              'Could not open incident recording',
            ),
          ),
        ),
      );
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

  String _incidentTime(dynamic raw) {
    if (raw is! String || raw.isEmpty) return '—';

    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
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

  String _confidenceText(dynamic confidence) {
    if (confidence is! num) return '—';
    return '${(confidence * 100).clamp(0, 100).toStringAsFixed(0)}%';
  }

  Future<void> _openIncidentDetails(Map<String, dynamic> incident) async {
    final eventId = incident['eventId']?.toString() ?? '';
    if (eventId.isEmpty) return;

    try {
      // Opening details marks this alert as read and moves it to History.
      await _updateIncidentAction(eventId, 'open');
      if (!mounted) return;
      _refreshIncidents();

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final dark = theme.brightness == Brightness.dark;
          final type = incident['detectionType']?.toString() ?? '';
          final deviceId = incident['deviceId']?.toString() ?? '—';
          final videoAvailable = incident['videoAvailable'] == true;
          final green = dark ? const Color(0xFF9AB89B) : const Color(0xFF426B4C);

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
            contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Color(0xFFD89425)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _threatName(dialogContext, type),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 390,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(),
                  const SizedBox(height: 8),
                  _detailRow(
                    dialogContext,
                    Icons.devices_outlined,
                    tr(dialogContext, 'الجهاز', 'Device'),
                    deviceId,
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    dialogContext,
                    Icons.schedule_outlined,
                    tr(dialogContext, 'التوقيت', 'Time'),
                    _incidentTime(incident['createdAt']),
                  ),
                  const SizedBox(height: 14),
                  _detailRow(
                    dialogContext,
                    Icons.analytics_outlined,
                    tr(dialogContext, 'نسبة الثقة', 'Confidence'),
                    _confidenceText(incident['confidence']),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_outline_rounded, color: green, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          tr(dialogContext, 'تم التأكيد', 'Confirmed'),
                          style: TextStyle(color: green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  if (!videoAvailable) ...[
                    const SizedBox(height: 12),
                    Text(
                      tr(dialogContext, 'لا يوجد تسجيل متاح', 'No recording available'),
                      style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(18, 4, 18, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: Text(tr(dialogContext, 'إغلاق', 'Close')),
              ),
              if (videoAvailable)
                FilledButton.icon(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _openIncidentVideo(context, eventId);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: dark
                        ? const Color(0xFF507E59)
                        : const Color(0xFF426B4C),
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.play_circle_outline_rounded),
                  label: Text(tr(dialogContext, 'مشاهدة التسجيل', 'View Recording')),
                ),
            ],
          );
        },
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr(
            context,
            'تعذر فتح تفاصيل الحادث',
            'Could not open incident details',
          )),
        ),
      );
    }
  }

  Widget _detailRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: RaqeebColors.secondary(dark)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 12)),
              const SizedBox(height: 3),
              Text(value, style: TextStyle(color: RaqeebColors.text(dark), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _serverIncidentCard(
    BuildContext context,
    Map<String, dynamic> incident,
    bool dark,
  ) {
    final type = incident['detectionType']?.toString() ?? '';
    final deviceId = incident['deviceId']?.toString() ?? '—';
    final eventId = incident['eventId']?.toString() ?? '';
    final videoAvailable = incident['videoAvailable'] == true;
    final theme = Theme.of(context);
    final green = dark ? const Color(0xFF507E59) : const Color(0xFF426B4C);
    final red = dark ? const Color(0xFFEF9A9A) : const Color(0xFFB83B3B);
    final cardColor = theme.colorScheme.surface;

    final dismissButton = SizedBox(
      height: 46,
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: eventId.isEmpty ? null : () => _dismissIncident(eventId),
        style: OutlinedButton.styleFrom(
          foregroundColor: red,
          side: BorderSide(color: red.withValues(alpha: 0.75), width: 1.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        icon: const Icon(Icons.close_rounded, size: 19),
        label: Text(tr(context, 'استبعاد', 'Dismiss'), maxLines: 1),
      ),
    );

    final videoButton = SizedBox(
      height: 46,
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: !videoAvailable || eventId.isEmpty
            ? null
            : () => _openIncidentVideo(context, eventId),
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
              ? tr(context, 'مشاهدة التسجيل', 'View Recording')
              : tr(context, 'لا يوجد تسجيل', 'No Recording'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      elevation: 0,
      color: cardColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: RaqeebColors.secondary(dark).withValues(alpha: 0.24)),
      ),
      child: InkWell(
        onTap: eventId.isEmpty ? null : () => _openIncidentDetails(incident),
        mouseCursor: SystemMouseCursors.click,
        hoverColor: green.withValues(alpha: dark ? 0.12 : 0.05),
        splashColor: green.withValues(alpha: 0.12),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 42,
                    width: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD89425).withValues(alpha: dark ? 0.18 : 0.11),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.warning_amber_rounded,
                      color: Color(0xFFD89425),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _threatName(context, type),
                          style: TextStyle(
                            color: RaqeebColors.text(dark),
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          _incidentTime(incident['createdAt']),
                          style: TextStyle(
                            color: RaqeebColors.secondary(dark),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left_rounded
                        : Icons.chevron_right_rounded,
                    size: 27,
                    color: green,
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      tr(context, 'تم التأكيد', 'Confirmed'),
                      style: TextStyle(color: dark ? const Color(0xFF9AB89B) : green, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    '${tr(context, 'الجهاز', 'Device')}: $deviceId',
                    style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 17, color: green),
                  const SizedBox(width: 6),
                  Text(
                    tr(context, 'اضغط لعرض التفاصيل', 'Tap to view details'),
                    style: TextStyle(color: green, fontWeight: FontWeight.w600, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(height: 1, color: RaqeebColors.secondary(dark).withValues(alpha: 0.18)),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 390) {
                    return Column(
                      children: [
                        videoButton,
                        const SizedBox(height: 9),
                        dismissButton,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: dismissButton),
                      const SizedBox(width: 10),
                      Expanded(child: videoButton),
                    ],
                  );
                },
              ),
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
          Text(
            tr(context, 'التنبيهات', 'Alerts'),
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
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(
                      _errorMessage(context, snapshot.error!),
                      style: TextStyle(color: RaqeebColors.text(dark)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _refreshIncidents,
                      icon: const Icon(Icons.refresh),
                      label: Text(tr(context, 'إعادة المحاولة', 'Retry')),
                    ),
                  ],
                );
              }
              final incidents = snapshot.data ?? [];
              final unread = incidents.where((incident) {
                final status = incident['status']?.toString() ?? 'confirmed';
                return status == 'confirmed' && incident['readAt'] == null;
              }).toList();
              if (unread.isEmpty) {
                return EmptyIncidents(
                  icon: Icons.notifications_none_rounded,
                  title: tr(context, 'لا توجد تنبيهات جديدة', 'No new alerts'),
                  subtitle: tr(
                    context,
                    'لا توجد حوادث غير مقروءة حاليًا.',
                    'There are no unread incidents right now.',
                  ),
                );
              }
              return Column(
                children: unread
                    .map((incident) => _serverIncidentCard(context, incident, dark))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
