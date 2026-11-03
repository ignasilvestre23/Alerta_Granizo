import 'package:home_widget/home_widget.dart';
import '../core/format.dart';
import '../models/models.dart';

/// Package de tu MainActivity.kt (sin el nombre de la clase).
/// Ejemplo: 'com.tuapp.alertagranizo'
const kWidgetPackage = 'com.tuapp.storm_alert';

String _emoji(int c) {
  if (c == 0) return '☀️';
  if (c == 1) return '🌤️';
  if (c == 2) return '⛅';
  if (c == 3) return '☁️';
  if (c == 45 || c == 48) return '🌫️';
  if (c >= 51 && c <= 67) return '🌧️';
  if (c >= 71 && c <= 77) return '❄️';
  if (c >= 80 && c <= 82) return '🌦️';
  if (c >= 95) return '⛈️';
  return '☁️';
}

class WidgetService {
  static Future<void> update(Dashboard d, {required bool premium}) async {
    try {
      final w = d.weather;
      final r = d.radar;
      final now = DateTime.now();
      Future<void> s(String k, String v) =>
          HomeWidget.saveWidgetData<String>(k, v);

      // Línea de tormenta
      final km = r.nearestStrongKm;
      String storm;
      if (!r.available || km == null) {
        storm = 'Sin tormenta en camino';
      } else if (km <= 10) {
        storm = 'Tormenta sobre tu zona';
      } else if (r.approaching && r.etaMin != null && r.etaMin! > 0) {
        final arrival = now.add(Duration(minutes: r.etaMin!.round()));
        storm = '${stormWhere(r)} · ${hh(arrival)}';
      } else {
        storm = '${stormWhere(r)}, sin acercarse';
      }

      final riskShort = d.hail.risk == HailRisk.none
          ? 'Sin granizo'
          : 'Granizo ${d.hail.risk.label.toLowerCase()}';

      // Widget de riesgo (3x2)
      await s('r_place', d.placeName);
      await s('r_label', d.hail.risk.label);
      await s('r_headline', d.hail.headline);
      await s('r_storm', storm);
      await s('r_time', hh(now));
      await HomeWidget.saveWidgetData<int>('r_idx', d.hail.risk.index);

      // Widget de clima (4x2)
      await s('c_place', d.placeName);
      await s('c_icon', _emoji(w.code));
      await s('c_temp', '${w.temp.round()}°');
      await s('c_cond', codeLabel(w.code));
      await s('c_range', 'Máx ${w.tMax.round()}° · Mín ${w.tMin.round()}°');
      await s('c_risk', riskShort);
      await s('c_time', hh(now));
      await HomeWidget.saveWidgetData<int>('c_idx', d.hail.risk.index);

      for (var i = 0; i < 5; i++) {
        final h = w.hours.length > i ? w.hours[i] : null;
        await s('h${i}_l', h == null ? '' : (i == 0 ? 'Ahora' : '$i h'));
        await s('h${i}_e', h == null ? '' : _emoji(h.code));
        await s('h${i}_t', h == null ? '' : '${h.temp.round()}°');

        final day = w.days.length > i ? w.days[i] : null;
        await s(
            'd${i}_l',
            day == null
                ? ''
                : (i == 0
                    ? 'Hoy'
                    : i == 1
                        ? 'Mañ.'
                        : cap(weekday(day.date).substring(0, 3))));
        await s('d${i}_e', day == null ? '' : _emoji(day.code));
        await s('d${i}_t', day == null ? '' : '${day.tMax.round()}°');
        await s('d${i}_m', day == null ? '' : '${day.tMin.round()}°');
      }

      await HomeWidget.updateWidget(
          qualifiedAndroidName: '$kWidgetPackage.RiskWidgetProvider');
      await HomeWidget.updateWidget(
          qualifiedAndroidName: '$kWidgetPackage.ClimaWidgetProvider');
    } catch (_) {}
  }
}
