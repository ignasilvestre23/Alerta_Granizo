import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/pricing_config.dart';
import '../core/theme.dart';
import '../services/premium_service.dart';
import 'widgets.dart';

const _accent = Color(0xFF9ED4F7);
const _dark = Color(0xFF1A1D23);

class PaywallPage extends ConsumerStatefulWidget {
  const PaywallPage({super.key});
  @override
  ConsumerState<PaywallPage> createState() => _PaywallPageState();
}

class _PaywallPageState extends ConsumerState<PaywallPage> {
  Plan _plan = Plan.annual;

  String _price(PremiumState s, Plan p) {
    final pr = s.prices[p];
    if (pr != null) return pr.currency == 'ARS' ? ars(pr.raw) : pr.formatted;
    switch (p) {
      case Plan.annual:
        return ars(PricingConfig.annualFallback);
      case Plan.season:
        return ars(PricingConfig.seasonFallback);
      case Plan.monthly:
        return ars(PricingConfig.monthlyFallback);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(premiumProvider);
    final n = ref.read(premiumProvider.notifier);

    final ann = s.prices[Plan.annual];
    final annRaw = ann?.raw ?? PricingConfig.annualFallback.toDouble();
    final perMonth = (ann == null || ann.currency == 'ARS')
        ? 'Sale ${ars(annRaw / 12)} por mes'
        : '';

    final trialText = '${PricingConfig.trialDays} días gratis para probar';
    final monthlyHasTrial = s.prices[Plan.monthly]?.trial ?? true;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (s.message != null && s.message!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(s.message!, textAlign: TextAlign.center),
                ),
              if (s.isPremium)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Text('Ya sos Premium ✓',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                )
              else
                FilledButton(
                  onPressed: s.busy ? null : () => n.buy(_plan),
                  style: FilledButton.styleFrom(
                    backgroundColor: _accent,
                    foregroundColor: _dark,
                    minimumSize: const Size.fromHeight(64),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24)),
                  ),
                  child: Text(
                    _plan == Plan.season ? 'Comprar pase' : 'Suscribirme',
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800),
                  ),
                ),
              TextButton(
                  onPressed: n.restore, child: const Text('Restaurar compras')),
            ],
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (PricingConfig.repairCostRange.isNotEmpty) ...[
                  Text('ARREGLAR UN AUTO CON GRANIZO',
                      style: TextStyle(
                          fontSize: 16,
                          letterSpacing: 1.2,
                          color: context.muted)),
                  const SizedBox(height: 8),
                  Text(PricingConfig.repairCostRange,
                      style: const TextStyle(
                          fontSize: 40, fontWeight: FontWeight.w800)),
                  if (PricingConfig.repairCostSource.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(PricingConfig.repairCostSource,
                          style: TextStyle(fontSize: 18, color: context.muted)),
                    ),
                  Divider(height: 36, color: context.track),
                ],
                Text('PREMIUM, UN AÑO',
                    style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: context.muted)),
                const SizedBox(height: 8),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: 12,
                  children: [
                    Text(_price(s, Plan.annual),
                        style: const TextStyle(
                            fontSize: 46,
                            fontWeight: FontWeight.w800,
                            color: _accent)),
                    if (perMonth.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(perMonth,
                            style:
                                TextStyle(fontSize: 19, color: context.muted)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                    'Te dice a qué hora llega la tormenta, para que guardes el auto a tiempo.',
                    style: TextStyle(
                        fontSize: 19, height: 1.4, color: context.muted)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          AppCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _Feature(Icons.bolt, 'Cuándo llega la tormenta',
                    'Entre qué hora y qué hora, y de dónde viene.'),
                Divider(height: 32, color: context.track),
                _Feature(
                    Icons.place_outlined,
                    'Avisos en ${placeLimit(true)} lugares',
                    'Casa, trabajo, el campo, la casa de tus viejos.'),
                Divider(height: 32, color: context.track),
                const _Feature(
                    Icons.calendar_month_outlined,
                    'Historial de la temporada',
                    'Todos los avisos de granizo que tuviste, por día y lugar.'),
                Divider(height: 32, color: context.track),
                Text('Y ADEMÁS',
                    style: TextStyle(
                        fontSize: 16,
                        letterSpacing: 1.2,
                        color: context.muted)),
                const SizedBox(height: 14),
                const _Mini(Icons.warning_amber_rounded,
                    'Todas las alertas de peligro'),
                const _Mini(Icons.schedule, 'Silencio de noche a tu medida'),
                const _Mini(Icons.block, 'Sin publicidad'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _PlanTile(
            selected: _plan == Plan.annual,
            onTap: () => setState(() => _plan = Plan.annual),
            title: 'Anual',
            subtitle: perMonth.isEmpty ? 'Renovación anual' : perMonth,
            price: _price(s, Plan.annual),
            caption: 'por año',
          ),
          _PlanTile(
            selected: _plan == Plan.season,
            onTap: () => setState(() => _plan = Plan.season),
            title: 'Pase de temporada',
            subtitle: 'Del 1 de octubre al 31 de marzo',
            price: _price(s, Plan.season),
            caption: 'pago único',
          ),
          _PlanTile(
            selected: _plan == Plan.monthly,
            onTap: () => setState(() => _plan = Plan.monthly),
            title: 'Mensual',
            subtitle: monthlyHasTrial ? trialText : 'Renovación mensual',
            price: _price(s, Plan.monthly),
            caption: 'por mes',
          ),
          const SizedBox(height: 8),
          Text(
            'Las suscripciones se renuevan solas y las cancelás cuando quieras en '
            'Google Play → Pagos y suscripciones. El pase de temporada es un pago '
            'único. La hora de llegada es una estimación según el movimiento de la '
            'tormenta en el radar y puede fallar.',
            style: TextStyle(fontSize: 13, height: 1.4, color: context.muted),
          ),
        ],
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  const _Feature(this.icon, this.title, this.subtitle);
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _accent, size: 30),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 21, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        fontSize: 18, height: 1.35, color: context.muted)),
              ],
            ),
          ),
        ],
      );
}

class _Mini extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Mini(this.icon, this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            Icon(icon, color: context.muted, size: 26),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 19))),
          ],
        ),
      );
}

class _PlanTile extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  final String title, subtitle, price, caption;
  const _PlanTile({
    required this.selected,
    required this.onTap,
    required this.title,
    required this.subtitle,
    required this.price,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
                color: selected ? _accent : context.track,
                width: selected ? 2.5 : 1.5),
          ),
          child: Row(
            children: [
              Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: selected ? _accent : context.track,
                  size: 34),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 22, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(fontSize: 18, color: context.muted)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(price,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(caption,
                      style: TextStyle(fontSize: 18, color: context.muted)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
