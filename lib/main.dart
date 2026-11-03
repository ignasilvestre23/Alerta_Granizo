import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/background_service.dart';
import 'services/notification_service.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  await BackgroundService.init();
  runApp(const ProviderScope(child: StormApp()));
}
