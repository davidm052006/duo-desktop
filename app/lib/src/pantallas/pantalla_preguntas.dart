import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../config.dart';
import '../datos/cliente_duo.dart';
import '../estado/estado_tablero.dart';
import '../modelos/tablero.dart';
import '../tema/paleta.dart';
import '../widgets/panel_fallo.dart';
import '../widgets/tarjeta.dart';

/// Las preguntas que los agentes han dejado abiertas.
///
/// La fuente buena es `GET /questions`: trae el texto real de cada pregunta.
/// Ese endpoint todavía no existe en el servicio, así que cuando contesta 404
/// la pantalla cae a las tareas en estado `esperando` de `GET /board` y lo dice
/// por escrito en vez de convertir el título de la tarea en una pregunta
/// ficticia.
///
/// Responder sí funciona en los dos casos: `POST /questions/{id}/answer` ya
/// está implementado en el servicio, y el identificador de la tarea es el que
/// espera (`duo answer <id>`).
class PantallaPreguntas extends StatefulWidget {
  const PantallaPreguntas({super.key, this.config, this.transporte});

  /// Inyectables para los tests; en la app salen del entorno.
  final ConfigDuo? config;
  final http.Client? transporte;

  @override
  State<PantallaPreguntas> createState() => _PantallaPreguntasState();
}

/// En qué punto está la lectura de `GET /questions`.
enum _Fuente {
  /// Pidiendo las preguntas al servicio.
  cargando,

  /// El servicio las entregó: hay texto real que mostrar.
  propia,

  /// El endpoint no existe todavía. Se enseña lo que haya en `/board`.
  ausente,

  /// El endpoint existe pero falló. Se dice el código y se enseña `/board`.
  fallo,
}

class _PantallaPreguntasState extends State<PantallaPreguntas> {
  late final ConfigDuo _config = widget.config ?? ConfigDuo.desdeEntorno;

  /// Si el transporte lo trae el test, es suyo y no lo cerramos nosotros.
  late final http.Client _http = widget.transporte ?? http.Client();
  late final bool _httpPropio = widget.transporte == null;

  _Fuente _fuente = _Fuente.cargando;
  List<_Pregunta> _preguntas = const [];
  FalloDuo? _fallo;

  @override
  void initState() {
    super.initState();
    _carga();
  }

  @override
  void dispose() {
    if (_httpPropio) _http.close();
    super.dispose();
  }

  Future<void> _carga() async {
    setState(() {
      _fuente = _Fuente.cargando;
      _fallo = null;
    });

    try {
      final preguntas = await _servicio.preguntas();
      if (!mounted) return;
      setState(() {
        _preguntas = preguntas;
        _fuente = _Fuente.propia;
      });
    } on _SinEndpoint {
      if (!mounted) return;
      setState(() {
        _preguntas = const [];
        _fuente = _Fuente.ausente;
      });
    } on FalloDuo catch (e) {
      if (!mounted) return;
      setState(() {
        _preguntas = const [];
        _fuente = _Fuente.fallo;
        _fallo = e;
      });
    }
  }

  _ServicioPreguntas get _servicio =>
      _ServicioPreguntas(config: _config, cliente: _http);

  /// El botón de actualizar pide las dos cosas: las preguntas y el tablero del
  /// que sale el respaldo.
  Future<void> _refrescaTodo() async {
    final estado = context.read<EstadoTablero>();
    await Future.wait([_carga(), estado.refresca()]);
  }

  Future<void> _responde(String id, String? titulo) async {
    final enviada = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoResponder(
        id: id,
        titulo: titulo,
        servicio: _servicio,
      ),
    );

    if (enviada != true || !mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Respuesta enviada a $id.')),
    );
    await _refrescaTodo();
  }

  @override
  Widget build(BuildContext context) {
    final estado = context.watch<EstadoTablero>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 24,
        title: const Text('Preguntas'),
        actions: [
          IconButton(
            tooltip: 'Actualizar preguntas',
            onPressed: _refrescaTodo,
            icon: const Icon(Icons.refresh, size: 19),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
        children: [
          _AvisoFuente(fuente: _fuente, fallo: _fallo, alReintentar: _carga),
          const SizedBox(height: 18),
          if (_fuente == _Fuente.cargando)
            const _Cargando()
          else if (_fuente == _Fuente.propia)
            ..._listaPropia(context)
          else
            ..._listaDelTablero(context, estado),
        ],
      ),
    );
  }

  List<Widget> _listaPropia(BuildContext context) => [
    _Recuento(_preguntas.length),
    const SizedBox(height: 10),
    if (_preguntas.isEmpty)
      const _Vacio(desdeTablero: false)
    else
      for (final pregunta in _preguntas) ...[
        _TarjetaPregunta(
          pregunta: pregunta,
          alResponder: () => _responde(pregunta.id, pregunta.titulo),
        ),
        const SizedBox(height: 12),
      ],
  ];

  List<Widget> _listaDelTablero(BuildContext context, EstadoTablero estado) {
    switch (estado.fase) {
      case Fase.inicial:
      case Fase.cargando:
        return const [_Cargando()];
      case Fase.fallo:
        return [
          PanelFallo(fallo: estado.fallo!, alReintentar: estado.refresca),
        ];
      case Fase.listo:
        final pendientes = estado.tablero!.tareas
            .where((tarea) => tarea.estado == EstadoTarea.esperando)
            .toList(growable: false);

        return [
          _Recuento(pendientes.length),
          const SizedBox(height: 10),
          if (pendientes.isEmpty)
            const _Vacio(desdeTablero: true)
          else
            for (final tarea in pendientes) ...[
              _TarjetaPregunta(
                pregunta: _Pregunta.desdeTarea(tarea),
                alResponder: () => _responde(tarea.id, tarea.titulo),
              ),
              const SizedBox(height: 12),
            ],
        ];
    }
  }
}

// ---------------------------------------------------------------------------
// Datos
// ---------------------------------------------------------------------------

/// Una pregunta tal y como la pintamos.
///
/// `texto` es `null` cuando no lo sabemos: en el respaldo de `/board` nadie nos
/// ha dado el contenido de la pregunta, y rellenarlo con el título de la tarea
/// sería inventárselo.
class _Pregunta {
  const _Pregunta({
    required this.id,
    required this.texto,
    this.titulo,
    this.dueno,
    this.abierta,
    this.etiqueta,
    this.opciones = const [],
    this.desdeTablero = false,
  });

  final String id;
  final String? texto;
  final String? titulo;
  final String? dueno;
  final DateTime? abierta;

  /// El estado literal que vino del servicio, para mostrarlo sin interpretarlo.
  final String? etiqueta;
  final List<String> opciones;

  /// Salió del respaldo de `/board`, no de `GET /questions`.
  final bool desdeTablero;

  factory _Pregunta.desdeTarea(Tarea tarea) => _Pregunta(
    id: tarea.id,
    texto: null,
    titulo: tarea.titulo,
    dueno: tarea.dueno,
    abierta: tarea.abierta,
    etiqueta: tarea.estadoCrudo,
    desdeTablero: true,
  );

  /// `GET /questions` no tiene contrato escrito todavía, así que aceptamos los
  /// nombres de campo razonables en vez de atarnos a uno y romper al primer
  /// cambio. Sin identificador no hay pregunta: no se podría responder.
  static _Pregunta? intenta(Map<String, dynamic> json) {
    final id =
        _texto(json['id']) ??
        _texto(json['taskId']) ??
        _texto(json['task_id']) ??
        _texto(json['task']);
    if (id == null) return null;

    final fecha =
        _texto(json['opened']) ??
        _texto(json['asked']) ??
        _texto(json['createdAt']) ??
        _texto(json['created_at']);

    return _Pregunta(
      id: id,
      texto:
          _texto(json['text']) ??
          _texto(json['question']) ??
          _texto(json['body']) ??
          _texto(json['prompt']),
      titulo: _texto(json['title']),
      dueno:
          _texto(json['owner']) ?? _texto(json['agent']) ?? _texto(json['who']),
      abierta: fecha == null ? null : DateTime.tryParse(fecha),
      etiqueta: _texto(json['status']) ?? _texto(json['state']),
      opciones: _lista(json['options'] ?? json['choices']),
    );
  }

  static String? _texto(Object? valor) {
    if (valor is! String) return null;
    final limpio = valor.trim();
    return limpio.isEmpty ? null : limpio;
  }

  static List<String> _lista(Object? valor) {
    if (valor is! List) return const [];
    return valor
        .map(_texto)
        .whereType<String>()
        .toList(growable: false);
  }
}

/// El servicio no conoce todavía `GET /questions`. No es un error que haya que
/// enseñar como fallo: es una pieza que falta.
class _SinEndpoint implements Exception {
  const _SinEndpoint();
}

/// Las dos llamadas de preguntas, con los mismos criterios de error que
/// `ClienteDuo`: el código manda y el mensaje del servicio se muestra tal cual.
///
/// Vive aquí y no en `ClienteDuo` porque el territorio de T-020 es esta
/// pantalla. Cuando `GET /questions` entre en el contrato, esto se sube al
/// cliente y la pantalla se queda solo con la UI.
class _ServicioPreguntas {
  const _ServicioPreguntas({required this.config, required this.cliente});

  final ConfigDuo config;
  final http.Client cliente;

  static const _espera = Duration(seconds: 5);

  Map<String, String> get _cabeceras => {
    'Authorization': 'Bearer ${config.token}',
    'Accept': 'application/json',
  };

  Future<List<_Pregunta>> preguntas() async {
    final respuesta = await _pide(
      () => cliente.get(config.ruta('/questions'), headers: _cabeceras),
    );

    // 404/405/501: la ruta no está montada. 404 con cuerpo de error del
    // servicio sí es un fallo de verdad y cae más abajo.
    final cuerpo = _decodifica(respuesta.body);
    if (respuesta.statusCode == 501 ||
        respuesta.statusCode == 405 ||
        (respuesta.statusCode == 404 && cuerpo?['error'] == null)) {
      throw const _SinEndpoint();
    }

    if (respuesta.statusCode != 200) {
      throw _falloDe(respuesta, cuerpo);
    }

    // Sin contrato escrito, aceptamos las dos formas plausibles: un objeto con
    // la lista dentro, o la lista en la raíz.
    final raiz = _json(respuesta.body);
    final crudas = switch (raiz) {
      final List lista => lista,
      final Map mapa when mapa['questions'] is List => mapa['questions'] as List,
      final Map mapa when mapa['items'] is List => mapa['items'] as List,
      _ => null,
    };

    if (crudas == null) {
      throw const FalloDuo(
        'contrato_roto',
        'GET /questions respondió 200 con algo que no es una lista de preguntas.',
      );
    }

    return crudas
        .whereType<Map>()
        .map((e) => _Pregunta.intenta(Map<String, dynamic>.from(e)))
        .whereType<_Pregunta>()
        .toList(growable: false);
  }

  Future<void> responde({required String id, required String texto}) async {
    final respuesta = await _pide(
      () => cliente.post(
        config.ruta('/questions/${Uri.encodeComponent(id)}/answer'),
        headers: {..._cabeceras, 'Content-Type': 'application/json'},
        body: jsonEncode({'text': texto}),
      ),
    );

    if (respuesta.statusCode >= 200 && respuesta.statusCode < 300) return;
    throw _falloDe(respuesta, _decodifica(respuesta.body));
  }

  Future<http.Response> _pide(Future<http.Response> Function() peticion) async {
    try {
      return await peticion().timeout(_espera);
    } on TimeoutException {
      throw FalloDuo.sinServicio;
    } on SocketException {
      throw FalloDuo.sinServicio;
    } on http.ClientException {
      throw FalloDuo.sinServicio;
    }
  }

  static FalloDuo _falloDe(http.Response respuesta, Map<String, dynamic>? cuerpo) {
    final error = cuerpo?['error'] as Map<String, dynamic>?;
    return FalloDuo(
      error?['code'] as String? ?? 'http_${respuesta.statusCode}',
      error?['message'] as String? ??
          (respuesta.body.trim().isNotEmpty
              ? respuesta.body.trim()
              : 'El servicio respondió ${respuesta.statusCode}.'),
    );
  }

  static Map<String, dynamic>? _decodifica(String cuerpo) {
    final valor = _json(cuerpo);
    return valor is Map<String, dynamic> ? valor : null;
  }

  static Object? _json(String cuerpo) {
    try {
      return jsonDecode(cuerpo);
    } on Object {
      return null;
    }
  }
}

// ---------------------------------------------------------------------------
// UI
// ---------------------------------------------------------------------------

class _Cargando extends StatelessWidget {
  const _Cargando();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 40),
    child: Center(
      child: SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    ),
  );
}

class _Recuento extends StatelessWidget {
  const _Recuento(this.cuantas);

  final int cuantas;

  @override
  Widget build(BuildContext context) {
    final plural = cuantas == 1 ? '' : 'S';
    return Text(
      cuantas == 0
          ? 'SIN PREGUNTAS PENDIENTES'
          : '$cuantas PREGUNTA$plural PENDIENTE$plural',
      style: Theme.of(context).textTheme.labelSmall,
    );
  }
}

/// De dónde salen los datos que se están viendo. Es la parte honesta de la
/// pantalla: si el texto de la pregunta no existe, aquí se explica por qué.
class _AvisoFuente extends StatelessWidget {
  const _AvisoFuente({
    required this.fuente,
    required this.fallo,
    required this.alReintentar,
  });

  final _Fuente fuente;
  final FalloDuo? fallo;
  final VoidCallback alReintentar;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    final (icono, tono, mensaje) = switch (fuente) {
      _Fuente.cargando => (
        Icons.hourglass_empty,
        paleta.tintaTenue,
        'Consultando GET /questions en el servicio local…',
      ),
      _Fuente.propia => (
        Icons.check_circle_outline,
        paleta.acento,
        'Preguntas leídas de GET /questions. Responder llama a '
            'POST /questions/{id}/answer.',
      ),
      _Fuente.ausente => (
        Icons.info_outline,
        paleta.acento,
        'GET /questions todavía no existe en el servicio local: se listan las '
            'tareas en estado esperando de /board y el texto de cada pregunta '
            'queda sin mostrar. Responder sí funciona.',
      ),
      _Fuente.fallo => (
        Icons.error_outline,
        paleta.critico,
        'GET /questions falló (${fallo!.codigo}): ${fallo!.mensaje} '
            'Se listan las tareas esperando de /board mientras tanto.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tono.withValues(alpha: .08),
        border: Border.all(color: paleta.rejilla),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, size: 18, color: tono),
          const SizedBox(width: 10),
          Expanded(child: Text(mensaje, style: textos.bodySmall)),
          if (fuente == _Fuente.fallo) ...[
            const SizedBox(width: 10),
            TextButton(onPressed: alReintentar, child: const Text('Reintentar')),
          ],
        ],
      ),
    );
  }
}

class _Vacio extends StatelessWidget {
  const _Vacio({required this.desdeTablero});

  final bool desdeTablero;

  @override
  Widget build(BuildContext context) => Tarjeta(
    titulo: 'Todo al día',
    icono: Icons.check_circle_outline,
    hijo: Text(
      'Ningún agente está esperando una respuesta.',
      style: Theme.of(context).textTheme.bodyMedium,
    ),
    pie: Text(
      desdeTablero
          ? 'Se muestran las tareas con estado esperando de /board.'
          : 'GET /questions no devolvió ninguna pregunta abierta.',
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(color: context.paleta.tintaTenue),
    ),
  );
}

class _TarjetaPregunta extends StatelessWidget {
  const _TarjetaPregunta({required this.pregunta, required this.alResponder});

  final _Pregunta pregunta;
  final VoidCallback alResponder;

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return Tarjeta(
      titulo: pregunta.id,
      icono: Icons.help_outline,
      sufijo: pregunta.etiqueta == null
          ? null
          : Insignia(pregunta.etiqueta!, tono: paleta.acento, mono: true),
      hijo: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (pregunta.titulo != null)
            Text(pregunta.titulo!, style: textos.titleMedium),
          if (pregunta.dueno != null || pregunta.abierta != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                if (pregunta.dueno != null) ...[
                  Icon(Icons.person_outline, size: 15, color: paleta.tintaTenue),
                  const SizedBox(width: 6),
                  Mono(pregunta.dueno!, color: paleta.tintaSecundaria),
                  const SizedBox(width: 16),
                ],
                if (pregunta.abierta != null) ...[
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: paleta.tintaTenue,
                  ),
                  const SizedBox(width: 6),
                  Mono(_fecha(pregunta.abierta!), color: paleta.tintaSecundaria),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          Text('PREGUNTA', style: textos.labelSmall),
          const SizedBox(height: 5),
          if (pregunta.texto case final texto?)
            SelectableText(texto, style: textos.bodyMedium)
          else
            Text(
              pregunta.desdeTablero
                  ? 'El texto de la pregunta no viene en /board.'
                  : 'GET /questions no trajo el texto de esta pregunta.',
              style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
            ),
          if (pregunta.opciones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('OPCIONES', style: textos.labelSmall),
            const SizedBox(height: 5),
            for (final opcion in pregunta.opciones)
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text('· $opcion', style: textos.bodySmall),
              ),
          ],
        ],
      ),
      pie: Align(
        alignment: Alignment.centerRight,
        child: FilledButton.icon(
          onPressed: alResponder,
          icon: const Icon(Icons.reply, size: 16),
          label: const Text('Responder'),
        ),
      ),
    );
  }

  static String _fecha(DateTime fecha) {
    String dosDigitos(int numero) => numero.toString().padLeft(2, '0');
    return '${fecha.year}-${dosDigitos(fecha.month)}-${dosDigitos(fecha.day)}';
  }
}

/// El formulario de respuesta. Se cierra con `true` solo si el servicio aceptó
/// la respuesta; si falla, se queda abierto con el texto escrito y el error.
class _DialogoResponder extends StatefulWidget {
  const _DialogoResponder({
    required this.id,
    required this.titulo,
    required this.servicio,
  });

  final String id;
  final String? titulo;
  final _ServicioPreguntas servicio;

  @override
  State<_DialogoResponder> createState() => _DialogoResponderState();
}

class _DialogoResponderState extends State<_DialogoResponder> {
  final _formulario = GlobalKey<FormState>();
  final _respuesta = TextEditingController();

  bool _enviando = false;
  FalloDuo? _fallo;

  @override
  void dispose() {
    _respuesta.dispose();
    super.dispose();
  }

  Future<void> _envia() async {
    if (_enviando || !_formulario.currentState!.validate()) return;

    setState(() {
      _enviando = true;
      _fallo = null;
    });

    try {
      await widget.servicio.responde(
        id: widget.id,
        texto: _respuesta.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FalloDuo catch (e) {
      if (!mounted) return;
      setState(() {
        _fallo = e;
        _enviando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final paleta = context.paleta;
    final textos = Theme.of(context).textTheme;

    return AlertDialog(
      backgroundColor: paleta.panel,
      surfaceTintColor: Colors.transparent,
      titlePadding: const EdgeInsets.fromLTRB(22, 20, 22, 0),
      contentPadding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
      actionsPadding: const EdgeInsets.fromLTRB(22, 8, 22, 20),
      title: Row(
        children: [
          Icon(Icons.reply, size: 20, color: paleta.acentoAlt),
          const SizedBox(width: 10),
          Expanded(child: Text('Responder a ${widget.id}')),
          Insignia('POST /questions', tono: paleta.acento, mono: true),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formulario,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.titulo case final titulo?) ...[
                  Text(
                    titulo,
                    style: textos.bodySmall?.copyWith(
                      color: paleta.tintaSecundaria,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Text('RESPUESTA', style: textos.labelSmall),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _respuesta,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 8,
                  enabled: !_enviando,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'Lo que el agente necesita para seguir',
                  ),
                  validator: (valor) => (valor ?? '').trim().isEmpty
                      ? 'Escribe la respuesta: el servicio rechaza una vacía.'
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  'Se envía con POST /questions/${widget.id}/answer y reanuda '
                  'al agente.',
                  style: textos.bodySmall?.copyWith(color: paleta.tintaTenue),
                ),
                if (_fallo case final fallo?) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: paleta.critico.withValues(alpha: .10),
                      border: Border.all(color: paleta.critico),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Mono(fallo.codigo, color: paleta.critico, peso: FontWeight.w700),
                        const SizedBox(height: 5),
                        Text(fallo.mensaje, style: textos.bodySmall),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _enviando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _enviando ? null : _envia,
          icon: _enviando
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(_enviando ? 'Enviando…' : 'Enviar respuesta'),
        ),
      ],
    );
  }
}
