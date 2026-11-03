import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/models.dart';

const _dias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo'
];

String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String dayName(DateTime d, DateTime now) {
  final a = DateTime(d.year, d.month, d.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'hoy';
  if (diff == 1) return 'mañana';
  return _dias[d.weekday - 1];
}

String weekday(DateTime d) => _dias[d.weekday - 1];

String mm(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

String ago(DateTime t) {
  final m = DateTime.now().difference(t).inMinutes;
  if (m < 1) return 'recién';
  if (m < 60) return 'hace $m min';
  return 'hace ${m ~/ 60} h';
}

String hh(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

String codeLabel(int c) {
  if (c == 0) return 'Despejado';
  if (c == 1) return 'Mayormente despejado';
  if (c == 2) return 'Parcialmente nublado';
  if (c == 3) return 'Nublado';
  if (c == 45 || c == 48) return 'Niebla';
  if (c >= 51 && c <= 57) return 'Llovizna';
  if (c >= 61 && c <= 67) return 'Lluvia';
  if (c >= 71 && c <= 77) return 'Nieve';
  if (c >= 80 && c <= 82) return 'Chubascos';
  if (c == 85 || c == 86) return 'Nevadas';
  if (c == 95) return 'Tormenta eléctrica';
  if (c == 96 || c == 99) return 'Tormenta con granizo';
  return 'Variable';
}

IconData weatherIcon(int c) {
  if (c == 0 || c == 1) return Icons.wb_sunny_outlined;
  if (c == 2) return Icons.wb_cloudy_outlined;
  if (c == 3) return Icons.cloud_outlined;
  if (c == 45 || c == 48) return Icons.foggy;
  if (c >= 51 && c <= 67) return Icons.water_drop_outlined;
  if (c >= 71 && c <= 77) return Icons.ac_unit;
  if (c >= 80 && c <= 82) return Icons.grain;
  if (c >= 95) return Icons.thunderstorm_outlined;
  return Icons.cloud_outlined;
}

String compassEs(double deg) {
  const n = [
    'norte',
    'noreste',
    'este',
    'sureste',
    'sur',
    'suroeste',
    'oeste',
    'noroeste'
  ];
  return n[((deg + 22.5) / 45).floor() % 8];
}

String stormWhere(RadarReading r) {
  if (!r.available) return 'Radar no disponible';
  final km = r.nearestStrongKm;
  if (km == null) return 'Sin tormentas cerca';
  if (km <= 10) return 'Tormenta sobre tu zona';
  final dir = r.bearingDeg == null ? '' : ' al ${compassEs(r.bearingDeg!)}';
  return 'Tormenta a ${km.round()} km$dir';
}

/// Estimación lineal según el movimiento de la celda en el radar.
String etaText(RadarReading r, DateTime now) {
  final km = r.nearestStrongKm;
  if (!r.available || km == null) return 'Sin tormentas intensas cerca.';
  if (km <= 10) return 'La tormenta está sobre tu zona.';
  if (r.approaching && r.etaMin != null) {
    final m = r.etaMin!;
    final margin = math.max(10.0, m * 0.25);
    final from = now.add(Duration(minutes: math.max(0.0, m - margin).round()));
    final to = now.add(Duration(minutes: (m + margin).round()));
    final dir =
        r.bearingDeg == null ? '' : ', viene del ${compassEs(r.bearingDeg!)}';
    return 'Llegaría entre las ${hh(from)} y las ${hh(to)}$dir.';
  }
  return 'La tormenta no se está acercando por ahora.';
}
