import 'package:flutter/material.dart';
import '../incident_store.dart';
import '../raqeeb_ui.dart';

String incidentDateTime(DateTime time) {
  final local = time.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${local.year}-${two(local.month)}-${two(local.day)}  ${two(local.hour)}:${two(local.minute)}';
}

String incidentStatus(BuildContext context, String status) {
  switch (status) {
    case 'confirmed':
      return tr(context, 'تم التأكيد', 'Confirmed');
    case 'dismissed':
      return tr(context, 'تم الاستبعاد', 'Dismissed');
    default:
      return tr(context, 'جديد', 'New');
  }
}

Color incidentStatusColor(bool dark, String status) {
  switch (status) {
    case 'confirmed':
      return RaqeebColors.accent(dark);
    case 'dismissed':
      return RaqeebColors.secondary(dark);
    default:
      return RaqeebColors.danger(dark);
  }
}

class DemoBanner extends StatelessWidget {
  const DemoBanner({super.key, required this.onAdd, this.onClear});
  final VoidCallback onAdd;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: RaqeebColors.subtle(dark),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: RaqeebColors.border(dark)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.science_outlined, color: RaqeebColors.accent(dark)),
          const SizedBox(width: 8),
          Expanded(child: Text(tr(context, 'وضع تجربة الواجهة', 'UI demo mode'),
              style: TextStyle(fontWeight: FontWeight.bold,
                  color: RaqeebColors.text(dark)))),
        ]),
        const SizedBox(height: 8),
        Text(tr(context,
            'البيانات هنا تجريبية ومحفوظة على الجهاز فقط. لم تُربط الحوادث بالسيرفر بعد.',
            'These are local demo records only. The incident server API is not connected yet.'),
            style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 13)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_alert_outlined, size: 18),
            label: Text(tr(context, 'إضافة تنبيه تجريبي', 'Add demo alert')),
          ),
          if (onClear != null)
            OutlinedButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: Text(tr(context, 'مسح التجريبي', 'Clear demo')),
            ),
        ]),
      ]),
    );
  }
}

class EmptyIncidents extends StatelessWidget {
  const EmptyIncidents({super.key, required this.icon,
    required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 42, horizontal: 22),
      decoration: BoxDecoration(
        color: RaqeebColors.card(dark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: RaqeebColors.border(dark)),
      ),
      child: Column(children: [
        Icon(icon, size: 42, color: RaqeebColors.accent(dark)),
        const SizedBox(height: 12),
        Text(title, textAlign: TextAlign.center,
            style: TextStyle(color: RaqeebColors.text(dark),
                fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        Text(subtitle, textAlign: TextAlign.center,
            style: TextStyle(color: RaqeebColors.secondary(dark))),
      ]),
    );
  }
}

class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident});
  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final danger = RaqeebColors.danger(dark);
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: RaqeebColors.card(dark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: RaqeebColors.border(dark)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => IncidentDetailScreen(incidentId: incident.id))),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                    color: RaqeebColors.subtle(dark),
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.report_problem_outlined, color: danger),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(tr(context, 'اكتشاف سلاح', 'Weapon detected'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
                      color: RaqeebColors.text(dark)))),
              Flexible(child: Text(incidentStatus(context, incident.status),
                  textAlign: TextAlign.end,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12,
                      color: incidentStatusColor(dark, incident.status)))),
            ]),
            const SizedBox(height: 12),
            Text(incidentDateTime(incident.detectedAt),
                style: TextStyle(color: RaqeebColors.secondary(dark))),
            if (incident.isDemo) ...[
              const SizedBox(height: 7),
              Text(tr(context, 'تجريبي — ليس حادثًا حقيقيًا',
                      'DEMO — not a real incident'),
                  style: TextStyle(color: RaqeebColors.warning(dark), fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Align(alignment: AlignmentDirectional.centerEnd,
              child: Text(tr(context, 'عرض التفاصيل ←', 'View details →'),
                  style: TextStyle(color: RaqeebColors.accent(dark),
                      fontWeight: FontWeight.w600))),
          ]),
        ),
      ),
    );
  }
}

class IncidentDetailScreen extends StatelessWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});
  final String incidentId;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: IncidentStore.instance,
      builder: (context, _) {
        Incident? incident;
        for (final item in IncidentStore.instance.items) {
          if (item.id == incidentId) {
            incident = item;
            break;
          }
        }
        if (incident == null) {
          return Scaffold(appBar: AppBar(),
              body: Center(child: Text(tr(context, 'لم يتم العثور على الحادث',
                  'Incident not found'))));
        }
        final record = incident;
        return Scaffold(
          backgroundColor: RaqeebColors.background(dark),
          appBar: AppBar(title: Text(tr(context, 'تفاصيل الحادث', 'Incident Details'))),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: RaqeebColors.card(dark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: RaqeebColors.border(dark)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(Icons.warning_amber_rounded,
                        color: RaqeebColors.danger(dark), size: 30),
                    const SizedBox(width: 10),
                    Expanded(child: Text(tr(context, 'اكتشاف سلاح', 'Weapon detected'),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                            color: RaqeebColors.text(dark)))),
                  ]),
                  const SizedBox(height: 20),
                  _info(context, tr(context, 'رقم الحادث', 'Incident ID'), record.id),
                  _info(context, tr(context, 'وقت الاكتشاف', 'Detected at'),
                      incidentDateTime(record.detectedAt)),
                  _info(context, tr(context, 'حالة التنبيه', 'Status'),
                      incidentStatus(context, record.status)),
                  if (record.reviewedAt != null)
                    _info(context, tr(context, 'وقت المراجعة', 'Reviewed at'),
                        incidentDateTime(record.reviewedAt!)),
                  if (record.isDemo)
                    Text(tr(context, 'هذا تنبيه تجريبي وليس حدثًا أمنيًا حقيقيًا.',
                            'This is a demo alert, not a real security event.'),
                        style: TextStyle(color: RaqeebColors.warning(dark))),
                ]),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(26),
                decoration: BoxDecoration(
                  color: RaqeebColors.card(dark),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: RaqeebColors.border(dark)),
                ),
                child: Column(children: [
                  Icon(Icons.videocam_off_outlined, size: 42,
                      color: RaqeebColors.secondary(dark)),
                  const SizedBox(height: 12),
                  Text(tr(context, 'تسجيل الحادث غير متوفر بعد',
                      'Incident recording is not available yet'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RaqeebColors.text(dark))),
                  const SizedBox(height: 6),
                  Text(tr(context, 'سيظهر التسجيل هنا بعد ربط واجهة السيرفر.',
                      'The video will be available after the server API is connected.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: RaqeebColors.secondary(dark))),
                ]),
              ),
              const SizedBox(height: 24),
              if (record.status == 'new') ...[
                FilledButton.icon(
                  onPressed: () => _review(context, record.id, 'confirmed'),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(tr(context, 'تأكيد التنبيه', 'Confirm alert')),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => _review(context, record.id, 'dismissed'),
                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(tr(context, 'استبعاد التنبيه', 'Dismiss alert')),
                ),
                const SizedBox(height: 8),
                Text(tr(context,
                    'الاستبعاد لا يحذف سجل الحادث. هذا التغيير محلي وتجريبي حاليًا.',
                    'Dismissal keeps the incident in history. Changes are local demo-only.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12,
                        color: RaqeebColors.secondary(dark))),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _info(BuildContext context, String label, String value) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(color: RaqeebColors.secondary(dark), fontSize: 12)),
        const SizedBox(height: 4),
        SelectableText(value, style: TextStyle(color: RaqeebColors.text(dark),
            fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Future<void> _review(BuildContext context, String id, String status) async {
    final dismiss = status == 'dismissed';
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dismiss
            ? tr(context, 'استبعاد التنبيه؟', 'Dismiss this alert?')
            : tr(context, 'تأكيد التنبيه؟', 'Confirm this alert?')),
        content: Text(dismiss
            ? tr(context, 'سيبقى التنبيه محفوظًا في سجل الحوادث.',
                'The alert will remain in incident history.')
            : tr(context, 'سيتم وضع علامة «تم التأكيد» على التنبيه.',
                'The alert will be marked as confirmed.')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(tr(context, 'رجوع', 'Back'))),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(dismiss ? tr(context, 'استبعاد', 'Dismiss')
                  : tr(context, 'تأكيد', 'Confirm'))),
        ],
      ),
    );
    if (approved == true) await IncidentStore.instance.review(id, status);
  }
}
