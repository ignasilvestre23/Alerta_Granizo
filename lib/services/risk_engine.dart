import 'dart:math' as math;
import '../models/models.dart';

/// Combina pronóstico + radar + alertas SMN + reportes de vecinos.
/// Es una ESTIMACIÓN: no detecta granizo real.
HailAssessment assessHail({
  required WeatherSnapshot w,
  required RadarReading radar,
  required SmnData smn,
  required DateTime now,
  int neighborDevices = 0, // dispositivos distintos que reportaron <20 km, <1 h
}) {
  var level = 0;
  void up(int l) {
    if (l > level) level = l;
  }

  // 1) Pronóstico (próximas ~3 h)
  final win = w.hours.take(4).toList();
  final codes = [w.code, ...win.map((h) => h.code)];
  final cape = win.fold<double>(0, (m, h) => math.max(m, h.cape));
  final hailCode = codes.any((c) => c == 96 || c == 99);
  final storm = codes.any((c) => c == 95 || c == 96 || c == 99);
  if (hailCode) {
    up(cape >= 2500 ? 3 : 2);
  } else if (storm && cape >= 2000) {
    up(2);
  } else if (storm && cape >= 1000) {
    up(1);
  }

  // 2) Radar
  var growing = false;
  if (radar.available) {
    final near = radar.maxDbzNear;
    if (near >= 65) {
      up(4);
    } else if (near >= 60) {
      up(3);
    } else if (near >= 55) {
      up(2);
    } else if (near >= 50) {
      up(1);
    }
    final km = radar.nearestStrongKm;
    final eta = radar.etaMin;
    if (km != null && km <= 60) up(1);
    if (km != null && radar.approaching && eta != null) {
      if (eta <= 45) up(radar.maxDbzAll >= 60 ? 3 : 2);
    }
    if (km != null && radar.growing && km <= 60) {
      growing = true;
      up(km <= 30 ? 2 : 1);
    }
  }

  // 3) Alertas oficiales del SMN
  SmnAlert? futureHail;
  for (final a in smn.alerts.where((a) => a.isHail)) {
    if (a.isActive(now)) {
      up(2 + a.color.index); // amarilla 2, naranja 3, roja 4
    } else if (a.isFuture(now)) {
      futureHail = a;
    }
  }

  // 4) Vecinos (se exige más de 1 dispositivo para evitar falsos reportes)
  if (neighborDevices >= 4) {
    up(3);
  } else if (neighborDevices >= 2) {
    up(2);
  } else if (neighborDevices == 1) {
    up(1);
  }
  final vecinos = neighborDevices > 0
      ? ' Vecinos reportaron granizo cerca en la última hora.'
      : '';

  final risk = HailRisk.values[math.min(math.max(level, 0), 4)];
  switch (risk) {
    case HailRisk.none:
      final extra = futureHail != null
          ? ' El SMN ya tiene una alerta por granizo para más adelante: el detalle, abajo.'
          : '';
      return HailAssessment(risk, 'Sin granizo a la vista',
          'Nada indica granizo en las próximas horas.$extra');
    case HailRisk.low:
      if (growing) {
        return HailAssessment(
            risk,
            'Tormenta creciendo rápido cerca',
            'El radar muestra que la tormenta ganó intensidad en los últimos 20 minutos, '
                'algo que suele pasar antes del granizo.$vecinos');
      }
      return HailAssessment(risk, 'Tormentas fuertes en la zona',
          'Hay celdas intensas cerca. Por ahora el riesgo de granizo es bajo; seguimos mirando.$vecinos');
    case HailRisk.moderate:
      return HailAssessment(risk, 'Posible granizo en tu zona',
          'Hay tormentas con potencial de granizo cerca. Si podés, poné el auto bajo techo.$vecinos');
    case HailRisk.high:
      return HailAssessment(risk, 'Granizo probable',
          'Tormenta intensa en o cerca de tu ubicación. Buscá refugio y proteger el auto.$vecinos');
    case HailRisk.extreme:
      return HailAssessment(risk, 'Granizo severo inminente',
          'Celda muy intensa sobre tu zona. Resguardate ya, lejos de ventanas.$vecinos');
  }
}

bool assessHeavyRain(WeatherSnapshot w, RadarReading radar) {
  final next = w.hours.take(3).map((h) => h.precipMm);
  final peak = next.fold<double>(w.precip, (m, v) => math.max(m, v));
  return peak >= 10 || (radar.available && radar.maxDbzNear >= 45);
}

/// Riesgo de granizo de una hora puntual, según el pronóstico.
HailRisk hourRisk(HourPoint h) {
  final thunder = h.code == 95 || h.code == 96 || h.code == 99;
  final hail = h.code == 96 || h.code == 99;
  var l = 0;
  if (hail) {
    l = h.cape >= 2500 ? 3 : 2;
  } else if (thunder && h.cape >= 2000) {
    l = 2;
  } else if (thunder) {
    l = 1;
  } else if (h.cape >= 1500 && h.precipProb >= 40) {
    l = 1;
  }
  return HailRisk.values[l];
}
