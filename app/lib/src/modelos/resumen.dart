/// Lo que la pantalla de Inicio deduce del tablero.
///
/// Todo lo de aquí sale de `GET /board` y de nada más: el centro de control no
/// inventa datos que el servicio todavía no da (eventos en vivo, actividad del
/// sistema de archivos, texto de las preguntas). Lo que falta se marca con su
/// fase en la interfaz en vez de rellenarse con mentiras.
library;

import 'tablero.dart';

/// Las cuatro columnas que fija el diseño, en su orden.
///
/// El mapeo con los estados reales de `duo` es el punto que conviene tener
/// escrito: `abierta` es trabajo en curso; `entregada` espera a que David la
/// revise; `esperando` es una tarea parada porque hizo una pregunta.
enum ColumnaTablero {
  enProgreso('En progreso', EstadoTarea.abierta),
  enEspera('En espera', EstadoTarea.entregada),
  decision('Decisión', EstadoTarea.esperando),
  finalizadas('Finalizadas', EstadoTarea.integrada);

  const ColumnaTablero(this.etiqueta, this.estado);

  final String etiqueta;
  final EstadoTarea estado;
}

/// En qué anda un agente *según el tablero*. No es su estado de proceso: el
/// servicio no sabe todavía si hay un CLI vivo detrás (eso llega en Fase 2).
enum EstadoAgente {
  trabajando('trabajando'),
  esperandoDecision('esperando decisión'),
  entregado('entregado'),
  disponible('disponible');

  const EstadoAgente(this.etiqueta);

  final String etiqueta;
}

class ResumenAgente {
  const ResumenAgente({
    required this.alias,
    required this.nombre,
    required this.estado,
    required this.activas,
    required this.tarea,
    required this.carga,
  });

  final String alias;

  /// El nombre humano del agente. Un alias que no conozcamos se muestra tal
  /// cual: mejor un alias desnudo que un nombre inventado.
  final String nombre;
  final EstadoAgente estado;

  /// Tareas suyas que siguen vivas (todo lo que no está integrado).
  final int activas;

  /// La tarea que mejor explica su estado, o `null` si no tiene ninguna viva.
  final Tarea? tarea;

  /// Fracción de la carga total del equipo, entre 0 y 1.
  final double carga;

  static const _nombres = {
    'cc': 'Claude Code',
    'codex': 'Codex CLI',
    'chat': 'ChatGPT',
  };

  static String nombreDe(String alias) => _nombres[alias] ?? alias;
}

/// El estado del centro de control en un instante.
class ResumenInicio {
  const ResumenInicio({
    required this.agentes,
    required this.porColumna,
    required this.totalTareas,
    required this.pendientesDeDecision,
  });

  final List<ResumenAgente> agentes;
  final Map<ColumnaTablero, int> porColumna;
  final int totalTareas;

  /// Tareas paradas a la espera de una respuesta de David. Mientras no exista
  /// `GET /questions` (Fase 3), esto es lo más cerca que estamos de contar
  /// preguntas abiertas, y se dice así en pantalla.
  final List<Tarea> pendientesDeDecision;

  int get activos => agentes.where((a) => a.estado != EstadoAgente.disponible).length;

  /// Tareas vivas en total: lo que se reparte entre los agentes.
  int get activas => agentes.fold(0, (suma, a) => suma + a.activas);

  factory ResumenInicio.desde(Tablero tablero) {
    final tareas = tablero.tareas;
    final vivas = tareas.where((t) => t.estado != EstadoTarea.integrada).toList();

    // El orden del ledger manda: es el mismo que ve `duo status`, y así los
    // agentes no bailan de sitio entre refrescos.
    final alias = <String>{
      for (final a in tablero.agentes) a.agente,
      // Un agente con tareas pero sin fila en el ledger existe igualmente.
      for (final t in tareas)
        if (!tablero.agentes.any((a) => a.agente == t.dueno)) t.dueno,
    };

    final agentes = [
      for (final a in alias) _resumeAgente(a, vivas),
    ];

    return ResumenInicio(
      agentes: agentes,
      porColumna: {
        for (final c in ColumnaTablero.values)
          c: tareas.where((t) => t.estado == c.estado).length,
      },
      totalTareas: tareas.length,
      pendientesDeDecision:
          tareas.where((t) => t.estado == EstadoTarea.esperando).toList(growable: false),
    );
  }

  static ResumenAgente _resumeAgente(String alias, List<Tarea> vivas) {
    final suyas = vivas.where((t) => t.dueno == alias).toList();

    // Una pregunta sin responder bloquea de verdad: pesa más que una tarea en
    // curso a la hora de resumir en una palabra qué le pasa al agente.
    final tarea = _primeraCon(suyas, EstadoTarea.esperando) ??
        _primeraCon(suyas, EstadoTarea.abierta) ??
        _primeraCon(suyas, EstadoTarea.entregada) ??
        (suyas.isEmpty ? null : suyas.first);

    final estado = switch (tarea?.estado) {
      EstadoTarea.esperando => EstadoAgente.esperandoDecision,
      EstadoTarea.abierta => EstadoAgente.trabajando,
      EstadoTarea.entregada => EstadoAgente.entregado,
      _ => EstadoAgente.disponible,
    };

    return ResumenAgente(
      alias: alias,
      nombre: ResumenAgente.nombreDe(alias),
      estado: estado,
      activas: suyas.length,
      tarea: tarea,
      // La fracción se completa fuera: aquí todavía no sabemos el total.
      carga: vivas.isEmpty ? 0 : suyas.length / vivas.length,
    );
  }

  static Tarea? _primeraCon(List<Tarea> tareas, EstadoTarea estado) {
    for (final t in tareas) {
      if (t.estado == estado) return t;
    }
    return null;
  }
}
