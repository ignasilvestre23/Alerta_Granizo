class MapConfig {
  /// Clave de https://cloud.maptiler.com/account/keys/
  static const maptilerKey = 'hVVwrNfF14YKTPGcgKpC';

  /// Mapa oscuro minimalista, ideal para ver radar y nubes.
  /// Si querés más calles, probá 'streets-v2-dark'.
  static const darkStyle = 'dataviz-dark';
  static const lightStyle = 'streets-v2';

  static bool get usesMaptiler => maptilerKey.isNotEmpty;

  static String baseUrl(bool dark) => usesMaptiler
      ? 'https://api.maptiler.com/maps/${dark ? darkStyle : lightStyle}/{z}/{x}/{y}.png?key=$maptilerKey'
      : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // MapTiler entrega tiles de 512 px: menos pedidos, más nítido y fluido.
  static double get tileSize => usesMaptiler ? 512 : 256;
  static double get zoomOffset => usesMaptiler ? -1 : 0;

  static String get attribution =>
      usesMaptiler ? '© MapTiler © OpenStreetMap' : '© OpenStreetMap';
}
