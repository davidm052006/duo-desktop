import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
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
      throw const FalloDuo('respuesta_ilegible', 'El servicio devolvió algo que no es JSON.');
    }

    try {
      return Tablero.desdeJson(cuerpo);
    } on Object catch (e) {
      // Un 200 que no encaja con el contrato es un bug nuestro, no del usuario.
      throw FalloDuo('contrato_roto', 'La respuesta no encaja con el contrato: $e');
    }
  }

  Future<void> crearTarea({
    required String descripcion,
    String? agente,
    String? alcance,
  }) async {
    final cuerpoPeticion = <String, dynamic>{
      'description': descripcion,
      if (agente != null && agente.isNotEmpty) 'agent': agente,
      if (alcance != null && alcance.isNotEmpty) 'scope': alcance,
    };

    final http.Response respuesta;
    try {
      respuesta = await _http
          .post(
            _config.ruta('/tasks'),
            headers: {
              ..._cabeceras,
              'Content-Type': 'application/json',
            },
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

  Map<String, dynamic>? _decodifica(String cuerpo) {
    try {
      return jsonDecode(cuerpo) as Map<String, dynamic>;
    } on Object {
      return null;
    }
  }

  void cierra() => _http.close();
}
