import 'dart:io';

class ConfigSupabase {
  const ConfigSupabase._();

  static const _urlCompilada = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: '',
  );

  static const _publishableKeyCompilada = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: '',
  );

  static String get url {
    final runtime = Platform.environment['SUPABASE_URL']?.trim() ?? '';
    return runtime.isNotEmpty ? runtime : _urlCompilada.trim();
  }

  static String get publishableKey {
    final runtime =
        Platform.environment['SUPABASE_PUBLISHABLE_KEY']?.trim() ?? '';
    return runtime.isNotEmpty ? runtime : _publishableKeyCompilada.trim();
  }

  static bool get configurado =>
      url.isNotEmpty && publishableKey.isNotEmpty;
}
