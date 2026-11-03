import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/format.dart';
import '../core/server_config.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../providers/providers.dart';
import '../services/local_store.dart';
import '../services/reports_api.dart';
import 'ad_card.dart';
import 'report_sheet.dart';
import 'widgets.dart';

class NeighborsPage extends ConsumerWidget {
  const NeighborsPage({super.key});

  void _refreshAll(WidgetRef ref) {
    ref.invalidate(reportsProvider);
    ref.invalidate(feedProvider);
    ref.invalidate(dashboardProvider);
  }

  Future<bool> _confirm(
      BuildContext context, String title, String body, String ok) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true), child: Text(ok)),
        ],
      ),
    );
    return r == true;
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, LogEntry e) async {
    if (!await _confirm(context, 'Sacar reporte',
        'Se borra tu reporte y deja de verse para tus vecinos.', 'Sacar')) {
      return;
    }
    final done = await ReportsApi.deleteMine(e);
    _refreshAll(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            done ? 'Reporte sacado.' : 'No se pudo sacar. Probá de nuevo.'),
      ));
    }
  }

  Future<void> _deleteAll(BuildContext context, WidgetRef ref) async {
    if (!await _confirm(
        context,
        'Borrar todos mis reportes',
        'Se borran todos tus reportes del servidor y de tu teléfono.',
        'Borrar')) {
      return;
    }
    final done = await ReportsApi.deleteAllMine();
    _refreshAll(ref);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            done ? 'Reportes borrados.' : 'No se pudo borrar. Probá de nuevo.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = ref.watch(dashboardProvider).valueOrNull;
    final radius = ref.watch(radiusProvider);
    final feed = ref.watch(feedProvider);
    final mine = ref.watch(reportsProvider);
    final canVote = ref.watch(canVoteProvider).valueOrNull ?? false;
    final all = feed.valueOrNull ?? const <NeighborReport>[];
    final withPhoto = all.where((r) => r.hasPhoto).length;

    return RefreshIndicator(
      onRefresh: () async {
        _refreshAll(ref);
        try {
          await ref.read(feedProvider.future);
        } catch (_) {}
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text('Vecinos',
              style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Lo que están reportando cerca de ${d?.placeName ?? 'tu zona'}.',
              style: TextStyle(fontSize: 20, color: context.muted)),
          const SizedBox(height: 20),
          _RadiusSelector(
            value: radius,
            onChanged: (v) => ref.read(radiusProvider.notifier).state = v,
          ),
          const SizedBox(height: 14),
          AppCard(
            onTap: d == null
                ? null
                : () => showReportSheet(
                      context,
                      d.placeName,
                      d.lat,
                      d.lon,
                      onDone: () => _refreshAll(ref),
                    ),
            padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.grain),
                SizedBox(width: 14),
                Text('Reportar granizo',
                    style:
                        TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (!ServerConfig.enabled)
            AppCard(
              child: Text(
                'Servidor sin configurar: por ahora tus reportes solo se guardan en '
                'este teléfono.',
                style:
                    TextStyle(fontSize: 17, height: 1.4, color: context.muted),
              ),
            )
          else if (feed.isLoading && all.isEmpty)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (all.isEmpty)
            _EmptyCard(radius: radius)
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                '${all.length} ${all.length == 1 ? 'reporte' : 'reportes'}'
                '${withPhoto > 0 ? ' · $withPhoto con foto' : ''}',
                style: TextStyle(fontSize: 17, color: context.muted),
              ),
            ),
            for (final r in all.take(30))
              _ReportCard(r: r, d: d, canVote: canVote),
            if (!canVote)
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Text(
                  'Después de tu primer día con la app vas a poder votar si los reportes de la zona son reales.',
                  style: TextStyle(
                      fontSize: 16, height: 1.4, color: context.muted),
                ),
              ),
          ],
          const AdCard(),
          const SectionTitle('Tus reportes'),
          mine.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('$e'),
            data: (list) => list.isEmpty
                ? Text('Todavía no reportaste granizo.',
                    style: TextStyle(color: context.muted))
                : Column(
                    children: [
                      for (final e in list)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading:
                              const Text('🧊', style: TextStyle(fontSize: 26)),
                          title: Text(e.text),
                          subtitle: Text(
                              '${e.place} · ${e.time.day}/${e.time.month} ${hh(e.time)}'),
                          trailing: IconButton(
                            tooltip: 'Sacar reporte',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _delete(context, ref, e),
                          ),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _deleteAll(context, ref),
                        icon: const Icon(Icons.delete_sweep_outlined),
                        label: const Text('Borrar todos mis reportes'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _RadiusSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  const _RadiusSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Row(
        children: [
          for (final km in const [30, 100, 300])
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(km),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: value == km ? context.fg : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('$km km',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight:
                            value == km ? FontWeight.w800 : FontWeight.w500,
                        color: value == km ? context.bg : context.muted,
                      )),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  final int radius;
  const _EmptyCard({required this.radius});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 44),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: context.track.withOpacity(0.6)),
        ),
        child: Column(
          children: [
            Icon(Icons.grain, size: 44, color: context.muted),
            const SizedBox(height: 22),
            const Text('Nadie está reportando granizo',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'No hay reportes de las últimas 6 horas a menos de $radius km. '
              'Si está cayendo, sé el primero en avisar.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, height: 1.4, color: context.muted),
            ),
          ],
        ),
      );
}

class _ReportCard extends ConsumerWidget {
  final NeighborReport r;
  final Dashboard? d;
  final bool canVote;
  const _ReportCard({required this.r, required this.d, required this.canVote});

  String? get _confirmedBy {
    if (r.confirmedByVotes) return 'Confirmado por vecinos';
    final km = d?.radar.nearestStrongKm;
    if (d != null &&
        d!.radar.available &&
        km != null &&
        km <= 30 &&
        r.distKm <= 30) {
      return 'Confirmado por radar';
    }
    return null;
  }

  Future<void> _vote(BuildContext context, WidgetRef ref, bool real) async {
    if (!canVote) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Podés votar después de tu primer día con la app.')));
      return;
    }
    final ok = await ReportsApi.vote(r.id, real);
    ref.invalidate(myVoteProvider(r.id));
    ref.invalidate(feedProvider);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo enviar tu voto.')));
    }
  }

  Future<void> _flag(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Denunciar reporte'),
        content: const Text(
            'Si el reporte es falso, ofensivo o la foto no corresponde, avisanos. '
            'Cuando varios vecinos lo denuncian, deja de mostrarse.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Denunciar')),
        ],
      ),
    );
    if (ok != true) return;
    final done = await ReportsApi.flag(r.id);
    ref.invalidate(feedProvider);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              done ? 'Gracias, lo vamos a revisar.' : 'No se pudo enviar.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myVoteProvider(r.id)).valueOrNull;
    final confirmed = _confirmedBy;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (r.hasPhoto)
              ref.watch(photoProvider(r.id)).when(
                    data: (b) => b == null
                        ? const SizedBox.shrink()
                        : Image.memory(b,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover),
                    loading: () => const SizedBox(
                        height: 220,
                        child: Center(child: CircularProgressIndicator())),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7CC4F5).withOpacity(0.18),
                          shape: BoxShape.circle,
                        ),
                        child: const Text('🧊', style: TextStyle(fontSize: 26)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Granizo ${sizeTitle(r.size)}',
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(
                                '${sizeCm(r.size)} · a ${r.distKm.round()} km · ${ago(r.time)}',
                                style: TextStyle(
                                    fontSize: 16, color: context.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (r.note != null && r.note!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(r.note!,
                        style: const TextStyle(fontSize: 18, height: 1.35)),
                  ],
                  if (confirmed != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.check,
                            size: 20, color: Color(0xFF7CC4F5)),
                        const SizedBox(width: 6),
                        Text(confirmed,
                            style: const TextStyle(
                                fontSize: 17, color: Color(0xFF7CC4F5))),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Divider(height: 1, color: context.track),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Text('¿Es real?',
                          style: TextStyle(fontSize: 17, color: context.muted)),
                      const SizedBox(width: 12),
                      _VoteBtn(
                          label: 'Sí',
                          selected: mine == true,
                          onTap: () => _vote(context, ref, true)),
                      const SizedBox(width: 8),
                      _VoteBtn(
                          label: 'No',
                          selected: mine == false,
                          onTap: () => _vote(context, ref, false)),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Denunciar',
                        icon: Icon(Icons.flag_outlined, color: context.muted),
                        onPressed: () => _flag(context, ref),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VoteBtn extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _VoteBtn(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
        color:
            selected ? const Color(0xFF7CC4F5) : context.track.withOpacity(0.7),
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            child: Text(label,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: selected ? const Color(0xFF1A1D23) : context.fg,
                )),
          ),
        ),
      );
}
