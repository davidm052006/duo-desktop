class ConfigSupabase {
  const ConfigSupabase._();

  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static bool get configurado =>
      url.trim().isNotEmpty && publishableKey.trim().isNotEmpty;
}
