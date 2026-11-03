import 'package:workmanager/workmanager.dart';
import 'alert_checker.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, input) async {
    try {
      await NotificationService.init();
      await AlertChecker.runAll(task);
      return true;
    } catch (_) {
      return false;
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
    // Android: mínimo 15 min. Si hay una tormenta cerca, AlertChecker
    // programa revisiones cada 5 min.
    await Workmanager().registerPeriodicTask(
      'storm-check',
      'storm-check',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
}
