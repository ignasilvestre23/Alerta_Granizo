import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../core/pricing_config.dart';
import '../core/server_config.dart';
import '../services/premium_service.dart';
import '../services/reports_api.dart';
import 'add_place_sheet.dart';
import 'paywall_sheet.dart';
import 'history_page.dart';
import 'report_sheet.dart';
import 'widgets.dart';
import 'forecast_page.dart';
import 'ad_card.dart';
import '../services/risk_engine.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dash = ref.watch(dashboardProvider);
    final d = dash.valueOrNull;
    final premium = ref.watch(premiumProvider).isPremium;

    if (d == null) {
      if (dash.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('No pudimos obtener el pronóstico.\n${dash.error}',
                    textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(dashboardProvider),
                  child: const Text('Reintentar'),
                ),
              ],
            ),
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardProvider);
        try {
          await ref.read(dashboardProvider.future);
        } catch (_) {}
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          Text(d.placeName,
              style:
                  const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          _PlaceChips(d: d),
          const SizedBox(height: 22),
          _StatusLine(d: d),

          // ── Pronóstico del día (arriba)
          SectionTitle('Ahora'),
          _NowBlock(d: d),
          const SizedBox(height: 18),
          _HourlyStrip(hours: d.weather.hours),
          const SizedBox(height: 10),
          Text(
              'Lluvia esperada en milímetros por hora y probabilidad de que llueva. El punto de color marca riesgo de granizo en esa hora.',
              style:
                  TextStyle(fontSize: 16, color: context.muted, height: 1.4)),

          // ── Riesgo de granizo (abajo)
          const SizedBox(height: 34),
          Text('Riesgo de granizo',
              style: TextStyle(fontSize: 19, color: context.muted)),
          Text(d.hail.risk.label,
              style: const TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  height: 1.05,
                  letterSpacing: -1.5)),
          const SizedBox(height: 18),
          _RiskBar(risk: d.hail.risk),
          const SizedBox(height: 28),
          Text(d.hail.headline,
              style:
                  const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(d.hail.detail,
              style:
                  TextStyle(fontSize: 19, height: 1.4, color: context.muted)),
          _StormCard(d: d),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: AppCard(
                  onTap: () =>
                      showReportSheet(context, d.placeName, d.lat, d.lon),
                  padding:
                      const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.grain),
                      SizedBox(width: 14),
                      Text('Reportar granizo',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    shape: BoxShape.circle, color: Color(0xFF7CC4F5)),
                child: const Text('🧊', style: TextStyle(fontSize: 34)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          NavRow(
            icon: Icons.calendar_month_outlined,
            title: 'Historial de la temporada',
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (!premium)
                const Icon(Icons.workspace_premium_outlined, color: kGold),
              Icon(Icons.chevron_right, color: context.muted),
            ]),
            onTap: () => premium
                ? Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryPage()))
                : showPaywall(context),
          ),
          _NeighborsBlock(d: d),
          SectionTitle('Alertas de peligro',
              trailing: TextButton.icon(
                onPressed: () =>
                    premium ? _showAllAlerts(context, d) : showPaywall(context),
                icon: premium
                    ? const SizedBox.shrink()
                    : const Icon(Icons.workspace_premium_outlined,
                        color: kGold),
                label: const Text('Ver todas', style: TextStyle(fontSize: 15)),
              )),
          _AlertsBlock(
              d: d, limit: premium ? null : PricingConfig.freeAlertLimit),
          const SizedBox(height: 34),
          _RiskTimeline(d: d),
          SectionTitle('Próximos días',
              trailing: TextButton(
                onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ForecastPage())),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Detalle', style: TextStyle(fontSize: 15)),
                  Icon(Icons.chevron_right, size: 20),
                ]),
              )),
          _DaysBlock(days: d.weather.days),
          const AdCard(),
          const SizedBox(height: 28),
          Divider(color: context.track),
          NavRow(
            icon: Icons.info_outline,
            title: 'FUENTES Y AVISO',
            onTap: () => _showSources(context),
          ),
        ],
      ),
    );
  }

  void _showAllAlerts(BuildContext context, Dashboard d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          shrinkWrap: true,
          children: [
            const Text('Alertas vigentes y próximas',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _AlertsBlock(d: d),
          ],
        ),
      ),
    );
  }

  void _showSources(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Fuentes y aviso'),
        content: const SingleChildScrollView(
          child: Text(
            'Pronóstico: Open-Meteo (modelos numéricos).\n'
            'Radar: RainViewer.\n'
            'Alertas y observaciones: Servicio Meteorológico Nacional (SMN).\n\n'
            'El riesgo de granizo es una ESTIMACIÓN que combina estas fuentes. '
            'No detecta granizo real ni reemplaza las alertas oficiales. '
            'Ante una alerta del SMN o Defensa Civil, seguí sus indicaciones.',
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }
}

class _PlaceChips extends ConsumerWidget {
  final Dashboard d;
  const _PlaceChips({required this.d});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final premium = ref.watch(premiumProvider).isPremium;
    final limit = placeLimit(premium);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var i = 0; i < s.places.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _Chip(
                label: s.places[i].isGps
                    ? (i == s.selected ? d.placeName : 'Mi ubicación')
                    : s.places[i].name,
                gps: s.places[i].isGps,
                selected: i == s.selected,
                onTap: () => notifier.update((x) => x.copyWith(selected: i)),
              ),
            ),
          if (s.places.length < limit || !premium)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: () => s.places.length < limit
                  ? showAddPlaceSheet(context, ref)
                  : showPaywall(context),
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: context.track, width: 1.5),
                ),
                child: Icon(Icons.add, color: context.muted),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool gps;
  final bool selected;
  final VoidCallback onTap;
  const _Chip({
    required this.label,
    required this.gps,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = selected ? context.fg : context.cardBg;
    final fg = selected ? context.bg : context.fg;
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(30),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (gps) ...[
                Icon(Icons.my_location, size: 22, color: fg),
                const SizedBox(width: 10),
              ],
              Text(label,
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusLine extends StatelessWidget {
  final Dashboard d;
  const _StatusLine({required this.d});

  @override
  Widget build(BuildContext context) {
    final src = <String>['Pronóstico'];
    if (d.radar.available) src.add('radar');
    if (d.smn.available) src.add('SMN');
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: d.radar.available ? const Color(0xFF4CAF50) : context.muted,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text('${src.join(' · ')} · ${ago(d.fetchedAt)}',
              style: TextStyle(fontSize: 19, color: context.muted)),
        ),
      ],
    );
  }
}

class _RiskBar extends StatelessWidget {
  final HailRisk risk;
  const _RiskBar({required this.risk});

  @override
  Widget build(BuildContext context) {
    const names = ['Bajo', 'Moderado', 'Alto', 'Extremo'];
    return Column(
      children: [
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Container(
                  height: 8,
                  margin: EdgeInsets.only(right: i < 3 ? 12 : 0),
                  decoration: BoxDecoration(
                    color: i < risk.index ? risk.color : context.track,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (var i = 0; i < 4; i++)
              Expanded(
                child: Text(names[i],
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: risk.index == i + 1
                          ? FontWeight.w800
                          : FontWeight.w400,
                      color: risk.index == i + 1 ? context.fg : context.muted,
                    )),
              ),
          ],
        ),
      ],
    );
  }
}

class _AlertsBlock extends StatelessWidget {
  final Dashboard d;
  final int? limit; // null = todas
  const _AlertsBlock({required this.d, this.limit});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final cards = <MapEntry<int, Widget>>[];

    final near = d.neighbors
        .where((r) => r.distKm <= 20 && now.difference(r.time).inMinutes <= 60);
    final devices = near.map((r) => r.deviceId).toSet().length;
    if (devices > 0) {
      cards.add(MapEntry(
        2,
        _alertCard(
          context,
          const Color(0xFFFFC83D),
          'Granizo reportado cerca',
          devices == 1
              ? '1 vecino reportó granizo cerca'
              : '$devices vecinos reportaron granizo cerca',
          ['Atención · Reportes de vecinos'],
        ),
      ));
    }

    final r = d.radar;
    final km = r.nearestStrongKm;
    if (r.available && km != null) {
      final dir = r.bearingDeg == null ? '' : ' al ${compassEs(r.bearingDeg!)}';
      final over = km <= 10;
      final eta = r.etaMin;
      final soon = (r.approaching && eta != null && eta > 0)
          ? ', podría pasar cerca en unos ${math.max(5, (eta / 5).round() * 5)} min'
          : '';
      final hailish = d.hail.risk.index >= HailRisk.moderate.index;
      cards.add(MapEntry(
        over ? 4 : (hailish ? 3 : 2),
        _alertCard(
          context,
          over ? const Color(0xFFFF8A3D) : const Color(0xFFFFC83D),
          over
              ? 'Tormenta intensa sobre tu zona'
              : (hailish
                  ? 'Tormenta con posible granizo'
                  : 'Tormenta intensa cerca'),
          over
              ? 'Hay una celda muy intensa encima tuyo'
              : 'A ${km.round()} km$dir$soon',
          ['Atención · Detectada por radar'],
        ),
      ));
    }

    for (final a in d.smn.alerts) {
      String range = '';
      if (a.start != null && a.end != null) {
        range = ' · ${cap(dayName(a.start!, now))} ${a.start!.hour} h a '
            '${dayName(a.end!, now)} ${a.end!.hour} h';
      }
      cards.add(MapEntry(
        3 + a.color.index,
        _alertCard(
          context,
          a.color.color,
          a.title,
          a.description,
          ['En tu zona', 'Alerta ${a.color.label}$range'],
        ),
      ));
    }

    if (cards.isEmpty) {
      return AppCard(
        child: Text(
          d.smn.available
              ? 'Sin alertas vigentes para tu zona.'
              : 'No pudimos consultar las alertas del SMN ahora.',
          style: TextStyle(fontSize: 17, color: context.muted),
        ),
      );
    }

    cards.sort((x, y) => y.key.compareTo(x.key)); // las más graves primero
    final shown = limit == null ? cards : cards.take(limit!).toList();
    final hidden = cards.length - shown.length;
    return Column(
      children: [
        for (final c in shown) c.value,
        if (hidden > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => showPaywall(context),
              child: Text(
                  'Ver $hidden ${hidden == 1 ? 'alerta' : 'alertas'} más',
                  style: const TextStyle(fontSize: 17)),
            ),
          ),
      ],
    );
  }

  Widget _alertCard(BuildContext context, Color dot, String title, String body,
      List<String> footer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.all(22),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  if (body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(body,
                        style: const TextStyle(fontSize: 19, height: 1.35)),
                  ],
                  for (final f in footer) ...[
                    const SizedBox(height: 6),
                    Text(f,
                        style: TextStyle(fontSize: 18, color: context.muted)),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StormCard extends ConsumerWidget {
  final Dashboard d;
  const _StormCard({required this.d});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = d.radar;
    final km = r.nearestStrongKm;
    if (!r.available || km == null) return const SizedBox.shrink();
    final over = km <= 10;
    final e = r.etaMin ?? 0;
    final hasEta = r.approaching && e > 0;
    if (!over && !hasEta) return const SizedBox.shrink(); // no se acerca

    final premium = ref.watch(premiumProvider).isPremium;
    final now = DateTime.now();
    final mins = math.max(5, (e / 5).round() * 5);
    final dir = r.bearingDeg == null ? '' : ' al ${compassEs(r.bearingDeg!)}';
    const yellow = Color(0xFFEBD95C);

    String windowText() {
      final margin = math.max(10.0, e * 0.25);
      final from =
          now.add(Duration(minutes: math.max(0.0, e - margin).round()));
      final to = now.add(Duration(minutes: (e + margin).round()));
      final from2 = r.bearingDeg == null
          ? ''
          : ' · viene del ${compassEs(r.bearingDeg!)}';
      final sp = r.speedKmh == null ? '' : ' · ${r.speedKmh!.round()} km/h';
      return 'Entre las ${hh(from)} y las ${hh(to)}$from2$sp';
    }

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: AppCard(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                      over ? 'TORMENTA SOBRE TU ZONA' : 'TORMENTA EN CAMINO',
                      style: TextStyle(
                          fontSize: 15,
                          letterSpacing: 1.4,
                          color: context.muted)),
                ),
                if (!over)
                  Text('en unos $mins min',
                      style: TextStyle(fontSize: 17, color: context.muted)),
              ],
            ),
            if (!over) ...[
              const SizedBox(height: 8),
              Text(hh(now.add(Duration(minutes: mins))),
                  style: const TextStyle(
                      fontSize: 44, fontWeight: FontWeight.w800)),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                      color: yellow, shape: BoxShape.circle),
                  child: const Icon(Icons.bolt, color: Color(0xFF1A1D23)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LayoutBuilder(builder: (context, box) {
                    final n = math.max(3, (box.maxWidth / 14).floor());
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < n; i++)
                          Container(width: 8, height: 3, color: yellow),
                      ],
                    );
                  }),
                ),
                const Icon(Icons.chevron_right, color: yellow),
                const Icon(Icons.location_on_outlined,
                    color: Color(0xFF7CC4F5), size: 30),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(over ? 'sobre tu zona' : 'a ${km.round()} km$dir',
                      style: TextStyle(fontSize: 17, color: context.muted)),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(d.placeName,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
                'Hora aproximada, según cómo se movió la tormenta en los últimos 20 minutos.',
                style: TextStyle(
                    fontSize: 16, height: 1.35, color: context.muted)),
            const SizedBox(height: 12),
            if (premium && !over)
              Text(windowText(),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: kGold))
            else if (!premium)
              InkWell(
                onTap: () => showPaywall(context),
                child: const Row(
                  children: [
                    Icon(Icons.workspace_premium_outlined,
                        color: kGold, size: 22),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                          'Ventana horaria y de dónde viene, con Premium',
                          style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: kGold)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NeighborsBlock extends StatelessWidget {
  final Dashboard d;
  const _NeighborsBlock({required this.d});

  @override
  Widget build(BuildContext context) {
    if (!ServerConfig.enabled || d.neighbors.isEmpty)
      return const SizedBox.shrink();
    final r = d.neighbors.first;
    final km = d.radar.nearestStrongKm;
    final confirmed = d.radar.available && km != null && km <= 30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle('Reportes de vecinos'),
        AppCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 70,
                height: 70,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF7CC4F5).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Text('🧊', style: TextStyle(fontSize: 34)),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Granizo ${sizeTitle(r.size)}',
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('a ${r.distKm.round()} km · ${ago(r.time)}',
                        style: TextStyle(fontSize: 18, color: context.muted)),
                    if (confirmed) ...[
                      const SizedBox(height: 6),
                      const Row(children: [
                        Icon(Icons.check, size: 20, color: Color(0xFF7CC4F5)),
                        SizedBox(width: 6),
                        Text('Confirmado por radar',
                            style: TextStyle(
                                fontSize: 18, color: Color(0xFF7CC4F5))),
                      ]),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NowBlock extends StatelessWidget {
  final Dashboard d;
  const _NowBlock({required this.d});

  @override
  Widget build(BuildContext context) {
    final w = d.weather;
    final o = d.smn.obs;
    final useObs = o?.temp != null;
    final temp = useObs ? (o?.temp ?? w.temp) : w.temp;
    final hum = useObs ? (o?.humidity ?? w.humidity) : w.humidity;
    final wind = useObs ? (o?.wind ?? w.wind) : w.wind;
    final obsTime = o?.time;
    final src = useObs
        ? 'Estación del SMN${obsTime != null ? ' · ${ago(obsTime)}' : ''}'
        : 'Pronóstico · Open-Meteo';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${temp.round()}°',
                style: const TextStyle(
                    fontSize: 104,
                    fontWeight: FontWeight.w800,
                    height: 1,
                    letterSpacing: -4)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(codeLabel(w.code),
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  Text('Máx ${w.tMax.round()}° · Mín ${w.tMin.round()}°',
                      style: TextStyle(fontSize: 19, color: context.muted)),
                  Text('Sensación ${w.feels.round()}°',
                      style: TextStyle(fontSize: 19, color: context.muted)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (wind >= 1)
              Transform.rotate(
                angle: (w.windDir + 180) * math.pi / 180,
                child: Icon(Icons.navigation, size: 22, color: context.muted),
              )
            else
              Icon(Icons.air, size: 22, color: context.muted),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                wind >= 1
                    ? 'Viento ${wind.round()} km/h del ${compassEs(w.windDir)}'
                    : 'Viento calmo',
                style: TextStyle(fontSize: 19, color: context.muted),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('Ráfagas ${w.gust.round()} km/h · Humedad ${hum.round()}%',
            style: TextStyle(fontSize: 19, color: context.muted)),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(Icons.circle, size: 11, color: Color(0xFF7CC4F5)),
            const SizedBox(width: 10),
            Text(src, style: TextStyle(fontSize: 18, color: context.muted)),
          ],
        ),
      ],
    );
  }
}

class _HourlyStrip extends StatelessWidget {
  final List<HourPoint> hours;
  const _HourlyStrip({required this.hours});

  @override
  Widget build(BuildContext context) {
    final items = hours.take(24).toList();
    if (items.isEmpty) return const SizedBox.shrink();
    const w = 64.0;
    final maxMm = items.fold<double>(0.5, (m, h) => math.max(m, h.precipMm));
    final dayStart = [
      for (var i = 0; i < items.length; i++) i > 0 && items[i].time.hour == 0,
    ];
    final total = items.length * w;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: total,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _DaySeparators(dayStart, w, context.track),
              ),
            ),
            Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      SizedBox(
                        width: w,
                        child: Column(
                          children: [
                            Text(
                              dayStart[i]
                                  ? cap(weekday(items[i].time).substring(0, 3))
                                  : (i == 0
                                      ? 'Ahora'
                                      : '${items[i].time.hour} h'),
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: (i == 0 || dayStart[i])
                                    ? FontWeight.w800
                                    : FontWeight.w400,
                                color: (i == 0 || dayStart[i])
                                    ? context.fg
                                    : context.muted,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Icon(weatherIcon(items[i].code),
                                size: 30, color: context.muted),
                            const SizedBox(height: 10),
                            Text('${items[i].temp.round()}°',
                                style: const TextStyle(
                                    fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: hourRisk(items[i]).index == 0
                                    ? Colors.transparent
                                    : hourRisk(items[i]).color,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Transform.rotate(
                              angle: (items[i].windDir + 180) * math.pi / 180,
                              child: Icon(Icons.navigation,
                                  size: 16, color: context.muted),
                            ),
                            Text('${items[i].windSpeed.round()}',
                                style: TextStyle(
                                    fontSize: 12, color: context.muted)),
                          ],
                        ),
                      ),
                  ],
                ),
                SizedBox(
                  height: 80,
                  width: total,
                  child: CustomPaint(
                    painter: _TempLine(
                      temps: items.map((e) => e.temp).toList(),
                      w: w,
                      line: context.muted,
                      fill: context.bg,
                      stroke: context.fg,
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final h in items)
                      SizedBox(
                        width: w,
                        child: Center(
                          child: Text('${h.precipProb.round()}%',
                              style: TextStyle(
                                  fontSize: 15, color: context.muted)),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  height: 96,
                  child: Row(
                    children: [
                      for (final h in items)
                        SizedBox(
                          width: w,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              if (h.precipMm >= 0.1)
                                Text(mm(h.precipMm),
                                    style: TextStyle(
                                        fontSize: 13, color: context.muted)),
                              const SizedBox(height: 4),
                              Container(
                                width: 28,
                                height: h.precipMm < 0.05
                                    ? 0
                                    : 6 + 48 * (h.precipMm / maxMm),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF7C9DB8),
                                  borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(5)),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                Container(height: 1, color: context.track.withOpacity(0.7)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DaySeparators extends CustomPainter {
  final List<bool> starts;
  final double w;
  final Color color;
  _DaySeparators(this.starts, this.w, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var i = 0; i < starts.length; i++) {
      if (starts[i]) {
        canvas.drawLine(Offset(w * i, 0), Offset(w * i, size.height), p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _TempLine extends CustomPainter {
  final List<double> temps;
  final double w;
  final Color line, fill, stroke;
  _TempLine({
    required this.temps,
    required this.w,
    required this.line,
    required this.fill,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (temps.isEmpty) return;
    final mn = temps.reduce(math.min);
    final mx = temps.reduce(math.max);
    final range = (mx - mn).abs() < 0.5 ? 1.0 : mx - mn;
    const pad = 16.0;
    final h = size.height - pad * 2;
    final pts = <Offset>[
      for (var i = 0; i < temps.length; i++)
        Offset(w * i + w / 2, pad + (1 - (temps[i] - mn) / range) * h),
    ];
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5);
    for (final p in pts) {
      canvas.drawCircle(p, 6, Paint()..color = fill);
      canvas.drawCircle(
          p,
          6,
          Paint()
            ..color = stroke
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _DaysBlock extends StatelessWidget {
  final List<DayPoint> days;
  const _DaysBlock({required this.days});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hailDays = days.where((d) => d.hail).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < days.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              children: [
                SizedBox(
                  width: 130,
                  child: Text(cap(dayName(days[i].date, now)),
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                ),
                Icon(weatherIcon(days[i].code), size: 32, color: context.muted),
                const SizedBox(width: 16),
                Expanded(
                  child: days[i].risk.index > 0
                      ? Row(
                          children: [
                            Container(
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                color: days[i].risk.color,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(days[i].risk.label,
                                style: const TextStyle(fontSize: 19)),
                          ],
                        )
                      : Text(
                          days[i].precipMm >= 0.1
                              ? '${mm(days[i].precipMm)} mm de lluvia'
                              : '',
                          style: TextStyle(fontSize: 18, color: context.muted),
                        ),
                ),
                Text('${days[i].tMin.round()}°  ',
                    style: TextStyle(fontSize: 22, color: context.muted)),
                Text('${days[i].tMax.round()}°',
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          if (i < days.length - 1) Divider(height: 1, color: context.track),
        ],
        const SizedBox(height: 18),
        Text(
          hailDays.isEmpty
              ? 'Sin riesgo de granizo en toda la semana.'
              : 'Posible granizo: ${hailDays.map((d) => dayName(d.date, now)).join(', ')}.',
          style: TextStyle(fontSize: 19, color: context.muted),
        ),
      ],
    );
  }
}

class _RiskTimeline extends StatelessWidget {
  final Dashboard d;
  const _RiskTimeline({required this.d});

  @override
  Widget build(BuildContext context) {
    final hours = d.weather.hours.take(24).toList();
    if (hours.isEmpty) return const SizedBox.shrink();
    final risks = <HailRisk>[
      for (var i = 0; i < hours.length; i++)
        (i == 0 && d.hail.risk.index > hourRisk(hours[i]).index)
            ? d.hail.risk
            : hourRisk(hours[i]),
    ];
    var peak = 0;
    for (var i = 1; i < risks.length; i++) {
      if (risks[i].index > risks[peak].index) peak = i;
    }
    final peakText = risks[peak].index == 0
        ? 'Sin riesgo'
        : 'Pico a las ${hours[peak].time.hour} h · ${risks[peak].label}';
    const dark = Color(0xFF262B33);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('Próximas 24 horas',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(peakText,
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 16, color: context.muted)),
            ),
          ],
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 84,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final r in risks)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: 8.0 + r.index * 18.0,
                      decoration: BoxDecoration(
                        color: r.index == 0 ? dark : r.color,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(builder: (context, box) {
          final n = hours.length;
          return SizedBox(
            height: 22,
            child: Stack(
              children: [
                for (var i = 0; i < n; i += 4)
                  Positioned(
                    left: box.maxWidth * i / n,
                    child: Text('${hours[i].time.hour} h',
                        style: TextStyle(fontSize: 14, color: context.muted)),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 14),
        Wrap(
          spacing: 18,
          runSpacing: 8,
          children: [
            for (final r in HailRisk.values.skip(1))
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: r.color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(r.label, style: const TextStyle(fontSize: 16)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}
