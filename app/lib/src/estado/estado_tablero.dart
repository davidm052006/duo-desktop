import 'dart:async';

import 'package:flutter/foundation.dart';

import '../datos/cliente_duo.dart';
import '../modelos/tablero.dart';

enum Fase { inicial, cargando, listo, fallo }

/// El estado del tablero en la app.
///
/// Fase 1 refresca por sondeo. Cuando exista el WebSocket de la Fase 2, lo que
/// cambia es de dónde llegan los datos, no esta interfaz.
class EstadoTablero extends ChangeNotifier {
  EstadoTablero({ClienteDuo? cliente, this.intervalo = const Duration(seconds: 5)})
    : _cliente = cliente ?? ClienteDuo();

  final ClienteDuo _cliente;
  final Duration intervalo;

  Timer? _reloj;
  bool _enVuelo = false;

  Fase fase = Fase.inicial;
  Tablero? tablero;
  FalloDuo? fallo;
  DateTime? ultimaLectura;

  /// Primera carga más el sondeo periódico.
  void arranca() {
    refresca();
    _reloj?.cancel();
    _reloj = Timer.periodic(intervalo, (_) => refresca());
  }

  Future<void> refresca() async {
    // Si el servicio va lento, no apilamos peticiones encima.
    if (_enVuelo) return;
    _enVuelo = true;

    // Solo mostramos el spinner la primera vez: en los refrescos siguientes ya
    // hay datos en pantalla y hacerlos parpadear es peor que esperar.
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
      // Un fallo pasajero no debe borrar un tablero que ya se veía bien.
      if (tablero == null) fase = Fase.fallo;
    } finally {
      _enVuelo = false;
      notifyListeners();
    }
  }

  /// Hay datos en pantalla pero el último refresco falló.
  bool get obsoleto => tablero != null && fallo != null;

  @override
  void dispose() {
    _reloj?.cancel();
    _cliente.cierra();
    super.dispose();
  }
}
