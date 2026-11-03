import 'dart:math' as math;
import 'package:flutter/material.dart';

// ───────────────────────── Lugares ─────────────────────────
class Place {
  final String name;
  final double? lat;
  final double? lon;
  final bool alerts;
  const Place({required this.name, this.lat, this.lon, this.alerts = true});

  bool get isGps => lat == null || lon == null;

  Place copyWith({String? name, bool? alerts}) => Place(
        name: name ?? this.name,
        lat: lat,
        lon: lon,
        alerts: alerts ?? this.alerts,
      );

  Map<String, dynamic> toJson() =>
      {'name': name, 'lat': lat, 'lon': lon, 'alerts': alerts};

  factory Place.fromJson(Map<String, dynamic> j) => Place(
        name: j['name'] as String,
        lat: (j['lat'] as num?)?.toDouble(),
        lon: (j['lon'] as num?)?.toDouble(),
        alerts: j['alerts'] as bool? ?? true,
      );
}

// ───────────────────────── Pronóstico ─────────────────────────
class HourPoint {
  final DateTime time;
  final double temp;
  final int code;
  final double precipMm;
  final double precipProb;
  final double cape;
  final double lightning;
  final double gust;
  final double windSpeed; // km/h
  final double windDir; // grados desde donde sopla (0 = norte)
  const HourPoint({
    required this.time,
    required this.temp,
    required this.code,
    required this.precipMm,
    required this.precipProb,
    required this.cape,
    required this.lightning,
    required this.gust,
    this.windSpeed = 0,
    this.windDir = 0,
  });
}

class DayPoint {
  final DateTime date;
  final int code;
  final double tMin;
  final double tMax;
  final double precipMm;
  final double precipProb; // %
  final double stormProb; // % (estimación)
  final HailRisk risk;
  final bool hail;
  const DayPoint({
    required this.date,
    required this.code,
    required this.tMin,
    required this.tMax,
    required this.precipMm,
    required this.precipProb,
    required this.stormProb,
    required this.risk,
    required this.hail,
  });
}

class WeatherSnapshot {
  final double lat, lon;
  final double temp, feels, humidity, wind, gust, precip;
  final double windDir; // grados desde donde sopla (0 = norte)
  final int code;
  final double tMax, tMin;
  final List<HourPoint> hours; // desde la hora actual, 24 h
  final List<DayPoint> days; // 7 días
  final DateTime fetchedAt;
  const WeatherSnapshot({
    required this.lat,
    required this.lon,
    required this.temp,
    required this.feels,
    required this.humidity,
    required this.wind,
    required this.gust,
    required this.precip,
    required this.code,
    required this.tMax,
    required this.tMin,
    required this.hours,
    required this.days,
    required this.fetchedAt,
    this.windDir = 0,
  });
}

// ───────────────────────── SMN ─────────────────────────
enum AlertColor { yellow, orange, red }

extension AlertColorX on AlertColor {
  String get label => const ['amarilla', 'naranja', 'roja'][index];
  Color get color =>
      const [Color(0xFFFFC83D), Color(0xFFFF8A3D), Color(0xFFE5484D)][index];
}

class SmnAlert {
  final String title;
  final String description;
  final AlertColor color;
  final DateTime? start;
  final DateTime? end;
  const SmnAlert({
    required this.title,
    required this.description,
    required this.color,
    this.start,
    this.end,
  });

  String get _txt => '$title $description'.toLowerCase();
  bool get isHail => _txt.contains('granizo');
  bool get isStorm => _txt.contains('tormenta');

  bool isActive(DateTime now) =>
      (start == null || !now.isBefore(start!)) &&
      (end == null || now.isBefore(end!));
  bool isFuture(DateTime now) => start != null && now.isBefore(start!);
}

class SmnObs {
  final double? temp, humidity, wind;
  final DateTime? time;
  const SmnObs({this.temp, this.humidity, this.wind, this.time});
}

class SmnData {
  final bool available;
  final List<SmnAlert> alerts;
  final SmnObs? obs;
  const SmnData({required this.available, this.alerts = const [], this.obs});
  static const unavailable = SmnData(available: false);
}

// ───────────────────────── Radar ─────────────────────────
class RadarReading {
  final bool available;
  final double maxDbzNear; // máx. dBZ en 25 km
  final double maxDbzAll; // máx. dBZ en 100 km
  final double? nearestStrongKm; // celda >= 50 dBZ más cercana (100 km)
  final bool approaching;
  final double? etaMin;
  final double? bearingDeg; // rumbo hacia la celda (0 = norte)
  final double? speedKmh; // velocidad de acercamiento
  final double growthDbz; // cambio de intensidad en ~20 min
  const RadarReading({
    required this.available,
    this.maxDbzNear = 0,
    this.maxDbzAll = 0,
    this.nearestStrongKm,
    this.approaching = false,
    this.etaMin,
    this.bearingDeg,
    this.speedKmh,
    this.growthDbz = 0,
  });
  static const unavailable = RadarReading(available: false);

  /// La tormenta se está intensificando.
  bool get growing => growthDbz >= 5 && maxDbzAll >= 50;
}

// ───────────────────────── Riesgo ─────────────────────────
enum HailRisk { none, low, moderate, high, extreme }

extension HailRiskX on HailRisk {
  String get label =>
      const ['Sin riesgo', 'Bajo', 'Moderado', 'Alto', 'Extremo'][index];
  Color get color => const [
        Color(0xFF64708A), // sin riesgo
        Color(0xFFEBD95C), // bajo: amarillo
        Color(0xFFF5A524), // moderado: naranja
        Color(0xFFE5483D), // alto: rojo
        Color(0xFFA63CC9), // extremo: violeta
      ][index];
}

class HailAssessment {
  final HailRisk risk;
  final String headline;
  final String detail;
  const HailAssessment(this.risk, this.headline, this.detail);
}

class NeighborReport {
  final int id;
  final DateTime time;
  final double lat, lon;
  final String size;
  final String? place;
  final String? note;
  final String deviceId;
  final double distKm;
  final bool hasPhoto;
  final int yes, no;
  const NeighborReport({
    required this.id,
    required this.time,
    required this.lat,
    required this.lon,
    required this.size,
    required this.place,
    required this.deviceId,
    required this.distKm,
    this.note,
    this.hasPhoto = false,
    this.yes = 0,
    this.no = 0,
  });

  bool get confirmedByVotes => yes >= 2 && yes > no;
}

class Dashboard {
  final String placeName;
  final double lat, lon;
  final WeatherSnapshot weather;
  final SmnData smn;
  final RadarReading radar;
  final HailAssessment hail;
  final bool heavyRain;
  final List<NeighborReport> neighbors;
  final DateTime fetchedAt;
  const Dashboard({
    required this.placeName,
    required this.lat,
    required this.lon,
    required this.weather,
    required this.smn,
    required this.radar,
    required this.hail,
    required this.heavyRain,
    required this.neighbors,
    required this.fetchedAt,
  });
}

// ───────────────────────── Ajustes ─────────────────────────
class AppSettings {
  final List<Place> places;
  final int selected;
  final bool hailOn;
  final bool heavyRainOn;
  final int minRisk; // índice de HailRisk (2 = moderado)
  final bool quietOn;
  final int quietStart;
  final int quietEnd;
  final int themeMode; // 0 sistema, 1 claro, 2 oscuro

  const AppSettings({
    required this.places,
    this.selected = 0,
    this.hailOn = true,
    this.heavyRainOn = true,
    this.minRisk = 2,
    this.quietOn = true,
    this.quietStart = 23,
    this.quietEnd = 7,
    this.themeMode = 0,
  });

  factory AppSettings.initial() =>
      const AppSettings(places: [Place(name: 'Mi ubicación')]);

  Place get selectedPlace =>
      places[math.min(math.max(selected, 0), places.length - 1)];

  String get selectedKey =>
      '${selectedPlace.name}|${selectedPlace.lat}|${selectedPlace.lon}';

  ThemeMode get mode =>
      const [ThemeMode.system, ThemeMode.light, ThemeMode.dark][themeMode];

  AppSettings copyWith({
    List<Place>? places,
    int? selected,
    bool? hailOn,
    bool? heavyRainOn,
    int? minRisk,
    bool? quietOn,
    int? quietStart,
    int? quietEnd,
    int? themeMode,
  }) =>
      AppSettings(
        places: places ?? this.places,
        selected: selected ?? this.selected,
        hailOn: hailOn ?? this.hailOn,
        heavyRainOn: heavyRainOn ?? this.heavyRainOn,
        minRisk: minRisk ?? this.minRisk,
        quietOn: quietOn ?? this.quietOn,
        quietStart: quietStart ?? this.quietStart,
        quietEnd: quietEnd ?? this.quietEnd,
        themeMode: themeMode ?? this.themeMode,
      );

  Map<String, dynamic> toJson() => {
        'places': places.map((p) => p.toJson()).toList(),
        'selected': selected,
        'hailOn': hailOn,
        'heavyRainOn': heavyRainOn,
        'minRisk': minRisk,
        'quietOn': quietOn,
        'quietStart': quietStart,
        'quietEnd': quietEnd,
        'themeMode': themeMode,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) {
    final raw = (j['places'] as List?) ?? const [];
    final places = raw
        .map((e) => Place.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return AppSettings(
      places: places.isEmpty ? [const Place(name: 'Mi ubicación')] : places,
      selected: j['selected'] as int? ?? 0,
      hailOn: j['hailOn'] as bool? ?? true,
      heavyRainOn: j['heavyRainOn'] as bool? ?? true,
      minRisk: j['minRisk'] as int? ?? 2,
      quietOn: j['quietOn'] as bool? ?? true,
      quietStart: j['quietStart'] as int? ?? 23,
      quietEnd: j['quietEnd'] as int? ?? 7,
      themeMode: j['themeMode'] as int? ?? 0,
    );
  }
}

class GeoResult {
  final String name;
  final String? admin;
  final double lat, lon;
  const GeoResult(this.name, this.admin, this.lat, this.lon);
}
