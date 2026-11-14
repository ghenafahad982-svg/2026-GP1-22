import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local demo-only incidents. Not connected to the production incident API.
/// Never write sensitive incident videos or real operational reports here.
class Incident {
  const Incident({
    required this.id,
    required this.detectedAt,
    required this.threatType,
    required this.status,
    required this.isDemo,
    this.reviewedAt,
  });

  final String id;
  final DateTime detectedAt;
  final String threatType;
  final String status; // new, confirmed, dismissed
  final bool isDemo;
  final DateTime? reviewedAt;

  Incident copyWith({String? status, DateTime? reviewedAt}) => Incident(
    id: id,
    detectedAt: detectedAt,
    threatType: threatType,
    status: status ?? this.status,
    isDemo: isDemo,
    reviewedAt: reviewedAt ?? this.reviewedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'detectedAt': detectedAt.toIso8601String(),
    'threatType': threatType,
    'status': status,
    'isDemo': isDemo,
    'reviewedAt': reviewedAt?.toIso8601String(),
  };

  static Incident? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    try {
      final m = Map<String, dynamic>.from(raw);
      final detectedAt = DateTime.parse(m['detectedAt'] as String);
      final reviewedRaw = m['reviewedAt'];
      final status = m['status'] as String? ?? 'new';
      if (!['new', 'confirmed', 'dismissed'].contains(status)) return null;
      return Incident(
        id: m['id'] as String,
        detectedAt: detectedAt,
        threatType: m['threatType'] as String? ?? 'weapon',
        status: status,
        isDemo: m['isDemo'] == true,
        reviewedAt: reviewedRaw is String ? DateTime.tryParse(reviewedRaw) : null,
      );
    } catch (_) {
      return null;
    }
  }
}

class IncidentStore extends ChangeNotifier {
  IncidentStore._();
  static final IncidentStore instance = IncidentStore._();
  static const String _storageKey = 'raqeeb_demo_incidents_v1';

  List<Incident> _items = [];
  List<Incident> get items => List.unmodifiable(_items);
  List<Incident> get newItems =>
      List.unmodifiable(_items.where((e) => e.status == 'new'));
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_storageKey);
    if (value != null) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          _items = decoded.map(Incident.fromJson).whereType<Incident>().toList();
        }
      } catch (_) {
        _items = [];
      }
    }
    _sort();
    _loaded = true;
    notifyListeners();
  }

  void _sort() => _items.sort((a, b) => b.detectedAt.compareTo(a.detectedAt));

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(_items.map((e) => e.toJson()).toList()));
  }

  Future<void> addDemoIncident() async {
    final now = DateTime.now();
    _items.insert(0, Incident(
      id: 'DEMO-${now.microsecondsSinceEpoch}',
      detectedAt: now,
      threatType: 'weapon',
      status: 'new',
      isDemo: true,
    ));
    notifyListeners();
    await _save();
  }

  Future<void> review(String id, String status) async {
    if (status != 'confirmed' && status != 'dismissed') return;
    final index = _items.indexWhere((item) => item.id == id && item.status == 'new');
    if (index < 0) return;
    _items[index] = _items[index].copyWith(status: status, reviewedAt: DateTime.now());
    notifyListeners();
    await _save();
  }

  Future<void> clearDemoIncidents() async {
    _items.removeWhere((e) => e.isDemo);
    notifyListeners();
    await _save();
  }
}
