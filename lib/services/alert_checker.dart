import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import '../core/format.dart';
import '../models/models.dart';
import 'alert_prefs.dart';
import 'dashboard_service.dart';
import 'local_store.dart';
import 'notification_service.dart';
import 'premium_service.dart';
import 'widget_service.dart';

class AlertChecker {
  /// Sin Premium el silencio es fijo de 23:00 a 07:00.
  static bool _inQuiet(AppSettings s, DateTime now, bool premium) {
    final on = premium ? s.quietOn : true;
    final start = premium ? s.quietStart : 23;
    final end = premium ? s.quietEnd : 7;
    if (!on || start == end) return false;
    final h = now.hour;
    return start < end ? (h >= start && h < end) : (h >= start || h < end);
  }

  static bool _isSelected(Place p, AppSettings s) {
    final sel = s.selectedPlace;
    return p.name == sel.name && p.lat == sel.lat && p.lon == sel.lon;
  }

  static bool _cooled(
      SharedPreferences prefs, String key, int minutes, int now) {
    final last = prefs.getInt('${key}_t') ?? 0;
    return now - last > minutes * 60 * 1000;
  }

  static int _m5(double eta) => math.max(5, (eta / 5).round() * 5);

  static String _window(double eta, DateTime now) {
    final margin = math.max(10.0, eta * 0.25);
    final from =
        now.add(Duration(minutes: math.max(0.0, eta - margin).round()));
    final to = now.add(Duration(minutes: (eta + margin).round()));
    return 'entre las ${hh(from)} y las ${hh(to)}';
  }

  static Future<void> _statusNotification(Dashboard d, AlertPrefs ap) async {
    if (!ap.temp) {
      await NotificationService.cancel(NotificationService.statusId);
      return;
    }
    final w = d.weather;
    final wind = w.wind >= 1
        ? 'Viento ${w.wind.round()} km/h del ${compassEs(w.windDir)}'
        : 'Viento calmo';
    var line = '${d.placeName} · $wind';
    if (d.radar.available && d.radar.nearestStrongKm != null) {
      line += '\n⚠️ ${stormWhere(d.radar)}';
    }
    await NotificationService.showStatus(
        '${w.temp.round()}° · ${codeLabel(w.code)}', line);
  }

  /// Avisa si corresponde. Se usa con la app abierta y en segundo plano.
  static Future<void> maybeNotify(
      Dashboard d, AppSettings s, Place place) async {
    final prefs = await SharedPreferences.getInstance();
    final premium = premiumActive(prefs);
    final ap = await AlertPrefs.load();

    // Widgets y notificación de temperatura: solo para el lugar seleccionado.
    if (_isSelected(place, s)) {
      await WidgetService.update(d, premium: premium);
      await _statusNotification(d, ap);
    }

    if (!place.alerts) return;

    final nowDt = DateTime.now();
    final now = nowDt.millisecondsSinceEpoch;
    final risk = d.hail.risk;
    // Por seguridad, el riesgo extremo avisa aunque sea de noche.
    if (risk != HailRisk.extreme && _inQuiet(s, nowDt, premium)) return;

    final pk = '${place.name}_${place.lat}_${place.lon}';
    final r = d.radar;
    final eta = r.etaMin;
    final km = r.nearestStrongKm;
    final dir =
        r.bearingDeg == null ? '' : ', viene del ${compassEs(r.bearingDeg!)}';
    final where = km == null
        ? ''
        : 'a ${km.round()} km${r.bearingDeg == null ? '' : ' al ${compassEs(r.bearingDeg!)}'}';

    // ¿Granizo inminente? (celda fuerte llegando en ~25 min o ya muy cerca)
    final close = r.available &&
        ((r.approaching && eta != null && eta <= 25) ||
            (km != null && km <= 12));
    final imminent =
        ap.imminent && close && risk.index >= HailRisk.moderate.index;

    // --- Granizo según el riesgo (si no hay aviso de "inminente") ---
    if (s.hailOn && risk.index >= s.minRisk && !imminent) {
      final k = 'n_hail_$pk';
      final lastLevel = prefs.getInt('${k}_l') ?? 0;
      if (_cooled(prefs, k, 60, now) || risk.index > lastLevel) {
        await NotificationService.show(
          k.hashCode & 0x7fffffff,
          '🧊 Granizo: riesgo ${risk.label.toLowerCase()} en ${d.placeName}',
          d.hail.detail,
        );
        await prefs.setInt('${k}_t', now);
        await prefs.setInt('${k}_l', risk.index);
        await LogStore.history
            .add(d.placeName, 'Riesgo de granizo ${risk.label.toLowerCase()}');
      }
    }

    // --- Lluvia fuerte ---
    if (s.heavyRainOn && d.heavyRain) {
      final k = 'n_rain_$pk';
      if (_cooled(prefs, k, 60, now)) {
        await NotificationService.show(
          k.hashCode & 0x7fffffff,
          '🌧️ Lluvia fuerte en ${d.placeName}',
          'Se detecta lluvia intensa en tu zona. Cuidado con calles anegadas.',
        );
        await prefs.setInt('${k}_t', now);
      }
    }

    // --- Tormenta creciendo rápido ---
    if (ap.storm && r.available && r.growing && km != null && km <= 60) {
      final k = 'n_grow_$pk';
      if (_cooled(prefs, k, 60, now)) {
        await NotificationService.show(
          k.hashCode & 0x7fffffff,
          '${d.placeName}: Tormenta creciendo rápido cerca',
          'El radar muestra que la tormenta ganó intensidad en los últimos 20 minutos, '
              'algo que suele pasar antes del granizo.',
        );
        await prefs.setInt('${k}_t', now);
        await LogStore.history.add(d.placeName, 'Tormenta creciendo rápido');
      }
    }

    // --- Tormenta acercándose ---
    if (ap.storm &&
        r.available &&
        r.approaching &&
        eta != null &&
        eta > 0 &&
        eta <= 45 &&
        (km ?? 0) > 10) {
      final k = 'n_storm_$pk';
      if (_cooled(prefs, k, 45, now)) {
        final base =
            'Tormenta intensa $where. Podría pasar cerca en unos ${_m5(eta)} min.';
        await NotificationService.show(
          k.hashCode & 0x7fffffff,
          '⛈️ Tormenta acercándose a ${d.placeName}',
          premium
              ? '$base Ventana: ${_window(eta, nowDt)}.'
              : '$base Con Premium ves la ventana horaria y de dónde viene.',
        );
        await prefs.setInt('${k}_t', now);
        await LogStore.history.add(d.placeName, 'Tormenta acercándose');
      }
    }

    // --- Granizo inminente (~20 min antes) ---
    if (imminent) {
      final k = 'n_imm_$pk';
      final lastLevel = prefs.getInt('${k}_l') ?? 0;
      if (_cooled(prefs, k, 30, now) || risk.index > lastLevel) {
        final high = risk.index >= HailRisk.high.index;
        final when = (eta != null && eta > 0)
            ? 'Puede llegar en unos ${_m5(eta)} min${premium ? dir : ''}.'
            : 'Puede llegar en los próximos minutos.';
        await NotificationService.showImminent(
          k.hashCode & 0x7fffffff,
          high
              ? '🧊 ¡Granizo inminente en ${d.placeName}!'
              : '🧊 Posible granizo pronto en ${d.placeName}',
          '$when Guardá el auto y alejate de las ventanas.',
        );
        await prefs.setInt('${k}_t', now);
        await prefs.setInt('${k}_l', risk.index);
        await LogStore.history.add(d.placeName, 'Aviso de granizo inminente');
      }
    }
  }

  /// Chequeo en segundo plano. Si hay una tormenta cerca, programa otra
  /// revisión en 5 minutos (alterna dos nombres para no cancelarse a sí mismo).
  static Future<void> runAll([String task = 'storm-check']) async {
    final s = await SettingsStore.load();
    var watch = false;
    for (final p in s.places) {
      if (!p.alerts && !_isSelected(p, s)) continue;
      try {
        final d = await DashboardService.load(p, background: true);
        await maybeNotify(d, s, p);
        final eta = d.radar.etaMin;
        if (d.radar.available &&
            ((d.radar.approaching && eta != null && eta <= 90) ||
                d.hail.risk.index >= HailRisk.moderate.index)) {
          watch = true;
        }
      } catch (_) {}
    }
    await _scheduleWatch(watch, task);
  }

  static Future<void> _scheduleWatch(bool watch, String current) async {
    try {
      if (watch) {
        final next =
            current == 'storm-watch-a' ? 'storm-watch-b' : 'storm-watch-a';
        await Workmanager().registerOneOffTask(
          next,
          next,
          initialDelay: const Duration(minutes: 5),
          constraints: Constraints(networkType: NetworkType.connected),
          existingWorkPolicy: ExistingWorkPolicy.replace,
        );
      } else {
        await Workmanager().cancelByUniqueName('storm-watch-a');
        await Workmanager().cancelByUniqueName('storm-watch-b');
      }
    } catch (_) {}
  }
}
