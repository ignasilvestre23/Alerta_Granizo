import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../services/alert_prefs.dart';
import '../services/notification_service.dart';
import 'widgets.dart';

class AlertPrefsRows extends ConsumerWidget {
  const AlertPrefsRows({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(alertPrefsProvider);
    final n = ref.read(alertPrefsProvider.notifier);
    return Column(
      children: [
        NavRow(
          icon: Icons.thunderstorm_outlined,
          title: 'Tormenta acercándose',
          subtitle: 'Aviso cuando una tormenta intensa viene hacia tu zona',
          trailing: Switch(value: p.storm, onChanged: n.setStorm),
        ),
        Divider(height: 1, color: context.track),
        NavRow(
          icon: Icons.ac_unit,
          title: 'Granizo inminente',
          subtitle: 'Aviso unos 20 minutos antes (estimado)',
          trailing: Switch(value: p.imminent, onChanged: n.setImminent),
        ),
        Divider(height: 1, color: context.track),
        NavRow(
          icon: Icons.thermostat,
          title: 'Temperatura en notificaciones',
          subtitle: 'Muestra el clima y las tormentas cercanas',
          trailing: Switch(
            value: p.temp,
            onChanged: (v) async {
              await n.setTemp(v);
              ref.invalidate(dashboardProvider);
            },
          ),
        ),
        if (kDebugMode) ...[
          Divider(height: 1, color: context.track),
          NavRow(
            icon: Icons.bug_report_outlined,
            title: 'Probar aviso (solo en pruebas)',
            subtitle: 'Envía un aviso de granizo inminente de ejemplo',
            onTap: () => NotificationService.showImminent(
              9001,
              '🧊 ¡Granizo inminente en Casa!',
              'Puede llegar en ~20 min, viene del noroeste. Guardá el auto y alejate de las ventanas.',
            ),
          ),
        ],
      ],
    );
  }
}
