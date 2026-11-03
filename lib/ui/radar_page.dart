import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../core/format.dart';
import '../core/map_config.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../services/premium_service.dart';
import 'paywall_sheet.dart';
import 'add_place_sheet.dart';

const _lightBlue = Color(0xFF9ED4F7);
const _panel = Color(0xFF1A1D23);

// Invierte colores y rota el tono: deja OpenStreetMap en "modo noche".
const _nightMatrix = <double>[
  0.574,
  -1.430,
  -0.144,
  0,
  255,
  -0.426,
  -0.430,
  -0.144,
  0,
  255,
  -0.426,
  -1.430,
  0.856,
  0,
  255,
  0,
  0,
  0,
  1,
  0,
];

class RadarPage extends ConsumerStatefulWidget {
  const RadarPage({super.key});
  @override
  ConsumerState<RadarPage> createState() => _RadarPageState();
}

class _RadarPageState extends ConsumerState<RadarPage> {
  final _map = MapController();
  Timer? _anim;
  Timer? _refresh;
  int _i = -1;
  bool _playing = true;
  bool _sat = false;
  bool _expand = false;

  List<DateTime> _satTimes() {
    final t = DateTime.now().toUtc().subtract(const Duration(minutes: 40));
    final base =
        DateTime.utc(t.year, t.month, t.day, t.hour, (t.minute ~/ 10) * 10);
    return [
      for (var k = 5; k >= 0; k--) base.subtract(Duration(minutes: 10 * k))
    ];
  }

  String _iso(DateTime t) => '${t.toIso8601String().split('.').first}Z';

  int _count() {
    if (_sat) return 6;
    return ref.read(radarFramesProvider).valueOrNull?.frames.length ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _anim = Timer.periodic(const Duration(milliseconds: 900), (_) {
      if (!_playing || !mounted) return;
      final n = _count();
      if (n == 0) return;
      setState(() => _i = (_i + 1) % n);
    });
    _refresh = Timer.periodic(const Duration(minutes: 5), (_) {
      if (mounted) ref.invalidate(radarFramesProvider);
    });
  }

  @override
  void dispose() {
    _anim?.cancel();
    _refresh?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = ref.watch(dashboardProvider).valueOrNull;
    final fr = ref.watch(radarFramesProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final me = ref.watch(myPositionProvider).valueOrNull;
    final premium = ref.watch(premiumProvider).isPremium;
    if (d == null) return const Center(child: CircularProgressIndicator());

    final satTimes = _satTimes();
    final n = _sat ? satTimes.length : (fr?.frames.length ?? 0);
    final idx = n == 0 ? 0 : ((_i < 0 || _i >= n) ? n - 1 : _i);

    // Todos los cuadros quedan cargados; solo cambia cuál se ve (más fluido).
    final overlays = <Widget>[];
    DateTime? frameTime;
    if (n > 0) {
      if (_sat) {
        for (var k = 0; k < satTimes.length; k++) {
          final iso = _iso(satTimes[k]);
          overlays.add(Opacity(
            opacity: k == idx ? 0.75 : 0.0,
            child: TileLayer(
              key: ValueKey('sat$iso'),
              urlTemplate:
                  'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/GOES-East_ABI_Band13_Clean_Infrared/default/$iso/GoogleMapsCompatible_Level6/{z}/{y}/{x}.png',
              maxNativeZoom: 6,
              panBuffer: 0,
              keepBuffer: 1,
              tileDisplay: const TileDisplay.instantaneous(),
            ),
          ));
        }
        frameTime = satTimes[idx].toLocal();
      } else if (fr != null) {
        for (var k = 0; k < fr.frames.length; k++) {
          final f = fr.frames[k];
          overlays.add(Opacity(
            opacity: k == idx ? 0.8 : 0.0,
            child: TileLayer(
              key: ValueKey('rv${f.path}'),
              urlTemplate: '${fr.host}${f.path}/512/{z}/{x}/{y}/2/1_1.png',
              tileSize: 512,
              zoomOffset: -1,
              maxNativeZoom: 7,
              panBuffer: 0,
              keepBuffer: 1,
              tileDisplay: const TileDisplay.instantaneous(),
            ),
          ));
        }
        frameTime =
            DateTime.fromMillisecondsSinceEpoch(fr.frames[idx].time * 1000);
      }
    }

    final dark = context.isDark;
    Widget base = TileLayer(
      urlTemplate: MapConfig.baseUrl(dark),
      userAgentPackageName: 'com.example.storm_alert',
      tileSize: MapConfig.tileSize,
      zoomOffset: MapConfig.zoomOffset,
      keepBuffer: 3,
    );
    final stormColor = d.radar.nearestStrongKm == null
        ? const Color(0xFF4CAF50)
        : const Color(0xFFF59E0B);

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: LatLng(d.lat, d.lon),
            initialZoom: 7,
            minZoom: 4,
            maxZoom: 11,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            base,
            ...overlays,
            MarkerLayer(markers: [
              for (final p in settings.places.where((p) => !p.isGps))
                Marker(
                  point: LatLng(p.lat!, p.lon!),
                  width: 150,
                  height: 54,
                  alignment: Alignment.topCenter,
                  child: _HomePin(name: p.name),
                ),
              if (me != null)
                Marker(
                  point: LatLng(me.lat, me.lon),
                  width: 44,
                  height: 44,
                  child: const _MeDot(),
                ),
            ]),
          ],
        ),
        // ── Píldoras de arriba
        Positioned(
          top: 14,
          left: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Pill(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.circle, size: 12, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      '${_sat ? 'Satélite' : 'Radar'} · ${frameTime == null ? '--:--' : hh(frameTime)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              _Pill(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.info_outline,
                      size: 20, color: Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      _sat
                          ? 'Nubes por satélite · sin radar'
                          : 'Radar compuesto · sin rayos',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFF59E0B)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              _Pill(
                onTap: () => setState(() => _expand = !_expand),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.circle, size: 12, color: stormColor),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      stormWhere(d.radar),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(_expand ? Icons.expand_less : Icons.expand_more,
                      color: Colors.white70),
                ]),
              ),
              if (_expand)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _Pill(
                    onTap: premium ? null : () => showPaywall(context),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          premium
                              ? Icons.schedule
                              : Icons.workspace_premium_outlined,
                          size: 20,
                          color: kGold),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          premium
                              ? etaText(d.radar, DateTime.now())
                              : 'A qué hora llega, con Premium',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kGold),
                        ),
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),

        Positioned(
          top: 14,
          right: 16,
          child: _RoundBtn(
            color: _panel,
            icon: Icons.add_location_alt_outlined,
            iconColor: _lightBlue,
            onTap: () => showAddPlaceSheet(context, ref),
          ),
        ),

        // ── Botones flotantes
        Positioned(
          right: 16,
          bottom: 200,
          child: Column(
            children: [
              _RoundBtn(
                color: _lightBlue,
                icon: _sat ? Icons.radar : Icons.cloud_outlined,
                iconColor: _panel,
                onTap: () => setState(() {
                  _sat = !_sat;
                  _i = -1;
                }),
              ),
              const SizedBox(height: 14),
              _RoundBtn(
                color: _panel,
                icon: Icons.my_location,
                iconColor: _lightBlue,
                onTap: () => _map.move(
                    me != null ? LatLng(me.lat, me.lon) : LatLng(d.lat, d.lon),
                    8),
              ),
            ],
          ),
        ),
        // ── Panel inferior
        Positioned(
          left: 14,
          right: 14,
          bottom: 14,
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            decoration: BoxDecoration(
                color: _panel.withOpacity(0.96),
                borderRadius: BorderRadius.circular(30)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: n == 0
                          ? null
                          : () => setState(() => _playing = !_playing),
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: const BoxDecoration(
                            color: _lightBlue, shape: BoxShape.circle),
                        child: Icon(_playing ? Icons.pause : Icons.play_arrow,
                            color: _panel, size: 30),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Row(
                        children: [
                          for (var k = 0; k < n; k++)
                            Expanded(
                              child: GestureDetector(
                                onTap: () => setState(() {
                                  _playing = false;
                                  _i = k;
                                }),
                                child: Container(
                                  height: 24,
                                  color: Colors.transparent,
                                  alignment: Alignment.center,
                                  child: Container(
                                    height: 6,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 3),
                                    decoration: BoxDecoration(
                                      color: k <= idx
                                          ? _lightBlue
                                          : const Color(0xFF2E343D),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(frameTime == null ? '--:--' : hh(frameTime),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(_sat ? 'Nubes' : 'Lluvia',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white54)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          gradient: LinearGradient(
                            colors: _sat
                                ? const [
                                    Color(0xFF1B2330),
                                    Color(0xFF6B7280),
                                    Color(0xFFD1D5DB),
                                    Colors.white
                                  ]
                                : const [
                                    Color(0xFF88DDEE),
                                    Color(0xFF00A3E0),
                                    Color(0xFF005588),
                                    Color(0xFFFFEE00),
                                    Color(0xFFFFAA00),
                                    Color(0xFFFF4400),
                                    Color(0xFFC10000),
                                    Color(0xFFFF77FF),
                                  ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(_sat ? 'Tope frío' : 'Severa',
                        style: const TextStyle(
                            fontSize: 16, color: Colors.white54)),
                    IconButton(
                      icon:
                          const Icon(Icons.info_outline, color: Colors.white70),
                      onPressed: () => _info(context),
                    ),
                  ],
                ),
                Text(
                  '${MapConfig.attribution} · RainViewer · NASA GIBS',
                  style: const TextStyle(fontSize: 10, color: Colors.white38),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _info(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cómo leer el mapa'),
        content: const SingleChildScrollView(
          child: Text(
            'RADAR: mide la lluvia. Amarillo, naranja y rojo = lluvia fuerte; '
            'rosa o blanco = tormenta muy intensa, con posible granizo.\n\n'
            'SATÉLITE: infrarrojo del GOES-East (NASA). Más brillante = nube más '
            'alta y fría, típica de tormentas. Llega con ~30 min de demora.\n\n'
            'Esta app no muestra rayos. La hora de llegada es una estimación '
            'según cómo se movió la tormenta en los últimos 20 min.',
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

class _Pill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _Pill({required this.child, this.onTap});
  @override
  Widget build(BuildContext context) => Material(
        color: _panel.withOpacity(0.94),
        borderRadius: BorderRadius.circular(26),
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
            child: child,
          ),
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  final Color color, iconColor;
  final IconData icon;
  final VoidCallback onTap;
  const _RoundBtn({
    required this.color,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Material(
        color: color,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 68,
            height: 68,
            child: Icon(icon, color: iconColor, size: 30),
          ),
        ),
      );
}

class _HomePin extends StatelessWidget {
  final String name;
  const _HomePin({required this.name});

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          const Icon(Icons.location_on, size: 54, color: _lightBlue),
          const Padding(
            padding: EdgeInsets.only(top: 11),
            child: Icon(Icons.home, size: 20, color: _panel),
          ),
          Positioned(
            top: 56,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 140),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _panel.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      );
}

class _MeDot extends StatelessWidget {
  const _MeDot();
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF3B82F6).withOpacity(0.25),
        ),
        alignment: Alignment.center,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: const Color(0xFF3B82F6),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
          ),
        ),
      );
}
