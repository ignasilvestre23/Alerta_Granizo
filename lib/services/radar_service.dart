import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../models/models.dart';

class RadarFrame {
  final int time; // segundos unix (UTC)
  final String path;
  const RadarFrame(this.time, this.path);
}

class RadarFrames {
  final String host;
  final List<RadarFrame> frames;
  const RadarFrames(this.host, this.frames);
}

/// Radar de RainViewer (esquema Universal Blue). Convierte colores en dBZ,
/// busca celdas intensas (>= 50 dBZ), si se acercan, a qué velocidad y si
/// están creciendo.
class RadarService {
  static const int _z = 6;
  static const _mapsUrl = 'https://api.rainviewer.com/public/weather-maps.json';

  static const _rgb = <int>[
    0x88ddee, 0x6cd1eb, 0x51c5e8, 0x36bae5, 0x1baee2, // 15-19
    0x00a3e0, 0x009ad5, 0x0091ca, 0x0088bf, 0x007fb4, // 20-24
    0x0077aa, 0x0070a3, 0x00699c, 0x006295, 0x005b8e, // 25-29
    0x005588, 0x005180, 0x004e78, 0x004a70, 0x004768, // 30-34
    0xffee00, 0xffe000, 0xffd200, 0xffc500, 0xffb700, // 35-39
    0xffaa00, 0xff9f00, 0xff9500, 0xff8b00, 0xff8100, // 40-44
    0xff4400, 0xf23600, 0xe62800, 0xd91b00, 0xcd0d00, // 45-49
    0xc10000, 0xa80000, 0x8f0000, 0x760000, 0x5d0000, // 50-54
    0xffaaff, 0xff9fff, 0xff95ff, 0xff8bff, 0xff81ff, // 55-59
    0xff77ff, 0xff6cff, 0xff62ff, 0xff58ff, 0xff4eff, // 60-64
    0xffffff, // 65+
  ];
  static final Map<int, int> _cache = {};

  static int _decode(int r, int g, int b, int a) {
    if (a < 200) return -1;
    final key = (r << 16) | (g << 8) | b;
    final c = _cache[key];
    if (c != null) return c;
    var best = -1;
    var bestD = 1 << 30;
    for (var i = 0; i < _rgb.length; i++) {
      final c2 = _rgb[i];
      final dr = r - ((c2 >> 16) & 255);
      final dg = g - ((c2 >> 8) & 255);
      final db = b - (c2 & 255);
      final d = dr * dr + dg * dg + db * db;
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    final res = bestD <= 2500 ? 15 + best : -1;
    _cache[key] = res;
    return res;
  }

  static Future<RadarFrames?> frames() async {
    try {
      final r = await http
          .get(Uri.parse(_mapsUrl))
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final past = (j['radar']?['past'] as List?) ?? const [];
      if (past.isEmpty) return null;
      final list = past
          .map((e) =>
              RadarFrame((e['time'] as num).toInt(), e['path'] as String))
          .toList();
      final last = list.length > 6 ? list.sublist(list.length - 6) : list;
      return RadarFrames(j['host'] as String, last);
    } catch (_) {
      return null;
    }
  }

  Future<RadarReading> read(double lat, double lon) async {
    try {
      final fr = await frames();
      if (fr == null || fr.frames.length < 3) return RadarReading.unavailable;
      final newest = fr.frames.last;
      final older = fr.frames[fr.frames.length - 3];

      final a = await _frame(fr.host, newest.path, lat, lon);
      if (a == null) return RadarReading.unavailable;
      final b = await _frame(fr.host, older.path, lat, lon);

      final dtMin = (newest.time - older.time) / 60.0;
      var approaching = false;
      double? eta;
      double? speed;
      if (a.nearestStrongKm.isFinite) {
        if (a.nearestStrongKm <= 10) {
          approaching = true;
          eta = 0;
        } else if (b != null && b.nearestStrongKm.isFinite && dtMin > 0) {
          final v = (b.nearestStrongKm - a.nearestStrongKm) / dtMin; // km/min
          if (v > 0.2 && a.nearestStrongKm / v <= 240) {
            approaching = true;
            eta = a.nearestStrongKm / v;
            speed = v * 60;
          }
        }
      }
      final growth = b == null ? 0.0 : a.maxAll - b.maxAll;

      return RadarReading(
        available: true,
        maxDbzNear: a.maxNear,
        maxDbzAll: a.maxAll,
        nearestStrongKm: a.nearestStrongKm.isFinite ? a.nearestStrongKm : null,
        approaching: approaching,
        etaMin: eta,
        bearingDeg: a.nearestStrongKm.isFinite ? a.bearing : null,
        speedKmh: speed,
        growthDbz: growth,
      );
    } catch (_) {
      return RadarReading.unavailable;
    }
  }

  Future<_Frame?> _frame(
      String host, String path, double lat, double lon) async {
    const n = 1 << _z;
    final latRad = lat * pi / 180;
    final gx = (lon + 180) / 360 * n * 256;
    final gy = (1 - log(tan(latRad) + 1 / cos(latRad)) / pi) / 2 * n * 256;
    final mpp = 156543.03392 * cos(latRad) / n;
    final rPx = (100000 / mpp).ceil();

    final txMin = ((gx - rPx) / 256).floor();
    final txMax = ((gx + rPx) / 256).floor();
    final tyMin = ((gy - rPx) / 256).floor();
    final tyMax = ((gy + rPx) / 256).floor();

    final tiles = <String, img.Image>{};
    final futures = <Future<void>>[];
    for (var tx = txMin; tx <= txMax; tx++) {
      for (var ty = tyMin; ty <= tyMax; ty++) {
        futures.add(() async {
          try {
            final url = '$host$path/256/$_z/$tx/$ty/2/0_0.png';
            final r = await http
                .get(Uri.parse(url))
                .timeout(const Duration(seconds: 15));
            if (r.statusCode != 200) return;
            final im = img.decodePng(r.bodyBytes);
            if (im != null) tiles['${tx}_$ty'] = im;
          } catch (_) {}
        }());
      }
    }
    await Future.wait(futures);
    if (tiles.isEmpty) return null;

    var maxNear = 0.0;
    var maxAll = 0.0;
    var nearest = double.infinity;
    var ndx = 0;
    var ndy = 0;
    final cx = gx.round();
    final cy = gy.round();
    for (var dy = -rPx; dy <= rPx; dy++) {
      for (var dx = -rPx; dx <= rPx; dx++) {
        final distKm = sqrt(dx * dx + dy * dy) * mpp / 1000;
        if (distKm > 100) continue;
        final px = cx + dx;
        final py = cy + dy;
        final tile = tiles['${px ~/ 256}_${py ~/ 256}'];
        if (tile == null) continue;
        final lx = px % 256;
        final ly = py % 256;
        if (lx >= tile.width || ly >= tile.height) continue;
        final p = tile.getPixel(lx, ly);
        final dbz = _decode(p.r.toInt(), p.g.toInt(), p.b.toInt(), p.a.toInt());
        if (dbz < 0) continue;
        if (dbz > maxAll) maxAll = dbz.toDouble();
        if (distKm <= 25 && dbz > maxNear) maxNear = dbz.toDouble();
        if (dbz >= 50 && distKm < nearest) {
          nearest = distKm;
          ndx = dx;
          ndy = dy;
        }
      }
    }
    return _Frame(maxNear, maxAll, nearest, ndx, ndy);
  }
}

class _Frame {
  final double maxNear;
  final double maxAll;
  final double nearestStrongKm;
  final int dx; // píxeles al este (+)
  final int dy; // píxeles al sur (+)
  const _Frame(
      this.maxNear, this.maxAll, this.nearestStrongKm, this.dx, this.dy);

  double get bearing {
    final b = atan2(dx.toDouble(), -dy.toDouble()) * 180 / pi;
    return b < 0 ? b + 360 : b;
  }
}
