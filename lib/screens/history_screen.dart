import 'package:flutter/material.dart';
import '../incident_store.dart';
import '../raqeeb_ui.dart';
import 'incident_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: RaqeebColors.background(dark),
      appBar: AppBar(
        centerTitle: true,
        title: Text(tr(context, 'سجل الحوادث', 'Incident History')),
      ),
      body: AnimatedBuilder(
        animation: IncidentStore.instance,
        builder: (context, _) {
          final items = IncidentStore.instance.items;
          return ListView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            children: [
              Text(tr(context, 'جميع الحوادث', 'All incidents'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold,
                      color: RaqeebColors.text(dark))),
              const SizedBox(height: 8),
              Text(tr(context,
                  'تظل التنبيهات المؤكدة والمستبعدة في السجل للمراجعة.',
                  'Confirmed and dismissed alerts remain in the history for review.'),
                  style: TextStyle(color: RaqeebColors.secondary(dark))),
              const SizedBox(height: 20),
              if (items.isEmpty)
                EmptyIncidents(
                  icon: Icons.history_rounded,
                  title: tr(context, 'السجل فارغ', 'History is empty'),
                  subtitle: tr(context,
                      'ستظهر الحوادث هنا بعد تسجيلها.',
                      'Incidents will appear here after they are recorded.'),
                )
              else
                ...items.map((incident) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: IncidentCard(incident: incident),
                )),
            ],
          );
        },
      ),
    );
  }
}
