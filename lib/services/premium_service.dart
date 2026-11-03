import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/pricing_config.dart';

enum Plan { annual, season, monthly }

class PlanPrice {
  final double raw;
  final String currency;
  final String formatted;
  final bool trial; // hay prueba gratis disponible para este usuario
  const PlanPrice(this.raw, this.currency, this.formatted, this.trial);
}

class PremiumState {
  final bool isPremium;
  final bool storeAvailable;
  final bool busy;
  final String? message;
  final Map<Plan, PlanPrice> prices;
  final Plan? plan; // plan vigente
  final int until; // vencimiento en ms (0 = suscripción, sin fecha fija)
  const PremiumState({
    this.isPremium = false,
    this.storeAvailable = false,
    this.busy = false,
    this.message,
    this.prices = const {},
    this.plan,
    this.until = 0,
  });

  PremiumState copyWith({
    bool? isPremium,
    bool? storeAvailable,
    bool? busy,
    String? message,
    Map<Plan, PlanPrice>? prices,
  }) =>
      PremiumState(
        isPremium: isPremium ?? this.isPremium,
        storeAvailable: storeAvailable ?? this.storeAvailable,
        busy: busy ?? this.busy,
        message: message ?? this.message,
        prices: prices ?? this.prices,
        plan: plan,
        until: until,
      );
}

/// Texto para Ajustes: "Mensual · se renueva solo" / "Pase de temporada · hasta el 31/3/2027".
String premiumLabel(PremiumState s) {
  final name = switch (s.plan) {
    Plan.annual => 'Anual',
    Plan.season => 'Pase de temporada',
    Plan.monthly => 'Mensual',
    null => 'Activo',
  };
  if (s.until > 0) {
    final d = DateTime.fromMillisecondsSinceEpoch(s.until);
    return '$name · hasta el ${d.day}/${d.month}/${d.year}';
  }
  return '$name · se renueva solo';
}

/// Premium vigente según lo guardado en el teléfono (también para segundo plano).
/// Se corta si pasó la fecha del pase o si hace más de 45 días que no se
/// verifica con Google Play.
bool premiumActive(SharedPreferences p) {
  if (!(p.getBool('premium') ?? false)) return false;
  final now = DateTime.now().millisecondsSinceEpoch;
  final until = p.getInt('premium_until') ?? 0;
  if (until != 0 && now >= until) return false;
  final verified = p.getInt('premium_verified') ?? 0;
  if (now - verified > 45 * 24 * 3600 * 1000) return false;
  return true;
}

class PremiumNotifier extends StateNotifier<PremiumState> {
  PremiumNotifier() : super(const PremiumState()) {
    _init();
  }

  final _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _sub;
  final Map<Plan, ProductDetails> _toBuy = {};
  final Map<Plan, int> _active = {}; // plan -> vencimiento (ms); 0 = sin fecha
  bool _verifying = false;

  String _id(Plan p) {
    switch (p) {
      case Plan.annual:
        return PricingConfig.annualId;
      case Plan.season:
        return PricingConfig.seasonId;
      case Plan.monthly:
        return PricingConfig.monthlyId;
    }
  }

  Plan? _planOf(String id) {
    for (final p in Plan.values) {
      if (_id(p) == id) return p;
    }
    return null;
  }

  /// El pase de temporada vence el 31 de marzo siguiente a la compra.
  int _seasonUntil(DateTime bought) {
    final y = bought.month >= 4 ? bought.year + 1 : bought.year;
    return DateTime(y, 3, 31, 23, 59, 59).millisecondsSinceEpoch;
  }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    final planName = p.getString('premium_plan');
    Plan? plan;
    for (final e in Plan.values) {
      if (e.name == planName) plan = e;
    }
    state = PremiumState(
      isPremium: premiumActive(p),
      plan: plan,
      until: p.getInt('premium_until') ?? 0,
    );
    await _verify();
  }

  /// Revisa con Google Play qué compras siguen vigentes.
  Future<void> _verify() async {
    if (_verifying) return;
    _verifying = true;
    try {
      if (!await _iap.isAvailable()) return;
      _sub ??= _iap.purchaseStream.listen(_onPurchases, onError: (_) {});
      final resp = await _iap.queryProductDetails({
        PricingConfig.annualId,
        PricingConfig.seasonId,
        PricingConfig.monthlyId,
      });
      _index(resp.productDetails);
      _active.clear();
      await _iap.restorePurchases();
      await Future.delayed(const Duration(seconds: 5));
      // Si la tienda conoce los productos y no devolvió ninguna compra
      // vigente (venció, se canceló o se reembolsó), se quita Premium.
      if (mounted &&
          !kDebugMode &&
          resp.productDetails.isNotEmpty &&
          _active.isEmpty) {
        await _grant(false);
      }
      final p = await SharedPreferences.getInstance();
      await p.setInt('premium_checked', DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
    } finally {
      _verifying = false;
    }
  }

  /// Se llama seguido; solo verifica si pasaron más de 6 horas.
  Future<void> refreshIfStale() async {
    final p = await SharedPreferences.getInstance();
    final last = p.getInt('premium_checked') ?? 0;
    if (DateTime.now().millisecondsSinceEpoch - last > 6 * 3600 * 1000) {
      await _verify();
    }
  }

  void _index(List<ProductDetails> list) {
    final byId = <String, List<ProductDetails>>{};
    for (final d in list) {
      byId.putIfAbsent(d.id, () => []).add(d);
    }
    final prices = <Plan, PlanPrice>{};
    for (final plan in Plan.values) {
      final l = byId[_id(plan)];
      if (l == null || l.isEmpty) continue;
      // Plan base = el de mayor precio; la oferta de prueba gratis tiene precio 0.
      final base = l.reduce((a, b) => a.rawPrice >= b.rawPrice ? a : b);
      final trial = l.where((d) => d.rawPrice == 0).toList();
      _toBuy[plan] = trial.isNotEmpty ? trial.first : base;
      prices[plan] = PlanPrice(
          base.rawPrice, base.currencyCode, base.price, trial.isNotEmpty);
    }
    if (mounted)
      state = state.copyWith(storeAvailable: prices.isNotEmpty, prices: prices);
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      final plan = _planOf(pd.productID);
      if (plan != null) {
        switch (pd.status) {
          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            await _onOwned(plan, pd);
            break;
          case PurchaseStatus.error:
            state = state.copyWith(
                busy: false, message: 'No se pudo completar la compra.');
            break;
          case PurchaseStatus.canceled:
            state = state.copyWith(busy: false, message: '');
            break;
          case PurchaseStatus.pending:
            state = state.copyWith(busy: true, message: 'Compra pendiente…');
            break;
        }
      }
      if (pd.pendingCompletePurchase) {
        try {
          await _iap.completePurchase(pd);
        } catch (_) {}
      }
    }
  }

  Future<void> _onOwned(Plan plan, PurchaseDetails pd) async {
    var until = 0;
    if (plan == Plan.season) {
      final ms = int.tryParse(pd.transactionDate ?? '');
      final bought =
          ms == null ? DateTime.now() : DateTime.fromMillisecondsSinceEpoch(ms);
      until = _seasonUntil(bought);
      if (until <= DateTime.now().millisecondsSinceEpoch) {
        // Pase vencido: se "consume" para poder comprar el de la temporada siguiente.
        try {
          await _iap
              .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>()
              .consumePurchase(pd);
        } catch (_) {}
        return;
      }
    }
    _active[plan] = until;
    await _grantBest();
    if (mounted && pd.status == PurchaseStatus.purchased) {
      state = state.copyWith(busy: false, message: '¡Premium activado!');
    }
  }

  /// Si hay una suscripción (sin fecha) manda ella; si no, la fecha más lejana.
  Future<void> _grantBest() async {
    if (_active.isEmpty) return;
    final subs = _active.entries.where((e) => e.value == 0).toList();
    if (subs.isNotEmpty) {
      await _grant(true, until: 0, plan: subs.first.key);
    } else {
      final e = _active.entries.reduce((a, b) => a.value >= b.value ? a : b);
      await _grant(true, until: e.value, plan: e.key);
    }
  }

  Future<void> buy(Plan plan) async {
    final pd = _toBuy[plan];
    if (pd == null) {
      state = state.copyWith(
          message: 'La tienda todavía no está disponible. Probá más tarde.');
      return;
    }
    state = state.copyWith(busy: true, message: '');
    try {
      // En Android las suscripciones también se compran con buyNonConsumable.
      await _iap.buyNonConsumable(
          purchaseParam: PurchaseParam(productDetails: pd));
    } catch (_) {
      state =
          state.copyWith(busy: false, message: 'No se pudo iniciar la compra.');
    }
  }

  Future<void> restore() async {
    try {
      state = state.copyWith(message: 'Buscando compras anteriores…');
      await _iap.restorePurchases();
    } catch (_) {
      state = state.copyWith(message: 'No se pudo consultar la tienda.');
    }
  }

  /// Solo en modo debug: mantené apretada la tarjeta Premium en Ajustes.
  Future<void> debugToggle() async {
    if (kDebugMode) await _grant(!state.isPremium, plan: Plan.annual);
  }

  Future<void> _grant(bool v, {int until = 0, Plan? plan}) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('premium', v);
    await p.setInt('premium_until', v ? until : 0);
    if (v) {
      await p.setInt('premium_verified', DateTime.now().millisecondsSinceEpoch);
      if (plan != null) await p.setString('premium_plan', plan.name);
    } else {
      await p.remove('premium_plan');
    }
    if (!mounted) return;
    state = PremiumState(
      isPremium: v,
      storeAvailable: state.storeAvailable,
      busy: state.busy,
      message: state.message,
      prices: state.prices,
      plan: v ? (plan ?? state.plan) : null,
      until: v ? until : 0,
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

final premiumProvider = StateNotifierProvider<PremiumNotifier, PremiumState>(
    (ref) => PremiumNotifier());
