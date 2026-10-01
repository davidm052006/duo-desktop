/// Los modelos del tablero, tal y como los entrega `GET /board`.
///
/// El JSON viene en inglés porque es el contrato HTTP (docs/api/CONTRATO_BOARD.md);
/// de este archivo hacia adentro la app habla español. La traducción ocurre
/// aquí y en ningún otro sitio.
library;

enum EstadoTarea {
  abierta,
  esperando,
  entregada,
  integrada,
  desconocido;

  /// El servicio devuelve el estado literal de `BOARD.md`, sin interpretarlo.
  /// Si aparece uno nuevo no se rompe la app: cae en `desconocido`.
  static EstadoTarea desdeTexto(String texto) => values.firstWhere(
    (e) => e.name == texto.trim().toLowerCase(),
    orElse: () => EstadoTarea.desconocido,
  );
}

class Tarea {
  const Tarea({
    required this.id,
    required this.titulo,
    required this.dueno,
    required this.rama,
    required this.estado,
    required this.estadoCrudo,
    required this.abierta,
  });

  final String id;
  final String titulo;
  final String dueno;
  final String rama;
  final EstadoTarea estado;

  /// El texto original, para mostrarlo incluso si es un estado que no conocemos.
  final String estadoCrudo;
  final DateTime abierta;

  factory Tarea.desdeJson(Map<String, dynamic> json) {
    final estado = json['status'] as String;
    return Tarea(
      id: json['id'] as String,
      titulo: json['title'] as String,
      dueno: json['owner'] as String,
      rama: json['branch'] as String,
      estado: EstadoTarea.desdeTexto(estado),
      estadoCrudo: estado,
      abierta: DateTime.parse(json['opened'] as String),
    );
  }
}

class CargaAgente {
  const CargaAgente({
    required this.agente,
    required this.puntos,
    required this.tareas,
    required this.ultima,
  });

  final String agente;
  final int puntos;
  final int tareas;

  /// `null` cuando el agente no ha cerrado nada todavía (el `-` del ledger).
  final DateTime? ultima;

  factory CargaAgente.desdeJson(Map<String, dynamic> json) {
    final ultima = json['last'] as String?;
    return CargaAgente(
      agente: json['agent'] as String,
      puntos: json['points'] as int,
      tareas: json['tasks'] as int,
      ultima: ultima == null ? null : DateTime.parse(ultima),
    );
  }
}

class Proyecto {
  const Proyecto({required this.nombre, required this.repo, required this.pizarra});

  final String nombre;
  final String repo;
  final String pizarra;

  factory Proyecto.desdeJson(Map<String, dynamic> json) => Proyecto(
    nombre: json['name'] as String,
    repo: json['repo'] as String? ?? '',
    pizarra: json['board'] as String? ?? '',
  );
}

class Tablero {
  const Tablero({
    required this.proyecto,
    required this.tareas,
    required this.agentes,
  });

  final Proyecto? proyecto;
  final List<Tarea> tareas;
  final List<CargaAgente> agentes;

  factory Tablero.desdeJson(Map<String, dynamic> json) {
    final board = json['board'] as Map<String, dynamic>;
    final ledger = json['ledger'] as Map<String, dynamic>;
    final proyecto = json['project'] as Map<String, dynamic>?;

    return Tablero(
      // `project` es una extensión posterior al contrato v1: puede no venir.
      proyecto: proyecto == null ? null : Proyecto.desdeJson(proyecto),
      tareas: (board['tasks'] as List)
          .cast<Map<String, dynamic>>()
          .map(Tarea.desdeJson)
          .toList(growable: false),
      agentes: (ledger['agents'] as List)
          .cast<Map<String, dynamic>>()
          .map(CargaAgente.desdeJson)
          .toList(growable: false),
    );
  }

  /// Para dimensionar las barras de carga sin que una barra vacía las rompa.
  int get puntosMaximos =>
      agentes.fold(0, (max, a) => a.puntos > max ? a.puntos : max);

  Iterable<Tarea> tareasDe(String agente) => tareas.where((t) => t.dueno == agente);
}
