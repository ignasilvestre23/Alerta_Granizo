import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/pricing_config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/location_service.dart';
import '../services/premium_service.dart';
import '../services/weather_service.dart';

/// Pide un nombre para el lugar (Casa, Trabajo, Campo...).
Future<String?> askPlaceName(BuildContext context, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Nombre del lugar'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            maxLength: 24,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in const ['Casa', 'Trabajo', 'Campo'])
                ActionChip(label: Text(s), onPressed: () => c.text = s),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
        FilledButton(
          onPressed: () {
            final t = c.text.trim();
            Navigator.pop(ctx, t.isEmpty ? null : t);
          },
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
}

Future<void> showAddPlaceSheet(BuildContext context, WidgetRef ref) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (_) => _AddPlace(ref: ref),
  );
}

class _AddPlace extends StatefulWidget {
  final WidgetRef ref;
  const _AddPlace({required this.ref});
  @override
  State<_AddPlace> createState() => _AddPlaceState();
}

class _AddPlaceState extends State<_AddPlace> {
  final _c = TextEditingController();
  List<GeoResult> _res = [];
  bool _loading = false;
  bool _locating = false;

  Future<void> _search() async {
    setState(() => _loading = true);
    try {
      _res = await WeatherService.search(_c.text);
    } catch (_) {
      _res = [];
    }
    if (mounted) setState(() => _loading = false);
  }

  void _add(String name, double lat, double lon) {
    final limit = placeLimit(widget.ref.read(premiumProvider).isPremium);
    widget.ref.read(settingsProvider.notifier).update((s) {
      if (s.places.length >= limit) return s;
      return s.copyWith(
        places: [...s.places, Place(name: name, lat: lat, lon: lon)],
        selected: s.places.length,
      );
    });
    Navigator.pop(context);
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    try {
      final loc = await LocationService.current();
      if (!mounted) return;
      final name = await askPlaceName(context, 'Casa');
      if (name != null && mounted) _add(name, loc.lat, loc.lon);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('No pudimos obtener tu ubicación. Revisá el permiso.')));
      }
    }
    if (mounted) setState(() => _locating = false);
  }

  Future<void> _pick(GeoResult r) async {
    final name = await askPlaceName(context, r.name);
    if (name != null && mounted) _add(name, r.lat, r.lon);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 20, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Agregar lugar',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          FilledButton.tonalIcon(
            onPressed: _locating ? null : _useMyLocation,
            icon: const Icon(Icons.my_location),
            label: Text(_locating ? 'Buscando…' : 'Usar mi ubicación actual'),
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
          const SizedBox(height: 16),
          Text('o buscá una localidad',
              style: TextStyle(fontSize: 14, color: context.muted)),
          const SizedBox(height: 8),
          TextField(
            controller: _c,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Ciudad o localidad',
              suffixIcon: IconButton(
                  icon: const Icon(Icons.search), onPressed: _search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          const SizedBox(height: 8),
          if (_loading) const LinearProgressIndicator(),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final r in _res)
                  ListTile(
                    title: Text(r.name),
                    subtitle: Text(r.admin ?? '',
                        style: TextStyle(color: context.muted)),
                    onTap: () => _pick(r),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
