import 'dart:async';

import 'package:flutter/foundation.dart';

import '../datos/cliente_duo.dart';
import '../modelos/evento_duo.dart';
import '../modelos/tablero.dart';

enum Fase { inicial, cargando, listo, fallo }

/// Fuente de verdad del workspace.
///
/// Arranca con una lectura HTTP para que la UI tenga datos aunque el WebSocket
/// tarde en abrir. Después /events pasa a ser la ruta principal. El sondeo solo
/// queda como respaldo mientras el canal en vivo está desconectado.
class EstadoTablero extends ChangeNotifier {
  EstadoTablero({
    ClienteDuo? cliente,
    this.intervalo = const Duration(seconds: 5),
    this.reconexion = const Duration(seconds: 2),
  }) : _cliente = cliente ?? ClienteDuo();

  final ClienteDuo _cliente;
  final Duration intervalo;
  final Duration reconexion;

  Timer? _reloj;
  Timer? _reintentoEventos;
  StreamSubscription<EventoDuo>? _suscripcionEventos;
  bool _enVuelo = false;
  bool _cerrado = false;

  Fase fase = Fase.inicial;
  Tablero? tablero;
  FalloDuo? fallo;
  FalloDuo? falloEventos;
  DateTime? ultimaLectura;
  bool eventosConectados = false;
  final List<SalidaAgente> salidas = [];

  void arranca() {
    unawaited(refresca());
    _conectaEventos();

    _reloj?.cancel();
    _reloj = Timer.periodic(intervalo, (_) {
      if (!eventosConectados) unawaited(refresca());
    });
  }

  Future<void> refresca() async {
    if (_enVuelo || _cerrado) return;
    _enVuelo = true;

    if (fase == Fase.inicial) {
      fase = Fase.cargando;
      notifyListeners();
    }

    try {
      tablero = await _cliente.tablero();
      fallo = null;
      fase = Fase.listo;
      ultimaLectura = DateTime.now();
    } on FalloDuo catch (e) {
      fallo = e;
      if (tablero == null) fase = Fase.fallo;
    } finally {
      _enVuelo = false;
      if (!_cerrado) notifyListeners();
    }
  }

  void _conectaEventos() {
    if (_cerrado || _suscripcionEventos != null) return;

    _reintentoEventos?.cancel();
    _reintentoEventos = null;

    _suscripcionEventos = _cliente.eventos().listen(
      _recibeEvento,
      onError: _fallanEventos,
      onDone: _terminanEventos,
      cancelOnError: true,
    );
  }

  void _recibeEvento(EventoDuo evento) {
    if (_cerrado) return;

    eventosConectados = true;
    falloEventos = null;

    switch (evento) {
      case EventoTablero(:final tablero):
        this.tablero = tablero;
        fallo = null;
        fase = Fase.listo;
        ultimaLectura = DateTime.now();
      case EventoSalidaAgente(:final tareaId, :final agente, :final texto):
        if (texto.isNotEmpty) {
          salidas.add(
            SalidaAgente(
              tareaId: tareaId,
              agente: agente,
              texto: texto,
              recibida: DateTime.now(),
            ),
          );
          if (salidas.length > 400) {
            salidas.removeRange(0, salidas.length - 400);
          }
        }
    }

    notifyListeners();
  }

  void _fallanEventos(Object error, StackTrace stackTrace) {
    if (_cerrado) return;
    falloEventos = error is FalloDuo
        ? error
        : FalloDuo('websocket_failed', error.toString());
    _desconectaEventos();
  }

  void _terminanEventos() {
    if (_cerrado) return;
    _desconectaEventos();
  }

  void _desconectaEventos() {
    eventosConectados = false;
    final anterior = _suscripcionEventos;
    _suscripcionEventos = null;
    if (anterior != null) unawaited(anterior.cancel());

    if (!_cerrado) {
      notifyListeners();
      _reintentoEventos?.cancel();
      _reintentoEventos = Timer(reconexion, _conectaEventos);
    }
  }

  void limpiaSalidas() {
    if (salidas.isEmpty) return;
    salidas.clear();
    notifyListeners();
  }

  /// Una instalación nueva puede tener el servicio local funcionando sin
  /// haber configurado todavía una pizarra legacy de duo.
  bool get sinProyectoLocal =>
      tablero == null && fallo?.codigo == 'board_not_found';

  /// board_not_found demuestra que el servicio respondió; no debe mostrarse
  /// como una caída del proceso local.
  bool get servicioLocalResponde =>
      tablero != null || fallo?.codigo == 'board_not_found';

  bool get obsoleto => tablero != null && fallo != null;

  @override
  void dispose() {
    _cerrado = true;
    _reloj?.cancel();
    _reintentoEventos?.cancel();
    unawaited(_suscripcionEventos?.cancel());
    _suscripcionEventos = null;
    _cliente.cierra();
    super.dispose();
  }
}
