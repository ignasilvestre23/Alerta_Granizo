import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import 'granito_page.dart';
import 'home_page.dart';
import 'neighbors_page.dart';
import 'radar_page.dart';
import 'settings_page.dart';

class StormApp extends ConsumerWidget {
  const StormApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(settingsProvider.select((s) => s.mode));
    return MaterialApp(
      title: 'Alerta Granizo',
      debugShowCheckedModeBanner: false,
      themeMode: mode,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const RootShell(),
    );
  }
}

class RootShell extends ConsumerWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(tabProvider);
    const pages = <Widget>[
      HomePage(),
      RadarPage(),
      NeighborsPage(),
      GranitoPage(),
      SettingsPage(),
    ];
    return Scaffold(
      body: SafeArea(bottom: false, child: pages[tab]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: tab,
        onDestinationSelected: (i) => ref.read(tabProvider.notifier).state = i,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Inicio'),
          NavigationDestination(icon: Icon(Icons.radar), label: 'Radar'),
          NavigationDestination(icon: Icon(Icons.forum_outlined), selectedIcon: Icon(Icons.forum), label: 'Vecinos'),
          NavigationDestination(icon: Text('🧊', style: TextStyle(fontSize: 22)), label: 'Granito'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
