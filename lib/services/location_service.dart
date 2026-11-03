import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef LatLon = ({double lat, double lon});

class LocationService {
  /// Solo con la app abierta.
  static Future<LatLon> current() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('Permiso de ubicación denegado');
    }
    Position pos;
    try {
      pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 15),
      );
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last == null) rethrow;
      pos = last;
    }
    final p = await SharedPreferences.getInstance();
    await p.setDouble('lat', pos.latitude);
    await p.setDouble('lon', pos.longitude);
    return (lat: pos.latitude, lon: pos.longitude);
  }

  /// En segundo plano NO se pide el GPS: se usa la última ubicación
  /// guardada con la app abierta (no hace falta el permiso de segundo plano).
  static Future<LatLon> forBackground() async {
    final p = await SharedPreferences.getInstance();
    final lat = p.getDouble('lat');
    final lon = p.getDouble('lon');
    if (lat == null || lon == null) {
      throw Exception('Sin ubicación guardada');
    }
    return (lat: lat, lon: lon);
  }

  static Future<String?> placeName(double lat, double lon) async {
    try {
      final pm = await placemarkFromCoordinates(lat, lon);
      if (pm.isEmpty) return null;
      final p = pm.first;
      for (final v in [
        p.locality,
        p.subAdministrativeArea,
        p.administrativeArea
      ]) {
        if (v != null && v.trim().isNotEmpty) return v;
      }
    } catch (_) {}
    return null;
  }
}
