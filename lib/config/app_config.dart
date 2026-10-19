class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured {
    final uri = Uri.tryParse(supabaseUrl);
    return uri != null &&
        uri.scheme == 'https' &&
        uri.host.endsWith('.supabase.co') &&
        supabaseAnonKey.isNotEmpty &&
        !supabaseAnonKey.startsWith('YOUR_');
  }
}
