import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../core/pricing_config.dart';
import '../services/premium_service.dart';
import 'add_place_sheet.dart';
import 'paywall_sheet.dart';
import 'widgets.dart';
import 'privacy_page.dart';
import 'alert_prefs_rows.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final n = ref.read(settingsProvider.notifier);
    final prem = ref.watch(premiumProvider);
    final limit = placeLimit(prem.isPremium);
    String pad(int h) => '${h.toString().padLeft(2, '0')}:00';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        const Text('Ajustes',
            style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        GestureDetector(
          onLongPress: kDebugMode
              ? () => ref.read(premiumProvider.notifier).debugToggle()
              : null,
          child: AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: NavRow(
              icon: Icons.workspace_premium_outlined,
              title: prem.isPremium ? 'Premium activo' : 'Pasate a Premium',
              subtitle: prem.isPremium
                  ? premiumLabel(prem)
                  : 'Cuándo llega la tormenta, 10 lugares y más',
              onTap: prem.isPremium ? null : () => showPaywall(context),
            ),
          ),
        ),
        const SectionTitle('Alertas'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(
            children: [
              NavRow(
                icon: Icons.notifications_none,
                title: 'Avisos de granizo',
                subtitle: 'Radar, alertas del SMN y pronóstico',
                trailing: Switch(
                  value: s.hailOn,
                  onChanged: (v) => n.update((x) => x.copyWith(hailOn: v)),
                ),
              ),
              Divider(height: 1, color: context.track),
              const AlertPrefsRows(),
              Divider(height: 1, color: context.track),
              NavRow(
                icon: Icons.grain,
                title: 'Qué te avisamos',
                subtitle:
                    'Granizo desde riesgo ${HailRisk.values[s.minRisk].label.toLowerCase()}'
                    '${s.heavyRainOn ? ' · lluvia fuerte' : ''}',
                onTap: () => _whatWeNotify(context, ref),
              ),
              Divider(height: 1, color: context.track),
              NavRow(
                icon: Icons.nightlight_outlined,
                title: 'De noche',
                subtitle: !prem.isPremium
                    ? 'Silencio de 23:00 a 07:00'
                    : (s.quietOn
                        ? 'Silencio de ${pad(s.quietStart)} a ${pad(s.quietEnd)}'
                        : 'Sin silencio nocturno'),
                onTap: () => _quiet(context, ref),
              ),
            ],
          ),
        ),
        SectionTitle('Mis lugares (${s.places.length}/$limit)',
            trailing: TextButton.icon(
              onPressed: s.places.length < limit
                  ? () => showAddPlaceSheet(context, ref)
                  : (prem.isPremium ? null : () => showPaywall(context)),
              icon: const Icon(Icons.add),
              label: const Text('Agregar', style: TextStyle(fontSize: 17)),
            )),
        for (var i = 0; i < s.places.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AppCard(
              onTap: () => _placeOptions(context, ref, i),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(s.places[i].name,
                            style: const TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(s.places[i].alerts ? 'Con avisos' : 'Sin avisos',
                            style:
                                TextStyle(fontSize: 17, color: context.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: context.muted),
                ],
              ),
            ),
          ),
        const SectionTitle('Apariencia'),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('Sistema')),
              ButtonSegment(value: 1, label: Text('Claro')),
              ButtonSegment(value: 2, label: Text('Oscuro')),
            ],
            selected: {s.themeMode},
            onSelectionChanged: (v) =>
                n.update((x) => x.copyWith(themeMode: v.first)),
          ),
        ),
        const SectionTitle('Más'),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: NavRow(
            icon: Icons.shield_outlined,
            title: 'Privacidad y datos',
            subtitle: 'Qué datos usamos y cómo borrarlos',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PrivacyPage())),
          ),
        ),
        const SizedBox(height: 24),
        Text('FUENTES: Open-Meteo · RainViewer · SMN',
            style: TextStyle(fontSize: 15, color: context.muted)),
        const SizedBox(height: 6),
        Text('Versión 1', style: TextStyle(fontSize: 17, color: context.muted)),
      ],
    );
  }

  void _whatWeNotify(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final s = ref.watch(settingsProvider);
        final n = ref.read(settingsProvider.notifier);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Qué te avisamos',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                const Text('Granizo desde riesgo:'),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('Bajo')),
                    ButtonSegment(value: 2, label: Text('Moderado')),
                    ButtonSegment(value: 3, label: Text('Alto')),
                  ],
                  selected: {
                    s.minRisk < 1 ? 1 : (s.minRisk > 3 ? 3 : s.minRisk)
                  },
                  onSelectionChanged: (v) =>
                      n.update((x) => x.copyWith(minRisk: v.first)),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Lluvia fuerte'),
                  value: s.heavyRainOn,
                  onChanged: (v) => n.update((x) => x.copyWith(heavyRainOn: v)),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _quiet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Consumer(builder: (context, ref, _) {
        final s = ref.watch(settingsProvider);
        final n = ref.read(settingsProvider.notifier);
        if (!ref.watch(premiumProvider).isPremium) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('De noche',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text(
                      'Los avisos se silencian de 23:00 a 07:00 (excepto riesgo extremo). '
                      'Con Premium elegís vos el horario.'),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () {
                      Navigator.pop(context);
                      showPaywall(context);
                    },
                    child: const Text('Elegir mi horario con Premium'),
                  ),
                ],
              ),
            ),
          );
        }
        Future<void> pick(bool start) async {
          final t = await showTimePicker(
            context: context,
            initialTime:
                TimeOfDay(hour: start ? s.quietStart : s.quietEnd, minute: 0),
          );
          if (t == null) return;
          n.update((x) => start
              ? x.copyWith(quietStart: t.hour)
              : x.copyWith(quietEnd: t.hour));
        }

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('De noche',
                    style:
                        TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Silenciar avisos'),
                  value: s.quietOn,
                  onChanged: (v) => n.update((x) => x.copyWith(quietOn: v)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Desde'),
                  trailing:
                      Text('${s.quietStart.toString().padLeft(2, '0')}:00'),
                  onTap: () => pick(true),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Hasta'),
                  trailing: Text('${s.quietEnd.toString().padLeft(2, '0')}:00'),
                  onTap: () => pick(false),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  void _placeOptions(BuildContext context, WidgetRef ref, int i) {
    final s = ref.read(settingsProvider);
    final p = s.places[i];
    final n = ref.read(settingsProvider.notifier);
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(p.name,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: Icon(p.alerts
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined),
              title: Text(p.alerts ? 'Desactivar avisos' : 'Activar avisos'),
              onTap: () {
                n.update((x) {
                  final list = [...x.places];
                  list[i] = list[i].copyWith(alerts: !list[i].alerts);
                  return x.copyWith(places: list);
                });
                Navigator.pop(ctx);
              },
            ),
            if (!p.isGps) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Cambiar nombre'),
                onTap: () async {
                  Navigator.pop(ctx);
                  final name = await askPlaceName(context, p.name);
                  if (name == null) return;
                  n.update((x) {
                    final list = [...x.places];
                    list[i] = list[i].copyWith(name: name);
                    return x.copyWith(places: list);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Eliminar lugar'),
                onTap: () {
                  n.update((x) {
                    final list = [...x.places]..removeAt(i);
                    return x.copyWith(places: list, selected: 0);
                  });
                  Navigator.pop(ctx);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _erase(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrar tus datos'),
        content: const Text(
            'Se borran tus lugares, ajustes, reportes e historial de este teléfono.\n\n'
            'Los reportes de granizo que ya enviaste quedan en el servidor de forma '
            'anónima (ubicación aproximada de ~1 km, sin tu nombre) y se borran solos '
            'con el tiempo. Para el pronóstico se consulta Open-Meteo, RainViewer y '
            'el SMN con tu ubicación.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              await ref.read(settingsProvider.notifier).reset();
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Borrar'),
          ),
        ],
      ),
    );
  }
}
