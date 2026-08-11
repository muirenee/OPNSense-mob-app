import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class AuditEntry {
  const AuditEntry({
    required this.timestamp,
    required this.action,
    required this.target,
    required this.result,
    this.details = '',
  });

  final DateTime timestamp;
  final String action;
  final String target;
  final String result;
  final String details;

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'action': action,
        'target': target,
        'result': result,
        'details': details,
      };

  static AuditEntry fromJson(Map<String, dynamic> json) => AuditEntry(
        timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        action: json['action']?.toString() ?? '',
        target: json['target']?.toString() ?? '',
        result: json['result']?.toString() ?? '',
        details: json['details']?.toString() ?? '',
      );
}

class AuditRepository {
  AuditRepository({required this.profileId});

  final String profileId;

  String get _key => 'audit_v1_$profileId';

  Future<void> record({
    required String action,
    required String target,
    required String result,
    String details = '',
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await load();
    entries.insert(
      0,
      AuditEntry(
        timestamp: DateTime.now(),
        action: action,
        target: target,
        result: result,
        details: details,
      ),
    );
    final trimmed = entries.take(200).map((item) => item.toJson()).toList();
    await prefs.setString(_key, jsonEncode(trimmed));
  }

  Future<List<AuditEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return <AuditEntry>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <AuditEntry>[];
      return decoded
          .whereType<Map>()
          .map((item) => AuditEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList();
    } catch (_) {
      return <AuditEntry>[];
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
