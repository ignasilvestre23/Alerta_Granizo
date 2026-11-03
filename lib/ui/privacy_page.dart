import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../services/reports_api.dart';

const kContactEmail = 'TU_MAIL@ejemplo.com'; // poné tu mail real

const _sections = <(String, String)>[
  (
    'Qué datos usa la app',
    'Tu ubicación, solo con la app abierta, para mostrar el pronóstico y el radar de tu zona. '
        'La última ubicación se guarda en tu teléfono para avisarte aunque la app esté cerrada. '
        'La app no usa tu ubicación en segundo plano y no tiene cuentas: no pide nombre, mail ni teléfono.'
  ),
  (
    'Con quién se comparte',
    'Open-Meteo (pronóstico), RainViewer (radar), NASA GIBS (satélite), el SMN (alertas) y el '
        'proveedor del mapa (MapTiler u OpenStreetMap) reciben tus coordenadas o la zona del mapa '
        'que mirás para devolverte datos.'
  ),
  (
    'Reportes de granizo',
    'Si reportás granizo se envía: tamaño, hora, tu ubicación redondeada a ~1 km, el nombre de tu '
        'localidad, un identificador anónimo aleatorio y, si querés, una nota y una foto. La foto se '
        'achica y se le borran los datos de ubicación del archivo. Otros usuarios cercanos lo ven por '
        '24 horas y se elimina del servidor a los 2 días. Podés borrarlo cuando quieras. Los vecinos '
        'pueden votar si es real o denunciarlo.'
  ),
  (
    'Anuncios',
    'Sin Premium se muestran anuncios de Google AdMob, que puede usar el identificador de publicidad '
        'de tu dispositivo (lo podés restablecer o desactivar en los ajustes de Android). '
        'Con Premium no se cargan anuncios.'
  ),
  (
    'Pagos',
    'Las compras las procesa Google Play. La app no ve ni guarda tus datos de pago; solo guarda en '
        'tu teléfono si Premium está activo.'
  ),
  (
    'Tus derechos',
    'Con el botón de abajo borrás todos tus datos del teléfono y todos tus reportes enviados. '
        'Consultas: $kContactEmail'
  ),
];

class PrivacyPage extends ConsumerWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacidad y datos')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final s in _sections) ...[
            Text(s.$1,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(s.$2,
                style: TextStyle(
                    fontSize: 17, height: 1.45, color: context.muted)),
            const SizedBox(height: 22),
          ],
          FilledButton.icon(
            icon: const Icon(Icons.delete_forever_outlined),
            label: const Text('Borrar mis datos'),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Borrar mis datos'),
                  content: const Text(
                      'Se borran tus lugares, ajustes, reportes e historial, y tus reportes '
                      'enviados al servidor. No se puede deshacer.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    FilledButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Borrar')),
                  ],
                ),
              );
              if (ok != true) return;
              await ReportsApi.deleteAllMine();
              await ref.read(settingsProvider.notifier).reset();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Datos borrados.')));
              }
            },
          ),
        ],
      ),
    );
  }
}
