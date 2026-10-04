import 'dart:io';

abstract final class ConfigCloud {
  static const _urlCompilada = String.fromEnvironment('DUO_CLOUD_URL');

  static String get url {
    final runtime = Platform.environment['DUO_CLOUD_URL']?.trim() ?? '';
    return runtime.isNotEmpty ? runtime : _urlCompilada.trim();
  }

  static bool get configurado => url.isNotEmpty;

  static Uri endpoint(String path) {
    if (!configurado) {
      throw StateError(
        'Falta DUO_CLOUD_URL. Configura DUO_CLOUD_URL en el entorno o al compilar.',
      );
    }

    final base = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$base$normalized');
  }
}
