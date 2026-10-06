import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Consulta el canal de releases mientras Duo está abierto. La instalación se
/// mantiene en el launcher, que es quien valida el archivo y puede reiniciar
/// los procesos de forma segura en Windows y Linux.
class EstadoActualizacion extends ChangeNotifier {
  EstadoActualizacion({http.Client? cliente, Duration? intervalo})
    : _cliente = cliente ?? http.Client(),
        _intervalo = intervalo ?? const Duration(minutes: 5);

  final http.Client _cliente;
  final Duration _intervalo;
  Timer? _reloj;
  _ActualizacionDisponible? _disponible;
  bool comprobando = false;
  bool instalando = false;
  bool leida = true;
  String? error;

  bool get hayActualizacion => _disponible != null;
  String? get versionNueva => _disponible?.version;
  bool get obligatoria => _disponible?.obligatoria ?? false;

  void inicia() {
    unawaited(comprueba());
    _reloj = Timer.periodic(_intervalo, (_) => unawaited(comprueba()));
  }

  Future<void> comprueba() async {
    if (comprobando || instalando) return;
    final ajustes = await _AjustesLauncher.leer();
    if (ajustes == null ||
        !ajustes.comprobar ||
        ajustes.versionActual.isEmpty) {
      return;
    }

    comprobando = true;
    error = null;
    notifyListeners();
    try {
      final release = await _cliente.get(
        Uri.parse(
          'https://api.github.com/repos/${ajustes.owner}/${ajustes.repo}/releases/latest',
        ),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'User-Agent': 'DuoDesktop',
        },
      );
      if (release.statusCode != 200) {
        throw HttpException('No se pudo consultar las actualizaciones.');
      }
      final assets =
          (jsonDecode(release.body) as Map<String, dynamic>)['assets']
              as List<dynamic>;
      final nombre = Platform.isLinux ? 'latest-linux.json' : 'latest.json';
      final asset = assets
          .cast<Map<String, dynamic>>()
          .where((a) => a['name'] == nombre)
          .firstOrNull;
      if (asset == null) return;
      final manifest = await _cliente.get(
        Uri.parse(asset['browser_download_url'] as String),
        headers: const {'User-Agent': 'DuoDesktop'},
      );
      if (manifest.statusCode != 200) {
        throw HttpException('No se pudo leer la actualización.');
      }
      final datos = jsonDecode(manifest.body) as Map<String, dynamic>;
      final version = datos['version'] as String? ?? '';
      final canal = datos['channel'] as String? ?? '';
      final minima = datos['minimumLauncherVersion'] as String? ?? '1.0.0';
      if (canal.toLowerCase() != ajustes.canal.toLowerCase() ||
          _compararVersion(version, ajustes.versionActual) <= 0 ||
          _compararVersion(minima, '1.0.0') > 0) {
        return;
      }
      if (_disponible?.version != version) leida = false;
      _disponible = _ActualizacionDisponible(
        version,
        datos['mandatory'] == true,
      );
    } on Object catch (e) {
      // La app sigue funcionando sin red. El error se muestra solo dentro del
      // centro de notificaciones, no como una alerta invasiva.
      error = e.toString();
    } finally {
      comprobando = false;
      notifyListeners();
    }
  }

  void marcaLeida() {
    if (!leida) {
      leida = true;
      notifyListeners();
    }
  }

  Future<void> instalar() async {
    final ruta = Platform.environment['DUO_LAUNCHER_PATH'];
    if (ruta == null || ruta.isEmpty || instalando) {
      error = 'Esta sesión no fue iniciada por el lanzador de Duo.';
      notifyListeners();
      return;
    }
    instalando = true;
    notifyListeners();
    try {
      await Process.start(ruta, const [
        '--apply-update',
      ], mode: ProcessStartMode.detached);
      // El nuevo launcher descargará, validará y reiniciará Duo. Salir aquí
      // libera los binarios sin pedir al usuario que cierre la aplicación.
      exit(0);
    } on Object catch (e) {
      instalando = false;
      error = 'No se pudo iniciar la actualización: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _reloj?.cancel();
    _cliente.close();
    super.dispose();
  }
}

class _ActualizacionDisponible {
  const _ActualizacionDisponible(this.version, this.obligatoria);
  final String version;
  final bool obligatoria;
}

class _AjustesLauncher {
  const _AjustesLauncher({
    required this.owner,
    required this.repo,
    required this.canal,
    required this.versionActual,
    required this.comprobar,
  });
  final String owner;
  final String repo;
  final String canal;
  final String versionActual;
  final bool comprobar;

  static Future<_AjustesLauncher?> leer() async {
    final ejecutable = Platform.environment['DUO_LAUNCHER_PATH'];
    if (ejecutable == null || ejecutable.isEmpty) return null;
    try {
      final datos =
          jsonDecode(
                await File(
                  '${File(ejecutable).parent.path}${Platform.pathSeparator}launcher-config.json',
                ).readAsString(),
              )
              as Map<String, dynamic>;
      return _AjustesLauncher(
        owner: datos['releasesOwner'] as String? ?? 'davidm052006',
        repo: datos['releasesRepository'] as String? ?? 'duo-desktop',
        canal: datos['channel'] as String? ?? 'beta',
        versionActual: Platform.environment['DUO_VERSION'] ?? '',
        comprobar: datos['checkForUpdates'] as bool? ?? true,
      );
    } on Object {
      return null;
    }
  }
}

int _compararVersion(String izquierda, String derecha) {
  final a = izquierda.split('.').map((v) => int.tryParse(v) ?? 0).toList();
  final b = derecha.split('.').map((v) => int.tryParse(v) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final comparacion = (i < a.length ? a[i] : 0).compareTo(
      i < b.length ? b[i] : 0,
    );
    if (comparacion != 0) return comparacion;
  }
  return 0;
}

extension on Iterable<Map<String, dynamic>> {
  Map<String, dynamic>? get firstOrNull => isEmpty ? null : first;
}
