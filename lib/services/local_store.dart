import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

class SettingsStore {
  static Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('settings');
    if (raw == null) return AppSettings.initial();
    try {
      return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return AppSettings.initial();
    }
  }

  static Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('settings', jsonEncode(s.toJson()));
  }

  static Future<void> eraseAll() async {
    final p = await SharedPreferences.getInstance();
    const keys = [
      'premium',
      'premium_until',
      'premium_plan',
      'premium_verified',
      'premium_checked',
    ];
    final keep = <String, Object?>{for (final k in keys) k: p.get(k)};
    await p.clear();
    for (final e in keep.entries) {
      final v = e.value;
      if (v is bool) {
        await p.setBool(e.key, v);
      } else if (v is int) {
        await p.setInt(e.key, v);
      } else if (v is String) {
        await p.setString(e.key, v);
      }
    }
  }
}

class LogEntry {
  final DateTime time;
  final String place;
  final String text;
  final int? serverId; // id del reporte en el servidor (si se envió)
  const LogEntry(this.time, this.place, this.text, {this.serverId});
}

/// Lista simple guardada en el teléfono (reportes e historial).
class LogStore {
  final String key;
  const LogStore(this.key);

  static const reports = LogStore('reports');
  static const history = LogStore('history');

  Future<List<LogEntry>> list() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key) ?? const [];
    final out = <LogEntry>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        out.add(LogEntry(
          DateTime.parse(m['t'] as String),
          m['p'] as String,
          m['x'] as String,
          serverId: (m['i'] as num?)?.toInt(),
        ));
      } catch (_) {}
    }
    return out.reversed.toList();
  }

  Future<void> add(String place, String text, {int? serverId}) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key) ?? <String>[];
    raw.add(jsonEncode({
      't': DateTime.now().toIso8601String(),
      'p': place,
      'x': text,
      if (serverId != null) 'i': serverId,
    }));
    await p.setStringList(
        key, raw.length > 200 ? raw.sublist(raw.length - 200) : raw);
  }

  Future<void> remove(LogEntry e) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList(key) ?? <String>[];
    final keep = <String>[];
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        if (DateTime.parse(m['t'] as String) == e.time) continue;
      } catch (_) {}
      keep.add(s);
    }
    await p.setStringList(key, keep);
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key);
  }
}
