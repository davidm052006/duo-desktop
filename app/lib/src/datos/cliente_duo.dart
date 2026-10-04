import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../config.dart';
import '../modelos/evento_duo.dart';
import '../modelos/tablero.dart';

/// Un fallo que la UI puede mostrar sin inventarse nada.
///
/// El contrato manda usar `error.code` y no el texto del mensaje (§10), así que
/// el código viaja aparte y es lo único sobre lo que la app decide.
class FalloDuo implements Exception {
  const FalloDuo(this.codigo, this.mensaje);

  final String codigo;
  final String mensaje;

  /// El servicio no responde: todavía arrancando, o se cayó.
  static const sinServicio = FalloDuo(
    'service_unreachable',
    'El servicio local no responde. ¿Está arrancado?',
  );

  @override
  String toString() => '$codigo: $mensaje';
}

/// Capacidad del dispositivo actual. Es deliberadamente distinta de la
/// asignación Cloud: que un CLI no esté instalado aquí no impide asignar la
/// tarea a otro miembro que sí lo tenga.
class CapacidadAgenteLocal {
  const CapacidadAgenteLocal({
    required this.provider,
    required this.disponible,
    this.ejecutable,
  });

  final String provider;
  final bool disponible;
  final String? ejecutable;

  factory CapacidadAgenteLocal.desdeJson(Map<String, dynamic> json) =>
      CapacidadAgenteLocal(
        provider: '${json['provider'] ?? ''}',
        disponible: json['available'] == true,
        ejecutable: json['executable'] as String?,
      );
}

class ClienteDuo {
  ClienteDuo({ConfigDuo? config, http.Client? transporte})
    : _config = config ?? ConfigDuo.desdeEntorno,
      _http = transporte ?? http.Client();

  final ConfigDuo _config;
  final http.Client _http;

  static const _espera = Duration(seconds: 5);

  Map<String, String> get _cabeceras => {
    // El contrato v1 fija `Authorization: Bearer`, y es la única que el
    // servicio acepta.
    'Authorization': 'Bearer ${_config.token}',
    'Accept': 'application/json',
  };

  Future<Tablero> tablero() async {
    final http.Response respuesta;
    try {
      respuesta = await _http
          .get(_config.ruta('/board'), headers: _cabeceras)
          .timeout(_espera);
    } on TimeoutException {
      throw FalloDuo.sinServicio;
    } on SocketException {
      throw FalloDuo.sinServicio;
    } on http.ClientException {
      throw FalloDuo.sinServicio;
    }

    final cuerpo = _decodifica(respuesta.body);

    if (respuesta.statusCode != 200) {
      final error = cuerpo?['error'] as Map<String, dynamic>?;
      throw FalloDuo(
        error?['code'] as String? ?? 'http_${respuesta.statusCode}',
        error?['message'] as String? ??
            'El servicio respondió ${respuesta.statusCode}.',
      );
    }

    if (cuerpo == null) {
      throw const FalloDuo(
        'respuesta_ilegible',
        'El servicio devolvió algo que no es JSON.',
      );
    }

    try {
      return Tablero.desdeJson(cuerpo);
    } on Object catch (e) {
      // Un 200 que no encaja con el contrato es un bug nuestro, no del usuario.
      throw FalloDuo(
        'contrato_roto',
        'La respuesta no encaja con el contrato: $e',
      );
    }
  }

  Future<List<CapacidadAgenteLocal>> capacidadesAgentes() async {
    final http.Response respuesta;
    try {
      respuesta = await _http
          .get(_config.ruta('/agents/capabilities'), headers: _cabeceras)
          .timeout(_espera);
    } on TimeoutException {
      throw FalloDuo.sinServicio;
    } on SocketException {
      throw FalloDuo.sinServicio;
    } on http.ClientException {
      throw FalloDuo.sinServicio;
    }

    final cuerpo = _decodifica(respuesta.body);
    if (respuesta.statusCode != 200) {
      final error = cuerpo?['error'] as Map<String, dynamic>?;
      throw FalloDuo(
        error?['code'] as String? ?? 'http_${respuesta.statusCode}',
        error?['message'] as String? ??
            'No se pudieron leer los agentes locales.',
      );
    }

    final agentes = cuerpo?['agents'];
    if (agentes is! List) {
      throw const FalloDuo(
        'contrato_roto',
        'La respuesta de capacidades no contiene agents.',
      );
    }
    return agentes
        .whereType<Map>()
        .map(
          (json) =>
              CapacidadAgenteLocal.desdeJson(json.cast<String, dynamic>()),
        )
        .toList(growable: false);
  }

  Stream<EventoDuo> eventos() async* {
    IOWebSocketChannel? canal;

    try {
      canal = IOWebSocketChannel.connect(
        _config.rutaWebSocket('/events'),
        headers: _cabeceras,
        pingInterval: const Duration(seconds: 20),
      );

      await canal.ready.timeout(_espera);

      await for (final mensaje in canal.stream) {
        final texto = switch (mensaje) {
          String valor => valor,
          List<int> bytes => utf8.decode(bytes),
          _ => throw const FormatException('Frame WebSocket no soportado.'),
        };

        final dynamic decodificado = jsonDecode(texto);
        if (decodificado is! Map) {
          throw const FormatException('Evento WebSocket inválido.');
        }

        yield EventoDuo.desdeJson(decodificado.cast<String, dynamic>());
      }
    } on TimeoutException {
      throw FalloDuo.sinServicio;
    } on SocketException {
      throw FalloDuo.sinServicio;
    } on WebSocketChannelException catch (e) {
      throw FalloDuo(
        'websocket_failed',
        e.message ?? 'Falló la conexión WebSocket.',
      );
    } on FormatException catch (e) {
      throw FalloDuo('evento_invalido', e.message);
    } finally {
      await canal?.sink.close();
    }
  }

  Future<void> crearTarea({
    required String descripcion,
    String? agente,
    String? alcance,
  }) async {
    final cuerpoPeticion = <String, dynamic>{
      'text': descripcion,
      if (agente != null && agente.isNotEmpty) 'agent': agente,
      if (alcance != null && alcance.isNotEmpty) 'scope': alcance,
    };

    final http.Response respuesta;
    try {
      respuesta = await _http
          .post(
            _config.ruta('/tasks'),
            headers: {..._cabeceras, 'Content-Type': 'application/json'},
            body: jsonEncode(cuerpoPeticion),
          )
          .timeout(_espera);
    } on TimeoutException {
      throw FalloDuo.sinServicio;
    } on SocketException {
      throw FalloDuo.sinServicio;
    } on http.ClientException {
      throw FalloDuo.sinServicio;
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return;
    }

    final cuerpo = _decodifica(respuesta.body);
    final error = cuerpo?['error'] as Map<String, dynamic>?;
    final mensaje = error?['message'] as String?;

    throw FalloDuo(
      error?['code'] as String? ?? 'http_${respuesta.statusCode}',
      mensaje ??
          (respuesta.body.trim().isNotEmpty
              ? respuesta.body.trim()
              : 'El servicio respondió ${respuesta.statusCode}.'),
    );
  }

  Future<void> publicarRama(String tareaId) =>
      _postGitHub('/github/push', tareaId);

  Future<void> abrirPullRequest(String tareaId) =>
      _postGitHub('/github/pr', tareaId);

  Future<void> _postGitHub(String ruta, String tareaId) async {
    final http.Response respuesta;
    try {
      respuesta = await _http
          .post(
            _config.ruta(ruta),
            headers: {..._cabeceras, 'Content-Type': 'application/json'},
            body: jsonEncode({'taskId': tareaId}),
          )
          .timeout(_espera);
    } on TimeoutException {
      throw FalloDuo.sinServicio;
    } on SocketException {
      throw FalloDuo.sinServicio;
    } on http.ClientException {
      throw FalloDuo.sinServicio;
    }

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) {
      return;
    }

    final cuerpo = _decodifica(respuesta.body);
    final error = cuerpo?['error'] as Map<String, dynamic>?;
    throw FalloDuo(
      error?['code'] as String? ?? 'http_${respuesta.statusCode}',
      error?['message'] as String? ??
          (respuesta.body.trim().isNotEmpty
              ? respuesta.body.trim()
              : 'El servicio respondió ${respuesta.statusCode}.'),
    );
  }

  Map<String, dynamic>? _decodifica(String cuerpo) {
    try {
      return jsonDecode(cuerpo) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  void cierra() => _http.close();
}
