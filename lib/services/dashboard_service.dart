import '../models/models.dart';
import 'location_service.dart';
import 'radar_service.dart';
import 'reports_api.dart';
import 'risk_engine.dart';
import 'smn_service.dart';
import 'weather_service.dart';

class DashboardService {
  static Future<Dashboard> load(Place place, {bool background = false}) async {
    double lat;
    double lon;
    var name = place.name;
    if (place.isGps) {
      final loc = background
          ? await LocationService.forBackground()
          : await LocationService.current();
      lat = loc.lat;
      lon = loc.lon;
      name = (background ? null : await LocationService.placeName(lat, lon)) ??
          'Mi ubicación';
    } else {
      lat = place.lat!;
      lon = place.lon!;
    }

    final wf = WeatherService().fetch(lat, lon);
    final sf = SmnService().fetch(lat, lon);
    final rf = RadarService().read(lat, lon);
    final nf = ReportsApi.nearby(lat, lon);
    final w = await wf;
    final smn = await sf;
    final radar = await rf;
    final neighbors = await nf;
    final now = DateTime.now();

    final recent = neighbors.where(
        (r) => r.distKm <= 20 && now.difference(r.time).inMinutes <= 60);
    final devices = recent.map((r) => r.deviceId).toSet().length;

    return Dashboard(
      placeName: name,
      lat: lat,
      lon: lon,
      weather: w,
      smn: smn,
      radar: radar,
      hail: assessHail(
          w: w, radar: radar, smn: smn, now: now, neighborDevices: devices),
      heavyRain: assessHeavyRain(w, radar),
      neighbors: neighbors,
      fetchedAt: now,
    );
  }
}
