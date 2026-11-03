import 'package:flutter/material.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const statusId = 7001;
  static const _icon = 'ic_notification';
  static const _accent = Color(0xFF0D294E);

  static Future<void> init() async {
    const android = AndroidInitializationSettings(_icon);
    const ios = DarwinInitializationSettings();
    await _plugin
        .initialize(const InitializationSettings(android: android, iOS: ios));
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static const _ios = DarwinNotificationDetails(
    presentAlert: true,
    presentSound: true,
    interruptionLevel: InterruptionLevel.timeSensitive,
  );

  /// Avisos generales (granizo, lluvia fuerte, tormenta acercándose).
  static Future<void> show(int id, String title, String body) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'storm_alerts',
          'Alertas de tormenta',
          channelDescription: 'Granizo, tormentas y lluvia fuerte',
          importance: Importance.max,
          priority: Priority.high,
          icon: _icon,
          color: _accent,
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: _ios,
      ),
    );
  }

  /// Granizo inminente: máxima prioridad.
  static Future<void> showImminent(int id, String title, String body) {
    return _plugin.show(
      id,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'storm_imminent',
          'Granizo inminente',
          channelDescription: 'Aviso minutos antes de que llegue el granizo',
          importance: Importance.max,
          priority: Priority.max,
          icon: _icon,
          color: const Color(0xFFE53935),
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: _ios,
      ),
    );
  }

  /// Notificación fija con la temperatura (silenciosa).
  static Future<void> showStatus(String title, String body) {
    return _plugin.show(
      statusId,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'temp_status',
          'Temperatura',
          channelDescription: 'Clima actual en la barra de notificaciones',
          importance: Importance.low,
          priority: Priority.low,
          icon: _icon,
          color: _accent,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: false,
          playSound: false,
          enableVibration: false,
          styleInformation: BigTextStyleInformation(body),
        ),
      ),
    );
  }

  static Future<void> cancel(int id) => _plugin.cancel(id);
}
