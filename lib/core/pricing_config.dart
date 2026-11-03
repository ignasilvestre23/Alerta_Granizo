/// Precios y IDs de Premium. Los precios reales los definís en Google Play
/// Console; estos valores solo se muestran si la tienda no responde.
class PricingConfig {
  // IDs EXACTOS que tenés que crear en Google Play Console
  static const annualId = 'premium_anual'; // suscripción, plan base anual
  static const monthlyId = 'premium_mensual'; // suscripción, plan base mensual (+ oferta 3 días gratis)
  static const seasonId = 'premium_temporada'; // producto único (pago único)

  static const annualFallback = 35000; // ARS
  static const seasonFallback = 19000;
  static const monthlyFallback = 6500;
  static const trialDays = 3;

  /// Alertas de peligro visibles sin Premium (las más graves primero).
  static const freeAlertLimit = 2;

  /// Tarjeta "Arreglar un auto con granizo". Dejala vacía si no tenés un
  /// dato propio con fuente; si la completás, la tarjeta aparece.
  static const repairCostRange = ''; // ej: '\$1,5 a \$4 millones'
  static const repairCostSource = ''; // ej: 'Talleres de tu zona, mes y año'
}

int placeLimit(bool premium) => premium ? 10 : 3;

/// 35000 -> '$ 35.000'
String ars(num v) {
  final s = v.round().toString();
  final withDots = s.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  return '\$ $withDots';
}
