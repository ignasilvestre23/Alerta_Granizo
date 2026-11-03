import 'package:flutter/foundation.dart';

class AdsConfig {
  // ID de PRUEBA de Google. En modo debug siempre se usa este.
  static const _testBanner = 'ca-app-pub-3926436705231205/5696204799';

  // Tu ID real de AdMob (bloque de anuncios tipo "Banner").
  // Dejalo vacío hasta tenerlo. Nunca toques tus propios anuncios reales.
  static const prodBanner = '';

  static String get bannerId =>
      (kReleaseMode && prodBanner.isNotEmpty) ? prodBanner : _testBanner;
}
