import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../providers/providers.dart';
import '../services/local_store.dart';
import 'widgets.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  String _day(DateTime d, DateTime now) {
    final a = DateTime(d.year, d.month, d.day);
    final b = DateTime(now.year, now.month, now.day);
    final diff = b.difference(a).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    return '${cap(weekday(d))} ${d.day}/${d.month}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final h = ref.watch(historyProvider);
    final now = DateTime.now();
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de la temporada')),
      body: h.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (List<LogEntry> list) {
          if (list.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Todavía no hubo avisos esta temporada. Acá vas a ver, día por día, '
                  'qué pasó en cada lugar.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 17, height: 1.4, color: context.muted),
                ),
              ),
            );
          }
          final groups = <String, List<LogEntry>>{};
          for (final e in list) {
            groups.putIfAbsent(_day(e.time, now), () => []).add(e);
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            children: [
              Text(
                '${list.length} ${list.length == 1 ? 'aviso' : 'avisos'} en '
                '${groups.length} ${groups.length == 1 ? 'día' : 'días'}',
                style: TextStyle(fontSize: 17, color: context.muted),
              ),
              for (final g in groups.entries) ...[
                SectionTitle(g.key),
                AppCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Column(
                    children: [
                      for (final e in g.value)
                        ListTile(
                          leading: Text(hh(e.time),
                              style: TextStyle(
                                  fontSize: 16, color: context.muted)),
                          title: Text(e.text,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.w700)),
                          subtitle: Text(e.place),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}
