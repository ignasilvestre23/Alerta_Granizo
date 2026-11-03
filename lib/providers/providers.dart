import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/models.dart';
import '../services/alert_checker.dart';
import '../services/dashboard_service.dart';
import '../services/local_store.dart';
import '../services/radar_service.dart';
import '../services/reports_api.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../services/premium_service.dart';
import 'dart:typed_data';

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(AppSettings.initial()) {
    _load();
  }

  Future<void> _load() async {
    state = await SettingsStore.load();
  }

  Future<void> update(AppSettings Function(AppSettings s) fn) async {
    state = fn(state);
    await SettingsStore.save(state);
  }

  Future<void> reset() async {
    await SettingsStore.eraseAll();
    state = AppSettings.initial();
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>(
    (ref) => SettingsNotifier());

final tabProvider = StateProvider<int>((ref) => 0);

/// Se actualiza cada 5 min con la app abierta y avisa si corresponde.
final dashboardProvider = StreamProvider.autoDispose<Dashboard>((ref) async* {
  ref.watch(settingsProvider.select((s) => s.selectedKey));
  final place = ref.read(settingsProvider).selectedPlace;
  var alive = true;
  ref.onDispose(() => alive = false);
  while (alive) {
    try {
      final d = await DashboardService.load(place);
      ref.read(premiumProvider.notifier).refreshIfStale();
      await AlertChecker.maybeNotify(d, ref.read(settingsProvider), place);
      yield d;
    } catch (e, st) {
      yield* Stream.error(e, st);
    }
    await Future.delayed(const Duration(minutes: 5));
  }
});

final radarFramesProvider =
    FutureProvider.autoDispose<RadarFrames?>((ref) => RadarService.frames());

final reportsProvider = FutureProvider.autoDispose<List<LogEntry>>(
    (ref) => LogStore.reports.list());
final historyProvider = FutureProvider.autoDispose<List<LogEntry>>(
    (ref) => LogStore.history.list());

/// Radio elegido en la pantalla Vecinos (30, 100 o 300 km).
final radiusProvider = StateProvider<int>((ref) => 30);

/// Reportes de las últimas 6 horas dentro del radio elegido.
final feedProvider =
    FutureProvider.autoDispose<List<NeighborReport>>((ref) async {
  final d = ref.watch(dashboardProvider).valueOrNull;
  if (d == null) return [];
  final radius = ref.watch(radiusProvider);
  return ReportsApi.nearby(d.lat, d.lon, radiusKm: radius.toDouble());
});

/// Tu posición real (punto azul del mapa). Se actualiza mientras mirás el radar.
final myPositionProvider = StreamProvider.autoDispose<LatLon>((ref) async* {
  try {
    yield await LocationService.current();
    await for (final p in Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 100,
      ),
    )) {
      yield (lat: p.latitude, lon: p.longitude);
    }
  } catch (_) {}
});

/// Foto de un reporte (se pide al mostrarlo y queda guardada en memoria).
final photoProvider = FutureProvider.family<Uint8List?, int>(
    (ref, id) => ReportsApi.fetchPhoto(id));

/// ¿Ya pasó el primer día con la app? (para poder votar)
final canVoteProvider =
    FutureProvider.autoDispose<bool>((ref) => ReportsApi.canVote());

/// Mi voto en un reporte: true = real, false = no, null = no voté.
final myVoteProvider = FutureProvider.autoDispose
    .family<bool?, int>((ref, id) => ReportsApi.myVote(id));
