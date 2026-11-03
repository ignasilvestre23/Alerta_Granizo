import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

/// Alertas y observaciones del Servicio Meteorológico Nacional (Argentina).
///
/// ⚠️ La API del SMN usa un token JWT y sus endpoints no están documentados
/// oficialmente. Las rutas y el método para obtener el token de abajo son
/// una mejor estimación SIN verificar. Si falla, la app sigue funcionando
/// (muestra "alertas del SMN no disponibles"). Ajustá las constantes si
/// cambian.
class SmnService {
  static const _site = 'https://www.smn.gob.ar';
  static const _api = 'https://ws1.smn.gob.ar/v1';

  static String? _token;
  static DateTime? _tokenAt;

  Future<String?> _getToken() async {
    if (_token != null &&
        _tokenAt != null &&
        DateTime.now().difference(_tokenAt!) < const Duration(hours: 3)) {
      return _token;
    }
    final r = await http.get(Uri.parse(_site)).timeout(const Duration(seconds: 15));
    final m = RegExp(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+')
        .firstMatch(r.body);
    if (m == null) return null;
    _token = m.group(0);
    _tokenAt = DateTime.now();
    return _token;
  }

  Future<dynamic> _getJson(String url, Map<String, String> headers) async {
    final r = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) throw Exception('SMN ${r.statusCode}');
    return jsonDecode(r.body);
  }

  Future<SmnData> fetch(double lat, double lon) async {
    try {
      final token = await _getToken();
      if (token == null) return SmnData.unavailable;
      final headers = {
        'Authorization': 'JWT $token',
        'Accept': 'application/json',
      };

      final loc = await _getJson('$_api/georef/location/coord?lat=$lat&lon=$lon', headers);
      final id = (loc is Map ? loc['id'] : null)?.toString();
      if (id == null) return SmnData.unavailable;

      final alerts = <SmnAlert>[];
      try {
        final a = await _getJson('$_api/alerts/location/$id', headers);
        final list = (a is Map ? a['warnings'] : a) as List? ?? const [];
        for (final w in list) {
          final p = _parseAlert(w);
          if (p != null) alerts.add(p);
        }
      } catch (_) {
        return SmnData.unavailable;
      }

      SmnObs? obs;
      try {
        final w = await _getJson('$_api/weather/location/$id', headers);
        if (w is Map) {
          double? n(dynamic v) => v is num ? v.toDouble() : double.tryParse('$v');
          final wind = w['wind'];
          obs = SmnObs(
            temp: n(w['temperature']),
            humidity: n(w['humidity']),
            wind: n(wind is Map ? wind['speed'] : wind),
            time: _dt(w['date'] ?? w['updated']),
          );
        }
      } catch (_) {}

      return SmnData(available: true, alerts: alerts, obs: obs);
    } catch (_) {
      return SmnData.unavailable;
    }
  }

  DateTime? _dt(dynamic v) {
    if (v is! String) return null;
    return DateTime.tryParse(v)?.toLocal();
  }

  SmnAlert? _parseAlert(dynamic w) {
    if (w is! Map) return null;
    String s(List<String> keys) {
      for (final k in keys) {
        final v = w[k];
        if (v is String && v.isNotEmpty) return v;
      }
      return '';
    }

    final title = s(['title', 'name', 'event', 'phenomenon']);
    final desc = s(['description', 'detail', 'text', 'body']);
    if (title.isEmpty && desc.isEmpty) return null;

    final lv = '${w['level'] ?? w['severity'] ?? w['color'] ?? ''} $title'.toLowerCase();
    AlertColor color = AlertColor.yellow;
    if (lv.contains('roja') || lv.contains('red') || lv.trim() == '4') {
      color = AlertColor.red;
    } else if (lv.contains('naranja') || lv.contains('orange') || lv.trim() == '3') {
      color = AlertColor.orange;
    }

    return SmnAlert(
      title: title.isEmpty ? 'Alerta meteorológica' : title,
      description: desc,
      color: color,
      start: _dt(w['start'] ?? w['from'] ?? w['date_from']),
      end: _dt(w['end'] ?? w['to'] ?? w['date_to']),
    );
  }
}
