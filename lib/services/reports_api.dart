import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show compute;
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/server_config.dart';
import '../models/models.dart';
import 'local_store.dart';

const hailSizes = <String, String>{
  'arveja': 'Arveja (menos de 1 cm)',
  'moneda': 'Moneda (2–3 cm)',
  'nuez': 'Nuez (3–4 cm)',
  'golf': 'Pelota de golf (4–5 cm)',
  'tenis': 'Pelota de tenis o más (6 cm+)',
};

String sizeTitle(String key) =>
    const {
      'arveja': 'tamaño arveja',
      'moneda': 'tamaño moneda',
      'nuez': 'tamaño nuez',
      'golf': 'como pelota de golf',
      'tenis': 'como pelota de tenis',
    }[key] ??
    '';

String sizeCm(String key) =>
    const {
      'arveja': '~0,5 cm',
      'moneda': '2–3 cm',
      'nuez': '3–4 cm',
      'golf': '4–5 cm',
      'tenis': '6 cm o más',
    }[key] ??
    '';

/// Achica la foto, corrige la orientación y la vuelve a comprimir.
/// Al re-armar el JPG se pierden los datos EXIF (incluida la ubicación).
String? _processPhoto(Uint8List bytes) {
  try {
    final src = img.decodeImage(bytes);
    if (src == null) return null;
    var im = img.bakeOrientation(src);
    const maxSide = 720;
    if (im.width > maxSide || im.height > maxSide) {
      im = im.width >= im.height
          ? img.copyResize(im, width: maxSide)
          : img.copyResize(im, height: maxSide);
    }
    for (final q in [60, 45, 30]) {
      final b64 = base64Encode(img.encodeJpg(im, quality: q));
      if (b64.length <= 240000) return b64;
    }
  } catch (_) {}
  return null;
}

class ReportsApi {
  /// Tiempo con la app instalada antes de poder votar.
  static const _voteAfter = Duration(hours: 24);

  static Map<String, String> _headers({bool json = false}) {
    final k = ServerConfig.supabaseAnonKey;
    final h = <String, String>{'apikey': k};
    // Las claves nuevas (sb_publishable_...) no son JWT: solo van en "apikey".
    if (k.startsWith('eyJ')) h['Authorization'] = 'Bearer $k';
    if (json) h['Content-Type'] = 'application/json';
    return h;
  }

  static Future<String> _randomId(String key, int len) async {
    final p = await SharedPreferences.getInstance();
    var id = p.getString(key);
    if (id == null) {
      final r = Random.secure();
      id = List.generate(len, (_) => r.nextInt(16).toRadixString(16)).join();
      await p.setString(key, id);
    }
    return id;
  }

  /// Público y anónimo: sirve para contar vecinos distintos.
  static Future<String> _deviceId() => _randomId('device_id', 24);

  /// Secreto: solo vos lo tenés, permite borrar tus propios reportes.
  static Future<String> _secret() => _randomId('owner_secret', 32);

  // ───────────── Votos y denuncias ─────────────

  static Future<bool> canVote() async {
    final p = await SharedPreferences.getInstance();
    final first = p.getInt('first_run_ms');
    final now = DateTime.now().millisecondsSinceEpoch;
    if (first == null) {
      await p.setInt('first_run_ms', now);
      return false;
    }
    return now - first >= _voteAfter.inMilliseconds;
  }

  static Future<bool?> myVote(int id) async {
    final p = await SharedPreferences.getInstance();
    final v = p.getString('vote_$id');
    if (v == null) return null;
    return v == 'y';
  }

  static Future<bool> vote(int id, bool real) async {
    if (!ServerConfig.enabled) return false;
    try {
      final r = await http
          .post(
            Uri.parse('${ServerConfig.supabaseUrl}/rest/v1/rpc/vote_report'),
            headers: _headers(json: true),
            body: jsonEncode({
              'p_report': id,
              'p_device': await _deviceId(),
              'p_real': real
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200 && r.statusCode != 204) return false;
      final p = await SharedPreferences.getInstance();
      await p.setString('vote_$id', real ? 'y' : 'n');
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> flag(int id) async {
    if (!ServerConfig.enabled) return false;
    try {
      final r = await http
          .post(
            Uri.parse('${ServerConfig.supabaseUrl}/rest/v1/rpc/flag_report'),
            headers: _headers(json: true),
            body: jsonEncode({'p_report': id, 'p_device': await _deviceId()}),
          )
          .timeout(const Duration(seconds: 15));
      return r.statusCode == 200 || r.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  // ───────────── Fotos ─────────────

  static Future<Uint8List?> fetchPhoto(int id) async {
    if (!ServerConfig.enabled) return null;
    try {
      final uri = Uri.parse('${ServerConfig.supabaseUrl}/rest/v1/hail_reports')
          .replace(queryParameters: {'id': 'eq.$id', 'select': 'photo_b64'});
      final r = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return null;
      final list = jsonDecode(r.body) as List;
      if (list.isEmpty) return null;
      final b64 = list.first['photo_b64'] as String?;
      return b64 == null ? null : base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  // ───────────── Reportes ─────────────

  /// Envía el reporte (con foto y nota opcionales) y lo guarda en el teléfono.
  static Future<String> submit({
    required String place,
    required double lat,
    required double lon,
    required String size,
    Uint8List? photo,
    String? note,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt('last_report_ms') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - last < 10 * 60 * 1000) {
      return 'Ya enviaste un reporte hace poco. Probá de nuevo en unos minutos.';
    }
    await prefs.setInt('last_report_ms', now);

    String? b64;
    if (photo != null) b64 = await compute(_processPhoto, photo);
    final cleanNote = (note ?? '').trim();
    final label =
        '${hailSizes[size] ?? size}${b64 != null ? ' · con foto' : ''}';

    if (!ServerConfig.enabled) {
      await LogStore.reports.add(place, label);
      return 'Reporte guardado en tu teléfono (servidor sin configurar).';
    }

    int? serverId;
    String msg;
    try {
      final body = jsonEncode({
        // ubicación aproximada (~1 km) por privacidad
        'lat': double.parse(lat.toStringAsFixed(2)),
        'lon': double.parse(lon.toStringAsFixed(2)),
        'size': size,
        'place': place.length > 60 ? place.substring(0, 60) : place,
        'device_id': await _deviceId(),
        'owner_token': await _secret(),
        if (b64 != null) 'photo_b64': b64,
        if (cleanNote.isNotEmpty)
          'note':
              cleanNote.length > 140 ? cleanNote.substring(0, 140) : cleanNote,
      });
      final r = await http
          .post(
            Uri.parse(
                '${ServerConfig.supabaseUrl}/rest/v1/hail_reports?select=id'),
            headers: {
              ..._headers(json: true),
              'Prefer': 'return=representation'
            },
            body: body,
          )
          .timeout(const Duration(seconds: 40));
      if (r.statusCode == 201 || r.statusCode == 200) {
        try {
          final j = jsonDecode(r.body) as List;
          serverId = (j.first['id'] as num).toInt();
        } catch (_) {}
        msg = 'Reporte enviado a tus vecinos. ¡Gracias!';
      } else {
        msg =
            'No se pudo enviar (${r.statusCode}); quedó guardado en tu teléfono.';
      }
    } catch (_) {
      msg = 'No se pudo enviar; quedó guardado en tu teléfono.';
    }
    await LogStore.reports.add(place, label, serverId: serverId);
    return msg;
  }

  /// Saca UN reporte tuyo del servidor y del teléfono.
  static Future<bool> deleteMine(LogEntry e) async {
    final id = e.serverId;
    if (id != null && ServerConfig.enabled) {
      try {
        final r = await http
            .post(
              Uri.parse(
                  '${ServerConfig.supabaseUrl}/rest/v1/rpc/delete_my_report'),
              headers: _headers(json: true),
              body: jsonEncode({'p_id': id, 'p_token': await _secret()}),
            )
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200 && r.statusCode != 204) return false;
      } catch (_) {
        return false;
      }
    }
    await LogStore.reports.remove(e);
    return true;
  }

  /// Borra TODOS tus reportes del servidor y del teléfono.
  static Future<bool> deleteAllMine() async {
    if (ServerConfig.enabled) {
      try {
        final r = await http
            .post(
              Uri.parse(
                  '${ServerConfig.supabaseUrl}/rest/v1/rpc/delete_all_my_reports'),
              headers: _headers(json: true),
              body: jsonEncode({'p_token': await _secret()}),
            )
            .timeout(const Duration(seconds: 15));
        if (r.statusCode != 200 && r.statusCode != 204) return false;
      } catch (_) {
        return false;
      }
    }
    await LogStore.reports.clear();
    return true;
  }

  static double _km(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180;
    final dLon = (lon2 - lon1) * pi / 180;
    final a = pow(sin(dLat / 2), 2) +
        cos(lat1 * pi / 180) * cos(lat2 * pi / 180) * pow(sin(dLon / 2), 2);
    return 2 * r * asin(sqrt(a));
  }

  /// Reportes cercanos (sin las fotos: se piden una por una al mostrarlas).
  static Future<List<NeighborReport>> nearby(double lat, double lon,
      {double radiusKm = 30,
      Duration window = const Duration(hours: 6)}) async {
    if (!ServerConfig.enabled) return [];
    try {
      final dLat = radiusKm / 111.0;
      final dLon = radiusKm / (111.0 * max(0.2, cos(lat * pi / 180)));
      final since = DateTime.now()
          .toUtc()
          .subtract(window)
          .toIso8601String()
          .split('.')
          .first;
      final uri = Uri.parse('${ServerConfig.supabaseUrl}/rest/v1/hail_reports')
          .replace(queryParameters: {
        'select':
            'id,created_at,lat,lon,size,place,device_id,note,has_photo,yes_votes,no_votes',
        'and':
            '(lat.gte.${lat - dLat},lat.lte.${lat + dLat},lon.gte.${lon - dLon},lon.lte.${lon + dLon},created_at.gte.${since}Z)',
        'order': 'created_at.desc',
        'limit': '300',
      });
      final r = await http
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return [];
      final list = jsonDecode(r.body) as List;
      final out = <NeighborReport>[];
      for (final e in list) {
        final m = e as Map<String, dynamic>;
        final rl = (m['lat'] as num).toDouble();
        final ro = (m['lon'] as num).toDouble();
        final d = _km(lat, lon, rl, ro);
        if (d > radiusKm) continue;
        out.add(NeighborReport(
          id: (m['id'] as num).toInt(),
          time: DateTime.parse(m['created_at'] as String).toLocal(),
          lat: rl,
          lon: ro,
          size: m['size'] as String,
          place: m['place'] as String?,
          note: m['note'] as String?,
          deviceId: m['device_id'] as String,
          distKm: d,
          hasPhoto: m['has_photo'] as bool? ?? false,
          yes: (m['yes_votes'] as num?)?.toInt() ?? 0,
          no: (m['no_votes'] as num?)?.toInt() ?? 0,
        ));
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
