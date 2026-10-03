/// Cómo encuentra la app al servicio local.
///
/// `scripts/dev.fish` elige un puerto efímero y un token nuevo en cada arranque
/// y los pasa por `--dart-define`. No hay valores por defecto útiles para el
/// token a propósito: si falta, queremos ver el 401 y no un fallo raro.
class ConfigDuo {
  const ConfigDuo({required this.puerto, required this.token});

  final int puerto;
  final String token;

  static const ConfigDuo desdeEntorno = ConfigDuo(
    puerto: int.fromEnvironment('SERVICE_PORT', defaultValue: 5132),
    token: String.fromEnvironment('TOKEN'),
  );

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
