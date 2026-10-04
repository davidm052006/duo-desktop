abstract final class ConfigCloud {
  static const url = String.fromEnvironment('DUO_CLOUD_URL');

  static bool get configurado => url.trim().isNotEmpty;

  static Uri endpoint(String path) {
    if (!configurado) {
      throw StateError(
        'Falta DUO_CLOUD_URL. Inicia Flutter con --dart-define=DUO_CLOUD_URL=...',
      );
    }

    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }
}
