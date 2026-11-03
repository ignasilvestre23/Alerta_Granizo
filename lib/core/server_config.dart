/// Datos de tu servidor de reportes (Supabase).
/// Ver README_CAMBIOS.md: creá un proyecto gratis y pegá acá los 2 valores.
class ServerConfig {
  /// Ejemplo: 'https://abcdxyz.supabase.co'
  static const supabaseUrl = 'https://iivmcfpsuvdhsbfqqzzd.supabase.co';

  /// Clave pública (anon / publishable). NO uses la "service_role".
  static const supabaseAnonKey =
      'sb_publishable_io-1pP_Y5N0SCTutKTsknw_Aw45nPGk';

  static bool get enabled =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
