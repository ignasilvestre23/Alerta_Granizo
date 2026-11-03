import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

class AlertPrefs {
  final bool storm; // tormenta acercándose
  final bool imminent; // granizo inminente
  final bool temp; // temperatura en notificaciones
  const AlertPrefs(
      {this.storm = true, this.imminent = true, this.temp = false});

  static Future<AlertPrefs> load() async {
    final p = await SharedPreferences.getInstance();
    return AlertPrefs(
      storm: p.getBool('ap_storm') ?? true,
      imminent: p.getBool('ap_imminent') ?? true,
      temp: p.getBool('ap_temp') ?? false,
    );
  }
}

class AlertPrefsNotifier extends StateNotifier<AlertPrefs> {
  AlertPrefsNotifier() : super(const AlertPrefs()) {
    _load();
  }

  Future<void> _load() async {
    state = await AlertPrefs.load();
  }

  Future<void> _set(String key, bool v, AlertPrefs next) async {
    state = next;
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, v);
  }

  Future<void> setStorm(bool v) => _set('ap_storm', v,
      AlertPrefs(storm: v, imminent: state.imminent, temp: state.temp));

  Future<void> setImminent(bool v) => _set('ap_imminent', v,
      AlertPrefs(storm: state.storm, imminent: v, temp: state.temp));

  Future<void> setTemp(bool v) async {
    await _set('ap_temp', v,
        AlertPrefs(storm: state.storm, imminent: state.imminent, temp: v));
    if (!v) await NotificationService.cancel(NotificationService.statusId);
  }
}

final alertPrefsProvider =
    StateNotifierProvider<AlertPrefsNotifier, AlertPrefs>(
        (ref) => AlertPrefsNotifier());
