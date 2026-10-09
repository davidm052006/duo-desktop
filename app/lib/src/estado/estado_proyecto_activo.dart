import 'package:flutter/foundation.dart';

import '../datos/cliente_cloud.dart';

/// Proyecto Cloud que el usuario tiene seleccionado para trabajar.
///
/// El tablero global usa esta selección para leer las tareas del proyecto
/// colaborativo en vez de seguir mostrando una pizarra legacy distinta.
class EstadoProyectoActivo extends ChangeNotifier {
  ProyectoCloud? _proyecto;

  ProyectoCloud? get proyecto => _proyecto;

  void seleccionar(ProyectoCloud proyecto) {
    if (_proyecto?.id == proyecto.id) {
      _proyecto = proyecto;
      notifyListeners();
      return;
    }
    _proyecto = proyecto;
    notifyListeners();
  }

  void limpiar() {
    if (_proyecto == null) return;
    _proyecto = null;
    notifyListeners();
  }
}
