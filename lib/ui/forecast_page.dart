import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';

class ForecastPage extends ConsumerWidget {
  const ForecastPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dashboardProvider).valueOrNull;
    final now = DateTime.now();
    return Scaffold(
      body: SafeArea(
        child: d == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 30),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Text('Pronóstico',
                      style:
                          TextStyle(fontSize: 42, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Text(d.placeName,
                      style: TextStyle(fontSize: 22, color: context.muted)),
                  const SizedBox(height: 24),
                  for (var i = 0; i < d.weather.days.length; i++) ...[
                    _DayRow(day: d.weather.days[i], now: now),
                    if (i == 2) ...[
                      Divider(height: 1, color: context.track),
                      Padding(
                        padding: const EdgeInsets.only(top: 22, bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('MÁS ADELANTE',
                                style: TextStyle(
                                    fontSize: 16,
                                    letterSpacing: 1.4,
                                    color: context.muted)),
                            const SizedBox(height: 10),
                            Text(
                              'Del cuarto día en adelante es tendencia: los modelos marcan '
                              'para dónde va el tiempo. El horario y el tamaño del granizo '
                              'los vemos cuando se acerca.',
                              style: TextStyle(
                                  fontSize: 18,
                                  height: 1.4,
                                  color: context.muted),
                            ),
                          ],
                        ),
                      ),
                    ] else if (i < d.weather.days.length - 1)
                      Divider(height: 1, color: context.track),
                  ],
                  const SizedBox(height: 24),
                  Text(
                    'Tormenta: estimación según la inestabilidad del aire y la '
                    'probabilidad de lluvia. No reemplaza las alertas oficiales.',
                    style: TextStyle(
                        fontSize: 14, height: 1.4, color: context.muted),
                  ),
                ],
              ),
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  final DayPoint day;
  final DateTime now;
  const _DayRow({required this.day, required this.now});

  String get _note {
    switch (day.risk) {
      case HailRisk.none:
        return 'Sin tormentas con granizo';
      case HailRisk.low:
        return 'Hay señales de tormentas. Lo vamos afinando a medida que se acerca el día.';
      case HailRisk.moderate:
        return 'Posible granizo. Lo vamos afinando a medida que se acerca el día.';
      case HailRisk.high:
      case HailRisk.extreme:
        return 'Granizo probable. Lo vamos afinando a medida que se acerca el día.';
    }
  }

  String get _rain {
    if (day.precipMm < 0.1) return 'No';
    if (day.precipMm < 1) return '<1 mm';
    return '${day.precipMm.round()} mm';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(cap(dayName(day.date, now)),
                  style: const TextStyle(
                      fontSize: 32, fontWeight: FontWeight.w800)),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: day.risk.color,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(day.risk.label,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w700)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(_note,
              style:
                  TextStyle(fontSize: 18, height: 1.35, color: context.muted)),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Stat('Mín / máx', '${day.tMin.round()}° / ${day.tMax.round()}°',
                  5),
              _Stat('Lluvia', _rain, 4),
              _Stat('Prob. lluvia', '${day.precipProb.round()}%', 5),
              _Stat('Tormenta', '${day.stormProb.round()}%', 5),
            ],
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label, value;
  final int flex;
  const _Stat(this.label, this.value, this.flex);

  @override
  Widget build(BuildContext context) => Expanded(
        flex: flex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: context.muted)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          ],
        ),
      );
}
