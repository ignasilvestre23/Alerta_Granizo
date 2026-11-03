import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../models/models.dart';

class WeatherService {
  double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;
  dynamic _at(List l, int i) => i < l.length ? l[i] : null;
  List _l(Map m, String k) => (m[k] as List?) ?? const [];

  bool _hailHour(HourPoint p) =>
      p.code == 96 || p.code == 99 || (p.code == 95 && p.cape >= 2000);

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<WeatherSnapshot> fetch(double lat, double lon) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': '$lat',
      'longitude': '$lon',
      'current':
          'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,precipitation,wind_speed_10m,wind_direction_10m,wind_gusts_10m',
      'hourly':
          'temperature_2m,weather_code,precipitation,precipitation_probability,cape,lightning_potential,wind_gusts_10m,wind_speed_10m,wind_direction_10m',
      'daily':
          'weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum',
      'forecast_days': '7',
      'timezone': 'auto',
      'wind_speed_unit': 'kmh',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 20));
    if (r.statusCode != 200) {
      throw Exception('Open-Meteo error ${r.statusCode}');
    }
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final cur = j['current'] as Map<String, dynamic>;
    final h = j['hourly'] as Map<String, dynamic>;
    final dly = j['daily'] as Map<String, dynamic>;

    final times = _l(h, 'time');
    final temp = _l(h, 'temperature_2m');
    final code = _l(h, 'weather_code');
    final pr = _l(h, 'precipitation');
    final pp = _l(h, 'precipitation_probability');
    final cape = _l(h, 'cape');
    final li = _l(h, 'lightning_potential');
    final gu = _l(h, 'wind_gusts_10m');
    final ws = _l(h, 'wind_speed_10m');
    final wd = _l(h, 'wind_direction_10m');

    final all = <HourPoint>[
      for (var i = 0; i < times.length; i++)
        HourPoint(
          time: DateTime.parse(times[i] as String),
          temp: _d(_at(temp, i)),
          code: (_at(code, i) as num?)?.toInt() ?? 0,
          precipMm: _d(_at(pr, i)),
          precipProb: _d(_at(pp, i)),
          cape: _d(_at(cape, i)),
          lightning: _d(_at(li, i)),
          gust: _d(_at(gu, i)),
          windSpeed: _d(_at(ws, i)),
          windDir: _d(_at(wd, i)),
        ),
    ];

    final curTime = DateTime.parse(cur['time'] as String);
    var idx = all.lastIndexWhere((p) => !p.time.isAfter(curTime));
    if (idx < 0) idx = 0;
    final hours = all.skip(idx).take(24).toList();

    final dt = _l(dly, 'time');
    final dcode = _l(dly, 'weather_code');
    final dmax = _l(dly, 'temperature_2m_max');
    final dmin = _l(dly, 'temperature_2m_min');
    final dpr = _l(dly, 'precipitation_sum');

    final days = <DayPoint>[];
    for (var i = 0; i < dt.length; i++) {
      final date = DateTime.parse(dt[i] as String);
      final dayHours = all.where((p) => _sameDay(p.time, date)).toList();

      var precipProb = 0.0;
      var stormProb = 0.0;
      var maxCape = 0.0;
      var hailCode = false;
      var stormCode = false;
      for (final p in dayHours) {
        precipProb = math.max(precipProb, p.precipProb);
        maxCape = math.max(maxCape, p.cape);
        final thunder = p.code == 95 || p.code == 96 || p.code == 99;
        stormCode = stormCode || thunder;
        hailCode = hailCode || p.code == 96 || p.code == 99;
        // Estimación: lluvia probable x inestabilidad del aire (CAPE).
        final inst = (p.cape / 1500).clamp(0.0, 1.0).toDouble();
        var s = p.precipProb * inst;
        if (thunder) s = math.max(s, 50.0);
        stormProb = math.max(stormProb, s);
      }

      var level = 0;
      if (stormProb >= 30) level = 1;
      if (hailCode || (stormCode && maxCape >= 2000)) level = 2;
      if (hailCode && maxCape >= 2500) level = 3;

      days.add(DayPoint(
        date: date,
        code: (_at(dcode, i) as num?)?.toInt() ?? 0,
        tMax: _d(_at(dmax, i)),
        tMin: _d(_at(dmin, i)),
        precipMm: _d(_at(dpr, i)),
        precipProb: precipProb,
        stormProb: stormProb,
        risk: HailRisk.values[level],
        hail: dayHours.any(_hailHour),
      ));
    }

    return WeatherSnapshot(
      lat: lat,
      lon: lon,
      temp: _d(cur['temperature_2m']),
      feels: _d(cur['apparent_temperature']),
      humidity: _d(cur['relative_humidity_2m']),
      wind: _d(cur['wind_speed_10m']),
      windDir: _d(cur['wind_direction_10m']),
      gust: _d(cur['wind_gusts_10m']),
      precip: _d(cur['precipitation']),
      code: (cur['weather_code'] as num?)?.toInt() ?? 0,
      tMax: days.isNotEmpty ? days.first.tMax : _d(cur['temperature_2m']),
      tMin: days.isNotEmpty ? days.first.tMin : _d(cur['temperature_2m']),
      hours: hours,
      days: days,
      fetchedAt: DateTime.now(),
    );
  }

  /// Buscador de localidades (Open-Meteo Geocoding).
  static Future<List<GeoResult>> search(String q) async {
    if (q.trim().length < 2) return [];
    final uri = Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
      'name': q.trim(),
      'count': '8',
      'language': 'es',
      'countryCode': 'AR',
    });
    final r = await http.get(uri).timeout(const Duration(seconds: 15));
    if (r.statusCode != 200) return [];
    final j = jsonDecode(r.body) as Map<String, dynamic>;
    final res = (j['results'] as List?) ?? const [];
    return res.map((e) {
      final m = e as Map<String, dynamic>;
      return GeoResult(
        m['name'] as String,
        m['admin1'] as String?,
        (m['latitude'] as num).toDouble(),
        (m['longitude'] as num).toDouble(),
      );
    }).toList();
  }
}
