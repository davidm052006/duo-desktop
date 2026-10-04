import 'dart:io';

/// Cómo encuentra la app al servicio local.
///
/// `scripts/dev.fish` elige un puerto efímero y un token nuevo en cada arranque
/// y los pasa por `--dart-define`. No hay valores por defecto útiles para el
/// token a propósito: si falta, queremos ver el 401 y no un fallo raro.
class ConfigDuo {
  const ConfigDuo({required this.puerto, required this.token});

  final int puerto;
  final String token;

  static ConfigDuo get desdeEntorno {
    const puertoCompilado = int.fromEnvironment(
      'SERVICE_PORT',
      defaultValue: 5132,
    );
    const tokenCompilado = String.fromEnvironment('TOKEN');

    final puertoRuntime = int.tryParse(
      Platform.environment['DUO_SERVICE_PORT'] ?? '',
    );
    final tokenRuntime = Platform.environment['DUO_TOKEN'] ?? '';

    return ConfigDuo(
      puerto: puertoRuntime ?? puertoCompilado,
      token: tokenRuntime.isNotEmpty ? tokenRuntime : tokenCompilado,
    );
  }

  /// El servicio escucha solo en loopback (ver docs/ARQUITECTURA.md).
  Uri ruta(String camino) => Uri.http('127.0.0.1:$puerto', camino);

  Uri rutaWebSocket(String camino) => Uri(
    scheme: 'ws',
    host: '127.0.0.1',
    port: puerto,
    path: camino,
  );

  bool get tieneToken => token.isNotEmpty;
}
